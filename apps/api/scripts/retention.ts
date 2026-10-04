// Retention job (V2 TASK-13 §5.2, REQ-S-014): photos of closed issues after 2 years, notifications after
// 90 days, log files after 14 days, plus the v1 unattached-photo cleanup. Output: one line per rule,
// counts only. Exit 1 when any item failed.
// Usage: npm run retention:run [-- --dry-run] [-- --rule photos.closed_issues]
import { prisma } from '../src/lib/db';
import { formatResult, parseRetentionArgs, runRetention } from '../src/modules/retention/retention.service';

async function main() {
  const args = parseRetentionArgs(process.argv.slice(2));
  const results = await runRetention(args);
  for (const r of results) console.log(`${args.dryRun ? '[dry-run] ' : ''}${formatResult(r)}`);
  if (results.some((r) => r.failed > 0)) process.exitCode = 1;
}

main()
  .catch((err: unknown) => {
    console.error('retention:run failed:', err instanceof Error ? err.message : 'unknown error');
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
