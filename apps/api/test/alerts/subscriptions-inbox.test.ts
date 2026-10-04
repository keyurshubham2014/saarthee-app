// T-08-12, T-08-13 (AC-10, AC-11, AC-12): subscriptions (user + visitor device) and the notification inbox.
import { randomUUID } from 'node:crypto';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { resetClock, setClock } from '../../src/lib/clock';
import { prisma } from '../../src/lib/db';
import { signUserToken } from '../../src/lib/tokens';
import { useMemoryPush } from '../auth/helpers';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { makeUser } from '../helpers/factories';
import { composer, ist, PREFIX, publishFlow, staffUser, wardsFixture } from './helpers';

useMemoryPush();
const clock = ist('2030-01-10T11:00:00');
let fx: Awaited<ReturnType<typeof wardsFixture>>;

beforeEach(async () => {
  await resetDb();
  setClock(() => clock);
  fx = await wardsFixture();
});
afterAll(resetClock);

async function citizen(homeNumber = 1, language: 'gu' | 'en' = 'gu') {
  const user = await makeUser({ homeWardId: fx.byNumber(homeNumber).id, language });
  return { user, auth: { Authorization: `Bearer ${signUserToken(user).accessToken}` } };
}

describe('subscriptions (T-08-12)', () => {
  it('saves extra wards and preferences; 6 wards, home ward and unknown ward are 400; topics follow preferences', async () => {
    const c = await citizen(1);
    const empty = await api().get(`${PREFIX}/me/subscriptions`).set(c.auth);
    expect(empty.body).toMatchObject({ homeWardId: fx.byNumber(1).id, extraWardIds: [], mutedTypes: [], criticalOnly: false, customPreferences: false });
    expect(empty.body.topics).toEqual(['ward_1', 'zone_west', 'city_all']);

    const put = (body: object) => api().put(`${PREFIX}/me/subscriptions`).set(c.auth).send(body);
    const ok = await put({ extraWardIds: [fx.byNumber(3).id], mutedTypes: [], criticalOnly: false });
    expect(ok.body.topics).toEqual(['ward_1', 'ward_3', 'zone_west', 'zone_east', 'city_all']);
    const six = Array.from({ length: 6 }, () => randomUUID());
    const tooMany = await put({ extraWardIds: six, mutedTypes: [], criticalOnly: false });
    expect(tooMany.status).toBe(400);
    expect(tooMany.body.error.details[0].issue).toBe('You can add up to 5 extra wards.');
    expect((await put({ extraWardIds: [fx.byNumber(1).id], mutedTypes: [], criticalOnly: false })).status).toBe(400);
    expect((await put({ extraWardIds: [randomUUID()], mutedTypes: [], criticalOnly: false })).status).toBe(400);
    expect((await put({ extraWardIds: [], mutedTypes: ['bogus'], criticalOnly: false })).status).toBe(400);

    const muted = await put({ extraWardIds: [fx.byNumber(3).id], mutedTypes: ['road_closure'], criticalOnly: true });
    expect(muted.body).toMatchObject({ extraWardIds: [fx.byNumber(3).id], mutedTypes: ['road_closure'], criticalOnly: true, customPreferences: true, topics: [] });
    expect((await api().get(`${PREFIX}/me/subscriptions`).set(c.auth)).body.customPreferences).toBe(true);
    expect((await api().get(`${PREFIX}/me/subscriptions`)).status).toBe(401);
  });

  it('visitor device subscriptions: 404 unknown install, 409 when signed in, stores home ward on the device', async () => {
    const installId = randomUUID();
    const body = { homeWardId: fx.byNumber(2).id, extraWardIds: [], mutedTypes: ['heat'], criticalOnly: false };
    expect((await api().put(`${PREFIX}/devices/${installId}/subscriptions`).send(body)).status).toBe(404);
    await prisma.device.create({ data: { installId, platform: 'android', appVersion: '2.0.0' } });
    const res = await api().put(`${PREFIX}/devices/${installId}/subscriptions`).send(body);
    expect(res.body).toMatchObject({ homeWardId: fx.byNumber(2).id, mutedTypes: ['heat'], customPreferences: true });
    expect((await prisma.device.findUniqueOrThrow({ where: { installId } })).homeWardId).toBe(fx.byNumber(2).id);
    expect((await api().get(`${PREFIX}/devices/${installId}/subscriptions`)).body.mutedTypes).toEqual(['heat']);
    const c = await citizen();
    const signed = await api().put(`${PREFIX}/devices/${installId}/subscriptions`).set(c.auth).send(body);
    expect([signed.status, signed.body.error.code]).toEqual([409, 'SIGNED_IN_USE_ME']);
  });
});

