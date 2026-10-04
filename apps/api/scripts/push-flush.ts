/**
 * `npm run push:flush` — sends queued notifications whose send_after has passed (TASK-04 §5.3).
 * Scheduled every 5 minutes in TASK-13. Prints counts only.
 */
import { prisma } from '../src/lib/db';
import { flushQueued } from '../src/lib/push';

async function main() {
  const sent = await flushQueued(new Date());
  console.log(`push:flush sent=${sent}`);
}

main()
  .catch((err: unknown) => {
    console.error(`push:flush failed: ${(err as { code?: string }).code ?? (err as Error).name}`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
