/**
 * `npm run services:seed [-- --force]` (V2 TASK-12 §6 step 2): inserts the verified AMC services that are
 * missing (by slug). Staff edits are never overwritten unless `--force` is given. Safe in every environment.
 */
import { prisma } from '../src/lib/db';
import { seedServices } from '../src/modules/services/seed';

async function main() {
  const force = process.argv.includes('--force');
  const r = await seedServices(prisma, { force });
  console.log(`services:seed inserted=${r.inserted} updated=${r.updated} unchanged=${r.unchanged}${force ? ' (force)' : ''}`);
}

main()
  .catch((err: unknown) => {
    console.error(`services:seed failed: ${(err as { code?: string }).code ?? (err as Error).name}`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
