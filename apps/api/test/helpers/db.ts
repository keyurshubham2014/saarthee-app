import { Client } from 'pg';
import { prisma } from '../../src/lib/db';
import { resetRateLimitStores } from '../../src/middleware/rateLimit';

const KEEP = new Set(['_prisma_migrations', 'spatial_ref_sys']);

/** Empties every table (except migrations bookkeeping and PostGIS reference data) and every rate-limit counter. */
export async function resetDb(): Promise<void> {
  const rows = await prisma.$queryRaw<{ tablename: string }[]>`
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'`;
  const tables = rows.map((r) => r.tablename).filter((t) => !KEEP.has(t));
  if (tables.length > 0) {
    // Identifiers come from pg_tables (not user input) and are quoted.
    const list = tables.map((t) => `"public"."${t.replace(/"/g, '""')}"`).join(', ');
    await prisma.$executeRawUnsafe(`TRUNCATE TABLE ${list} RESTART IDENTITY CASCADE`);
  }
  await resetRateLimitStores();
}

/** Postgres error text of a failed Prisma call (constraint names, trigger messages). */
export async function dbError(p: Promise<unknown>): Promise<string> {
  try {
    await p;
  } catch (err) {
    const e = err as { message?: string; meta?: unknown };
    return `${e.message ?? ''} ${JSON.stringify(e.meta ?? {})}`;
  }
  throw new Error('expected the database call to fail');
}

/**
 * Runs one parameterised statement with the plain pg driver (Prisma hides the constraint name of unique
 * violations) and returns `<constraint> <message>` of the error it raises; throws if it succeeds.
 */
export async function sqlError(text: string, values: unknown[] = []): Promise<string> {
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  try {
    await client.query(text, values);
  } catch (err) {
    const e = err as { constraint?: string; message: string };
    return `${e.constraint ?? ''} ${e.message}`;
  } finally {
    await client.end();
  }
  throw new Error('expected the statement to fail');
}
