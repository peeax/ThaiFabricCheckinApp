import { createHash } from "node:crypto";

export function createFingerprint(parts: string[]): string {
  const normalized = parts
    .map((part) => part.normalize("NFKC").trim().toLowerCase().replace(/\s+/g, " "))
    .join("|");
  return createHash("sha256").update(normalized).digest("hex");
}

export function documentIdForFingerprint(fingerprint: string): string {
  return `tat_${fingerprint.slice(0, 28)}`;
}
