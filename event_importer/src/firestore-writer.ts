import { FieldValue, Firestore } from "@google-cloud/firestore";

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
  const selectedEvents = events.slice(0, maximumWrites);
  const refs = selectedEvents.map((event) =>
    firestore.collection("events").doc(documentIdForFingerprint(event.fingerprint)),
  );
  const existingSnapshots = await firestore.getAll(...refs);
  const writer = firestore.bulkWriter();

  for (const [index, event] of selectedEvents.entries()) {
    const ref = refs[index]!;
    const existing = existingSnapshots[index]!;
    const sourceSnapshot = serializeCandidate(event);

    if (!existing.exists) {
      writer.set(ref, {
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
      continue;
    }

    const current = existing.data() ?? {};
    const importerOwnsDraft =
      current.status === "draft" &&
      String(current.updatedBy ?? "").startsWith("importer:");
    if (!importerOwnsDraft) {
      writer.update(ref, {
        lastSeenAt: FieldValue.serverTimestamp(),
        sourceSnapshot,
        importerVersion: "0.1.0",
      });
      result.protected += 1;
      continue;
    }

    writer.update(ref, {
      ...sourceSnapshot,
      updatedAt: FieldValue.serverTimestamp(),
      lastSeenAt: FieldValue.serverTimestamp(),
      updatedBy: `importer:${event.sourceKey}`,
      sourceSnapshot,
      importerVersion: "0.1.0",
    });
    result.updated += 1;
  }

  await writer.close();
  return result;
}

function serializeCandidate(event: EventCandidate) {
  return {
    ...event,
    startDate: dateKey(event.startDate),
    endDate: dateKey(event.endDate),
  };
}

function dateKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}
