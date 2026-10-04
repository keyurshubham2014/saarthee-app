/**
 * npm run geo:backfill — assigns ward/zone to issues with ward_id NULL (V2 TASK-02 §5.2).
 * Prints `checked=N inside=N nearest=N outside=N`.
 */
import { PrismaClient } from '@prisma/client';
import { backfillIssueWards, formatBackfill } from '../../src/lib/geo/backfill';

async function main() {
  const prisma = new PrismaClient();
  try {
    const maxNearestM = Number(process.env.GEO_NEAREST_MAX_M || 3000);
    console.log(formatBackfill(await backfillIssueWards(prisma, maxNearestM)));
  } catch (err) {
    console.error('geo:backfill failed:', err instanceof Error ? err.message : err);
    process.exitCode = 1;
  } finally {
    await prisma.$disconnect();
  }
}

void main();
