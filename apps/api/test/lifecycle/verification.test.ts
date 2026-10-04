// T-06-05 (AC-4), T-06-06 (AC-5), T-06-07 (AC-6), T-06-13 (quota), T-06-15 (haversine vs PostGIS).
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { resetClock } from '../../src/lib/clock';
import { prisma } from '../../src/lib/db';
import { haversineM } from '../../src/lib/geo/distance';
import { distanceMetres } from '../../src/lib/geo';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { INSIDE, markedFixedIssue, north, ownedPhoto, postVerify, seedReference, user, verifyBody } from './helpers';

beforeEach(async () => {
  await resetDb();
  await seedReference();
});
afterEach(() => resetClock());

const status = async (id: string) => (await prisma.issue.findUniqueOrThrow({ where: { id } })).status;

describe('verification rejections store nothing (T-06-05, AC-4)', () => {
  it('150 m away, 80 m accuracy, another user’s photo, second answer the same day', async () => {
    const reporter = await user();
    const issue = await markedFixedIssue(reporter.user.id);
    const v = await user();
    const far = await postVerify(v.auth, issue.id, await verifyBody(v.user.id, 'fixed', 150));
    expect(far.status).toBe(422);
    expect(far.body.error.code).toBe('TOO_FAR_FROM_ISSUE');
    expect(far.body.error.details[0]).toMatchObject({ field: 'location', radiusM: 100 });
    expect(far.body.error.details[0].distanceM).toBeGreaterThanOrEqual(149);
    const vague = await postVerify(v.auth, issue.id, await verifyBody(v.user.id, 'fixed', 40, { gpsAccuracyM: 80 }));
    expect(vague.body.error.code).toBe('LOCATION_TOO_INACCURATE');
    const otherPhoto = await ownedPhoto((await user()).user.id, { purpose: 'verification' });
    const stolen = await postVerify(v.auth, issue.id, await verifyBody(v.user.id, 'fixed', 40, { photoId: otherPhoto }));
    expect(stolen.status).toBe(422);
    expect(stolen.body.error.code).toBe('PHOTO_UNUSABLE');
    expect(await prisma.issueVerification.count()).toBe(0);
    expect(await prisma.issueEvent.count({ where: { issueId: issue.id, type: 'verification' } })).toBe(0);

    const ok = await postVerify(v.auth, issue.id, await verifyBody(v.user.id, 'not_fixed', 40));
    expect(ok.status).toBe(201);
    const again = await postVerify(v.auth, issue.id, await verifyBody(v.user.id, 'fixed', 40));
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('ALREADY_ANSWERED_TODAY');
    expect(await prisma.issueVerification.count()).toBe(1);
  });

  it('repeat clientSubmissionId → 200 with the original', async () => {
    const issue = await markedFixedIssue((await user()).user.id);
    const v = await user();
    const body = await verifyBody(v.user.id, 'not_fixed', 30);
    const first = await postVerify(v.auth, issue.id, body);
    const second = await postVerify(v.auth, issue.id, body);
    expect(first.status).toBe(201);
    expect(second.status).toBe(200);
    expect(second.body.verificationId).toBe(first.body.verificationId);
  });
});

