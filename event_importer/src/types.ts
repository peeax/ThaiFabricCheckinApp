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

export type ImportSummary = {
  sourceKey: string;
  sourceUrl: string;
  dryRun: boolean;
  found: number;
  valid: number;
  rejected: number;
  created: number;
  updated: number;
  protected: number;
  events: EventCandidate[];
  errors: string[];
  warnings: string[];
};
