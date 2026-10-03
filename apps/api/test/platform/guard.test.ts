// T-01-06 (AC-8): v1 tables are read-only except inside withLegacyWrite.
import { randomUUID } from 'node:crypto';
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma, withLegacyWrite } from '../../src/lib/db';
import { createAdmin } from '../helpers/auth';
import { dbError, resetDb } from '../helpers/db';
import { makeCcrsCategory, makeComplaint } from '../helpers/factories';

beforeEach(resetDb);

async function fixtures() {
  const { admin } = await createAdmin();
  const cat = await makeCcrsCategory('Streetlight');
  const complaint = await makeComplaint({ categoryId: cat.id });
  const reminder = await withLegacyWrite((tx) =>
    tx.reminder.create({ data: { complaintId: complaint.id, tokenHash: 'a'.repeat(64), sentBy: admin.id } }),
  );
  const invite = await withLegacyWrite((tx) =>
    tx.inviteCode.create({ data: { code: 'GUARD01', sourceTag: 'rwa', groupLabel: 'g' } }),
  );
  return { admin, cat, complaint, reminder, invite };
}

describe('legacy read-only guard', () => {
  it('rejects INSERT / UPDATE / DELETE on every v1 table with LEGACY_READ_ONLY', async () => {
    const f = await fixtures();
    const attempts: [string, () => Promise<unknown>][] = [
      ['complaints update', () => prisma.complaint.update({ where: { id: f.complaint.id }, data: { wardCode: 'x' } })],
      ['complaints delete', () => prisma.$executeRaw`DELETE FROM complaints WHERE id = ${f.complaint.id}::uuid`],
      ['complaints insert', () => prisma.complaint.create({ data: { ...f.complaint, id: randomUUID(), clientSubmissionId: randomUUID() } })],
      ['reminders update', () => prisma.reminder.update({ where: { id: f.reminder.id }, data: { revokedAt: new Date() } })],
      ['reminders insert', () => prisma.reminder.create({ data: { complaintId: f.complaint.id, tokenHash: 'b'.repeat(64), sentBy: f.admin.id } })],
      ['reminders delete', () => prisma.reminder.delete({ where: { id: f.reminder.id } })],
      ['invite_codes insert', () => prisma.inviteCode.create({ data: { code: 'GUARD02', sourceTag: 'rwa', groupLabel: 'g' } })],
      ['invite_codes update', () => prisma.inviteCode.update({ where: { id: f.invite.id }, data: { isActive: false } })],
      ['invite_codes delete', () => prisma.inviteCode.delete({ where: { id: f.invite.id } })],
      ['ccrs_categories insert', () => prisma.ccrsCategory.create({ data: { name: 'New' } })],
      ['ccrs_categories update', () => prisma.ccrsCategory.update({ where: { id: f.cat.id }, data: { isActive: false } })],
      ['ccrs_categories delete', () => prisma.$executeRaw`DELETE FROM ccrs_categories WHERE id = ${f.cat.id}::uuid`],
    ];
    for (const [name, run] of attempts) {
      expect(await dbError(run()), name).toContain('LEGACY_READ_ONLY');
    }
    expect(await prisma.complaint.count()).toBe(1);
  });

  it('rejects writes to verifications (row-level trigger)', async () => {
    const f = await fixtures();
    const photo = await prisma.photo.create({
      data: {
        storageKey: `photos/2026/10/${randomUUID()}.jpg`, purpose: 'verification', mimeType: 'image/jpeg', byteSize: 1,
        sha256: 'c'.repeat(64), uploadedForComplaintId: f.complaint.id,
      },
    });
    const data = {
      clientSubmissionId: randomUUID(), complaintId: f.complaint.id, result: 'fixed' as const, photoId: photo.id,
      latitude: 23, longitude: 72.5, deviceCapturedAt: new Date(), appPlatform: 'android' as const, appVersion: 't',
    };
    expect(await dbError(prisma.verification.create({ data }))).toContain('LEGACY_READ_ONLY');
    const v = await withLegacyWrite((tx) => tx.verification.create({ data }));
    expect(await dbError(prisma.verification.update({ where: { id: v.id }, data: { note: 'x' } }))).toContain('LEGACY_READ_ONLY');
    expect(await dbError(prisma.verification.delete({ where: { id: v.id } }))).toContain('LEGACY_READ_ONLY');
  });

  it('allows the same writes inside withLegacyWrite, and only for that transaction', async () => {
    const f = await fixtures();
    await withLegacyWrite(async (tx) => {
      await tx.complaint.update({ where: { id: f.complaint.id }, data: { wardCode: 'w1' } });
      await tx.reminder.update({ where: { id: f.reminder.id }, data: { revokedAt: new Date() } });
      await tx.inviteCode.update({ where: { id: f.invite.id }, data: { isActive: false } });
      await tx.ccrsCategory.update({ where: { id: f.cat.id }, data: { sortOrder: 99 } });
    });
    expect((await prisma.complaint.findUniqueOrThrow({ where: { id: f.complaint.id } })).wardCode).toBe('w1');
    // The setting is transaction-local: the next statement is guarded again.
    expect(await dbError(prisma.complaint.update({ where: { id: f.complaint.id }, data: { wardCode: 'w2' } }))).toContain('LEGACY_READ_ONLY');
  });

  it('keeps photos and events writable', async () => {
    const photo = await prisma.photo.create({
      data: { storageKey: `photos/2026/10/${randomUUID()}.jpg`, purpose: 'report', mimeType: 'image/jpeg', byteSize: 1, sha256: 'd'.repeat(64) },
    });
    await prisma.photo.update({ where: { id: photo.id }, data: { attachedAt: new Date() } });
    await prisma.event.create({ data: { name: 'report_opened', occurredAt: new Date() } });
    expect(await prisma.event.count()).toBe(1);
  });
});
