import { describe, expect, it } from "vitest";

import { parseNewsroomFeaturePosts } from "../src/sources/tat-newsroom-features.js";

describe("TAT Newsroom feature source", () => {
  it("creates review-required drafts for future event articles", () => {
    const result = parseNewsroomFeaturePosts(
      [
        {
          id: 88749,
          link: "https://www.tatnews.org/example/",
          title: { rendered: "Bangkok Art Biennale 2026" },
          excerpt: {
            rendered:
              "Running from 29 October 2026 to 28 February 2027 across Bangkok.",
          },
          content: { rendered: "" },
          _embedded: {
            "wp:featuredmedia": [{ source_url: "https://example.com/image.jpg" }],
          },
        },
      ],
      new Date("2026-09-21T00:00:00Z"),
      20,
    );

    expect(result.errors).toEqual([]);
    expect(result.events[0]).toMatchObject({
      province: "กรุงเทพมหานคร",
      startDate: new Date("2026-10-29T00:00:00Z"),
      endDate: new Date("2027-02-28T00:00:00Z"),
    });
    expect(result.events[0]?.qualityFlags).toContain("admin_review_required");
  });

  it("skips monthly calendar articles handled by the structured source", () => {
    const result = parseNewsroomFeaturePosts(
      [
        {
          id: 88367,
          link: "https://www.tatnews.org/calendar/",
          title: { rendered: "September Event and Calendar" },
          excerpt: { rendered: "Events in Bangkok from 1-30 September 2026." },
          content: { rendered: "" },
        },
      ],
      new Date("2026-09-01T00:00:00Z"),
      20,
    );
    expect(result.events).toEqual([]);
  });
});
