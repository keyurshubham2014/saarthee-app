// T-01-01 (AC-2): PostGIS present, the 7 TASK-01 migrations applied after the 10 v1 ones, v2 tables exist,
// and tables owned by later tasks are not created by TASK-01.
import { describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';

const V1 = [
  '20261003000000_init_enums',
  '20261003000100_create_admin_users',
  '20261003000200_create_invite_codes',
  '20261003000300_create_ccrs_categories',
  '20261003000400_create_photos',
  '20261003000500_create_complaints',
  '20261003000600_create_reminders',
  '20261003000700_create_verifications',
  '20261003000800_create_events',
  '20261003000900_create_views',
];
const TASK01 = [
  '20261004000000_enable_postgis',
  '20261004000100_v2_enums',
  '20261004000200_create_users_consents_devices',
  '20261004000300_create_categories',
  '20261004000400_create_issues',
  '20261004000500_create_issue_children',
  '20261004000600_legacy_read_only',
];

const tableExists = async (t: string) =>
  (await prisma.$queryRaw<{ ok: boolean }[]>`SELECT to_regclass(${`public.${t}`}) IS NOT NULL AS ok`)[0]!.ok;

describe('migrations', () => {
  it('runs PostGIS 3.5', async () => {
    const [row] = await prisma.$queryRaw<{ v: string }[]>`SELECT postgis_lib_version() AS v`;
    expect(row!.v).toMatch(/^3\.5\./);
  });

  it('applies the 10 v1 + 7 TASK-01 migrations in order, none failed or pending', async () => {
    const rows = await prisma.$queryRaw<{ migration_name: string; finished_at: Date | null; rolled_back_at: Date | null }[]>`
      SELECT migration_name, finished_at, rolled_back_at FROM _prisma_migrations ORDER BY migration_name`;
    const names = rows.map((r) => r.migration_name);
    expect(names.slice(0, 17)).toEqual([...V1, ...TASK01]);
    // Later tasks append migrations with later timestamps only.
    expect(names.slice(17).every((n) => n > TASK01[TASK01.length - 1]!)).toBe(true);
    expect(rows.every((r) => r.finished_at !== null && r.rolled_back_at === null)).toBe(true);
  });

  it('creates every TASK-01 table', async () => {
    for (const t of ['users', 'consents', 'devices', 'categories', 'issues', 'issue_photos', 'issue_events', 'issue_verifications', 'me_toos', 'follows']) {
      expect(await tableExists(t), t).toBe(true);
    }
  });

  it('does not create tables owned by later tasks', async () => {
    const applied = (await prisma.$queryRaw<{ n: string }[]>`SELECT migration_name AS n FROM _prisma_migrations`).map((r) => r.n);
    // amc_problem_types (TASK-05), wards (TASK-02), alerts (TASK-08) exist only once their own migration ran.
    for (const [table, migrationPart] of [
      ['amc_problem_types', 'amc_problem_types'],
      ['wards', 'create_zones_wards'],
      ['alerts', 'alerts'],
    ] as const) {
      const owned = applied.some((n) => n.includes(migrationPart));
      expect(await tableExists(table), table).toBe(owned);
    }
  });
});
