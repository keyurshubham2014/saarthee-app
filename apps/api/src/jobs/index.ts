import { flushQueued } from '../lib/push';
import { alertJobs } from '../modules/alerts/jobs';
import { listJobs, registerJobs } from './runner';
import type { JobDefinition } from './types';

export { runJob, startScheduler, listJobs, getJob, registerJob, registerJobs, clearJobs, type Scheduler } from './runner';
export type { JobDefinition, JobContext, JobOutcome, JobResult } from './types';

/** Built-in jobs owned by shared libs. */
const coreJobs: JobDefinition[] = [
  {
    name: 'push-flush',
    everyMs: 5 * 60_000,
    run: async ({ now }) => ({ sent: await flushQueued(now) }),
  },
];

/**
 * Every app job. Modules export `jobs` from `src/modules/<m>/jobs.ts`; the integrator appends the
 * import here (append-only list, TASK-06 contract).
 */
export function appJobs(): JobDefinition[] {
  return [...coreJobs, ...alertJobs()];
}

/** Registers every app job once (safe to call from server.ts and the jobs:run script). */
export function registerAppJobs(): void {
  if (listJobs().length > 0) return;
  registerJobs(appJobs());
}
