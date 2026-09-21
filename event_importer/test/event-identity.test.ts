import { describe, expect, it } from "vitest";

import { eventDedupeKey, normalizeTitle } from "../src/event-identity.js";
import type { EventCandidate } from "../src/types.js";

describe("event identity", () => {
  it("normalizes common event prefixes and punctuation", () => {
    expect(normalizeTitle("งาน  เทศกาลผ้าไทย 2026!"))
      .toBe("เทศกาลผ้าไทย 2026");
  });

  it("matches the same source title across Thai and English records", () => {
    const first = candidate({ title: "งานทดสอบ", originalTitle: "Fabric Festival" });
    const second = candidate({ title: "Fabric Festival", sourceKey: "another-source" });
    expect(eventDedupeKey(first)).toBe(eventDedupeKey(second));
  });
});

function candidate(overrides: Partial<EventCandidate>): EventCandidate {
  return {
    title: "Fabric Festival",
    description: "A test event",
    province: "เชียงใหม่",
    locationName: "เมืองเชียงใหม่",
    startDate: new Date("2026-10-01T00:00:00Z"),
    endDate: new Date("2026-10-02T00:00:00Z"),
    imageUrl: "",
    sourceName: "Test Source",
    sourceUrl: "https://example.com/events/1",
    sourceKey: "test-source",
    sourceEventId: "1",
    fingerprint: "a".repeat(64),
    qualityFlags: [],
    sourceLanguage: "en",
    ...overrides,
  };
}