describe('inbox (T-08-13)', () => {
  it('90-day window, live alert title in the user language, mark own read only, {all:true}, unreadCount', async () => {
    const c = await citizen(1, 'en');
    const other = await citizen(1);
    const mod = await staffUser('moderator');
    const { id: alertId } = await publishFlow(composer({ scope: 'wards', wardIds: [fx.byNumber(1).id] }, {}, clock), [mod.auth], mod.auth);
    const base = { titleEn: 'Your report was updated', titleGu: 'તમારી ફરિયાદ અપડેટ થઈ', bodyEn: 'Status: in progress', bodyGu: 'સ્થિતિ: કામ ચાલુ', status: 'sent' };
    await prisma.notification.create({ data: { ...base, userId: c.user.id, kind: 'issue_update', refId: 'i1', route: '/issues/i1', createdAt: new Date(clock.getTime() - 86_400_000) } });
    await prisma.notification.create({ data: { ...base, userId: c.user.id, kind: 'initiative', route: '/initiatives/x', createdAt: new Date(clock.getTime() - 2 * 86_400_000) } });
    await prisma.notification.create({ data: { ...base, userId: c.user.id, kind: 'issue_update', createdAt: new Date(clock.getTime() - 91 * 86_400_000) } });
    await prisma.alert.update({ where: { id: alertId }, data: { titleEn: 'Water cut moved to Friday' } });

    const res = await api().get(`${PREFIX}/me/notifications`).set(c.auth);
    expect(res.body.items.map((i: { kind: string }) => i.kind)).toEqual(['alert', 'issue_update', 'initiative']);
    expect(res.body.items[0]).toMatchObject({ title: 'Water cut moved to Friday', route: `/alerts/${alertId}`, alert: { severity: 'advisory', status: 'published' } });
    expect(res.body.unreadCount).toBe(3);

    const page = await api().get(`${PREFIX}/me/notifications?limit=2`).set(c.auth);
    const next = await api().get(`${PREFIX}/me/notifications?limit=2&cursor=${page.body.nextCursor}`).set(c.auth);
    expect(next.body.items.map((i: { kind: string }) => i.kind)).toEqual(['initiative']);

    const otherRow = await prisma.notification.findFirstOrThrow({ where: { userId: other.user.id } });
    const mine = res.body.items[1].id as string;
    const r1 = await api().post(`${PREFIX}/me/notifications/read`).set(c.auth).send({ ids: [mine, otherRow.id] });
    expect(r1.body.unreadCount).toBe(2);
    expect((await prisma.notification.findUniqueOrThrow({ where: { id: otherRow.id } })).readAt).toBeNull();
    expect((await api().post(`${PREFIX}/me/notifications/read`).set(c.auth).send({ ids: [mine] })).body.unreadCount).toBe(2);
    expect((await api().post(`${PREFIX}/me/notifications/read`).set(c.auth).send({ all: true })).body.unreadCount).toBe(0);
    expect((await api().post(`${PREFIX}/me/notifications/read`).set(c.auth).send({})).status).toBe(400);
    expect((await api().get(`${PREFIX}/me/notifications`)).status).toBe(401);
  });
});
