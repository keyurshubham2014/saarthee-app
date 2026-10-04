// TASK-08 §5.2 seed: sample alerts in every severity and status, subscriptions and inbox rows; idempotent.
import { beforeAll, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { runSeed } from '../../prisma/seed/run';
import { resetDb } from '../helpers/db';

const ctx = { prisma, photoDir: process.env.PHOTO_STORAGE_DIR!, adminEmail: 'seed-admin@test.local', adminPassword: 'Seed-Admin-Password-1!', log: () => undefined };

beforeAll(async () => {
  await resetDb();
  await runSeed(ctx);
}, 120_000);

describe('alerts seed', () => {
  it('has every severity and status, a SACHET draft with empty Gujarati, a superseded pair', async () => {
    for (const severity of ['info', 'advisory', 'warning', 'critical'] as const) {
      expect(await prisma.alert.count({ where: { severity, status: 'published' } }), severity).toBeGreaterThan(0);
    }
    for (const status of ['draft', 'pending_approval', 'published', 'expired', 'retracted'] as const) {
      expect(await prisma.alert.count({ where: { status } }), status).toBeGreaterThan(0);
    }
    expect(await prisma.alert.count({ where: { origin: 'sachet', titleGu: '' } })).toBe(1);
    expect(await prisma.alert.count({ where: { supersedesId: { not: null } } })).toBe(1);
    expect(await prisma.subscription.count({ where: { scope: 'ward' } })).toBe(2);
    const kinds = await prisma.notification.groupBy({ by: ['kind'], where: { userId: { not: null } } });
    expect(kinds.map((k) => k.kind).sort()).toEqual(['alert', 'initiative', 'issue_update']);
  });

  it('a second run changes nothing', async () => {
    const before = [await prisma.alert.count(), await prisma.alertWard.count(), await prisma.subscription.count(), await prisma.notification.count()];
    await runSeed(ctx);
    expect([await prisma.alert.count(), await prisma.alertWard.count(), await prisma.subscription.count(), await prisma.notification.count()]).toEqual(before);
  });
});
