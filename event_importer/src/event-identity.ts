import { createFingerprint } from "./fingerprint.js";
import type { EventCandidate } from "./types.js";

export function eventDedupeKey(event: EventCandidate): string {
  return createFingerprint([
    normalizeTitle(event.originalTitle ?? event.title),
    event.province,
    dateKey(event.startDate),
  ]);
}

export function eventDocumentId(event: EventCandidate): string {
  return `event_${eventDedupeKey(event).slice(0, 28)}`;
}

export function sourceReferenceId(sourceKey: string, sourceEventId: string): string {
  return createFingerprint([sourceKey, sourceEventId]);
}

export function dateKey(date: Date): string {
  return date.toISOString().slice(0, 10);
}

export function normalizeTitle(value: string): string {
  return value
    .normalize("NFKC")
    .toLowerCase()
    .replace(/^(งาน|เทศกาล|กิจกรรม)\s*/u, "")
    .replace(/[^a-z0-9\u0E00-\u0E7F]+/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}
