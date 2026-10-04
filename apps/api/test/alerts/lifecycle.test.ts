// T-08-09, T-08-10, T-08-11 (AC-7, AC-8, AC-9): expiry, supersede/retract, public reads.
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { resetClock, setClock } from '../../src/lib/clock';
import { prisma } from '../../src/lib/db';
import { clearJobs, registerAppJobs, runJob } from '../../src/jobs';
import { useMemoryPush } from '../auth/helpers';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { act, composer, createDraft, ist, PREFIX, publishFlow, staffUser, wardsFixture } from './helpers';

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
afterAll(() => {
  resetClock();
  clearJobs();
});

const w1 = () => ({ scope: 'wards', wardIds: [fx.byNumber(1).id] });
const list = (wards: string[], active: boolean, extra = '') => api().get(`${PREFIX}/alerts?wards=${wards.join(',')}&active=${active}${extra}`);

describe('expiry (T-08-09)', () => {
  it('a published alert past valid_to is never active, reads as expired, and alerts-expire stores it and withdraws held sends', async () => {
    const { id } = await publishFlow(composer(w1(), { validTo: new Date(clock.getTime() + 60_000).toISOString() }, clock), [mod.auth], mod.auth);
    expect((await list([fx.byNumber(1).id], true)).body.items.map((a: { id: string }) => a.id)).toEqual([id]);
    clock = new Date(clock.getTime() + 120_000);
    expect((await list([fx.byNumber(1).id], true)).body.items).toHaveLength(0);
    const past = await list([fx.byNumber(1).id], false);
    expect(past.body.items[0]).toMatchObject({ id, status: 'expired', isActive: false });
    await prisma.notification.create({ data: { kind: 'alert', refId: id, topic: 'ward_1', titleEn: 't', titleGu: 't', bodyEn: 'b', bodyGu: 'b', status: 'queued', sendAfter: ist('2030-01-11T07:00:00') } });
    registerAppJobs();
    const out = await runJob('alerts-expire', clock);
    expect(out).toMatchObject({ status: 'ran', result: { expired: 1, withdrawn: 1 } });
    expect((await prisma.alert.findUniqueOrThrow({ where: { id } })).status).toBe('expired');
    expect((await runJob('alerts-expire', clock)).status).toBe('ran');
  });
});

describe('supersede and retract (T-08-10)', () => {
  it('update supersedes a pushed Warning; old is expired with supersededById; retraction pushes "Cancelled"', async () => {
    const old = await publishFlow(composer(w1(), { severity: 'warning' }, clock), [mod.auth, admin.auth], admin.auth);
    const sup = await act(admin.auth, old.id, 'supersede');
    expect(sup.status).toBe(201);
    expect(sup.body).toMatchObject({ status: 'draft', supersedesId: old.id });
    expect((await act(admin.auth, old.id, 'supersede')).body.error.code).toBe('ALERT_ALREADY_SUPERSEDED');
    await act(mod.auth, sup.body.id, 'submit');
    await act(mod.auth, sup.body.id, 'approve');
    await act(admin.auth, sup.body.id, 'approve');
    expect((await act(admin.auth, sup.body.id, 'publish')).status).toBe(200);
    const detail = await api().get(`${PREFIX}/alerts/${old.id}`);
    expect(detail.body).toMatchObject({ status: 'expired', supersededById: sup.body.id });

    const other = await publishFlow(composer(w1(), {}, clock), [mod.auth], mod.auth);
    push.sent.length = 0;
    const r = await act(mod.auth, other.id, 'retract', { reason: 'Wrong ward given' });
    expect(r.body).toMatchObject({ status: 'retracted', retractionReason: 'Wrong ward given' });
    const titles = push.sent.filter((s) => s.topic).map((s) => s.payload.title);
    expect(titles).toEqual(expect.arrayContaining(['Cancelled: Water supply cut in Alpha', 'રદ: આલ્ફામાં પાણી પુરવઠો બંધ']));
    expect((await api().get(`${PREFIX}/alerts/${other.id}`)).body).toMatchObject({ status: 'retracted', retractionReason: 'Wrong ward given' });
    expect((await act(mod.auth, other.id, 'retract', { reason: 'Again please' })).status).toBe(409);
    expect((await act(mod.auth, other.id, 'supersede')).status).toBe(409);
  });
});

describe('public reads (T-08-11)', () => {
  it('drafts and pending are 404; Critical first then valid_from; ward filter; validation; cursor paging', async () => {
    const draft = await createDraft(mod.auth, composer(w1(), {}, clock));
    expect((await api().get(`${PREFIX}/alerts/${draft}`)).status).toBe(404);
    await act(mod.auth, draft, 'submit');
    expect((await api().get(`${PREFIX}/alerts/${draft}`)).status).toBe(404);

    const later = new Date(clock.getTime() + 3_600_000);
    const a1 = await publishFlow(composer(w1(), {}, clock), [mod.auth], mod.auth);
    const a2 = await publishFlow(composer(w1(), { validFrom: later.toISOString() }, clock), [mod.auth], mod.auth);
    const crit = await publishFlow(composer(w1(), { severity: 'critical', validFrom: later.toISOString() }, clock), [mod.auth, admin.auth], admin.auth);
    const elsewhere = await publishFlow(composer({ scope: 'wards', wardIds: [fx.byNumber(3).id] }, {}, clock), [mod.auth], mod.auth);
    const res = await list([fx.byNumber(1).id], true);
    expect(res.body.items.map((a: { id: string }) => a.id)).toEqual([crit.id, a1.id, a2.id]);
    expect(res.body.items[0]).toMatchObject({ severity: 'critical', target: { scope: 'wards', wardNumbers: [1] }, sourceName: 'AMC Water Department' });
    expect((await list([fx.byNumber(1).id, fx.byNumber(3).id], true)).body.items).toHaveLength(4);
    void elsewhere;

    const p1 = await list([fx.byNumber(1).id], true, '&limit=2');
    expect(p1.body.items).toHaveLength(2);
    const p2 = await list([fx.byNumber(1).id], true, `&limit=2&cursor=${p1.body.nextCursor}`);
    expect(p2.body.items.map((a: { id: string }) => a.id)).toEqual([a2.id]);
    expect(p2.body.nextCursor).toBeNull();

    expect((await api().get(`${PREFIX}/alerts`)).status).toBe(400);
    expect((await api().get(`${PREFIX}/alerts?wards=12`)).status).toBe(400);
    const seven = Array.from({ length: 7 }, () => fx.byNumber(1).id).join(',');
    expect((await api().get(`${PREFIX}/alerts?wards=${seven}`)).status).toBe(400);
    expect((await list([fx.byNumber(1).id], true, '&cursor=nope')).status).toBe(400);
    const detail = await api().get(`${PREFIX}/alerts/${a1.id}`);
    expect(detail.body.wards[0]).toMatchObject({ number: 1, nameEn: 'Alpha' });
  });
});
