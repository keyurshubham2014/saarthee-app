/**
 * npm run legacy:migrate — copies v1 complaints into v2 issues (V2 TASK-01 §5.2). Idempotent.
 * Prints `complaints=N imported=N skipped=N`; exit 1 on unknown v1 categories or empty `categories`.
 */
import { PrismaClient } from '@prisma/client';
import { formatLegacyResult, LegacyMigrationError, migrateLegacyComplaints } from '../src/lib/legacy/migrate';

async function main() {
  const prisma = new PrismaClient();
  try {
    console.log(formatLegacyResult(await migrateLegacyComplaints(prisma)));
  } catch (err) {
    if (err instanceof LegacyMigrationError) {
      console.error(`legacy:migrate failed: ${err.message}`);
    } else {
      console.error('legacy:migrate failed:', err instanceof Error ? err.message : err);
    }
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
}

void main();
