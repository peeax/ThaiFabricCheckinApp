import * as cheerio from "cheerio";
import { createWorker, PSM } from "tesseract.js";
import thaiLanguage from "@tesseract.js-data/tha";

import { eventCandidateSchema, type EventCandidate } from "../types.js";

const calendarIndexUrl = "https://www.tatnewsthai.org/calendar";
const sourceKey = "tat-thai-calendar";

type ThaiCalendar = {
  id: number;
  sourceUrl: string;
  imageUrls: string[];
};

type ThaiEventText = {
  title: string;
  locationName: string;
  reviewed: boolean;
};

const reviewedCalendar24: ThaiEventText[] = [
  {
    title: "เสน่ห์สีสัน สวรรคโลก",
    locationName: "ตลาดชุมชนเก่าย่านสตรีทอาร์ต อำเภอเมืองสวรรคโลก",
    reviewed: true,
  },
  {
    title: "มหกรรมวัฒนธรรมแห่งชาติ สี สรรค์ ไทย",
    locationName: "อิมแพ็ค เอ็กซิบิชั่น ฮอลล์ 7-8 เมืองทองธานี",
    reviewed: true,
  },
  {
    title: "เมืองเก่า เล่าเรื่องอาร์ต เสน่ห์ไทย ณ ราชบุรี",
    locationName: "The Old Town Ratchaburi อำเภอเมือง จังหวัดราชบุรี",
    reviewed: true,
  },
  {
    title: "เทศกาลฤดูร้อนญี่ปุ่น J-Park Natsu Matsuri 2026",
    locationName: "โครงการ J-Park Sriracha Nihon Mura อำเภอศรีราชา",
    reviewed: true,
  },
  {
    title: "เทศกาลดนตรีอุทัยธานี Feel All the Feelings 2026",
    locationName: "ภูพฤกษา รีสอร์ท อำเภอบ้านไร่",
    reviewed: true,
  },
  {
    title: "มหกรรมศิลปะการแสดงและดนตรีนานาชาติ",
    locationName: "หอประชุมใหญ่ ศูนย์วัฒนธรรมแห่งประเทศไทย",
    reviewed: true,
  },
  {
    title: "ลวดลายแห่งสงขลา",
    locationName: "พิพิธภัณฑสถานแห่งชาติสงขลา",
    reviewed: true,
  },
  {
    title: "มันส์เหนือมาก",
    locationName: "สนามกีฬากลางจังหวัดสุพรรณบุรี",
    reviewed: true,
  },
  {
    title: "เทศกาลกาแฟไทย Thailand Coffee Fest 2026: Made by All of Us",
    locationName: "อิมแพ็ค เอ็กซิบิชั่น เซ็นเตอร์ ฮอลล์ 5-8 เมืองทองธานี",
    reviewed: true,
  },
  {
    title: "งานบุญเดือนสิบ แข่งเรือยาว ไหลเรือไฟ ไหว้พระแก้วคู่บ้าน",
    locationName: "อำเภออากาศอำนวย",
    reviewed: true,
  },
  {
    title: "พัทยามาราธอน 2026 (Pattaya Marathon 2026)",
    locationName: "เมืองพัทยา",
    reviewed: true,
  },
  {
    title: "งานประเพณีบุญสารทเดือนสิบและงานกาชาด จังหวัดนครศรีธรรมราช ประจำปี 2569",
    locationName: "จังหวัดนครศรีธรรมราช",
    reviewed: true,
  },
];

export async function enrichWithThaiCalendar(
  events: EventCandidate[],
): Promise<{ events: EventCandidate[]; sourceUrl: string; warnings: string[] }> {
  const calendar = await fetchLatestThaiCalendar();
  const warnings: string[] = [];
  let thaiEvents: ThaiEventText[];

  if (calendar.id === 24 && events.length === reviewedCalendar24.length) {
    thaiEvents = reviewedCalendar24;
  } else {
    thaiEvents = await recognizeCalendarCards(calendar.imageUrls);
    warnings.push(
      `Calendar ${calendar.id} uses OCR text and requires admin review before publishing.`,
    );
  }

  if (thaiEvents.length !== events.length) {
    throw new Error(
      `Thai calendar contains ${thaiEvents.length} readable events, but the English source contains ${events.length}`,
    );
  }

  return {
    sourceUrl: calendar.sourceUrl,
    warnings,
    events: events.map((event, index) =>
      localizeCandidate(event, thaiEvents[index]!, calendar, index),
    ),
  };
}

export function parseCalendarIndex(html: string): string | null {
  const $ = cheerio.load(html);
  const href = $('a[href*="/calendar/"]')
    .toArray()
    .map((anchor) => $(anchor).attr("href"))
    .find((value) => /\/calendar\/\d+\/?$/.test(value ?? ""));
  return href ? new URL(href, calendarIndexUrl).toString() : null;
}

export function parseCalendarPage(html: string, sourceUrl: string): ThaiCalendar {
  const $ = cheerio.load(html);
  const id = Number(new URL(sourceUrl).pathname.match(/\/calendar\/(\d+)/)?.[1]);
  const imageUrls = $("#image-gallery img")
    .toArray()
    .map((image) => $(image).attr("src") ?? "")
    .filter(Boolean)
    .map((url) => new URL(url, sourceUrl).toString());
  if (!Number.isInteger(id) || imageUrls.length === 0) {
    throw new Error("Thai calendar page has no usable gallery");
  }
  return { id, sourceUrl, imageUrls };
}

async function fetchLatestThaiCalendar(): Promise<ThaiCalendar> {
  const indexHtml = await fetchText(calendarIndexUrl);
  const sourceUrl = parseCalendarIndex(indexHtml);
  if (!sourceUrl) throw new Error("No Thai travel calendar was found");
  return parseCalendarPage(await fetchText(sourceUrl), sourceUrl);
}

