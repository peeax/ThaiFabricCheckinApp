import { describe, expect, it } from "vitest";

import { parseTatNewsroomPost } from "../src/sources/tat-newsroom.js";

describe("parseTatNewsroomPost", () => {
  it("extracts events and maps the province to Thai", () => {
    const result = parseTatNewsroomPost({
      id: 88367,
      link: "https://www.tatnews.org/example/",
      title: { rendered: "September Event and Calendar" },
      content: {
        rendered: `
          <div class="elementor-widget-text-editor">
            <h3>Colors of Thai Thai</h3>
            <p>2–6 September 2026<br>IMPACT Exhibition Hall 7–8<br>Nonthaburi</p>
            <p><strong>Highlights:</strong><br>A national cultural showcase.</p>
          </div>
        `,
      },
      _embedded: {
        "wp:featuredmedia": [{ source_url: "https://example.com/image.jpg" }],
      },
    });

    expect(result.errors).toEqual([]);
    expect(result.events).toHaveLength(1);
    expect(result.events[0]).toMatchObject({
      title: "Colors of Thai Thai",
      province: "นนทบุรี",
      locationName: "IMPACT Exhibition Hall 7–8",
    });
  });
});
