/* npm run amc:problems:fetch [-- --from-snapshot]  (V2 TASK-05 §5.3). Operator CLI only; never scheduled. */
import { PrismaClient } from '@prisma/client';
import { config } from '../src/config';
import { runAmcFetch } from '../src/modules/categories/amc-fetch';

async function main() {
  const prisma = new PrismaClient();
  try {
    const code = await runAmcFetch({
      prisma,
      url: config.AMC_PROBLEMS_URL,
      minIntervalHours: config.AMC_PROBLEMS_MIN_INTERVAL_HOURS,
      contactEmail: config.AMC_FETCH_CONTACT_EMAIL,
      fromSnapshot: process.argv.includes('--from-snapshot'),
    });
    process.exitCode = code;
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  console.error('AMC fetch failed:', e instanceof Error ? e.message : e);
  process.exit(1);
});
