// T-09-10 (scorecard numbers vs hand calculation), T-09-11 (concurrent refresh), T-09-12 (election mode) — AC-9..11.
import { randomUUID } from 'node:crypto';
import express from 'express';
import request from 'supertest';
import type { IssueStatus } from '@prisma/client';
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { refreshScorecard } from '../../src/modules/representatives/scorecard.service';
import { assertNotElectionFrozen, invalidateElectionModeCache, isElectionMode } from '../../src/modules/settings/electionMode';
import { requireUser } from '../../src/middleware/requireUser';
import { errorHandler } from '../../src/middleware/errorHandler';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { makeCategory, makeIssue } from '../helpers/factories';
import { fixtureWards, makeRep, useMemoryMail, userWithToken } from './helpers';

useMemoryMail();
const DAY = 86_400_000;
let wards: Map<number, string>;
let categoryId: string;

beforeEach(async () => {
  await resetDb();
  wards = await fixtureWards();
  categoryId = (await makeCategory()).id;
  invalidateElectionModeCache();
});

interface Spec { status: IssueStatus; ack?: number; fix?: number; reopened?: boolean; changedDaysAgo?: number; createdDaysAgo?: number; visibility?: 'public' | 'hidden'; mergedIntoId?: string }

async function issue(wardId: string, s: Spec) {
  const created = new Date(Date.now() - (s.createdDaysAgo ?? 30) * DAY);
  const i = await makeIssue({
    categoryId, wardId, status: s.status, visibility: s.visibility ?? 'public', createdAt: created,
    statusChangedAt: new Date(Date.now() - (s.changedDaysAgo ?? 1) * DAY), mergedIntoId: s.mergedIntoId,
  });
  const ev = async (to: IssueStatus, days: number) =>
    prisma.issueEvent.create({ data: { issueId: i.id, actorRole: 'system', type: 'status_change', toStatus: to, createdAt: new Date(created.getTime() + days * DAY) } });
  if (s.ack !== undefined) await ev('acknowledged', s.ack);
  if (s.fix !== undefined) await ev('marked_fixed', s.fix);
  if (s.reopened) await ev('reopened', (s.fix ?? 0) + 1);
  return i;
}

/** Ward 1: 12 counted issues + excluded hidden/rejected/merged + one 100-day-old open issue (backlog only). */
async function seedWard1() {
  const w = wards.get(1)!;
  await prisma.ward.update({ where: { id: w }, data: { population: 50_000 } });
  const specs: Spec[] = [
    { status: 'verified', ack: 1, fix: 4 },
    { status: 'verified', ack: 2, fix: 6 },
    { status: 'verified', ack: 3, fix: 8 },
    { status: 'reopened', ack: 1, fix: 5, reopened: true },
    { status: 'marked_fixed', ack: 2, fix: 10, changedDaysAgo: 3 },
    { status: 'in_progress', ack: 4 },
    { status: 'acknowledged', ack: 5 },
    { status: 'reported' },
    { status: 'reported' },
    { status: 'sent' },
    { status: 'verified', ack: 1, fix: 2 },
    { status: 'acknowledged', ack: 3 },
    // Excluded from everything:
    { status: 'reported', visibility: 'hidden', ack: 1 },
    { status: 'rejected', ack: 1 },
    { status: 'merged', ack: 1 },
    // Outside the window: backlog only.
    { status: 'reported', createdDaysAgo: 100 },
  ];
  let first: string | undefined;
  for (const s of specs) {
    const i = await issue(w, s.status === 'merged' ? { ...s, mergedIntoId: first } : s);
    first ??= i.id;
  }
}

describe('ward scorecard (T-09-10, AC-9)', () => {
  it('matches the hand calculation; small samples are null; population missing → null', async () => {
    await seedWard1();
    const w2 = wards.get(2)!;
    await issue(w2, { status: 'verified', ack: 1, fix: 2 });
    await issue(w2, { status: 'reported' });
    await issue(w2, { status: 'acknowledged', ack: 2 });
    await refreshScorecard();

    const one = await api().get(`/api/v1/wards/${wards.get(1)}/scorecard`);
    expect(one.status).toBe(200);
    expect(one.body).toMatchObject({ hidden: false, windowDays: 90, population: { value: 50_000 } });
    // ack days [1,1,1,2,2,3,3,4,5] → 2; fix days [2,4,5,6,8,10] → 5.5; verified 4/(4+1) = 80;
    // reopened 1 of 6 fixed = 16.7; backlog 7 in window + 1 old = 8; 12/50,000×1,000 = 0.24 → 0.2.
    expect(one.body.metrics).toEqual({
      issuesReported: 12, medianDaysAck: 2, medianDaysFix: 5.5, verifiedPct: 80, reopenPct: 16.7, openBacklog: 8, reportsPer1000: 0.2,
    });

    const two = await api().get(`/api/v1/wards/${w2}/scorecard`);
    expect(two.body.metrics).toEqual({
      issuesReported: 3, medianDaysAck: null, medianDaysFix: null, verifiedPct: null, reopenPct: null, openBacklog: 2, reportsPer1000: null,
    });
    expect(two.body.population).toEqual({ value: null, sourceNote: null });
    expect((await api().get(`/api/v1/wards/${randomUUID()}/scorecard`)).status).toBe(404);
  });
});

