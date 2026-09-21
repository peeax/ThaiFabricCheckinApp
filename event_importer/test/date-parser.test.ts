import { describe, expect, it } from "vitest";

import {
  parseEnglishDateRange,
  parseEnglishDateRangeFromText,
} from "../src/date-parser.js";

describe("parseEnglishDateRange", () => {
  it.each([
    ["5 September 2026", "2026-09-05", "2026-09-05"],
    ["2–6 September 2026", "2026-09-02", "2026-09-06"],
    ["28 August – 1 September 2026", "2026-08-28", "2026-09-01"],
    ["5 September –17 October 2026", "2026-09-05", "2026-10-17"],
    ["3–6 September 2026 | 10:00–18:00 hrs", "2026-09-03", "2026-09-06"],
  ])("parses %s", (input, expectedStart, expectedEnd) => {
    const result = parseEnglishDateRange(input);
    expect(result?.startDate.toISOString().slice(0, 10)).toBe(expectedStart);
    expect(result?.endDate.toISOString().slice(0, 10)).toBe(expectedEnd);
  });

  it("rejects unsupported text", () => {
    expect(parseEnglishDateRange("Every weekend")).toBeNull();
  });
});

describe("parseEnglishDateRangeFromText", () => {
  it.each([
    [
      "Running from 29 October 2026 to 28 February 2027 in Bangkok.",
      undefined,
      "2026-10-29",
      "2027-02-28",
    ],
    [
      "The festival takes place from 11–20 September 2026.",
      undefined,
      "2026-09-11",
      "2026-09-20",
    ],
    [
      "From 17 August to 6 November along the river.",
      2026,
      "2026-08-17",
      "2026-11-06",
    ],
  ])("extracts dates from prose", (input, year, expectedStart, expectedEnd) => {
    const result = parseEnglishDateRangeFromText(input, year);
    expect(result?.startDate.toISOString().slice(0, 10)).toBe(expectedStart);
    expect(result?.endDate.toISOString().slice(0, 10)).toBe(expectedEnd);
  });
});
