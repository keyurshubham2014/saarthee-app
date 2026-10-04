import { prisma } from '../lib/db';
import { logger } from '../lib/logger';
import { cronMatches, parseCron, type CronSpec } from './cron';
import type { JobDefinition, JobOutcome } from './types';

const DEFAULT_TIMEOUT_MS = 10 * 60_000;
const NAME_RE = /^[a-z][a-z0-9-]{1,62}$/;

/** In-process registry: name -> definition. Duplicate names are a startup error. */
const registry = new Map<string, JobDefinition & { cronSpec?: CronSpec }>();
/** Jobs currently running in this process (no overlap even before the DB lock is asked for). */
const running = new Set<string>();

export function registerJob(def: JobDefinition): void {
  if (!NAME_RE.test(def.name)) throw new Error(`job name "${def.name}" must be kebab-case`);
  if (registry.has(def.name)) throw new Error(`job "${def.name}" registered twice`);
  if ((def.everyMs === undefined) === (def.cron === undefined)) {
    throw new Error(`job "${def.name}" needs exactly one of everyMs or cron`);
  }
  if (def.everyMs !== undefined && (!Number.isInteger(def.everyMs) || def.everyMs < 1000)) {
    throw new Error(`job "${def.name}" everyMs must be an integer >= 1000`);
  }
  registry.set(def.name, { ...def, cronSpec: def.cron ? parseCron(def.cron) : undefined });
}

export function registerJobs(defs: readonly JobDefinition[]): void {
  for (const d of defs) registerJob(d);
}

export function listJobs(): JobDefinition[] {
  return [...registry.values()];
}

export function getJob(name: string): JobDefinition | undefined {
  return registry.get(name);
}

/** Test helper: forget every registered job. */
export function clearJobs(): void {
  registry.clear();
  running.clear();
}

/**
 * Runs one job now under a transaction-scoped Postgres advisory lock keyed by its name, so a second
 * process (or a manual `jobs:run`) running the same job concurrently exits without doing work.
 */
export async function runJob(name: string, now: Date = new Date()): Promise<JobOutcome> {
  const def = registry.get(name);
  if (!def) throw new Error(`unknown job "${name}"`);
  if (running.has(name)) return { name, status: 'skipped_running' };
  running.add(name);
  const started = Date.now();
  const log = logger.child({ job: name });
  try {
    const timeout = def.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    const outcome = await prisma.$transaction(
      async (tx) => {
        const rows = await tx.$queryRaw<{ locked: boolean }[]>`
          SELECT pg_try_advisory_xact_lock(hashtext(${`saarthee.job:${name}`})) AS locked`;
        if (!rows[0]?.locked) return { name, status: 'skipped_locked' } as const;
        const result = (await def.run({ name, now, logger: log })) ?? {};
        return { name, status: 'ran', result, durationMs: Date.now() - started } as const;
      },
      { timeout, maxWait: 10_000 },
    );
    if (outcome.status === 'ran') log.info({ result: outcome.result, durationMs: outcome.durationMs }, 'job ran');
    else log.info('job skipped: another process holds the lock');
    return outcome;
  } catch (err) {
    const error = (err as { code?: string }).code ?? (err as Error).name ?? 'Error';
    log.error({ error, reason: err instanceof Error ? err.message : 'unknown' }, 'job failed');
    return { name, status: 'failed', error, durationMs: Date.now() - started };
  } finally {
    running.delete(name);
  }
}

export interface Scheduler {
  stop: () => void;
}

/**
 * Starts timers for every registered job: `everyMs` jobs on their own interval, `cron` jobs checked
 * once per minute. Timers are unref'd so they never keep the process alive. Caller decides whether to
 * start (server.ts checks JOBS_ENABLED).
 */
export function startScheduler(clock: () => Date = () => new Date()): Scheduler {
  const timers: NodeJS.Timeout[] = [];
  const cronJobs = listJobs().filter((j) => j.cron);
  for (const job of listJobs()) {
    if (job.everyMs) timers.push(setInterval(() => void runJob(job.name, clock()), job.everyMs).unref());
  }
  if (cronJobs.length > 0) {
    let lastMinute = -1;
    timers.push(
      setInterval(() => {
        const now = clock();
        const minute = Math.floor(now.getTime() / 60_000);
        if (minute === lastMinute) return;
        lastMinute = minute;
        for (const job of cronJobs) {
          const spec = registry.get(job.name)?.cronSpec;
          if (spec && cronMatches(spec, now)) void runJob(job.name, now);
        }
      }, 15_000).unref(),
    );
  }
  logger.info({ jobs: listJobs().map((j) => j.name) }, 'job scheduler started');
  return { stop: () => timers.forEach((t) => clearInterval(t)) };
}
