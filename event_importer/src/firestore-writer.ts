import {
  FieldValue,
  Firestore,
  Timestamp,
  type DocumentSnapshot,
} from "@google-cloud/firestore";

import {
  dateKey,
  eventDedupeKey,
  eventDocumentId,
  sourceReferenceId,
} from "./event-identity.js";
import { documentIdForFingerprint } from "./fingerprint.js";
import type {
  EventCandidate,
  ImportSummary,
  RawEventSnapshot,
  SourceAdapter,
} from "./types.js";

export type WriteResult = {
  created: number;
  updated: number;
  duplicates: number;
  protected: number;
};

type CandidateGroup = {
  event: EventCandidate;
  sourceRefs: Array<Record<string, unknown>>;
};

export class ImportStore {
  constructor(readonly firestore: Firestore) {}

  static fromEnvironment(): ImportStore {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    if (!projectId) {
      throw new Error("FIREBASE_PROJECT_ID is required when --write is used");
    }
    return new ImportStore(
      new Firestore({ projectId, ignoreUndefinedProperties: true }),
    );
  }

  async filterEnabledSources(sources: SourceAdapter[]): Promise<SourceAdapter[]> {
    const refs = sources.map((source) =>
      this.firestore.collection("eventSources").doc(source.key),
    );
    const snapshots = await this.firestore.getAll(...refs);
    const writer = this.firestore.bulkWriter();

    for (const [index, source] of sources.entries()) {
      const ref = refs[index]!;
      const snapshot = snapshots[index]!;
      const metadata = {
        name: source.name,
        sourceUrl: source.sourceUrl,
        scheduleGroup: source.scheduleGroup,
        fetchIntervalHours: intervalHours(source.scheduleGroup),
        adapterAvailable: true,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (snapshot.exists) {
        writer.set(ref, metadata, { merge: true });
      } else {
        writer.set(ref, {
          ...metadata,
          enabled: source.enabledByDefault,
          createdAt: FieldValue.serverTimestamp(),
          consecutiveFailures: 0,
        });
      }
    }
    await writer.close();

    return sources.filter((source, index) => {
      const snapshot = snapshots[index]!;
      if (!snapshot.exists) return source.enabledByDefault;
      return snapshot.data()?.enabled !== false;
    });
  }

  async beginRun(
    summary: Pick<ImportSummary, "runId" | "trigger" | "group" | "dryRun">,
  ) {
    await this.firestore.collection("importRuns").doc(summary.runId).set({
      ...summary,
      status: "running",
      startedAt: FieldValue.serverTimestamp(),
    });
  }

  async finishRun(
    summary: ImportSummary,
    status: "success" | "warning" | "failed",
  ) {
    await this.firestore.collection("importRuns").doc(summary.runId).set(
      {
        trigger: summary.trigger,
        group: summary.group,
        dryRun: summary.dryRun,
        status,
        found: summary.found,
        valid: summary.valid,
        rejected: summary.rejected,
        created: summary.created,
        updated: summary.updated,
        duplicates: summary.duplicates,
        protected: summary.protected,
        sources: summary.sources,
        errors: summary.errors.slice(0, 50),
        warnings: summary.warnings.slice(0, 50),
        finishedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  }

  async markSourceResult(
    source: SourceAdapter,
    succeeded: boolean,
    counts: { found: number; rejected: number },
  ) {
    const payload: Record<string, unknown> = {
      lastAttemptAt: FieldValue.serverTimestamp(),
      lastFound: counts.found,
      lastRejected: counts.rejected,
    };
    if (succeeded) {
      payload.lastSuccessAt = FieldValue.serverTimestamp();
      payload.consecutiveFailures = 0;
    } else {
      payload.consecutiveFailures = FieldValue.increment(1);
    }
    await this.firestore.collection("eventSources").doc(source.key).set(payload, {
      merge: true,
    });
  }

  async writeDraftEvents(
    events: EventCandidate[],
    snapshots: RawEventSnapshot[],
    maximumWrites: number,
  ): Promise<WriteResult> {
    const selectedEvents = events.slice(0, maximumWrites);
    const groups = groupCandidates(selectedEvents);
    const result: WriteResult = {
      created: 0,
      updated: 0,
      duplicates: selectedEvents.length - groups.size,
      protected: 0,
    };
    if (groups.size === 0) return result;

    const grouped = [...groups.values()];
    const canonicalRefs = grouped.map(({ event }) =>
      this.firestore.collection("events").doc(eventDocumentId(event)),
    );
    const legacyRefs = grouped.map(({ event }) =>
      this.firestore
        .collection("events")
        .doc(documentIdForFingerprint(event.fingerprint)),
    );
    const [canonicalSnapshots, legacySnapshots, matchingSnapshots] =
      await Promise.all([
        this.firestore.getAll(...canonicalRefs),
        this.firestore.getAll(...legacyRefs),
        this.findByDedupeKeys(grouped.map(({ event }) => eventDedupeKey(event))),
      ]);

    const matchesByKey = new Map(
      matchingSnapshots.map((snapshot) => [
        String(snapshot.data()?.dedupeKey ?? ""),
        snapshot,
      ]),
    );
    const writer = this.firestore.bulkWriter();

    for (const [index, group] of grouped.entries()) {
      const { event, sourceRefs } = group;
      const dedupeKey = eventDedupeKey(event);
      const canonical = canonicalSnapshots[index]!;
      const legacy = legacySnapshots[index]!;
      const existing = canonical.exists
        ? canonical
        : legacy.exists
          ? legacy
          : matchesByKey.get(dedupeKey);
      const ref = existing?.ref ?? canonicalRefs[index]!;
      const sourceSnapshot = serializeCandidate(event, sourceRefs, dedupeKey);

      if (!existing?.exists) {
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
          importerVersion: "0.3.0",
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
          sourceRefs,
          sourceSnapshot,
          importerVersion: "0.3.0",
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
        importerVersion: "0.3.0",
      });
      result.updated += 1;
    }

    const selectedSourceIds = new Set(
      selectedEvents.map((event) =>
        sourceReferenceId(event.sourceKey, event.sourceEventId),
      ),
    );
    for (const snapshot of snapshots) {
      const snapshotId = sourceReferenceId(
        snapshot.sourceKey,
        snapshot.sourceEventId,
      );
      if (!selectedSourceIds.has(snapshotId)) continue;
      const expiresAt = new Date(snapshot.retrievedAt);
      expiresAt.setUTCDate(expiresAt.getUTCDate() + 60);
      writer.set(
        this.firestore.collection("rawEventSnapshots").doc(snapshotId),
        {
          ...snapshot,
          retrievedAt: Timestamp.fromDate(snapshot.retrievedAt),
          expiresAt: Timestamp.fromDate(expiresAt),
        },
        { merge: true },
      );
    }

    await writer.close();
    return result;
  }

  async cleanupExpiredSnapshots(limit = 200): Promise<number> {
    const expired = await this.firestore
      .collection("rawEventSnapshots")
      .where("expiresAt", "<=", Timestamp.now())
      .limit(limit)
      .get();
    if (expired.empty) return 0;
    const writer = this.firestore.bulkWriter();
    for (const snapshot of expired.docs) writer.delete(snapshot.ref);
    await writer.close();
    return expired.size;
  }

  private async findByDedupeKeys(
    keys: string[],
  ): Promise<Array<DocumentSnapshot<Record<string, unknown>>>> {
    const snapshots: Array<DocumentSnapshot<Record<string, unknown>>> = [];
    for (const keyGroup of chunks([...new Set(keys)], 30)) {
      const result = await this.firestore
        .collection("events")
        .where("dedupeKey", "in", keyGroup)
        .get();
      snapshots.push(...result.docs);
    }
    return snapshots;
  }
}

function groupCandidates(events: EventCandidate[]): Map<string, CandidateGroup> {
  const groups = new Map<string, CandidateGroup>();
  for (const event of events) {
    const key = eventDedupeKey(event);
    const sourceRef = serializeSourceRef(event);
    const existing = groups.get(key);
    if (!existing) {
      groups.set(key, { event, sourceRefs: [sourceRef] });
      continue;
    }
    existing.sourceRefs.push(sourceRef);
    existing.event = preferCandidate(existing.event, event);
  }
  return groups;
}

function preferCandidate(left: EventCandidate, right: EventCandidate): EventCandidate {
  return candidateScore(right) > candidateScore(left) ? right : left;
}

function candidateScore(event: EventCandidate): number {
  return (
    (event.sourceLanguage === "th" ? 4 : 0) +
    (event.imageUrl ? 2 : 0) +
    Math.min(event.description.length / 200, 2) -
    event.qualityFlags.filter((flag) => flag.includes("review")).length
  );
}

function serializeSourceRef(event: EventCandidate) {
  return {
    sourceKey: event.sourceKey,
    sourceEventId: event.sourceEventId,
    sourceName: event.sourceName,
    sourceUrl: event.sourceUrl,
    fingerprint: event.fingerprint,
  };
}

function serializeCandidate(
  event: EventCandidate,
  sourceRefs: Array<Record<string, unknown>>,
  dedupeKey: string,
) {
  return {
    ...event,
    startDate: dateKey(event.startDate),
    endDate: dateKey(event.endDate),
    dedupeKey,
    sourceRefs,
  };
}

function intervalHours(group: SourceAdapter["scheduleGroup"]): number {
  if (group === "frequent") return 6;
  if (group === "daily") return 24;
  return 168;
}

function chunks<T>(values: T[], size: number): T[][] {
  const result: T[][] = [];
  for (let index = 0; index < values.length; index += size) {
    result.push(values.slice(index, index + size));
  }
  return result;
}

export async function writeDraftEvents(
  events: EventCandidate[],
  maximumWrites: number,
): Promise<WriteResult> {
  return ImportStore.fromEnvironment().writeDraftEvents(events, [], maximumWrites);
}
