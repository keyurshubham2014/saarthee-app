/**
 * `npm run initiatives:remind` (V2 TASK-12 §5.3, REQ-F-060; every 15 min in the job runner): 24-hour
 * reminders to everyone going. Idempotent (reminder_sent_at). Prints counts only.
 */
import { prisma } from '../src/lib/db';
import { remindInitiatives } from '../src/modules/initiatives/remind';

async function main() {
  const r = await remindInitiatives();
  console.log(`initiatives:remind initiatives=${r.initiatives} reminders=${r.reminders}`);
}

main()
  .catch((err: unknown) => {
    console.error(`initiatives:remind failed: ${(err as { code?: string }).code ?? (err as Error).name}`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
