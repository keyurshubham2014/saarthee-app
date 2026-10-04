// TASK-02 §6 step 8 (AC-1, AC-9 on the dev seed): the `wards` seed module loads 48 wards / 7 zones, puts every
// seeded issue in one of the 5 pilot wards (Spec D5) and assigns legacy issues a ward; re-running changes nothing.
import { beforeAll, describe, expect, it } from 'vitest';
import { runSeed } from '../../prisma/seed/run';
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

beforeAll(async () => {
  await resetDb();
  await runSeed(ctx);
}, 120_000);

describe('wards seed module', () => {
  it('loads 48 wards and 7 zones and logs the import and backfill lines', async () => {
    expect(await prisma.ward.count()).toBe(48);
    expect(await prisma.zone.count()).toBe(7);
    expect(logs.some((l) => l.startsWith('Seed wards: geo:import version=opencity-amc-wards-2025-11 zones=7 wards=48'))).toBe(true);
    expect(logs.some((l) => /^Seed wards: geo:backfill checked=\d+ inside=\d+ nearest=0 outside=0$/.test(l))).toBe(true);
  });

  it('every seeded (non-legacy) issue sits in one of the 5 pilot wards, with the ward’s zone', async () => {
    const issues = await prisma.issue.findMany({ where: { legacyComplaintId: null }, include: { ward: true } });
    expect(issues.length).toBeGreaterThan(0);
    const pilot = new Set(['Paldi', 'Navrangpura', 'Vasna', 'Naranpura', 'Nava Vadaj']);
    for (const i of issues) {
      expect(i.ward, i.title).not.toBeNull();
      expect(pilot.has(i.ward!.nameEn), `${i.title} in ${i.ward!.nameEn}`).toBe(true);
      expect(i.zoneId).toBe(i.ward!.zoneId);
    }
    expect(new Set(issues.map((i) => i.ward!.nameEn))).toEqual(pilot);
  });

  it('legacy issues get a ward too; a second seed run changes no ward or issue row', async () => {
    expect(await prisma.issue.count({ where: { legacyComplaintId: { not: null }, wardId: null } })).toBe(0);
    const before = await prisma.ward.findMany({ select: { number: true, updatedAt: true }, orderBy: { number: 'asc' } });
    const issuesBefore = await prisma.issue.findMany({ select: { id: true, wardId: true, updatedAt: true }, orderBy: { id: 'asc' } });
    await runSeed(ctx);
    expect(await prisma.ward.findMany({ select: { number: true, updatedAt: true }, orderBy: { number: 'asc' } })).toEqual(before);
    expect(await prisma.issue.findMany({ select: { id: true, wardId: true, updatedAt: true }, orderBy: { id: 'asc' } })).toEqual(issuesBefore);
  });
});
