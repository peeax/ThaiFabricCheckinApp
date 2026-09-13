import { writeFile } from "node:fs/promises";

import { writeDraftEvents } from "./firestore-writer.js";
import { enrichWithThaiCalendar } from "./sources/tat-news-thai.js";
import { fetchTatNewsroomEvents } from "./sources/tat-newsroom.js";
import type { ImportSummary } from "./types.js";

const args = process.argv.slice(2);
const writeMode = args.includes("--write");
const postId = numberArgument("--post-id");
const limit = numberArgument("--limit") ?? 50;

if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
  throw new Error("--limit must be an integer between 1 and 100");
}

const sourceResult = await fetchTatNewsroomEvents(postId);
const warnings: string[] = [];
let localizedEvents = sourceResult.events;
let summarySourceUrl = sourceResult.sourceUrl;
try {
  const localized = await enrichWithThaiCalendar(sourceResult.events);
  localizedEvents = localized.events;
  summarySourceUrl = localized.sourceUrl;
  warnings.push(...localized.warnings);
} catch (error) {
  warnings.push(
    `Thai calendar enrichment failed; English drafts were retained: ${errorMessage(error)}`,
  );
}
const selectedEvents = localizedEvents.slice(0, limit);
const summary: ImportSummary = {
  sourceKey: "tat-thai-calendar",
  sourceUrl: summarySourceUrl,
  dryRun: !writeMode,
  found: sourceResult.events.length + sourceResult.errors.length,
  valid: selectedEvents.length,
  rejected: sourceResult.errors.length,
  created: 0,
  updated: 0,
  protected: 0,
  events: selectedEvents,
  errors: sourceResult.errors,
  warnings,
};

if (writeMode) {
  const writeResult = await writeDraftEvents(selectedEvents, limit);
  summary.created = writeResult.created;
  summary.updated = writeResult.updated;
  summary.protected = writeResult.protected;
}

const serialized = JSON.stringify(summary, null, 2);
await writeFile("dry-run-output.json", serialized, "utf8");
console.log(serialized);

if (sourceResult.events.length === 0 || sourceResult.errors.length > 10) {
  process.exitCode = 1;
}

function numberArgument(name: string): number | undefined {
  const inline = args.find((argument) => argument.startsWith(`${name}=`));
  if (inline) return Number(inline.slice(name.length + 1));
  const index = args.indexOf(name);
  return index >= 0 && args[index + 1] ? Number(args[index + 1]) : undefined;
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
