/**
 * `npm run reps:expire` (TASK-11 §6 step 6): ends every representative verification whose term_end is before
 * today (IST). Safe to run repeatedly; the second run changes nothing.
 */
import { prisma } from '../src/lib/db';
import { runRepsExpire } from '../src/modules/rep-claims/jobs';

runRepsExpire()
  .then((out) => console.log(`reps-expire: ${out.expired} verification(s) ended`))
  .catch((err: unknown) => {
    console.error(`reps-expire failed: ${(err as { code?: string }).code ?? (err as Error).name}`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
