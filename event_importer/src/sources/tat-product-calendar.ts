import { createFingerprint } from "../fingerprint.js";
import { normalizeProvince } from "../provinces.js";
import { snapshotFor } from "../source-utils.js";
import {
  eventCandidateSchema,
  type EventCandidate,
  type RawEventSnapshot,
  type SourceAdapter,
  type SourceResult,
} from "../types.js";

const apiUrl = "https://tourismproduct.tourismthailand.org/api/tat/activities";
const calendarUrl = "https://tourismproduct.tourismthailand.org/th/calendar";
const sourceKey = "tat-product-calendar";

type TatProductActivity = {
  id?: unknown;
  name?: unknown;
  name_en?: unknown;
  description?: unknown;
  startDate?: unknown;
  endDate?: unknown;
  province?: unknown;
  district?: unknown;
  location?: unknown;
  tatEventStatus?: unknown;
};

type TatProductResponse = {
  data?: unknown;
  source?: unknown;
  message?: unknown;
};

export const tatProductCalendarSource: SourceAdapter = {
  key: sourceKey,
  name: "ปฏิทินฝ่ายสินค้าการท่องเที่ยว ททท.",
  sourceUrl: calendarUrl,
  scheduleGroup: "frequent",
  enabledByDefault: false,
  async fetch(context): Promise<SourceResult> {
    const response = await fetch(
      `${apiUrl}?limit=${Math.min(context.limit, 100).toString()}`,
      {
        headers: { "User-Agent": "AewmaiEventImporter/0.3 (+event data review)" },
        signal: AbortSignal.timeout(20_000),
      },
    );
    if (!response.ok) {
      throw new Error(`TAT product calendar failed with HTTP ${response.status}`);
    }

    const payload = (await response.json()) as TatProductResponse;
    if (payload.source === "fallback") {
      return {
        sourceKey,
        sourceName: this.name,
        sourceUrl: calendarUrl,
        events: [],
        snapshots: [],
        errors: [],
        warnings: [
          `Upstream returned fallback data and was skipped: ${String(payload.message ?? "unknown reason")}`,
        ],
      };
    }

    const activities = Array.isArray(payload.data)
      ? (payload.data as TatProductActivity[])
      : [];
    return parseTatProductActivities(activities, context.now);
  },
};

export function parseTatProductActivities(
  activities: TatProductActivity[],
  retrievedAt: Date,
): SourceResult {
  const events: EventCandidate[] = [];
  const snapshots: RawEventSnapshot[] = [];
  const errors: string[] = [];

  for (const activity of activities) {
    const id = String(activity.id ?? "").trim();
    const title = String(activity.name ?? "").trim();
    const province = normalizeProvince(String(activity.province ?? ""));
    if (!id || !province) {
      errors.push(`${title || id || "unknown activity"}: invalid id or province`);
      continue;
    }

    const sourceEventId = `activity:${id}`;
    const candidate = eventCandidateSchema.safeParse({
      title,
      description: String(activity.description ?? title).trim() || title,
      province,
      locationName:
        String(activity.location ?? activity.district ?? province).trim() || province,
      startDate: activity.startDate,
      endDate: activity.endDate ?? activity.startDate,
      imageUrl: "",
      sourceName: "ฝ่ายสินค้าการท่องเที่ยว การท่องเที่ยวแห่งประเทศไทย",
      sourceUrl: calendarUrl,
      sourceKey,
      sourceEventId,
      fingerprint: createFingerprint([sourceKey, sourceEventId]),
      qualityFlags: ["official_api", "missing_image", "admin_review_required"],
      sourceLanguage: "th",
      originalTitle:
        String(activity.name_en ?? "").trim().length >= 3
          ? String(activity.name_en).trim()
          : undefined,
    });

    if (!candidate.success) {
      errors.push(
        `${title || id}: ${candidate.error.issues.map((issue) => issue.message).join(", ")}`,
      );
      continue;
    }

    events.push(candidate.data);
    snapshots.push(snapshotFor(candidate.data, activity, retrievedAt));
  }

  return {
    sourceKey,
    sourceName: "ปฏิทินฝ่ายสินค้าการท่องเที่ยว ททท.",
    sourceUrl: calendarUrl,
    events,
    snapshots,
    errors,
    warnings: [],
  };
}
