import { describe, expect, it } from "vitest";

import {
  normalizeProvinceName,
  parseCheckInInput,
  provinceFromGeocodingResponse,
} from "../src/validation.js";

describe("check-in validation", () => {
  it("normalizes Thai province prefixes", () => {
    expect(normalizeProvinceName("จังหวัดเชียงใหม่")).toBe("เชียงใหม่");
    expect(normalizeProvinceName("กรุงเทพฯ")).toBe("กรุงเทพมหานคร");
  });

  it("rejects inaccurate and mocked locations", () => {
    expect(() =>
      parseCheckInInput({
        latitude: 13.7,
        longitude: 100.5,
        accuracyMeters: 1001,
        provinceName: "กรุงเทพมหานคร",
        isMocked: false,
      }),
    ).toThrow();
    expect(() =>
      parseCheckInInput({
        latitude: 13.7,
        longitude: 100.5,
        accuracyMeters: 10,
        provinceName: "กรุงเทพมหานคร",
        isMocked: true,
      }),
    ).toThrow();
  });

  it("extracts the administrative province from geocoding results", () => {
    expect(
      provinceFromGeocodingResponse({
        results: [
          {
            address_components: [
              {
                long_name: "จังหวัดขอนแก่น",
                types: ["administrative_area_level_1"],
              },
            ],
          },
        ],
      }),
    ).toBe("ขอนแก่น");
  });
});
