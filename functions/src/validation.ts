import { HttpsError } from "firebase-functions/v2/https";

export type CheckInInput = {
  latitude: number;
  longitude: number;
  accuracyMeters: number;
  provinceName: string;
  isMocked: boolean;
};

export function parseCheckInInput(data: unknown): CheckInInput {
  const value = data as Record<string, unknown> | null;
  const latitude = value?.latitude;
  const longitude = value?.longitude;
  const accuracyMeters = value?.accuracyMeters;
  const provinceName = normalizeProvinceName(value?.provinceName);
  const isMocked = value?.isMocked === true;

  if (
    typeof latitude !== "number" ||
    !Number.isFinite(latitude) ||
    latitude < -90 ||
    latitude > 90 ||
    typeof longitude !== "number" ||
    !Number.isFinite(longitude) ||
    longitude < -180 ||
    longitude > 180
  ) {
    throw new HttpsError("invalid-argument", "Invalid coordinates");
  }
  if (
    typeof accuracyMeters !== "number" ||
    !Number.isFinite(accuracyMeters) ||
    accuracyMeters < 0 ||
    accuracyMeters > 1_000
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Location accuracy is insufficient",
    );
  }
  if (!provinceName || provinceName.length > 60) {
    throw new HttpsError("invalid-argument", "Invalid province");
  }
  if (isMocked) {
    throw new HttpsError("failed-precondition", "Mock locations are not allowed");
  }

  return { latitude, longitude, accuracyMeters, provinceName, isMocked };
}

export function normalizeProvinceName(value: unknown): string {
  if (typeof value !== "string") return "";
  const normalized = value
    .normalize("NFKC")
    .replace(/^จังหวัด/, "")
    .replace(/^จ\.\s*/, "")
    .trim();
  if (normalized === "กรุงเทพฯ" || normalized === "กรุงเทพ") {
    return "กรุงเทพมหานคร";
  }
  return normalized;
}

export function provinceFromGeocodingResponse(payload: unknown): string | null {
  const results = (payload as { results?: unknown[] } | null)?.results;
  if (!Array.isArray(results)) return null;
  for (const result of results) {
    const components = (result as { address_components?: unknown[] })
      .address_components;
    if (!Array.isArray(components)) continue;
    for (const component of components) {
      const candidate = component as { long_name?: unknown; types?: unknown[] };
      if (
        Array.isArray(candidate.types) &&
        candidate.types.includes("administrative_area_level_1")
      ) {
        const province = normalizeProvinceName(candidate.long_name);
        return province || null;
      }
    }
  }
  return null;
}
