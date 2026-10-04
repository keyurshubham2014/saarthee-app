import { config } from '../../config';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { withdrawQueued } from '../../lib/push';
import type { JobDefinition } from '../../jobs/types';
import { ingestSource } from './sources/ingest';
import { sachetSource } from './sources/sachet';

/**
 * alerts-expire (§5.3 Jobs): published alerts past valid_to become `expired`; their held (queued) sends are
 * withdrawn so nothing goes out at 07:00 for an alert that already ended. Idempotent.
 */
export async function expireAlerts(at: Date = clockNow()): Promise<{ expired: number; withdrawn: number }> {
  const rows = await prisma.$queryRaw<{ id: string }[]>`
    UPDATE alerts SET status = 'expired', updated_at = now()
    WHERE status = 'published' AND valid_to <= ${at}
    RETURNING id`;
  let withdrawn = 0;
  for (const r of rows) withdrawn += await withdrawQueued('alert', r.id);
  return { expired: rows.length, withdrawn };
}

/** Jobs exported to the shared runner (src/jobs). SACHET only when enabled; IMD not registered until access. */
export function alertJobs(): JobDefinition[] {
  const jobs: JobDefinition[] = [{ name: 'alerts-expire', everyMs: 60_000, run: async () => expireAlerts() }];
  if (config.SACHET_ENABLED) {
    jobs.push({
      name: 'alerts-ingest-sachet',
      everyMs: config.SACHET_POLL_MINUTES * 60_000,
      timeoutMs: 5 * 60_000,
      run: async ({ logger }) => {
        const r = await ingestSource(sachetSource(), { dryRun: false, logger });
        return { created: r.created, skipped: r.skipped, failed: r.failed };
      },
    });
  }
  return jobs;
}
