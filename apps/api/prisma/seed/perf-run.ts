/* `npm run seed:perf` (V2 TASK-07): adds the discovery performance volume to the development database. */
import { PrismaClient } from '@prisma/client';
import { seedPerfIssues } from './perf-issues';

async function main() {
  if (process.env.APP_ENV !== 'development') throw new Error('APP_ENV must be development.');
  const prisma = new PrismaClient();
  try {
    if ((await prisma.ward.count()) === 0) throw new Error('No wards: run `npm run seed` first.');
    const r = await seedPerfIssues(prisma);
    console.log(`Perf seed: ${r.issues} issues (${r.dense} in the Paldi–Vasna bbox), ${r.users} fictional users.`);
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  console.error('Perf seed failed:', e instanceof Error ? e.message : e);
  process.exit(1);
});
