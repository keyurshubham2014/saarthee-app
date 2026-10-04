// T-02-08 (AC-9): geo:backfill — inside → ward + its zone; near → nearest ward; far → left NULL; idempotent;
// existing ward kept; FKs fk_issues_ward / fk_issues_zone / fk_users_home_ward exist and SET NULL.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { backfillIssueWards, formatBackfill } from '../../src/lib/geo/backfill';
import { resetDb } from '../helpers/db';
import { makeCategory, makeIssue, makeUser } from '../helpers/factories';
import { importFixtureWards } from './helpers';

beforeEach(async () => {
  await resetDb();
  await importFixtureWards();
});

describe('geo:backfill', () => {
  it('assigns inside / nearest wards, leaves far issues NULL, prints counts, and is idempotent', async () => {
    const cat = await makeCategory();
    const inside = await makeIssue({ categoryId: cat.id, lat: 23.005, lng: 72.525 }); // ward 3 (east)
    const near = await makeIssue({ categoryId: cat.id, lat: 23.005, lng: 72.495124 }); // ~500 m west of ward 1
    const far = await makeIssue({ categoryId: cat.id, lat: 23.2156, lng: 72.6369 }); // Gandhinagar
    const w2 = await prisma.ward.findUniqueOrThrow({ where: { number: 2 } });
    const preset = await makeIssue({ categoryId: cat.id, lat: 23.005, lng: 72.525, wardId: w2.id, zoneId: w2.zoneId });

    const r = await backfillIssueWards(prisma, 3000);
    expect(r).toEqual({ checked: 3, inside: 1, nearest: 1, outside: 1 });
    expect(formatBackfill(r)).toBe('geo:backfill checked=3 inside=1 nearest=1 outside=1');

    const get = (id: string) =>
      prisma.issue.findUniqueOrThrow({ where: { id }, include: { ward: { include: { zone: true } }, zone: true } });
    const a = await get(inside.id);
    expect(a.ward?.number).toBe(3);
    expect(a.zone?.code).toBe('east');
    expect(a.zoneId).toBe(a.ward?.zoneId);
    const b = await get(near.id);
    expect(b.ward?.number).toBe(1);
    expect(b.zone?.code).toBe('west');
    expect((await get(far.id)).wardId).toBeNull();
    expect((await get(preset.id)).ward?.number).toBe(2); // existing wards are never overwritten

    expect(await backfillIssueWards(prisma, 3000)).toEqual({ checked: 1, inside: 0, nearest: 0, outside: 1 });
  });

  it('the nearest limit is respected (100 m limit leaves the 500 m issue unassigned)', async () => {
    const near = await makeIssue({ lat: 23.005, lng: 72.495124 });
    expect(await backfillIssueWards(prisma, 100)).toMatchObject({ nearest: 0, outside: 1 });
    expect((await prisma.issue.findUniqueOrThrow({ where: { id: near.id } })).wardId).toBeNull();
  });

  it('ward foreign keys exist and SET NULL on ward deletion', async () => {
    const fks = await prisma.$queryRaw<{ conname: string }[]>`
      SELECT conname FROM pg_constraint
      WHERE conname IN ('fk_issues_ward', 'fk_issues_zone', 'fk_users_home_ward', 'fk_wards_zone') ORDER BY 1`;
    expect(fks.map((f) => f.conname)).toEqual(['fk_issues_ward', 'fk_issues_zone', 'fk_users_home_ward', 'fk_wards_zone']);

    const w3 = await prisma.ward.findUniqueOrThrow({ where: { number: 3 } });
    const user = await makeUser({ homeWardId: w3.id });
    const issue = await makeIssue({ lat: 23.005, lng: 72.525, wardId: w3.id, zoneId: w3.zoneId });
    await expect(prisma.issue.update({ where: { id: issue.id }, data: { wardId: '00000000-0000-4000-8000-000000000000' } })).rejects.toThrow();
    await prisma.ward.delete({ where: { id: w3.id } });
    expect((await prisma.user.findUniqueOrThrow({ where: { id: user.id } })).homeWardId).toBeNull();
    expect((await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } })).wardId).toBeNull();
  });
});
