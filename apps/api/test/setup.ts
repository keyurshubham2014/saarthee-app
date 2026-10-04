import { Client } from 'pg';
import { afterAll, beforeAll } from 'vitest';
import { assertTestDatabaseUrl, safeDbName, withDatabaseName, workerDatabaseName } from './env';

/**
 * Runs before every test file, in the file's own module context (test/README.md):
 * - points DATABASE_URL at this worker's private database `<template>_w<poolId>` BEFORE the test file imports
 *   anything that reads it (Prisma connects lazily, on the first query);
 * - beforeAll: recreates that database as a fresh copy of the migrated template (CREATE DATABASE … TEMPLATE),
 *   so each file starts from an empty, fully migrated schema and files can run in parallel;
 * - afterAll: disconnects the shared Prisma client.
 */
const templateUrl = process.env.DATABASE_URL;
const template = safeDbName(assertTestDatabaseUrl(templateUrl));
const workerDb = workerDatabaseName(template, process.env.VITEST_POOL_ID ?? '0');
process.env.TEST_TEMPLATE_DATABASE = template;
process.env.DATABASE_URL = withDatabaseName(templateUrl!, workerDb);
// Second line of defence inside every worker, before any test touches the database.
assertTestDatabaseUrl(process.env.DATABASE_URL);

beforeAll(async () => {
  const admin = new Client({ connectionString: withDatabaseName(templateUrl!, 'postgres') });
  await admin.connect();
  try {
    // Names validated by safeDbName (identifiers cannot be bind parameters).
    await admin.query(`DROP DATABASE IF EXISTS "${workerDb}" WITH (FORCE)`);
    // FILE_COPY: with the default WAL_LOG strategy the first write to the copy stalled for ~15 min on the
    // emulated (amd64-on-arm64) PostGIS container; FILE_COPY is fast everywhere for a small schema.
    await admin.query(`CREATE DATABASE "${workerDb}" TEMPLATE "${template}" STRATEGY FILE_COPY`);
  } finally {
    await admin.end();
  }
}, 60_000);

afterAll(async () => {
  const { prisma } = await import('../src/lib/db');
  await prisma.$disconnect();
});
