import type { Logger } from 'pino';

/**
 * One scheduled job (TASK-06 §5 contract, summary Open Question 7). Modules export these from
 * `src/modules/<m>/jobs.ts`; `src/jobs/index.ts` registers them. Exactly one of `everyMs` / `cron`.
 * `run` must be idempotent: the runner guarantees no overlap (in-process flag + Postgres advisory
 * lock across processes) but a job may still run again after a crash mid-run.
 */
export interface JobDefinition {
  name: string;
  /** Fixed interval in milliseconds (>= 1000). */
  everyMs?: number;
  /** Five-field cron expression in server local time: `m h dom mon dow` (`*`, `*\/n`, `a-b`, `a,b`). */
  cron?: string;
  /** Max time the run may hold its lock (default 10 min). */
  timeoutMs?: number;
  run: (ctx: JobContext) => Promise<JobResult | void>;
}

export interface JobContext {
  name: string;
  now: Date;
  logger: Logger;
}

/** Free-form counters a job may return; logged without personal data. */
export type JobResult = Record<string, number | string | boolean>;

export type JobOutcome =
  | { name: string; status: 'ran'; result: JobResult; durationMs: number }
  | { name: string; status: 'skipped_running' | 'skipped_locked' }
  | { name: string; status: 'failed'; error: string; durationMs: number };
