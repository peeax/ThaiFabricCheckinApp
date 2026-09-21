import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";

import { ImportStore } from "./firestore-writer.js";
import { normalizeProvince } from "./provinces.js";
import { selectSources, sourceRegistry } from "./source-registry.js";
import type {
  EventCandidate,
  ImportSummary,
  RawEventSnapshot,
  SourceAdapter,
  SourceResult,
  SourceRunSummary,
} from "./types.js";

const args = process.argv.slice(2);
const writeMode = args.includes("--write");
const postId = numberArgument("--post-id");
const limit = numberArgument("--limit") ?? 50;
const group = stringArgument("--group") ?? "all";
const sourceKeys = valuesArgument("--source");
const trigger = stringArgument("--trigger") === "scheduled" ? "scheduled" : "manual";
const runId = `${new Date().toISOString().replace(/[:.]/g, "-")}_${randomUUID().slice(0, 8)}`;

if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
  throw new Error("--limit must be an integer between 1 and 100");
}

let sources = selectSources({ sourceKeys, group });
const store = writeMode ? ImportStore.fromEnvironment() : null;
if (store) {
  const enabledSources = await store.filterEnabledSources([...sourceRegistry]);
  const enabledKeys = new Set(enabledSources.map((source) => source.key));
  sources = sources.filter((source) => enabledKeys.has(source.key));
  if (sources.length === 0) {
    throw new Error("All selected event sources are disabled");
  }
}

const summary: ImportSummary = {
  runId,
  trigger,
  group,
  dryRun: !writeMode,
  found: 0,
  valid: 0,
  rejected: 0,
  created: 0,
  updated: 0,
  duplicates: 0,
  protected: 0,
  events: [],
  sources: [],
  errors: [],
  warnings: [],
};

if (store) await store.beginRun(summary);

try {
  const results = await mapWithConcurrency(sources, 3, (source) =>
    runSource(source, { postId, limit }),
  );
  const snapshots: RawEventSnapshot[] = [];

  for (const { adapter, result, runSummary } of results) {
    summary.sources.push(runSummary);
    summary.found += runSummary.found;
    summary.rejected += runSummary.rejected;
    summary.errors.push(...runSummary.errors.map((error) => `[${adapter.key}] ${error}`));
    summary.warnings.push(
      ...runSummary.warnings.map((warning) => `[${adapter.key}] ${warning}`),
    );
    if (result) {
      const validated = validateEvents(result.events);
      summary.events.push(...validated.events);
      summary.errors.push(
        ...validated.errors.map((error) => `[${adapter.key}] ${error}`),
      );
      summary.rejected += validated.errors.length;
      snapshots.push(...result.snapshots);
    }
    if (store) {
      await store.markSourceResult(adapter, runSummary.status !== "failed", {
        found: runSummary.found,
        rejected: runSummary.rejected,
      });
    }
  }

  summary.events = summary.events.slice(0, limit);
  summary.valid = summary.events.length;
  enforceQualityGate(summary);

  if (store) {
    const writeResult = await store.writeDraftEvents(summary.events, snapshots, limit);
    summary.created = writeResult.created;
    summary.updated = writeResult.updated;
    summary.duplicates = writeResult.duplicates;
    summary.protected = writeResult.protected;
    await store.cleanupExpiredSnapshots();
  }

  const status = importStatus(summary);
  if (store) await store.finishRun(summary, status);
  await outputSummary(summary);
  if (status === "failed") process.exitCode = 1;
} catch (error) {
  summary.errors.push(errorMessage(error));
  if (store) await store.finishRun(summary, "failed");
  await outputSummary(summary);
  process.exitCode = 1;
}

