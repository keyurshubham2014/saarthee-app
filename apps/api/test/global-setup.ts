import { execFileSync } from 'node:child_process';
import path from 'node:path';
import { Client } from 'pg';
import { assertTestDatabaseUrl, loadTestEnv, safeDbName, withDatabaseName } from './env';

/**
 * Once per run (see test/README.md):
 * 1. guard: the database name must be a test database (test/env.ts);
 * 2. (re)build the TEMPLATE database named in .env.test: drop and recreate its `public` schema, then apply
 *    every migration with `prisma migrate deploy` (no seed). Equivalent to `prisma migrate reset --skip-seed`,
 *    which the Prisma CLI refuses to run non-interactively from an agent;
 * 3. every test FILE then runs in its own copy of that template (test/setup.ts), so files run in parallel
 *    and never see each other's rows;
 * 4. teardown drops the per-worker copies.
 */
export default async function setup() {
  const apiRoot = path.resolve(__dirname, '..');
  const env = loadTestEnv(apiRoot);
  const url = env.DATABASE_URL!;
  const name = safeDbName(assertTestDatabaseUrl(url));

  const admin = new Client({ connectionString: withDatabaseName(url, 'postgres') });
  await admin.connect();
  try {
    const exists = await admin.query('SELECT 1 FROM pg_database WHERE datname = $1', [name]);
    // Identifier validated by safeDbName; CREATE DATABASE cannot take a bind parameter.
    if (exists.rowCount === 0) await admin.query(`CREATE DATABASE "${name}"`);
    await dropWorkerDatabases(admin, name);
  } finally {
    await admin.end();
  }

  const db = new Client({ connectionString: url });
  await db.connect();
  try {
    await db.query('DROP SCHEMA IF EXISTS public CASCADE');
    await db.query('CREATE SCHEMA public');
  } finally {
    await db.end();
  }

  execFileSync('npx', ['prisma', 'migrate', 'deploy'], {
    cwd: apiRoot,
    env: { ...process.env, ...env, PRISMA_HIDE_UPDATE_MESSAGE: '1' },
    stdio: ['ignore', 'ignore', 'inherit'],
  });

  return async function teardown() {
    if (process.env.TEST_KEEP_DBS === '1') return;
    const c = new Client({ connectionString: withDatabaseName(url, 'postgres') });
    await c.connect();
    try {
      await dropWorkerDatabases(c, name);
    } finally {
      await c.end();
    }
  };
}

/** Drops the per-worker copies `<template>_wN` left by a previous (possibly crashed) run. */
async function dropWorkerDatabases(admin: Client, template: string) {
  const rows = await admin.query<{ datname: string }>(
    `SELECT datname FROM pg_database WHERE datname LIKE $1 || '\\_w%'`,
    [template],
  );
  for (const r of rows.rows) {
    await admin.query(`DROP DATABASE IF EXISTS "${safeDbName(r.datname)}" WITH (FORCE)`);
  }
}
