// T-08-07, T-08-08, T-08-14 (AC-5, AC-6, AC-10, AC-12): topics, payload, filtered device sends, quiet hours, fan-out.
import { randomUUID } from 'node:crypto';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { resetClock, setClock } from '../../src/lib/clock';
import { prisma } from '../../src/lib/db';
import { flushQueued } from '../../src/lib/push';
import { useMemoryPush } from '../auth/helpers';
import { resetDb } from '../helpers/db';
import { makeUser } from '../helpers/factories';
import { act, composer, ist, publishFlow, staffUser, wardsFixture } from './helpers';

const push = useMemoryPush();
let clock = ist('2030-01-10T11:00:00');
let fx: Awaited<ReturnType<typeof wardsFixture>>;
let mod: Awaited<ReturnType<typeof staffUser>>;
let admin: Awaited<ReturnType<typeof staffUser>>;

beforeEach(async () => {
  await resetDb();
  push.sent.length = 0;
  clock = ist('2030-01-10T11:00:00');
  setClock(() => clock);
  fx = await wardsFixture();
  mod = await staffUser('moderator');
  admin = await staffUser('admin');
});
afterAll(resetClock);

async function device(opts: { userId?: string; homeWardId?: string; language?: 'gu' | 'en' } = {}) {
  return prisma.device.create({
    data: { installId: randomUUID(), userId: opts.userId ?? null, homeWardId: opts.homeWardId ?? null, fcmToken: `tok-${randomUUID()}`, platform: 'android', appVersion: '2.0.0', language: opts.language ?? 'gu' },
  });
}

const topicsSent = () => push.sent.filter((s) => s.topic).map((s) => s.topic).sort();

describe('topics and payload (T-08-07)', () => {
  it('wards / zone / city topics in both languages, channel, tag, route and one log row per base topic', async () => {
    const w = await publishFlow(composer({ scope: 'wards', wardIds: [fx.byNumber(1).id, fx.byNumber(3).id] }, {}, clock), [mod.auth], mod.auth);
    expect(topicsSent()).toEqual(['ward_1__en', 'ward_1__gu', 'ward_3__en', 'ward_3__gu']);
    const gu = push.sent.find((s) => s.topic === 'ward_1__gu')!.payload;
    expect(gu).toMatchObject({ channel: 'alerts', tag: `alert:${w.id}`, data: { kind: 'alert', refId: w.id, route: `/alerts/${w.id}` } });
    expect(gu.title).toBe('આલ્ફામાં પાણી પુરવઠો બંધ');
    expect(await prisma.notification.count({ where: { refId: w.id, topic: { not: null } } })).toBe(2);

    push.sent.length = 0;
    await publishFlow(composer({ scope: 'zone', zoneId: fx.zone('west').id }, {}, clock), [mod.auth], mod.auth);
    expect(topicsSent()).toEqual(['zone_west__en', 'zone_west__gu']);

    push.sent.length = 0;
    const c = await publishFlow(composer({ scope: 'city' }, { severity: 'critical' }, clock), [mod.auth, admin.auth], admin.auth);
    expect(topicsSent()).toEqual(['city_all__en', 'city_all__gu']);
    expect(push.sent[0]!.payload.channel).toBe('critical_alerts');
    expect((await prisma.alertWard.count({ where: { alertId: c.id } }))).toBe(3);
  });

  it('a device with custom preferences in ward 1 gets one filtered device send; muted type or critical-only blocks it', async () => {
    const u = await makeUser({ homeWardId: fx.byNumber(1).id });
    const d = await device({ userId: u.id, language: 'en' });
    await prisma.subscription.create({ data: { userId: u.id, scope: 'city', mutedTypes: ['road_closure'] } });
    const visitor = await device({ homeWardId: fx.byNumber(1).id });
    await prisma.subscription.create({ data: { deviceId: visitor.id, scope: 'city', criticalOnly: true } });
    const elsewhere = await device({ homeWardId: fx.byNumber(3).id });
    await prisma.subscription.create({ data: { deviceId: elsewhere.id, scope: 'city', criticalOnly: true } });

    await publishFlow(composer({ scope: 'wards', wardIds: [fx.byNumber(1).id] }, {}, clock), [mod.auth], mod.auth);
    const tokenSends = push.sent.filter((s) => s.token);
    expect(tokenSends.map((s) => s.token)).toEqual([d.fcmToken]);
    expect(tokenSends[0]!.payload.title).toBe('Water supply cut in Alpha');

    push.sent.length = 0;
    await publishFlow(composer({ scope: 'wards', wardIds: [fx.byNumber(1).id] }, { type: 'road_closure', severity: 'warning' }, clock), [mod.auth, admin.auth], admin.auth);
    expect(push.sent.filter((s) => s.token)).toHaveLength(0);

    push.sent.length = 0;
    const crit = await publishFlow(composer({ scope: 'wards', wardIds: [fx.byNumber(1).id] }, { severity: 'critical' }, clock), [mod.auth, admin.auth], admin.auth);
    expect(push.sent.filter((s) => s.token).map((s) => s.token).sort()).toEqual([d.fcmToken, visitor.fcmToken].sort());
    expect(await prisma.notification.count({ where: { refId: crit.id, targetDeviceIds: { isEmpty: false } } })).toBe(1);
  });
});

