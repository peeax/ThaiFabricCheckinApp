import { describe, expect, it } from "vitest";

import { findProvince, normalizeProvince, provinceCount } from "../src/provinces.js";

describe("province matching", () => {
  it("keeps the canonical province count at 77", () => {
    expect(provinceCount()).toBe(77);
  });

  it("does not match short province names inside ordinary words", () => {
    expect(findProvince("A first taste of Thailand")).toBeUndefined();
  });

  it("maps Pattaya to Chon Buri and accepts Thai prefixes", () => {
    expect(findProvince("Wisdom Valley near Pattaya")?.[1]).toBe("ชลบุรี");
    expect(normalizeProvince("จ. เชียงใหม่")).toBe("เชียงใหม่");
  });
});
