/**
 * Manual run of a TASK-09 job until the shared runner registers them:
 * `npm run relay:flush` (relay-send) and `npm run scorecard:refresh` (scorecard-refresh).
 */
import { prisma } from '../src/lib/db';
import { jobs } from '../src/modules/representatives/jobs';

async function main() {
  const name = process.argv[2];
  const job = jobs.find((j) => j.name === name);
  if (!job) throw Object.assign(new Error(`unknown job ${name}`), { code: 'USAGE' });
  const out = await job.run();
  console.log(`${name}: done ${out ? JSON.stringify(out) : ''}`);
}

main()
  .catch((err: unknown) => {
    console.error(`job failed: ${(err as { code?: string }).code ?? (err as Error).name}`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
