/**
 * `npm run services:check-links` (V2 TASK-12 §5.3, REQ-F-058; monthly `0 6 1 * *` Asia/Kolkata in the job
 * runner). Checks every active service URL politely and stores the result. Broken links are data:
 * exit 0 with a summary table; exit 1 only when the database fails.
 */
import { prisma } from '../src/lib/db';
import { checkAllServiceLinks, summaryTable } from '../src/modules/services/link-check';

async function main() {
  const rows = await checkAllServiceLinks();
  console.log(summaryTable(rows));
}

main()
  .catch((err: unknown) => {
    console.error(`services:check-links failed: ${(err as { code?: string }).code ?? (err as Error).name}`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
