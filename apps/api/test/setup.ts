import { afterAll } from 'vitest';
import { prisma } from '../src/lib/db';
import { assertTestDatabaseUrl } from './env';

// Second line of defence inside every worker, before any test touches the database.
assertTestDatabaseUrl(process.env.DATABASE_URL);

afterAll(async () => {
  await prisma.$disconnect();
});
