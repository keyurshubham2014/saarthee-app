// T-06-03 (AC-2), T-06-04 (AC-3), T-06-12 (AC-11), T-06-14: concurrency, after photos, notification fan-out, /verify retired.
import { randomUUID } from 'node:crypto';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { resetClock, setClock } from '../../src/lib/clock';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { openIssue, ownedPhoto, postStatus, seedReference, user } from './helpers';

beforeEach(async () => {
  await resetDb();
  await seedReference();
});
afterEach(() => resetClock());

describe('concurrency and idempotency (T-06-03)', () => {
  it('two concurrent marked_fixed: one 200 + one STALE_STATUS; a repeated clientActionId returns the original event', async () => {
    const reporter = await user();
    const issue = await openIssue(reporter.user.id, { status: 'in_progress' });
    const m1 = await user('moderator');
    const m2 = await user('moderator');
    const key = randomUUID();
    const [a, b] = await Promise.all([
      postStatus(m1.auth, issue.id, 'marked_fixed', 'in_progress', { clientActionId: key }),
      postStatus(m2.auth, issue.id, 'marked_fixed', 'in_progress'),
    ]);
    const codes = [a.status, b.status].sort();
    expect(codes).toEqual([200, 409]);
    const loser = a.status === 409 ? a : b;
    expect(loser.body.error.code).toBe('STALE_STATUS');
    expect(loser.body.error.details[0].issue).toBe('marked_fixed');
    if (a.status === 200) {
      const again = await postStatus(m1.auth, issue.id, 'marked_fixed', 'in_progress', { clientActionId: key });
      expect(again.status).toBe(200);
      expect(again.body.event.id).toBe(a.body.event.id);
      expect(again.body.repeated).toBe(true);
    }
    expect(await prisma.issueEvent.count({ where: { issueId: issue.id, toStatus: 'marked_fixed' } })).toBe(1);
    const row = await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } });
    expect(row.statusVersion).toBe(1);
  });
});

describe('mark fixed with after photo (T-06-04, AC-3)', () => {
  it('attaches the after photo, sets marked_fixed_at and notifies followers but not the reporter', async () => {
    const reporter = await user();
    const follower = await user();
    const issue = await openIssue(reporter.user.id, { status: 'acknowledged' });
    await prisma.follow.create({ data: { issueId: issue.id, userId: follower.user.id } });
    const photoId = await ownedPhoto(reporter.user.id, { purpose: 'after' });
    const res = await postStatus(reporter.auth, issue.id, 'marked_fixed', 'acknowledged', { photoIds: [photoId], note: 'Patched today' });
    expect(res.status).toBe(200);
    expect(res.body.issue).toMatchObject({ status: 'marked_fixed', displayStatus: 'marked_fixed', isOverdue: false });
    expect(res.body.issue.verifyWindowClosesAt).toBeTruthy();
    const row = await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } });
    expect(row.markedFixedAt).not.toBeNull();
    expect(await prisma.issuePhoto.findFirst({ where: { issueId: issue.id, photoId } })).toMatchObject({ kind: 'after' });
    const notes = await prisma.notification.findMany({ where: { kind: 'issue_update', refId: issue.id } });
    expect(notes.map((n) => n.userId)).toEqual([follower.user.id]);
    expect(notes[0]).toMatchObject({ titleEn: 'Is it fixed? Help check', route: `/issues/${issue.id}/verify` });
  });

  it('a photo with the wrong purpose (or someone else’s) → 422 PHOTO_UNUSABLE and nothing changes', async () => {
    const reporter = await user();
    const issue = await openIssue(reporter.user.id);
    const report = await ownedPhoto(reporter.user.id, { purpose: 'report' });
    const res = await postStatus(reporter.auth, issue.id, 'marked_fixed', 'reported', { photoIds: [report] });
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('PHOTO_UNUSABLE');
    const other = await ownedPhoto((await user()).user.id, { purpose: 'after' });
    expect((await postStatus(reporter.auth, issue.id, 'marked_fixed', 'reported', { photoIds: [other] })).status).toBe(422);
    expect((await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } })).status).toBe('reported');
    expect(await prisma.issueEvent.count({ where: { issueId: issue.id } })).toBe(0);
  });

  it('POST /photos accepts purpose=after with an issueId and rejects it without one', async () => {
    const reporter = await user();
    const issue = await openIssue(reporter.user.id);
    const { jpegWithExif } = await import('../issues/helpers');
    const ok = await api().post('/api/v1/photos').set(reporter.auth).field('purpose', 'after').field('issueId', issue.id)
      .attach('photo', await jpegWithExif(), { filename: 'a.jpg', contentType: 'image/jpeg' });
    expect(ok.status).toBe(201);
    expect((await prisma.photo.findUniqueOrThrow({ where: { id: ok.body.photoId } })).purpose).toBe('after');
    const bad = await api().post('/api/v1/photos').set(reporter.auth).field('purpose', 'verification')
      .attach('photo', await jpegWithExif(), { filename: 'a.jpg', contentType: 'image/jpeg' });
    expect(bad.status).toBe(400);
  });
});

describe('notification fan-out (T-06-12, AC-11)', () => {
  it('3 followers incl. reporter get rows; the moderator none; push held to 07:00 IST at 23:00 IST', async () => {
    const day = new Date(Date.now() + 2 * 86_400_000);
    const at2300Ist = new Date(Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), day.getUTCDate(), 17, 30));
    setClock(() => at2300Ist);
    const reporter = await user('citizen', { language: 'gu' });
    const f1 = await user('citizen', { language: 'en' });
    const f2 = await user('citizen', { language: 'gu' });
    const mod = await user('moderator');
    const issue = await openIssue(reporter.user.id, { status: 'acknowledged' });
    for (const u of [f1, f2, mod]) await prisma.follow.create({ data: { issueId: issue.id, userId: u.user.id } });
    expect((await postStatus(mod.auth, issue.id, 'in_progress', 'acknowledged')).status).toBe(200);
    const rows = await prisma.notification.findMany({ where: { kind: 'issue_update', refId: issue.id } });
    expect(rows.map((r) => r.userId).sort()).toEqual([reporter.user.id, f1.user.id, f2.user.id].sort());
    const next0700Ist = new Date(at2300Ist.getTime() + 8 * 3_600_000);
    for (const r of rows) {
      expect(r).toMatchObject({ status: 'queued', route: `/issues/${issue.id}`, titleEn: 'Work has started', titleGu: 'કામ શરૂ થયું' });
      expect(r.sendAfter?.toISOString()).toBe(next0700Ist.toISOString());
      expect(`${r.titleEn} ${r.bodyEn}`).not.toMatch(/\+91|Sample Citizen/);
    }
  });
});

describe('v1 verify API (T-06-14)', () => {
  it('every /verify/* path answers 410 ENDPOINT_RETIRED', async () => {
    for (const path of ['/api/v1/verify/summary', '/api/v1/verify/photos', '/api/v1/verify/x/y']) {
      const res = await api().post(path).send({});
      expect(res.status).toBe(410);
      expect(res.body.error.code).toBe('ENDPOINT_RETIRED');
    }
  });
});