describe('verification outcomes (T-06-06, AC-5)', () => {
  it('(a) a neighbour 40 m away answers Fixed → verified, with distance and a follower notification', async () => {
    const reporter = await user();
    const issue = await markedFixedIssue(reporter.user.id);
    const v = await user();
    const res = await postVerify(v.auth, issue.id, await verifyBody(v.user.id, 'fixed', 40));
    expect(res.status).toBe(201);
    expect(res.body.issue).toEqual({ status: 'verified', displayStatus: 'verified' });
    expect(res.body.distanceM).toBeGreaterThanOrEqual(39);
    expect(res.body.distanceM).toBeLessThanOrEqual(41);
    const row = await prisma.issueVerification.findFirstOrThrow({ where: { issueId: issue.id } });
    expect(Number(row.distanceM)).toBeCloseTo(40, 0);
    const n = await prisma.notification.findFirstOrThrow({ where: { refId: issue.id, userId: reporter.user.id } });
    expect(n.titleEn).toBe('Fix verified');
  });

  it('(b) the reporter answers Not fixed → reopened, reopened_count 1, new SLA date', async () => {
    const reporter = await user();
    const issue = await markedFixedIssue(reporter.user.id);
    const res = await postVerify(reporter.auth, issue.id, await verifyBody(reporter.user.id, 'not_fixed', 20));
    expect(res.body.issue.status).toBe('reopened');
    const row = await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } });
    expect(row.reopenedCount).toBe(1);
    expect(row.slaDueAt.getTime()).toBeGreaterThan(Date.now() + 6 * 86_400_000);
    const ev = await prisma.issueEvent.findFirstOrThrow({ where: { issueId: issue.id, toStatus: 'reopened' } });
    expect(ev).toMatchObject({ actorRole: 'system', note: 'Reporter says it is not fixed' });
  });

  it('(c) two neighbours Not fixed and one Fixed → reopened (reopened beats verified)', async () => {
    const issue = await markedFixedIssue((await user()).user.id);
    const [a, b, c] = [await user(), await user(), await user()];
    await postVerify(a.auth, issue.id, await verifyBody(a.user.id, 'not_fixed', 30));
    expect(await status(issue.id)).toBe('marked_fixed');
    const fixed = await postVerify(c.auth, issue.id, await verifyBody(c.user.id, 'fixed', 30));
    expect(fixed.body.issue.status).toBe('verified');
    const last = await postVerify(b.auth, issue.id, await verifyBody(b.user.id, 'not_fixed', 30));
    expect(last.body.issue.status).toBe('reopened');
    expect(await prisma.issueVerification.count({ where: { issueId: issue.id } })).toBe(3);
  });

  it('the person who marked it fixed cannot verify it themselves', async () => {
    const mod = await user('moderator');
    const issue = await markedFixedIssue((await user()).user.id, 0, mod.user.id);
    const res = await postVerify(mod.auth, issue.id, await verifyBody(mod.user.id, 'fixed', 10));
    expect(res.status).toBe(201);
    expect(res.body.issue.status).toBe('marked_fixed');
  });
});

describe('reopen window (T-06-07, AC-6)', () => {
  it('8 days after marked fixed → fixed_unverified and 409 VERIFY_NOT_OPEN', async () => {
    const issue = await markedFixedIssue((await user()).user.id, 8);
    const v = await user();
    const res = await postVerify(v.auth, issue.id, await verifyBody(v.user.id, 'fixed', 10));
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('VERIFY_NOT_OPEN');
    const { deriveIssue } = await import('../../src/modules/issues/derive');
    const d = deriveIssue(await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } }));
    expect(d.displayStatus).toBe('fixed_unverified');
    expect(d.verifyWindowClosesAt!.getTime()).toBeLessThan(Date.now());
  });
});

describe('verification quota (T-06-13)', () => {
  it('the 21st verification within 24 h → 429', async () => {
    const v = await user();
    const reporter = await user();
    for (let i = 0; i < 20; i++) {
      const other = await markedFixedIssue(reporter.user.id);
      await prisma.issueVerification.create({ data: { issueId: other.id, userId: v.user.id, answer: 'fixed', createdDay: new Date('2026-10-04') } });
    }
    const issue = await markedFixedIssue(reporter.user.id);
    const res = await postVerify(v.auth, issue.id, await verifyBody(v.user.id, 'fixed', 10));
    expect(res.status).toBe(429);
    expect(res.body.error.details[0].issue).toBe('verifications_per_day');
  });
});

describe('haversine vs PostGIS (T-06-15)', () => {
  it('agree within 0.5 m on 10 point pairs inside the 100 m verify radius', async () => {
    const issue = await markedFixedIssue((await user()).user.id);
    const pairs = [5, 12, 30, 47, 60, 75, 88, 95, 99, 100].map((m, i) => (i % 2 ? north(m) : { lat: INSIDE.lat, lng: INSIDE.lng + m / 102_400 }));
    for (const p of pairs) {
      const pg = (await distanceMetres(issue.id, p.lat, p.lng))!;
      expect(Math.abs(pg - haversineM(INSIDE.lat, INSIDE.lng, p.lat, p.lng))).toBeLessThan(0.5);
    }
  });
});

it('unsigned verification → 401', async () => {
  const issue = await markedFixedIssue((await user()).user.id);
  expect((await api().post(`/api/v1/issues/${issue.id}/verifications`).send({})).status).toBe(401);
});
