import { flushQueued } from '../lib/push';
import { alertJobs } from '../modules/alerts/jobs';
import { jobs as initiativeJobs } from '../modules/initiatives/jobs';
import { lifecycleJobs } from '../modules/lifecycle/jobs';
import { jobs as representativeJobs } from '../modules/representatives/jobs';
import { jobs as serviceJobs } from '../modules/services/jobs';
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
  return [
    ...coreJobs,
    ...alertJobs(),
    // TASK-09: relay outbox and hourly scorecard refresh.
    ...representativeJobs.map((j): JobDefinition => ({ ...j, run: async () => void (await j.run()) })),
    // TASK-12: monthly service link check and initiative reminders.
    ...[...serviceJobs, ...initiativeJobs].map((j): JobDefinition => ({ ...j, run: async () => void (await j.run()) })),
    // TASK-06: hourly SLA overdue flag + notification, CCRS 24 h reopen reminder.
    ...lifecycleJobs,
  ];
}

/** Registers every app job once (safe to call from server.ts and the jobs:run script). */
export function registerAppJobs(): void {
  if (listJobs().length > 0) return;
  registerJobs(appJobs());
}
