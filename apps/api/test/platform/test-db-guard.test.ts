// T-01-12 (AC-9): the harness refuses any database whose name does not contain "_test", before any query.
import { describe, expect, it } from 'vitest';
import { assertTestDatabaseUrl, TestDatabaseGuardError, withDatabaseName } from '../env';

const base = 'postgresql://u:p@127.0.0.1:5433';

describe('test database guard', () => {
  it.each(['saarthee_test', 'saarthee_test_task01', 'saarthee_test_task12'])('accepts %s', (name) => {
    expect(assertTestDatabaseUrl(`${base}/${name}`)).toBe(name);
  });

  it.each(['saarthee', 'postgres', 'saarthee_shadow_task01', 'test', 'saartheetest'])('refuses %s', (name) => {
    expect(() => assertTestDatabaseUrl(`${base}/${name}`)).toThrow(TestDatabaseGuardError);
  });

  it('refuses a missing or non-postgres URL', () => {
    expect(() => assertTestDatabaseUrl(undefined)).toThrow(TestDatabaseGuardError);
    expect(() => assertTestDatabaseUrl('mysql://u:p@h/saarthee_test')).toThrow(TestDatabaseGuardError);
  });

  it('swaps only the database name (TEST_DB_NAME override)', () => {
    expect(withDatabaseName(`${base}/saarthee_test_task01?schema=public`, 'saarthee_test_task05')).toBe(
      `${base}/saarthee_test_task05?schema=public`,
    );
  });

  it('is what the running suite uses', () => {
    expect(process.env.DATABASE_URL).toContain('_test');
  });
});
