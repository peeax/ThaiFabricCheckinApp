import { createHash } from "node:crypto";

import { applicationDefault, initializeApp } from "firebase-admin/app";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import {
  normalizeProvinceName,
  parseCheckInInput,
  provinceFromGeocodingResponse,
} from "./validation.js";

initializeApp({ credential: applicationDefault() });
setGlobalOptions({ region: "asia-southeast1", maxInstances: 10 });

const db = getFirestore();
const geocodingApiKey = defineSecret("GOOGLE_GEOCODING_API_KEY");
const tatApiKey = defineSecret("TAT_API_KEY");
const checkInCooldownMs = 30_000;
const dailyCheckInAttemptLimit = 20;
const attractionCacheTtlMs = 6 * 60 * 60 * 1_000;

export const checkInProvince = onCall(
  {
    enforceAppCheck: true,
    secrets: [geocodingApiKey],
    timeoutSeconds: 30,
  },
  async (request) => {
    const uid = requireUser(request.auth?.uid);
    const input = parseCheckInInput(request.data);
    await consumeCheckInAttempt(uid);

    const detectedProvince = await reverseGeocodeProvince(
      input.latitude,
      input.longitude,
      geocodingApiKey.value(),
    );
    if (detectedProvince !== input.provinceName) {
      throw new HttpsError(
        "failed-precondition",
        "The verified location does not match the selected province",
      );
    }

    const provinceRef = db.collection("provinces").doc(detectedProvince);
    const userRef = db.collection("users").doc(uid);
    const checkInRef = userRef.collection("checkins").doc(detectedProvince);
    const leaderboardRef = db.collection("leaderboardProfiles").doc(uid);

    const provinceData = await db.runTransaction(async (transaction) => {
      const [provinceDoc, userDoc, checkInDoc] = await Promise.all([
        transaction.get(provinceRef),
        transaction.get(userRef),
        transaction.get(checkInRef),
      ]);
      if (!provinceDoc.exists) {
        throw new HttpsError("not-found", "Province is not available");
      }
      if (!userDoc.exists) {
        throw new HttpsError("failed-precondition", "User profile is incomplete");
      }
      if (checkInDoc.exists) {
        throw new HttpsError("already-exists", "Province already checked in");
      }

      const province = provinceDoc.data() ?? {};
      const username = String(userDoc.get("username") ?? "ไม่ระบุชื่อ");
      transaction.create(checkInRef, {
        ...province,
        provinceId: detectedProvince,
        at: FieldValue.serverTimestamp(),
        verifiedAt: FieldValue.serverTimestamp(),
        verificationMethod: "server-geocoding-v1",
        accuracyMeters: input.accuracyMeters,
      });
      transaction.update(userRef, {
        stampCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        leaderboardRef,
        {
          username,
          stampCount: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return province;
    });

    return { provinceId: detectedProvince, province: provinceData };
  },
);

export const fetchAttractions = onCall(
  {
    enforceAppCheck: true,
    secrets: [tatApiKey],
    timeoutSeconds: 30,
  },
  async (request) => {
    requireUser(request.auth?.uid);
    const province = normalizeProvinceName(
      (request.data as Record<string, unknown> | null)?.provinceName,
    );
    if (!province || province.length > 60) {
      throw new HttpsError("invalid-argument", "Invalid province");
    }
    const provinceDoc = await db.collection("provinces").doc(province).get();
    if (!provinceDoc.exists) {
      throw new HttpsError("not-found", "Province is not available");
    }

    const cacheId = createHash("sha256").update(province).digest("hex");
    const cacheRef = db.collection("attractionCache").doc(cacheId);
    const cached = await cacheRef.get();
    const expiresAt = cached.get("expiresAt");
    if (
      cached.exists &&
      expiresAt instanceof Timestamp &&
      expiresAt.toMillis() > Date.now()
    ) {
      return { items: cached.get("items") ?? [], cached: true };
    }

    const url = new URL("https://tatdataapi.io/api/v2/places");
    url.searchParams.set("keyword", province);
    url.searchParams.set("limit", "20");
    const response = await fetch(url, {
      headers: {
        "x-api-key": tatApiKey.value(),
        "Accept-Language": "th",
      },
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) {
      throw new HttpsError("unavailable", "Attraction service is unavailable");
    }
    const payload = (await response.json()) as { data?: unknown };
    const items = Array.isArray(payload.data) ? payload.data.slice(0, 20) : [];
    await cacheRef.set({
      province,
      items,
      fetchedAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(Date.now() + attractionCacheTtlMs),
    });
    return { items, cached: false };
  },
);

function requireUser(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "Sign-in is required");
  return uid;
}

async function consumeCheckInAttempt(uid: string): Promise<void> {
  const ref = db.collection("checkInRateLimits").doc(uid);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const now = Date.now();
    const day = new Date(now).toISOString().slice(0, 10);
    const previousDay = snapshot.get("day");
    const previousCount = previousDay === day ? Number(snapshot.get("count") ?? 0) : 0;
    const previousAttempt = snapshot.get("lastAttemptAt");
    if (
      previousAttempt instanceof Timestamp &&
      now - previousAttempt.toMillis() < checkInCooldownMs
    ) {
      throw new HttpsError("resource-exhausted", "Please wait before trying again");
    }
    if (previousCount >= dailyCheckInAttemptLimit) {
      throw new HttpsError("resource-exhausted", "Daily check-in limit reached");
    }
    transaction.set(ref, {
      day,
      count: previousCount + 1,
      lastAttemptAt: FieldValue.serverTimestamp(),
    });
  });
}

async function reverseGeocodeProvince(
  latitude: number,
  longitude: number,
  apiKey: string,
): Promise<string> {
  const url = new URL("https://maps.googleapis.com/maps/api/geocode/json");
  url.searchParams.set("latlng", `${latitude},${longitude}`);
  url.searchParams.set("language", "th");
  url.searchParams.set("result_type", "administrative_area_level_1");
  url.searchParams.set("key", apiKey);
  const response = await fetch(url, { signal: AbortSignal.timeout(10_000) });
  if (!response.ok) {
    throw new HttpsError("unavailable", "Location verification is unavailable");
  }
  const province = provinceFromGeocodingResponse(await response.json());
  if (!province) {
    throw new HttpsError("failed-precondition", "Province could not be verified");
  }
  return province;
}
