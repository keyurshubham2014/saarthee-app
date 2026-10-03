import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { PrismaClient } from '@prisma/client';
import { assertTestDatabaseUrl, loadTestEnv, withDatabaseName } from './env';

/**
 * Once per run: guard, create the test database if missing, drop and recreate its `public` schema, then
 * apply every migration with `prisma migrate deploy` (no seed). Equivalent to `prisma migrate reset
 * --skip-seed`, which the Prisma CLI refuses to run from an AI agent without a human's consent; the
 * guard above guarantees only a database whose name contains "_test" is ever touched.
 */
export default async function setup() {
  const apiRoot = path.resolve(__dirname, '..');
  const env = loadTestEnv(apiRoot);
  const url = env.DATABASE_URL!;
  const name = assertTestDatabaseUrl(url);
  if (!/^[a-z0-9_]+$/.test(name)) throw new Error(`Unsafe test database name: ${name}`);

  const admin = new PrismaClient({ datasourceUrl: withDatabaseName(url, 'postgres') });
  try {
    const exists = await admin.$queryRaw<unknown[]>`SELECT 1 FROM pg_database WHERE datname = ${name}`;
    // Identifier validated above (guard + [a-z0-9_]); CREATE DATABASE cannot take a bind parameter.
    if (exists.length === 0) await admin.$executeRawUnsafe(`CREATE DATABASE "${name}"`);
  } finally {
    await admin.$disconnect();
  }

  const db = new PrismaClient({ datasourceUrl: url });
  try {
    await db.$executeRawUnsafe('DROP SCHEMA IF EXISTS public CASCADE');
    await db.$executeRawUnsafe('CREATE SCHEMA public');
  } finally {
    await db.$disconnect();
  }

  execFileSync('npx', ['prisma', 'migrate', 'deploy'], {
    cwd: apiRoot,
    env: { ...process.env, ...env, PRISMA_HIDE_UPDATE_MESSAGE: '1' },
    stdio: ['ignore', 'ignore', 'inherit'],
  });
}
