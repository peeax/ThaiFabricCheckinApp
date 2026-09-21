import { describe, expect, it } from "vitest";

import { parseTatProductActivities } from "../src/sources/tat-product-calendar.js";

describe("TAT product calendar", () => {
  it("normalizes official activities", () => {
    const result = parseTatProductActivities(
      [
        {
          id: "42",
          name: "งานผ้าไทยเชียงใหม่",
          name_en: "Chiang Mai Fabric Festival",
          description: "กิจกรรมผ้าไทยและงานหัตถกรรม",
          startDate: "2026-10-01",
          endDate: "2026-10-03",
          province: "จ. เชียงใหม่",
          location: "ลานประตูท่าแพ",
        },
      ],
      new Date("2026-09-21T00:00:00Z"),
    );

    expect(result.errors).toEqual([]);
    expect(result.events[0]).toMatchObject({
      title: "งานผ้าไทยเชียงใหม่",
      province: "เชียงใหม่",
      locationName: "ลานประตูท่าแพ",
      sourceEventId: "activity:42",
    });
    expect(result.snapshots).toHaveLength(1);
  });

  it("rejects unknown provinces", () => {
    const result = parseTatProductActivities(
      [
        {
          id: "99",
          name: "Unknown event",
          description: "Unknown place",
          startDate: "2026-10-01",
          province: "Atlantis",
        },
      ],
      new Date("2026-09-21T00:00:00Z"),
    );
    expect(result.events).toEqual([]);
    expect(result.errors).toHaveLength(1);
  });
});
