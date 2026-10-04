/**
 * `npm run jobs:run -- <name>` — runs one registered job now under its advisory lock (TASK-06 contract).
 * `npm run jobs:run -- --list` prints job names. Exit code 1 when the job failed or is unknown.
 */
import { prisma } from '../src/lib/db';
import { getJob, listJobs, registerAppJobs, runJob } from '../src/jobs';

async function main() {
  registerAppJobs();
  const name = process.argv[2];
  if (!name || name === '--list') {
    for (const j of listJobs()) console.log(`${j.name}\t${j.cron ?? `every ${j.everyMs}ms`}`);
    return;
  }
  if (!getJob(name)) {
    console.error(`jobs:run unknown job "${name}"`);
    process.exitCode = 1;
    return;
  }
  const outcome = await runJob(name);
  console.log(`jobs:run ${JSON.stringify(outcome)}`);
  if (outcome.status === 'failed') process.exitCode = 1;
}

main()
  .catch((err: unknown) => {
    console.error(`jobs:run failed: ${(err as { code?: string }).code ?? (err as Error).name}`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