async function runSource(
  adapter: SourceAdapter,
  options: { postId?: number; limit: number },
): Promise<{
  adapter: SourceAdapter;
  result: SourceResult | null;
  runSummary: SourceRunSummary;
}> {
  const startedAt = Date.now();
  try {
    const result = await withRetry(
      () => adapter.fetch({ now: new Date(), ...options }),
      3,
    );
    const status =
      result.errors.length > 0 || result.warnings.length > 0
        ? "warning"
        : "success";
    return {
      adapter,
      result,
      runSummary: {
        sourceKey: adapter.key,
        sourceName: adapter.name,
        sourceUrl: result.sourceUrl,
        status,
        found: result.events.length + result.errors.length,
        valid: result.events.length,
        rejected: result.errors.length,
        warnings: result.warnings,
        errors: result.errors,
        durationMs: Date.now() - startedAt,
      },
    };
  } catch (error) {
    return {
      adapter,
      result: null,
      runSummary: {
        sourceKey: adapter.key,
        sourceName: adapter.name,
        sourceUrl: adapter.sourceUrl,
        status: "failed",
        found: 0,
        valid: 0,
        rejected: 1,
        warnings: [],
        errors: [errorMessage(error)],
        durationMs: Date.now() - startedAt,
      },
    };
  }
}

function validateEvents(events: EventCandidate[]): {
  events: EventCandidate[];
  errors: string[];
} {
  const valid: EventCandidate[] = [];
  const errors: string[] = [];
  for (const event of events) {
    if (event.endDate.valueOf() < event.startDate.valueOf()) {
      errors.push(`${event.title}: end date is before start date`);
      continue;
    }
    if (normalizeProvince(event.province) !== event.province) {
      errors.push(`${event.title}: unknown province '${event.province}'`);
      continue;
    }
    if (!event.sourceUrl.startsWith("https://")) {
      errors.push(`${event.title}: source URL must use HTTPS`);
      continue;
    }
    valid.push(event);
  }
  return { events: valid, errors };
}

function enforceQualityGate(summary: ImportSummary) {
  const attempted = summary.valid + summary.rejected;
  const failedSources = summary.sources.filter((source) => source.status === "failed");
  if (failedSources.length === summary.sources.length) {
    throw new Error("All selected event sources failed");
  }
  if (attempted > 0 && summary.rejected / attempted > 0.2) {
    throw new Error(
      `Quality gate rejected the run: ${summary.rejected}/${attempted} records failed validation`,
    );
  }
}

function importStatus(summary: ImportSummary): "success" | "warning" | "failed" {
  if (summary.errors.length > 0) return "warning";
  if (summary.warnings.length > 0) return "warning";
  return "success";
}

async function withRetry<T>(operation: () => Promise<T>, attempts: number): Promise<T> {
  let lastError: unknown;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      if (attempt < attempts) await delay(attempt * 1_000);
    }
  }
  throw lastError;
}

async function mapWithConcurrency<T, R>(
  values: T[],
  concurrency: number,
  operation: (value: T) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(values.length);
  let nextIndex = 0;
  async function worker() {
    while (nextIndex < values.length) {
      const index = nextIndex;
      nextIndex += 1;
      results[index] = await operation(values[index]!);
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(concurrency, values.length) }, () => worker()),
  );
  return results;
}

function delay(milliseconds: number) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function outputSummary(summary: ImportSummary) {
  const serialized = JSON.stringify(summary, null, 2);
  await writeFile("dry-run-output.json", serialized, "utf8");
  console.log(serialized);
}

function numberArgument(name: string): number | undefined {
  const value = stringArgument(name);
  return value === undefined ? undefined : Number(value);
}

function stringArgument(name: string): string | undefined {
  const inline = args.find((argument) => argument.startsWith(`${name}=`));
  if (inline) return inline.slice(name.length + 1);
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : undefined;
}

function valuesArgument(name: string): string[] {
  return args
    .flatMap((argument, index) => {
      if (argument.startsWith(`${name}=`)) {
        return argument.slice(name.length + 1).split(",");
      }
      return argument === name && args[index + 1] ? [args[index + 1]!] : [];
    })
    .map((value) => value.trim())
    .filter(Boolean);
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
