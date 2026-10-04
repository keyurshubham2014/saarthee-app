/**
 * `npm run reps:import -- --file <csv> [--dry-run]` and, with `--constituencies`,
 * `npm run constituencies:import -- --file <csv> [--dry-run]` (TASK-09 §5.2).
 * Prints one line per row (create|update|unchanged|error + messages) and the counts. Exit 1 on any error.
 * Import the constituencies file first: MLA/MP rows refer to AC numbers.
 */
import { readFileSync } from 'node:fs';
import { prisma } from '../src/lib/db';
import { logger } from '../src/lib/logger';
import { importConstituencies } from '../src/modules/staff-representatives/constituencies.import';
import { importRoster, type ImportReport } from '../src/modules/staff-representatives/roster.import';

function arg(name: string): string | undefined {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

export function printReport(label: string, r: ImportReport, dryRun: boolean): void {
  if (r.headerError) {
    console.log(`${label}: header rejected — ${r.headerError}`);
    return;
  }
  for (const row of r.rows) {
    console.log(`row ${row.row}\t${row.action}\t${row.name}${row.errors ? `\t${row.errors.join(' | ')}` : ''}`);
  }
  const c = r.counts;
  const mode = dryRun ? 'dry run (nothing written)' : r.committed ? 'committed' : 'aborted (nothing written)';
  console.log(`${label}: ${mode} — create=${c.create} update=${c.update} unchanged=${c.unchanged} error=${c.error}`);
}

async function main() {
  const file = arg('--file');
  const dryRun = process.argv.includes('--dry-run');
  const constituencies = process.argv.includes('--constituencies');
  if (!file) throw Object.assign(new Error('usage: --file <csv> [--dry-run]'), { code: 'USAGE' });
  const text = readFileSync(file, 'utf8');
  const label = constituencies ? 'constituencies:import' : 'reps:import';
  const report = constituencies ? await importConstituencies(text, { dryRun }) : await importRoster(text, { dryRun });
  printReport(label, report, dryRun);
  if (report.committed) {
    logger.info({ action: 'rep_roster_imported', kind: constituencies ? 'constituencies' : 'roster', ...report.counts }, 'staff_action');
  }
  if (report.headerError || report.counts.error > 0) process.exitCode = 1;
}

main()
  .catch((err: unknown) => {
    console.error(`import failed: ${(err as { code?: string }).code ?? (err as Error).message}`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
