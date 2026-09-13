import { describe, expect, it } from "vitest";

import {
  parseCalendarIndex,
  parseCalendarPage,
  parseOcrCard,
} from "../src/sources/tat-news-thai.js";

describe("TAT News Thai calendar", () => {
  it("finds the latest calendar URL", () => {
    expect(
      parseCalendarIndex(`
        <a href="https://www.tatnewsthai.org/calendar/24">ล่าสุด</a>
        <a href="https://www.tatnewsthai.org/calendar/23">ก่อนหน้า</a>
      `),
    ).toBe("https://www.tatnewsthai.org/calendar/24");
  });

  it("extracts gallery images", () => {
    expect(
      parseCalendarPage(
        '<div id="image-gallery"><img src="/storage/calendar/page-1.jpg"></div>',
        "https://www.tatnewsthai.org/calendar/24",
      ),
    ).toEqual({
      id: 24,
      sourceUrl: "https://www.tatnewsthai.org/calendar/24",
      imageUrls: ["https://www.tatnewsthai.org/storage/calendar/page-1.jpg"],
    });
  });

  it("normalizes a Thai OCR card", () => {
    expect(
      parseOcrCard(`
        ม ห ก ร ร ม ว ั ฒ น ธ ร ร ม แ ห ่ ง ช า ต ิ ส ี ส ร ร ค ์ ไ ท ย
        ว ั น ท ี ่ 2-6 ก ั น ย า ย น 2569
        ส ถ า น ท ี ่ : อ ิ ม แ พ ็ ค เ ม ื อ ง ท อ ง ธ า น ี
        จ ั ง ห ว ั ด น น ท บ ุ ร ี
      `),
    ).toMatchObject({
      title: "มหกรรมวัฒนธรรมแห่งชาติสีสรรค์ไทย",
      reviewed: false,
    });
  });
});
