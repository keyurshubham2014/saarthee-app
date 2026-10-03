/**
 * Test environment loading and the test-database guard (V2 TASK-01 §6 step 14, AC-9, T-01-12).
 * Used by vitest.config.ts (before any worker starts) and test/global-setup.ts. See test/README.md.
 */
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { parseEnv } from 'node:util';

export class TestDatabaseGuardError extends Error {}

/** Returns the database name of a postgres URL; throws when the URL is not a postgres URL. */
export function databaseName(url: string): string {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw new TestDatabaseGuardError('Test DATABASE_URL is not a valid URL.');
  }
  if (!/^postgres(ql)?:$/.test(parsed.protocol)) throw new TestDatabaseGuardError('Test DATABASE_URL must be postgresql://.');
  return decodeURIComponent(parsed.pathname.replace(/^\//, ''));
}

/**
 * Refuses (throws) unless the database name contains `_test` (e.g. `saarthee_test`, `saarthee_test_task05`).
 * Runs before any query, so pointing the tests at the dev database `saarthee` can never touch its data.
 */
export function assertTestDatabaseUrl(url: string | undefined): string {
  if (!url) throw new TestDatabaseGuardError('Test DATABASE_URL is not set (copy .env.test.example to .env.test).');
  const name = databaseName(url);
  if (!name.includes('_test')) {
    throw new TestDatabaseGuardError(`Refusing to run tests against database "${name}": the name must contain "_test".`);
  }
  return name;
}

/** Replaces the database name in a postgres URL. */
export function withDatabaseName(url: string, name: string): string {
  const u = new URL(url);
  u.pathname = `/${encodeURIComponent(name)}`;
  return u.toString();
}

/**
 * Builds the env for the test run: `.env.test` < process env (same keys, except DATABASE_URL), then the overrides
 * TEST_DATABASE_URL (full URL) or TEST_DB_NAME (db name only). Guard applied last.
 */
export function loadTestEnv(apiRoot = path.resolve(__dirname, '..')): Record<string, string> {
  const file = path.join(apiRoot, '.env.test');
  const fromFile = existsSync(file) ? (parseEnv(readFileSync(file, 'utf8')) as Record<string, string>) : {};
  const env: Record<string, string> = { ...fromFile };
  for (const [k, v] of Object.entries(process.env)) {
    if (v !== undefined && k in fromFile && k !== 'DATABASE_URL') env[k] = v;
  }
  if (process.env.TEST_DATABASE_URL) env.DATABASE_URL = process.env.TEST_DATABASE_URL;
  if (process.env.TEST_DB_NAME && env.DATABASE_URL) env.DATABASE_URL = withDatabaseName(env.DATABASE_URL, process.env.TEST_DB_NAME);
  assertTestDatabaseUrl(env.DATABASE_URL);
  return env;
}
