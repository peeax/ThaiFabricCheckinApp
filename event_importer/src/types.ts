import { z } from "zod";

export const eventCandidateSchema = z.object({
  title: z.string().trim().min(3),
  description: z.string().trim().min(3),
  province: z.string().trim().min(2),
  locationName: z.string().trim().min(2),
  startDate: z.coerce.date(),
  endDate: z.coerce.date(),
  imageUrl: z.url().or(z.literal("")),
  sourceName: z.string().trim().min(2),
  sourceUrl: z.url(),
  sourceKey: z.string().trim().min(2),
  sourceEventId: z.string().trim().min(2),
  fingerprint: z.string().regex(/^[a-f0-9]{64}$/),
  qualityFlags: z.array(z.string()),
  sourceLanguage: z.enum(["th", "en"]),
  originalTitle: z.string().trim().min(3).optional(),
  originalDescription: z.string().trim().min(3).optional(),
  originalLocationName: z.string().trim().min(2).optional(),
});

export type EventCandidate = z.infer<typeof eventCandidateSchema>;

export type RawEventSnapshot = {
  sourceKey: string;
  sourceEventId: string;
  sourceUrl: string;
  retrievedAt: Date;
  contentHash: string;
  rawData: unknown;
};

export type SourceResult = {
  sourceKey: string;
  sourceName: string;
  sourceUrl: string;
  events: EventCandidate[];
  snapshots: RawEventSnapshot[];
  errors: string[];
  warnings: string[];
};

export type SourceContext = {
  now: Date;
  postId?: number;
  limit: number;
};

export type SourceAdapter = {
  key: string;
  name: string;
  sourceUrl: string;
  scheduleGroup: "frequent" | "daily" | "weekly";
  enabledByDefault: boolean;
  fetch(context: SourceContext): Promise<SourceResult>;
};

export type SourceRunSummary = {
  sourceKey: string;
  sourceName: string;
  sourceUrl: string;
  status: "success" | "warning" | "failed";
  found: number;
  valid: number;
  rejected: number;
  warnings: string[];
  errors: string[];
  durationMs: number;
};

export type ImportSummary = {
  runId: string;
  trigger: "manual" | "scheduled";
  group: string;
  dryRun: boolean;
  found: number;
  valid: number;
  rejected: number;
  created: number;
  updated: number;
  duplicates: number;
  protected: number;
  events: EventCandidate[];
  sources: SourceRunSummary[];
  errors: string[];
  warnings: string[];
};