describe('scorecard refresh (T-09-11, AC-10)', () => {
  it('refreshed_at advances, metrics update, and reads during a concurrent refresh never fail', async () => {
    await refreshScorecard();
    const w = wards.get(1)!;
    const before = await api().get(`/api/v1/wards/${w}/scorecard`);
    expect(before.body.metrics.issuesReported).toBe(0);
    await issue(w, { status: 'acknowledged', ack: 1 });
    const reads = Array.from({ length: 10 }, () => api().get(`/api/v1/wards/${w}/scorecard`));
    const [, ...results] = await Promise.all([refreshScorecard(), ...reads]);
    expect(results.every((r) => r.status === 200)).toBe(true);
    const after = await api().get(`/api/v1/wards/${w}/scorecard`);
    expect(after.body.metrics.issuesReported).toBe(1);
    expect(new Date(after.body.refreshedAt).getTime()).toBeGreaterThan(new Date(before.body.refreshedAt).getTime());
  });
});

describe('election mode (T-09-12, AC-11)', () => {
  const window = (days = 30) => ({ from: new Date(Date.now() - 60_000).toISOString(), to: new Date(Date.now() + days * DAY).toISOString() });

  it('ward scope: banner data + hidden scorecard for listed wards only; 409 on a guarded rep write; citizens still message', async () => {
    const admin = await userWithToken({ role: 'admin' });
    const put = await api()
      .put('/api/v1/staff/settings/election-mode')
      .set(admin.auth)
      .send({ enabled: true, scope: 'wards', wardIds: [wards.get(1)], ...window(), note_en: 'Polls on 1 Nov', note_gu: 'મતદાન 1 નવે.' });
    expect(put.status).toBe(200);
    const sc1 = await api().get(`/api/v1/wards/${wards.get(1)}/scorecard`);
    expect(sc1.body).toMatchObject({ hidden: true, reason: 'election_mode' });
    expect((await api().get(`/api/v1/wards/${wards.get(2)}/scorecard`)).body.hidden).toBe(false);
    const reps = await api().get(`/api/v1/wards/${wards.get(1)}/representatives`);
    expect(reps.body.electionMode).toMatchObject({ active: true, noteEn: 'Polls on 1 Nov' });
    expect((await api().get(`/api/v1/wards/${wards.get(2)}/representatives`)).body.electionMode.active).toBe(false);
    const pub = await api().get('/api/v1/settings/public');
    expect(pub.body.electionMode).toMatchObject({ active: true, scope: 'wards', wardIds: [wards.get(1)] });

    // Guarded test-only route (TASK-11 applies the same middleware to comments and replies).
    const app = express();
    app.use(express.json());
    app.post('/t/:wardId', requireUser, assertNotElectionFrozen((req) => String(req.params.wardId)), (_req, res) => { res.json({ ok: true }); });
    app.use(errorHandler);
    const repUser = await userWithToken({ role: 'representative' });
    const frozen = await request(app).post(`/t/${wards.get(1)}`).set(repUser.auth).send({});
    expect(frozen.status).toBe(409);
    expect(frozen.body.error.code).toBe('ELECTION_MODE_FROZEN');
    expect((await request(app).post(`/t/${wards.get(2)}`).set(repUser.auth).send({})).status).toBe(200);
    expect((await request(app).post(`/t/${wards.get(1)}`).set(admin.auth).send({})).status).toBe(200);

    const rep = await makeRep({}, [{ wardId: wards.get(1)! }]);
    const cit = await userWithToken({ relayConsent: true });
    const sent = await api().post(`/api/v1/representatives/${rep.id}/messages`).set(cit.auth)
      .send({ clientMessageId: randomUUID(), subject: 'Hello office', body: 'Please fix the water leak near the school.' });
    expect(sent.status).toBe(202);

    // Turning it off restores everything (cache invalidated by the PUT).
    await api().put('/api/v1/staff/settings/election-mode').set(admin.auth).send({ enabled: false, scope: 'city', ...window() });
    expect((await api().get(`/api/v1/wards/${wards.get(1)}/scorecard`)).body.hidden).toBe(false);
  });

  it('city scope and window: active everywhere inside the window, inactive after it; validation and roles', async () => {
    const admin = await userWithToken({ role: 'admin' });
    const mod = await userWithToken({ role: 'moderator' });
    await api().put('/api/v1/staff/settings/election-mode').set(admin.auth).send({ enabled: true, scope: 'city', ...window(10) });
    expect(await isElectionMode(wards.get(3)!)).toBe(true);
    expect(await isElectionMode(wards.get(3)!, new Date(Date.now() + 11 * DAY))).toBe(false);
    expect((await api().get('/api/v1/staff/settings/election-mode').set(mod.auth)).body.scope).toBe('city');
    expect((await api().put('/api/v1/staff/settings/election-mode').set(mod.auth).send({ enabled: false, scope: 'city', ...window() })).status).toBe(403);
    const tooLong = await api().put('/api/v1/staff/settings/election-mode').set(admin.auth).send({ enabled: true, scope: 'city', ...window(121) });
    expect(tooLong.status).toBe(400);
    const noWards = await api().put('/api/v1/staff/settings/election-mode').set(admin.auth).send({ enabled: true, scope: 'wards', wardIds: [], ...window() });
    expect(noWards.status).toBe(400);
  });
});
