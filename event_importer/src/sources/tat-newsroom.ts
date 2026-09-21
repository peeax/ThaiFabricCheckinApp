import * as cheerio from "cheerio";

import { parseEnglishDateRange } from "../date-parser.js";
import { createFingerprint } from "../fingerprint.js";
import { findProvince, removeProvince } from "../provinces.js";
import { eventCandidateSchema, type EventCandidate } from "../types.js";

const apiBase = "https://www.tatnews.org/wp-json/wp/v2";
const categoryId = 263;
const sourceKey = "tat-newsroom-monthly";
const calendarTitlePattern = /(event and calendar|festivals and events in thailand)/i;

export type WordPressPost = {
  id: number;
  link: string;
  title: { rendered: string };
  content: { rendered: string };
  excerpt?: { rendered: string };
  _embedded?: {
    "wp:featuredmedia"?: Array<{ source_url?: string }>;
  };
};

export type TatNewsroomResult = {
  postId: number;
  sourceUrl: string;
  events: EventCandidate[];
  errors: string[];
};

export async function fetchTatNewsroomEvents(
  postId?: number,
): Promise<TatNewsroomResult> {
  const post = postId ? await fetchPost(postId) : await fetchLatestCalendarPost();
  const parsed = parseTatNewsroomPost(post);
  return { postId: post.id, sourceUrl: post.link, ...parsed };
}

async function fetchLatestCalendarPost(): Promise<WordPressPost> {
  const posts = await fetchNewsroomPosts(20);
  const calendarPost = posts.find((post) =>
    calendarTitlePattern.test(decodeHtml(post.title.rendered)),
  );
  if (!calendarPost) throw new Error("No recent TAT calendar post was found");
  return calendarPost;
}

export function fetchNewsroomPosts(limit = 20): Promise<WordPressPost[]> {
  const safeLimit = Math.max(1, Math.min(limit, 100));
  const url = `${apiBase}/posts?categories=${categoryId}&per_page=${safeLimit}&_embed=1`;
  return fetchJson<WordPressPost[]>(url);
}

async function fetchPost(postId: number): Promise<WordPressPost> {
  return fetchJson<WordPressPost>(`${apiBase}/posts/${postId}?_embed=1`);
}

async function fetchJson<T>(url: string): Promise<T> {
  const response = await fetch(url, {
    headers: { "User-Agent": "AewmaiEventImporter/0.1 (+event data review)" },
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) {
    throw new Error(`TAT Newsroom request failed with HTTP ${response.status}`);
  }
  return (await response.json()) as T;
}

export function parseTatNewsroomPost(post: WordPressPost): {
  events: EventCandidate[];
  errors: string[];
} {
  const $ = cheerio.load(post.content.rendered);
  const featuredImage = post._embedded?.["wp:featuredmedia"]?.[0]?.source_url ?? "";
  const events: EventCandidate[] = [];
  const errors: string[] = [];

  $(".elementor-widget-text-editor h2, .elementor-widget-text-editor h3").each(
    (_, heading) => {
      const title = cleanText($(heading).text());
      if (!title) return;

      const paragraphs: string[][] = [];
      $(heading)
        .nextUntil("h2, h3")
        .filter("p")
        .each((_, paragraph) => {
          const clone = $(paragraph).clone();
          clone.find("br").replaceWith("\n");
          const lines = clone
            .text()
            .split("\n")
            .map(cleanText)
            .filter(Boolean);
          if (lines.length > 0) paragraphs.push(lines);
        });
      const detailLines = paragraphs.find(
        (lines) => !/^highlights?:/i.test(lines.join(" ")),
      );
      const highlightLines = paragraphs.find((lines) =>
        /^highlights?:/i.test(lines.join(" ")),
      );

      if (!detailLines) {
        errors.push(`${title}: missing date and location paragraph`);
        return;
      }

      const dateRange = parseEnglishDateRange(detailLines[0] ?? "");
      if (!dateRange) {
        errors.push(`${title}: unsupported date '${detailLines[0] ?? ""}'`);
        return;
      }

      const locationLines = detailLines.slice(1);
      const provinceMatch = findProvince(locationLines.join("\n"));
      if (!provinceMatch) {
        errors.push(`${title}: province could not be identified`);
        return;
      }

      const [englishProvince, thaiProvince] = provinceMatch;
      const locationName = locationLines
        .map((line) => removeProvince(line, englishProvince))
        .filter(Boolean)
        .join(", ");
      const description = (highlightLines ?? [])
        .join(" ")
        .replace(/^highlights?:\s*/i, "")
        .trim();
      const sourceEventId = `${post.id}:${slugify(title)}`;
      const fingerprint = createFingerprint([sourceKey, sourceEventId]);

      const candidate = eventCandidateSchema.safeParse({
        title,
        description: description || title,
        province: thaiProvince,
        locationName: locationName || thaiProvince,
        startDate: dateRange.startDate,
        endDate: dateRange.endDate,
        imageUrl: featuredImage,
        sourceName: "TAT Newsroom",
        sourceUrl: post.link,
        sourceKey,
        sourceEventId,
        fingerprint,
        qualityFlags: [
          "needs_thai_translation",
          ...(featuredImage ? ["shared_article_image"] : ["missing_image"]),
        ],
        sourceLanguage: "en",
      });

      if (candidate.success) {
        events.push(candidate.data);
      } else {
        errors.push(`${title}: ${candidate.error.issues.map((issue) => issue.message).join(", ")}`);
      }
    },
  );

  return { events, errors };
}

function cleanText(value: string): string {
  return decodeHtml(value).replace(/\s+/g, " ").trim();
}

function decodeHtml(value: string): string {
  return cheerio.load(`<span>${value}</span>`)("span").text();
}

function slugify(value: string): string {
  return value
    .normalize("NFKD")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}
