/**
 * `npm run alerts:ingest -- --source sachet [--dry-run]` — polls the SACHET CAP feed once and creates alert
 * DRAFTS for Ahmedabad (never submits, approves, publishes or pushes). Prints counts and mapped ids only.
 * IMD: not available until API access is granted (TASK-08 §13).
 */
import { prisma } from '../src/lib/db';
import { logger } from '../src/lib/logger';
import { ingestSource } from '../src/modules/alerts/sources/ingest';
import { sachetSource } from '../src/modules/alerts/sources/sachet';

async function main() {
  const args = process.argv.slice(2);
  const source = args[args.indexOf('--source') + 1];
  const dryRun = args.includes('--dry-run');
  if (source !== 'sachet') {
    console.error('alerts:ingest usage: --source sachet [--dry-run] (imd: deferred until access is granted)');
    process.exitCode = 1;
    return;
  }
  const r = await ingestSource(sachetSource(), { dryRun, logger });
  console.log(`alerts:ingest source=sachet dryRun=${dryRun} created=${r.created} skipped=${r.skipped} failed=${r.failed}`);
  for (const d of r.drafts) console.log(`  ${d.originRef} ${d.severity} ${d.type} ${d.scope} wards=${d.wardCount}`);
}

main()
  .catch((err: unknown) => {
    console.error(`alerts:ingest failed: ${(err as Error).message}`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
