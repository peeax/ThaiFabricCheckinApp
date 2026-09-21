import * as cheerio from "cheerio";

import { parseEnglishDateRangeFromText } from "../date-parser.js";
import { createFingerprint } from "../fingerprint.js";
import { findProvince } from "../provinces.js";
import { snapshotFor } from "../source-utils.js";
import {
  eventCandidateSchema,
  type EventCandidate,
  type RawEventSnapshot,
  type SourceAdapter,
  type SourceResult,
} from "../types.js";
import { fetchNewsroomPosts } from "./tat-newsroom.js";

const sourceKey = "tat-newsroom-features";
const sourceUrl = "https://www.tatnews.org/category/thailand-events-festivals/";
const calendarTitlePattern = /(event and calendar|festivals and events in thailand)/i;

export const tatNewsroomFeaturesSource: SourceAdapter = {
  key: sourceKey,
  name: "ข่าวกิจกรรม TAT Newsroom",
  sourceUrl,
  scheduleGroup: "frequent",
  enabledByDefault: true,
  async fetch(context): Promise<SourceResult> {
    const posts = await fetchNewsroomPosts(Math.min(context.limit, 50));
    return parseNewsroomFeaturePosts(posts, context.now, context.limit);
  },
};

export function parseNewsroomFeaturePosts(
  posts: Awaited<ReturnType<typeof fetchNewsroomPosts>>,
  now: Date,
  limit: number,
): SourceResult {
  const events: EventCandidate[] = [];
  const snapshots: RawEventSnapshot[] = [];
  const errors: string[] = [];
  const today = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());

  for (const post of posts) {
    const title = plainText(post.title.rendered);
    if (calendarTitlePattern.test(title)) continue;
    const excerpt = plainText(post.excerpt?.rendered ?? post.content.rendered);
    const fallbackYear = Number(`${title} ${excerpt}`.match(/\b(20\d{2})\b/)?.[1]);
    const dateRange = parseEnglishDateRangeFromText(
      `${title}. ${excerpt}`,
      Number.isInteger(fallbackYear) ? fallbackYear : undefined,
    );
    if (!dateRange || dateRange.endDate.valueOf() < today) continue;

    const provinceMatch = findProvince(`${title}\n${excerpt}`);
    if (!provinceMatch) {
      errors.push(`${title}: province could not be identified`);
      continue;
    }

    const sourceEventId = `post:${post.id}`;
    const candidate = eventCandidateSchema.safeParse({
      title,
      description: excerpt || title,
      province: provinceMatch[1],
      locationName: provinceMatch[1],
      startDate: dateRange.startDate,
      endDate: dateRange.endDate,
      imageUrl: post._embedded?.["wp:featuredmedia"]?.[0]?.source_url ?? "",
      sourceName: "TAT Newsroom",
      sourceUrl: post.link,
      sourceKey,
      sourceEventId,
      fingerprint: createFingerprint([sourceKey, sourceEventId]),
      qualityFlags: [
        "official_news_article",
        "needs_thai_translation",
        "location_review_required",
        "admin_review_required",
      ],
      sourceLanguage: "en",
    });

    if (!candidate.success) {
      errors.push(
        `${title}: ${candidate.error.issues.map((issue) => issue.message).join(", ")}`,
      );
      continue;
    }

    events.push(candidate.data);
    snapshots.push(snapshotFor(candidate.data, post, now));
    if (events.length >= limit) break;
  }

  return {
    sourceKey,
    sourceName: "ข่าวกิจกรรม TAT Newsroom",
    sourceUrl,
    events,
    snapshots,
    errors,
    warnings: events.length === 0 ? ["No current feature events were found"] : [],
  };
}

function plainText(value: string): string {
  return cheerio.load(`<div>${value}</div>`)("div").text().replace(/\s+/g, " ").trim();
}
