import { snapshotFor } from "../source-utils.js";
import type { SourceAdapter, SourceResult } from "../types.js";
import { enrichWithThaiCalendar } from "./tat-news-thai.js";
import { fetchTatNewsroomEvents } from "./tat-newsroom.js";

export const tatMonthlyCalendarSource: SourceAdapter = {
  key: "tat-monthly-calendar",
  name: "ปฏิทินกิจกรรม ททท.",
  sourceUrl: "https://www.tatnews.org/category/thailand-events-festivals/",
  scheduleGroup: "daily",
  enabledByDefault: true,
  async fetch(context): Promise<SourceResult> {
    const sourceResult = await fetchTatNewsroomEvents(context.postId);
    const warnings: string[] = [];
    let events = sourceResult.events;
    let sourceUrl = sourceResult.sourceUrl;

    try {
      const localized = await enrichWithThaiCalendar(events);
      events = localized.events;
      sourceUrl = localized.sourceUrl;
      warnings.push(...localized.warnings);
    } catch (error) {
      warnings.push(
        `Thai calendar enrichment failed; English drafts were retained: ${errorMessage(error)}`,
      );
    }

    const selectedEvents = events.slice(0, context.limit);
    return {
      sourceKey: this.key,
      sourceName: this.name,
      sourceUrl,
      events: selectedEvents,
      snapshots: selectedEvents.map((event) =>
        snapshotFor(event, event, context.now),
      ),
      errors: sourceResult.errors,
      warnings,
    };
  },
};

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