describe('quiet hours (T-08-08)', () => {
  it('23:30 IST: Critical immediate; Advisory queued until 07:00, visible in inbox at once, sent by flushQueued', async () => {
    clock = ist('2030-01-10T23:30:00');
    const u = await makeUser({ homeWardId: fx.byNumber(1).id });
    const target = { scope: 'wards', wardIds: [fx.byNumber(1).id] };
    const crit = await publishFlow(composer(target, { severity: 'critical' }, clock), [mod.auth, admin.auth], admin.auth);
    expect(crit.body.delivery).toEqual({ held: false });
    expect(topicsSent()).toHaveLength(2);
    push.sent.length = 0;
    const adv = await publishFlow(composer(target, {}, clock), [mod.auth], mod.auth);
    expect(adv.body.delivery).toEqual({ held: true, sendAfter: ist('2030-01-11T07:00:00').toISOString() });
    expect(push.sent).toHaveLength(0);
    const queued = await prisma.notification.findMany({ where: { refId: adv.id, status: 'queued' } });
    expect(queued).toHaveLength(1);
    expect(await prisma.notification.count({ where: { userId: u.id, refId: adv.id } })).toBe(1);
    expect(await flushQueued(ist('2030-01-11T06:59:00'))).toBe(0);
    expect(await flushQueued(ist('2030-01-11T07:00:00'))).toBe(1);
    expect(topicsSent()).toEqual(['ward_1__en', 'ward_1__gu']);
  });

  it('06:59 holds, 07:00 sends; retracted before 07:00 → queued rows withdrawn and nothing sent', async () => {
    const target = { scope: 'wards', wardIds: [fx.byNumber(1).id] };
    clock = ist('2030-01-11T07:00:00');
    expect((await publishFlow(composer(target, {}, clock), [mod.auth], mod.auth)).body.delivery).toEqual({ held: false });
    clock = ist('2030-01-11T06:59:00');
    const held = await publishFlow(composer(target, {}, clock), [mod.auth], mod.auth);
    expect(held.body.delivery).toMatchObject({ held: true });
    push.sent.length = 0;
    expect((await act(mod.auth, held.id, 'retract', { reason: 'Supply restored early' })).status).toBe(200);
    const rows = await prisma.notification.findMany({ where: { refId: held.id, userId: null } });
    expect(rows.map((r) => [r.status, r.errorCode])).toEqual([['failed', 'alert_withdrawn']]);
    expect(await flushQueued(ist('2030-01-11T07:05:00'))).toBe(0);
    expect(push.sent).toHaveLength(0);
  });
});

describe('inbox fan-out (T-08-14)', () => {
  it('home-ward and extra-ward users get a row; other-ward and suspended users do not; no duplicates', async () => {
    const home = await makeUser({ homeWardId: fx.byNumber(1).id, language: 'en' });
    const extra = await makeUser({ homeWardId: fx.byNumber(3).id });
    await prisma.subscription.create({ data: { userId: extra.id, scope: 'ward', scopeId: fx.byNumber(1).id } });
    const other = await makeUser({ homeWardId: fx.byNumber(2).id });
    const suspended = await makeUser({ homeWardId: fx.byNumber(1).id, status: 'suspended' });
    const { id } = await publishFlow(composer({ scope: 'wards', wardIds: [fx.byNumber(1).id] }, {}, clock), [mod.auth], mod.auth);
    const rows = await prisma.notification.findMany({ where: { refId: id, userId: { not: null } } });
    expect(rows.map((r) => r.userId).sort()).toEqual([home.id, extra.id].sort());
    expect(rows[0]).toMatchObject({ kind: 'alert', route: `/alerts/${id}`, status: 'sent', readAt: null });
    const { fanOutInbox } = await import('../../src/modules/alerts/publish');
    const alert = await prisma.alert.findUniqueOrThrow({ where: { id } });
    expect(await prisma.$transaction((tx) => fanOutInbox(tx, alert, clock))).toBe(0);
    void other;
    void suspended;
  });
});