async function recognizeCalendarCards(imageUrls: string[]): Promise<ThaiEventText[]> {
  const worker = await createWorker("tha", undefined, {
    langPath: thaiLanguage.langPath,
    gzip: thaiLanguage.gzip,
  });
  await worker.setParameters({ tessedit_pageseg_mode: PSM.SINGLE_BLOCK });
  const cards: ThaiEventText[] = [];
  try {
    for (const imageUrl of imageUrls) {
      for (const rectangle of cardRectangles) {
        const result = await worker.recognize(imageUrl, { rectangle });
        const parsed = parseOcrCard(result.data.text);
        if (parsed) cards.push(parsed);
      }
    }
  } finally {
    await worker.terminate();
  }
  return cards;
}

const cardRectangles = [
  { left: 250, top: 1050, width: 2328, height: 1000 },
  { left: 250, top: 1950, width: 2328, height: 850 },
  { left: 250, top: 2750, width: 2328, height: 1000 },
];

export function parseOcrCard(rawText: string): ThaiEventText | null {
  const lines = rawText
    .split(/\r?\n/)
    .map(normalizeOcrText)
    .filter((line) => thaiCharacterCount(line) >= 4);
  const dateIndex = lines.findIndex(
    (line) => /25\d{2}/.test(line) && thaiMonths.some((month) => line.includes(month)),
  );
  if (dateIndex < 1) return null;

  const titleCandidates = lines
    .slice(Math.max(0, dateIndex - 5), dateIndex)
    .filter((line) => !line.includes("ประจำเดือน"));
  const title = titleCandidates.sort(
    (left, right) => thaiCharacterCount(right) - thaiCharacterCount(left),
  )[0];
  const locationCandidates = lines.slice(dateIndex + 1, dateIndex + 4);
  const locationName = locationCandidates
    .join(" ")
    .replace(/^.*?สถาน(?:ที่|ที)[:：]?\s*/, "")
    .trim();
  if (!title || thaiCharacterCount(title) < 5 || thaiCharacterCount(locationName) < 4) {
    return null;
  }
  return { title, locationName, reviewed: false };
}

function localizeCandidate(
  event: EventCandidate,
  thai: ThaiEventText,
  calendar: ThaiCalendar,
  index: number,
): EventCandidate {
  const imageUrl = calendar.imageUrls[Math.floor(index / 3)] ?? event.imageUrl;
  const qualityFlags = thai.reviewed
    ? ["reviewed_thai_calendar", "shared_calendar_image"]
    : ["thai_calendar_ocr", "ocr_review_required", "shared_calendar_image"];
  const provinceSuffix = thai.locationName.includes(event.province)
    ? ""
    : event.province === "กรุงเทพมหานคร"
      ? " กรุงเทพมหานคร"
      : ` จังหวัด${event.province}`;
  const localized = eventCandidateSchema.parse({
    ...event,
    title: thai.title,
    description: `กิจกรรม "${thai.title}" จัดขึ้น${formatThaiDateRange(event.startDate, event.endDate)} ณ ${thai.locationName}${provinceSuffix}`,
    locationName: thai.locationName,
    imageUrl,
    sourceName: "ข่าวการท่องเที่ยวแห่งประเทศไทย",
    sourceUrl: calendar.sourceUrl,
    sourceKey,
    sourceLanguage: "th",
    originalTitle: event.title,
    originalDescription: event.description,
    originalLocationName: event.locationName,
    qualityFlags,
  });
  return localized;
}

function formatThaiDateRange(startDate: Date, endDate: Date): string {
  const startDay = startDate.getUTCDate();
  const endDay = endDate.getUTCDate();
  const startMonth = thaiMonths[startDate.getUTCMonth()];
  const endMonth = thaiMonths[endDate.getUTCMonth()];
  const endYear = endDate.getUTCFullYear() + 543;
  if (startDate.valueOf() === endDate.valueOf()) {
    return `วันที่ ${startDay} ${startMonth} ${endYear}`;
  }
  if (startDate.getUTCMonth() === endDate.getUTCMonth()) {
    return `วันที่ ${startDay}-${endDay} ${endMonth} ${endYear}`;
  }
  return `วันที่ ${startDay} ${startMonth} ถึง ${endDay} ${endMonth} ${endYear}`;
}

function normalizeOcrText(value: string): string {
  let normalized = value
    .normalize("NFKC")
    .replace(/[๐-๙]/g, (digit) => String("๐๑๒๓๔๕๖๗๘๙".indexOf(digit)))
    .replace(/\s+/g, " ")
    .trim();
  for (let index = 0; index < 4; index += 1) {
    normalized = normalized.replace(/([\u0E00-\u0E7F])\s+(?=[\u0E00-\u0E7F])/g, "$1");
  }
  return normalized.replace("แสน่ห์", "เสน่ห์");
}

function thaiCharacterCount(value: string): number {
  return value.match(/[\u0E00-\u0E7F]/g)?.length ?? 0;
}

const thaiMonths = [
  "มกราคม",
  "กุมภาพันธ์",
  "มีนาคม",
  "เมษายน",
  "พฤษภาคม",
  "มิถุนายน",
  "กรกฎาคม",
  "สิงหาคม",
  "กันยายน",
  "ตุลาคม",
  "พฤศจิกายน",
  "ธันวาคม",
];

async function fetchText(url: string): Promise<string> {
  const response = await fetch(url, {
    headers: { "User-Agent": "AewmaiEventImporter/0.2 (+event data review)" },
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error(`Thai TAT request failed with HTTP ${response.status}`);
  return response.text();
}
