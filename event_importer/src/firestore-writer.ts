import { FieldValue, Firestore, Timestamp } from "@google-cloud/firestore";

import { documentIdForFingerprint } from "./fingerprint.js";
import type { EventCandidate } from "./types.js";

export type WriteResult = {
  created: number;
  updated: number;
  protected: number;
};

export async function writeDraftEvents(
  events: EventCandidate[],
  maximumWrites: number,
): Promise<WriteResult> {
  const projectId = process.env.FIREBASE_PROJECT_ID;
  if (!projectId) {
    throw new Error("FIREBASE_PROJECT_ID is required when --write is used");
  }
  const firestore = new Firestore({ projectId });
  const result: WriteResult = { created: 0, updated: 0, protected: 0 };
  let writes = 0;

  for (const event of events) {
    if (writes >= maximumWrites) break;
    const deterministicRef = firestore
      .collection("events")
      .doc(documentIdForFingerprint(event.fingerprint));
    const duplicate = await firestore
      .collection("events")
      .where("fingerprint", "==", event.fingerprint)
      .limit(1)
      .get();
    const ref = duplicate.docs[0]?.ref ?? deterministicRef;
    const existing = await ref.get();
    const sourceSnapshot = serializeCandidate(event);

    if (!existing.exists) {
      await ref.set({
        ...sourceSnapshot,
        status: "draft",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        importedAt: FieldValue.serverTimestamp(),
        lastSeenAt: FieldValue.serverTimestamp(),
        createdBy: `importer:${event.sourceKey}`,
        updatedBy: `importer:${event.sourceKey}`,
        sourceSnapshot,
        importerVersion: "0.1.0",
      });
      result.created += 1;
      writes += 1;
      continue;
    }

    const current = existing.data() ?? {};
    const importerOwnsDraft =
      current.status === "draft" &&
      String(current.updatedBy ?? "").startsWith("importer:");
    if (!importerOwnsDraft) {
      await ref.update({
        lastSeenAt: FieldValue.serverTimestamp(),
        sourceSnapshot,
        importerVersion: "0.1.0",
      });
      result.protected += 1;
      writes += 1;
      continue;
    }

    await ref.update({
      ...sourceSnapshot,
      updatedAt: FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
      updatedBy: `importer:${event.sourceKey}`,
      sourceSnapshot,
      importerVersion: "0.1.0",
    });
    result.updated += 1;
    writes += 1;
  }

  return result;
}

function serializeCandidate(event: EventCandidate) {
  return {
    ...event,
    startDate: Timestamp.fromDate(event.startDate),
    endDate: Timestamp.fromDate(event.endDate),
  };
}
