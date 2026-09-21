import { createHash } from "node:crypto";

import type { EventCandidate, RawEventSnapshot } from "./types.js";

export function snapshotFor(
  event: EventCandidate,
  rawData: unknown,
  retrievedAt: Date,
): RawEventSnapshot {
  return {
    sourceKey: event.sourceKey,
    sourceEventId: event.sourceEventId,
    sourceUrl: event.sourceUrl,
    retrievedAt,
    contentHash: hashJson(rawData),
    rawData,
  };
}

export function hashJson(value: unknown): string {
  return createHash("sha256").update(stableJson(value)).digest("hex");
}

export function stableJson(value: unknown): string {
  if (Array.isArray(value)) {
    return `[${value.map(stableJson).join(",")}]`;
  }
  if (value && typeof value === "object") {
    const entries = Object.entries(value as Record<string, unknown>).sort(
      ([left], [right]) => left.localeCompare(right),
    );
    return `{${entries
      .map(([key, child]) => `${JSON.stringify(key)}:${stableJson(child)}`)
      .join(",")}}`;
  }
  return JSON.stringify(value) ?? "null";
}
