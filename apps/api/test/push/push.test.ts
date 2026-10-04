// T-04-13, T-04-14 (AC-12, AC-13): push service with the memory driver, delivery log and deferred sends.
import { randomUUID } from 'node:crypto';
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { flushQueued, notifyTopic, notifyUser, type PushMessage } from '../../src/lib/push';
import { resetDb } from '../helpers/db';
import { makeUser } from '../helpers/factories';
import { useMemoryPush } from '../auth/helpers';

const driver = useMemoryPush();
beforeEach(async () => {
  await resetDb();
  driver.sent.length = 0;
  driver.failures.clear();
});

const msg = (extra: Partial<PushMessage> = {}): PushMessage => ({
  kind: 'alert',
  refId: 'a1',
  route: '/alerts/a1',
  channel: 'critical_alerts',
  title: { en: 'Heat alert', gu: 'ગરમીની ચેતવણી' },
  body: { en: 'Stay indoors 12–4 pm', gu: 'બપોરે 12–4 ઘરમાં રહો' },
  ...extra,
});

async function device(userId: string, token: string) {
  return prisma.device.create({ data: { installId: randomUUID(), userId, fcmToken: token, platform: 'android', appVersion: '2' } });
}

describe('push service', () => {
  it('topic send goes to __gu (Gujarati) and __en (English); one row `sent` with provider ids', async () => {
    const row = await notifyTopic('ward_12', msg());
    expect(row).toMatchObject({ status: 'sent', topic: 'ward_12', kind: 'alert', channel: 'critical_alerts' });
    expect(row.providerMessageIds).toHaveLength(2);
    expect(driver.sent.map((s) => [s.topic, s.payload.title])).toEqual([
      ['ward_12__gu', 'ગરમીની ચેતવણી'],
      ['ward_12__en', 'Heat alert'],
    ]);
    expect(driver.sent[0]!.payload.data).toMatchObject({ kind: 'alert', refId: 'a1', route: '/alerts/a1', notificationId: row.id });
    expect(await prisma.notification.count()).toBe(1);
    await expect(notifyTopic('Ward 12', msg())).rejects.toThrow();
  });

  it('topic partial / failed', async () => {
    driver.failures.set('city_all__en', 'messaging/internal-error');
    expect((await notifyTopic('city_all', msg())).status).toBe('partial');
    driver.failures.set('city_all__gu', 'messaging/internal-error');
    const failed = await notifyTopic('city_all', msg());
    expect(failed).toMatchObject({ status: 'failed', errorCode: 'messaging/internal-error', sentAt: null });
  });

  it('user send uses every token in the user language; no device → no_device; dead token cleared', async () => {
    const u = await makeUser({ language: 'en' });
    await device(u.id, 'tok-1');
    const dead = await device(u.id, 'tok-dead');
    driver.failures.set('tok-dead', 'messaging/registration-token-not-registered');
    const row = await notifyUser(u.id, msg({ kind: 'issue_update', channel: 'updates' }));
    expect(row).toMatchObject({ status: 'partial', userId: u.id });
    expect(driver.sent).toHaveLength(1);
    expect(driver.sent[0]).toMatchObject({ token: 'tok-1', payload: { title: 'Heat alert', channel: 'updates' } });
    expect((await prisma.device.findUniqueOrThrow({ where: { id: dead.id } })).fcmToken).toBeNull();

    const lonely = await makeUser();
    const none = await notifyUser(lonely.id, msg());
    expect(none.status).toBe('no_device');
    expect(await prisma.notification.count({ where: { userId: lonely.id } })).toBe(1);
  });

  it('T-04-14: sendAfter in the future → queued; flush sends it exactly once after the time', async () => {
    const u = await makeUser({ language: 'gu' });
    await device(u.id, 'tok-q');
    const t0 = new Date();
    const row = await notifyUser(u.id, msg({ sendAfter: new Date(t0.getTime() + 10 * 60_000) }));
    expect(row.status).toBe('queued');
    expect(driver.sent).toHaveLength(0);

    expect(await flushQueued(new Date(t0.getTime() + 5 * 60_000))).toBe(0);
    expect((await prisma.notification.findUniqueOrThrow({ where: { id: row.id } })).status).toBe('queued');

    expect(await flushQueued(new Date(t0.getTime() + 11 * 60_000))).toBe(1);
    expect(await flushQueued(new Date(t0.getTime() + 12 * 60_000))).toBe(0);
    expect(driver.sent).toHaveLength(1);
    expect(driver.sent[0]!.payload.title).toBe('ગરમીની ચેતવણી');
    expect((await prisma.notification.findUniqueOrThrow({ where: { id: row.id } })).status).toBe('sent');
  });

  it('rejects over-long text', async () => {
    await expect(notifyTopic('city_all', msg({ title: { en: 'x'.repeat(121), gu: 'x' } }))).rejects.toThrow();
  });
});
