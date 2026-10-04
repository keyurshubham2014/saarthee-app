// T-04-10, T-04-11 (AC-10): DELETE /me anonymises in one transaction, then deletes files and the Firebase user.
import { randomUUID } from 'node:crypto';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { storage } from '../../src/lib/storage';
import { registerErasureStep, unregisterErasureStep } from '../../src/modules/me/privacy.registry';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { makeIssue, makePhoto } from '../helpers/factories';
import { signIn, useFakeFirebase } from '../auth/helpers';

const gw = useFakeFirebase();
beforeEach(resetDb);
afterEach(() => unregisterErasureStep('test_boom'));

async function storedPhoto() {
  const key = await storage.save(Buffer.from('fake-jpeg-bytes'));
  return makePhoto({ storageKey: key });
}

async function scenario() {
  const a = await signIn(gw, { extra: { consents: [{ purpose: 'core_service', textVersion: 'v2-1' }, { purpose: 'notifications', textVersion: 'v2-1' }] } });
  const other = await signIn(gw);
  const p1 = await storedPhoto();
  const p2 = await storedPhoto();
  const issue = await makeIssue({ reporterId: a.user.id, description: 'Broken streetlight outside house 14' });
  await prisma.issuePhoto.createMany({
    data: [
      { issueId: issue.id, photoId: p1.id, kind: 'report', position: 0 },
      { issueId: issue.id, photoId: p2.id, kind: 'report', position: 1 },
    ],
  });
  const followed = await makeIssue({ reporterId: other.user.id, meTooCount: 1, followerCount: 1 });
  await prisma.follow.create({ data: { issueId: followed.id, userId: a.user.id } });
  await prisma.meToo.create({ data: { issueId: followed.id, userId: a.user.id } });
  await prisma.device.create({ data: { installId: randomUUID(), userId: a.user.id, fcmToken: 'fcm-del-1', platform: 'android', appVersion: '2' } });
  return { a, p1, p2, issue, followed };
}

describe('DELETE /me', () => {
  it('T-04-10: anonymises the user, keeps the issue without description/photos, deletes files, follows, devices', async () => {
    const { a, p1, p2, issue, followed } = await scenario();
    expect((await api().delete('/api/v1/me').set(a.auth).send({})).status).toBe(400);
    expect((await api().delete('/api/v1/me').set(a.auth).send({ confirm: 'delete' })).status).toBe(400);

    const res = await api().delete('/api/v1/me').set(a.auth).send({ confirm: 'DELETE' });
    expect(res.status).toBe(204);

    const user = await prisma.user.findUniqueOrThrow({ where: { id: a.user.id } });
    expect(user).toMatchObject({ phoneE164: null, firebaseUid: null, displayName: null, homeWardId: null, status: 'deleted', tokenVersion: 1 });
    expect(user.deletedAt).not.toBeNull();

    const kept = await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } });
    expect(kept).toMatchObject({ description: null, reporterId: a.user.id, status: 'reported', visibility: 'public' });
    expect(await prisma.issuePhoto.count({ where: { issueId: issue.id } })).toBe(0);
    for (const p of [p1, p2]) {
      expect(await storage.exists(p.storageKey)).toBe(false);
      expect((await prisma.photo.findUniqueOrThrow({ where: { id: p.id } })).deletedAt).not.toBeNull();
    }
    expect(await prisma.follow.count({ where: { userId: a.user.id } })).toBe(0);
    expect(await prisma.meToo.count({ where: { userId: a.user.id } })).toBe(0);
    expect(await prisma.device.count({ where: { userId: a.user.id } })).toBe(0);
    expect((await prisma.issue.findUniqueOrThrow({ where: { id: followed.id } })).followerCount).toBe(1);
    expect(await prisma.consent.count({ where: { userId: a.user.id, withdrawnAt: null } })).toBe(0);
    expect(await prisma.consent.count({ where: { userId: a.user.id } })).toBe(2);
    expect(gw.deletedUids).toContain(a.uid);

    const after = await api().get('/api/v1/me').set(a.auth);
    expect(after.status).toBe(401);
    expect(after.body.error.code).toBe('TOKEN_REVOKED');
  });

  it('T-04-11: a registered erasure step that throws rolls everything back', async () => {
    const { a, p1, issue } = await scenario();
    registerErasureStep('test_boom', async () => {
      throw new Error('boom');
    });
    const res = await api().delete('/api/v1/me').set(a.auth).send({ confirm: 'DELETE' });
    expect(res.status).toBe(500);
    const user = await prisma.user.findUniqueOrThrow({ where: { id: a.user.id } });
    expect(user).toMatchObject({ phoneE164: a.phone, status: 'active', tokenVersion: 0 });
    expect((await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } })).description).toBe('Broken streetlight outside house 14');
    expect(await prisma.issuePhoto.count({ where: { issueId: issue.id } })).toBe(2);
    expect(await storage.exists(p1.storageKey)).toBe(true);
    expect(await prisma.follow.count({ where: { userId: a.user.id } })).toBe(1);
    expect(await prisma.consent.count({ where: { userId: a.user.id, withdrawnAt: null } })).toBe(2);
    expect(gw.deletedUids).not.toContain(a.uid);
    expect((await api().get('/api/v1/me').set(a.auth)).status).toBe(200);
  });
});
