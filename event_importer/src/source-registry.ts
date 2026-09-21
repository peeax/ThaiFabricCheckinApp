import { tatMonthlyCalendarSource } from "./sources/tat-monthly-calendar.js";
import { tatNewsroomFeaturesSource } from "./sources/tat-newsroom-features.js";
import { tatProductCalendarSource } from "./sources/tat-product-calendar.js";
import type { SourceAdapter } from "./types.js";

export const sourceRegistry: readonly SourceAdapter[] = [
  tatMonthlyCalendarSource,
  tatNewsroomFeaturesSource,
  tatProductCalendarSource,
];

export function selectSources(options: {
  sourceKeys: string[];
  group: string;
}): SourceAdapter[] {
  const requested = new Set(options.sourceKeys);
  const selected = sourceRegistry.filter((source) => {
    if (requested.size > 0) return requested.has(source.key);
    if (options.group === "all") return source.enabledByDefault;
    return source.enabledByDefault && source.scheduleGroup === options.group;
  });

  const unknown = options.sourceKeys.filter(
    (key) => !sourceRegistry.some((source) => source.key === key),
  );
  if (unknown.length > 0) {
    throw new Error(`Unknown source key(s): ${unknown.join(", ")}`);
  }
  if (selected.length === 0) {
    throw new Error(`No enabled sources selected for group '${options.group}'`);
  }
  return selected;
}
