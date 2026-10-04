/* v2 development seed (V2 TASK-01 §5.2). Modules live in ./modules (NNN-name.ts, run in order). */
import { PrismaClient } from '@prisma/client';
import { runSeed } from './run';

function fail(msg: string): never {
  console.error(`Seed refused: ${msg}`);
  process.exit(1);
}

async function main() {
  if (process.env.APP_ENV !== 'development') fail('APP_ENV must be development.');
  const adminEmail = process.env.SEED_ADMIN_EMAIL?.trim().toLowerCase();
  const adminPassword = process.env.SEED_ADMIN_PASSWORD;
  const photoDir = process.env.PHOTO_STORAGE_DIR;
  if (!adminEmail || !adminPassword) fail('SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD must be set.');
  if (!photoDir) fail('PHOTO_STORAGE_DIR must be set.');
  const prisma = new PrismaClient();
  try {
    await runSeed({ prisma, photoDir, adminEmail, adminPassword, log: (l) => console.log(l) });
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  console.error('Seed failed:', e instanceof Error ? e.message : e);
  process.exit(1);
});
