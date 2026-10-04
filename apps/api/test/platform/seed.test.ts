// T-01-11 (AC-11): the modular v2 dev seed is idempotent and matches prisma/SEED-EXPECTATIONS.md.
import { beforeAll, describe, expect, it } from 'vitest';
import { loadSeedModules, runSeed } from '../../prisma/seed/run';
import { prisma } from '../../src/lib/db';
import { resetDb } from '../helpers/db';

const logs: string[] = [];
const ctx = {
  prisma,
  photoDir: process.env.PHOTO_STORAGE_DIR!,
  adminEmail: 'seed-admin@test.local',
  adminPassword: 'Seed-Admin-Password-1!',
  log: (l: string) => logs.push(l),
};

async function snapshot() {
  const tables = (await prisma.$queryRaw<{ t: string }[]>`
    SELECT tablename AS t FROM pg_tables WHERE schemaname = 'public' AND tablename <> '_prisma_migrations' ORDER BY 1`).map((r) => r.t);
  const out: Record<string, string> = {};
  for (const t of tables) {
    // Table names come from pg_tables; md5 over every row detects any change (including updated_at).
    const [row] = await prisma.$queryRawUnsafe<{ n: bigint; h: string | null }[]>(
      `SELECT count(*) AS n, md5(string_agg(md5(x::text), ',' ORDER BY md5(x::text))) AS h FROM "${t}" x`,
    );
    out[t] = `${row!.n}:${row!.h}`;
  }
  return out;
}

let first: Record<string, string>;
let firstRun: { ran: string[]; skipped: string[] };

beforeAll(async () => {
  await resetDb();
  firstRun = await runSeed(ctx);
  first = await snapshot();
}, 120_000);

describe('v2 development seed', () => {
  it('a second run changes nothing', async () => {
    await runSeed(ctx);
    expect(await snapshot()).toEqual(first);
  });

  it('registers ordered modules and skips the ones whose tables do not exist yet', async () => {
    const names = (await loadSeedModules()).map((m) => m.name);
    expect(names.slice(0, 5)).toEqual(['admin', 'categories-dev', 'legacy-v1', 'citizens', 'issues']);
    for (const placeholder of ['wards', 'representatives', 'alerts', 'services', 'initiatives']) expect(names).toContain(placeholder);
    for (const name of firstRun.skipped) {
      expect(logs.some((l) => l.startsWith(`Seed ${name}: skipped (requires `))).toBe(true);
    }
    expect(firstRun.ran.slice(0, 5)).toEqual(['admin', 'categories-dev', 'legacy-v1', 'citizens', 'issues']);
  });

  it('has 14 categories and 6 sample users (1 moderator, 1 suspended)', async () => {
    expect(await prisma.category.count()).toBe(14);
    expect(await prisma.user.count()).toBe(6);
    expect(await prisma.user.count({ where: { role: 'moderator' } })).toBe(1);
    expect(await prisma.user.count({ where: { status: 'suspended' } })).toBe(1);
    expect(await prisma.user.count({ where: { language: 'en' } })).toBeGreaterThan(0);
    expect(await prisma.user.count({ where: { language: 'gu' } })).toBeGreaterThan(0);
  });

  it('has a public issue in every status, one overdue, one hidden, one sensitive, and 11 legacy issues', async () => {
    const statuses = ['reported', 'sent', 'acknowledged', 'in_progress', 'marked_fixed', 'verified', 'reopened', 'rejected', 'merged'] as const;
    for (const status of statuses) {
      expect(await prisma.issue.count({ where: { status, visibility: 'public', legacyComplaintId: null } }), status).toBeGreaterThan(0);
    }
    const merged = await prisma.issue.findFirstOrThrow({ where: { status: 'merged', legacyComplaintId: null } });
    const canonical = await prisma.issue.findUniqueOrThrow({ where: { id: merged.mergedIntoId! } });
    expect(canonical.status).not.toBe('merged');

    const open = ['reported', 'sent', 'acknowledged', 'in_progress', 'reopened'] as const;
    expect(await prisma.issue.count({ where: { legacyComplaintId: null, status: { in: [...open] }, slaDueAt: { lt: new Date() } } })).toBe(1);
    expect(await prisma.issue.count({ where: { legacyComplaintId: null, visibility: 'hidden' } })).toBe(1);
    expect(await prisma.issue.count({ where: { isSensitive: true } })).toBe(1);
    expect(await prisma.issue.count({ where: { legacyComplaintId: { not: null } } })).toBe(11);
    expect(await prisma.issue.count({ where: { legacyComplaintId: null } })).toBe(12);
  });

  it('keeps counters consistent with me_toos / follows and every issue has a report photo and history', async () => {
    const issues = await prisma.issue.findMany({ include: { _count: { select: { meToos: true, follows: true, events: true } }, photos: true } });
    for (const i of issues) {
      if (i.legacyComplaintId === null) {
        expect(i.meTooCount).toBe(i._count.meToos);
        expect(i.followerCount).toBe(i._count.follows);
      }
      expect(i.photos.some((p) => p.kind === 'report' && p.position === 0)).toBe(true);
      expect(i._count.events).toBeGreaterThan(0);
    }
    expect(await prisma.issueVerification.count()).toBe(2);
  });
});
