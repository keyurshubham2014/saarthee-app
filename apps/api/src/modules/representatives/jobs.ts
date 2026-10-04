/**
 * Scheduled work owned by TASK-09, exported for the shared runner (summary Open Question 7: TASK-06's
 * `src/jobs`; wave-3 workers export `{ name, everyMs | cron, run }[]` and the integrator registers them).
 * Both jobs are idempotent: relay sends claim rows atomically, and the scorecard refresh is CONCURRENTLY.
 */
import { flushRelayOutbox } from './relay.service';
import { refreshScorecard } from './scorecard.service';

export interface ModuleJob {
  name: string;
  everyMs?: number;
  cron?: string;
  run: () => Promise<unknown>;
}

export const jobs: ModuleJob[] = [
  { name: 'relay-send', everyMs: 30_000, run: () => flushRelayOutbox() },
  { name: 'scorecard-refresh', cron: '5 * * * *', run: () => refreshScorecard() },
];
