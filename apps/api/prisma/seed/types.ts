import type { PrismaClient } from '@prisma/client';

/** Shared state handed to every seed module (V2 TASK-01 §5.2 seed framework). */
export interface SeedContext {
  prisma: PrismaClient;
  /** Absolute photo root (PHOTO_STORAGE_DIR). */
  photoDir: string;
  adminEmail: string;
  adminPassword: string;
  log: (line: string) => void;
}

/**
 * One seed module. Registration is by file: add `modules/<NNN>-<name>.ts` with a default export of this
 * shape; modules run in file-name order (numeric prefix). A module is skipped (with a log line) when any
 * table in `requires` does not exist yet, so later tasks can ship the module with their migration.
 * Every module must be idempotent: a second run changes nothing (fixed UUIDs, create-if-missing).
 */
export interface SeedModule {
  name: string;
  /** Tables that must exist (checked with to_regclass). */
  requires: string[];
  run(ctx: SeedContext): Promise<void>;
}

export const defineSeedModule = (m: SeedModule): SeedModule => m;

const DAY = 86_400_000;
export const daysAgo = (days: number, extraMs = 0) => new Date(Date.now() - days * DAY + extraMs);
