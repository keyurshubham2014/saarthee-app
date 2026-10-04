// T-10-04..T-10-08 (AC-4..AC-7) + staff status changes (acknowledge, mark fixed with an after photo).
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { dbError, resetDb } from '../helpers/db';
import { makePhoto } from '../helpers/factories';
import { useMemoryPush } from '../auth/helpers';
import { as, comment, get, issueInWard, issueOutside, makeCategory, makeIssue, post, wards, type Auth } from './helpers';

useMemoryPush();
let mod: Awaited<ReturnType<typeof as>>;
let w: Awaited<ReturnType<typeof wards>>;

beforeEach(async () => {
  await resetDb();
  w = await wards();
  mod = await as('moderator');
});

const ids = (body: { items: { id: string }[] }) => body.items.map((i) => i.id);
const queue = (auth: Auth, q: string) => get(auth, `/staff/moderation?queue=${q}`);

describe('queues (T-10-04)', () => {
  it('puts sensitive, flagged and out-of-area issues in their tabs; "Looks fine" removes them', async () => {
    const sensitiveCat = await makeCategory({ sensitive: true });
    const reporter = await as('citizen');
    const sensitive = await issueInWard(1, { categoryId: sensitiveCat.id, isSensitive: true, visibility: 'hidden', reporterId: reporter.user.id });
    const flagged = await issueInWard(2);
    for (let i = 0; i < 3; i++) {
      const c = await as('citizen');
      await post(c.auth, `/issues/${flagged.id}/flags`, { reason: i === 0 ? 'spam' : 'abusive' }).expect(201);
    }
    const outside = await issueOutside();
    await issueInWard(3); // ordinary issue: in no queue

    expect(ids((await queue(mod.auth, 'sensitive')).body)).toEqual([sensitive.id]);
    const flaggedRes = await queue(mod.auth, 'flagged');
    expect(ids(flaggedRes.body)).toEqual([flagged.id]);
    expect(flaggedRes.body.items[0].openFlags).toEqual([{ reason: 'abusive', count: 2 }, { reason: 'spam', count: 1 }]);
    expect(ids((await queue(mod.auth, 'out_of_area')).body)).toEqual([outside.id]);
    const summary = await get(mod.auth, '/staff/summary').expect(200);
    expect(summary.body).toMatchObject({ queues: { sensitive: 1, flagged: 1, outOfArea: 1 }, openFlags: 3 });

    // Reporter shown only by ward: the detail never carries name or phone.
    const detail = await get(mod.auth, `/staff/issues/${sensitive.id}`).expect(200);
    expect(JSON.stringify(detail.body)).not.toContain(reporter.user.phoneE164!);
    expect(detail.body.ward.number).toBe(1);

    await post(mod.auth, `/staff/issues/${sensitive.id}/reviewed`).expect(200);
    await post(mod.auth, `/staff/issues/${outside.id}/reviewed`).expect(200);
    expect(ids((await queue(mod.auth, 'sensitive')).body)).toEqual([]);
    expect(ids((await queue(mod.auth, 'out_of_area')).body)).toEqual([]);
    const after = await prisma.issue.findUniqueOrThrow({ where: { id: sensitive.id } });
    expect(after.visibility).toBe('public');
    expect(after.moderatedBy).toBe(mod.user.id);
    // Second "Looks fine" is stale.
    expect((await post(mod.auth, `/staff/issues/${sensitive.id}/reviewed`)).status).toBe(409);
  });
});

describe('reject (T-10-05)', () => {
  it('rejects with event, actions flags, notifies the reporter; a second reject is 409', async () => {
    const reporter = await as('citizen');
    const issue = await issueInWard(1, { reporterId: reporter.user.id });
    const c = await as('citizen');
    await post(c.auth, `/issues/${issue.id}/flags`, { reason: 'spam' }).expect(201);
    const res = await post(mod.auth, `/staff/issues/${issue.id}/reject`, { reason: 'spam', note: 'Advert' }).expect(200);
    expect(res.body.status).toBe('rejected');
    const event = await prisma.issueEvent.findFirstOrThrow({ where: { issueId: issue.id, type: 'rejected' } });
    expect(event).toMatchObject({ actorId: mod.user.id, actorRole: 'moderator', fromStatus: 'reported', toStatus: 'rejected', note: 'spam: Advert' });
    expect(await prisma.moderationFlag.count({ where: { issueId: issue.id, status: 'actioned' } })).toBe(1);
    const note = await prisma.notification.findFirstOrThrow({ where: { userId: reporter.user.id } });
    expect(note.bodyEn).toBe("Your report wasn't accepted: Spam");
    expect(note).toMatchObject({ titleGu: 'તમારો રિપોર્ટ સ્વીકારાયો નથી', bodyGu: 'તમારો રિપોર્ટ સ્વીકારાયો નથી. કારણ: સ્પામ.' });
    const again = await post(mod.auth, `/staff/issues/${issue.id}/reject`, { reason: 'spam' });
    expect(again.status).toBe(409);
    expect(again.body.error.code).toBe('ISSUE_STATE_INVALID');
  });

  it('concurrent rejects: exactly one succeeds', async () => {
    const issue = await issueInWard(1);
    const other = await as('moderator');
    const [a, b] = await Promise.all([
      post(mod.auth, `/staff/issues/${issue.id}/reject`, { reason: 'spam' }),
      post(other.auth, `/staff/issues/${issue.id}/reject`, { reason: 'other' }),
    ]);
    expect([a.status, b.status].sort()).toEqual([200, 409]);
    expect(await prisma.issueEvent.count({ where: { issueId: issue.id, type: 'rejected' } })).toBe(1);
  });
});

describe('hide / unhide and comments (T-10-06)', () => {
  it('hidden issues leave public endpoints but stay visible to staff', async () => {
    const cat = await makeCategory();
    const issue = await issueInWard(1, { categoryId: cat.id });
    const p = { lat: Number(issue.lat), lng: Number(issue.lng) };
    const nearby = () => get(undefined, `/issues/nearby?lat=${p.lat}&lng=${p.lng}&category=${cat.slug}`);
    expect(ids((await nearby()).body)).toContain(issue.id);
    await post(mod.auth, `/staff/issues/${issue.id}/hide`, { reason: 'Shows a face' }).expect(200);
    expect(ids((await nearby()).body)).not.toContain(issue.id);
    const staff = await get(mod.auth, `/staff/issues/${issue.id}`).expect(200);
    expect(staff.body.visibility).toBe('hidden');
    expect((await post(mod.auth, `/staff/issues/${issue.id}/hide`, { reason: 'again' })).status).toBe(409);
    await post(mod.auth, `/staff/issues/${issue.id}/unhide`, { reason: 'Blurred now' }).expect(200);
    expect(ids((await nearby()).body)).toContain(issue.id);
  });

  it('hides a comment and resolves flags', async () => {
    const issue = await issueInWard(1);
    const c = await as('citizen');
    const ev = await comment(issue.id, c.user.id);
    const flagger = await as('citizen');
    const flag = await post(flagger.auth, `/issues/${issue.id}/flags`, { reason: 'abusive', eventId: ev.id }).expect(201);
    await post(mod.auth, `/staff/comments/${ev.id}/hide`, { reason: 'abusive' }).expect(200);
    const detail = await get(mod.auth, `/staff/issues/${issue.id}`);
    expect(detail.body.timeline.find((e: { id: string }) => e.id === ev.id).hidden).toBe(true);
    // Gone from the public timeline (signed out and other citizens); staff keep it.
    const publicIds = (r: { body: { items: { id: string }[] } }) => r.body.items.map((e) => e.id);
    expect(publicIds(await get(undefined, `/issues/${issue.id}/events`))).not.toContain(ev.id);
    expect(publicIds(await get(flagger.auth, `/issues/${issue.id}/events`))).not.toContain(ev.id);
    expect(publicIds(await get(mod.auth, `/issues/${issue.id}/events`))).toContain(ev.id);
    expect((await prisma.moderationFlag.findUniqueOrThrow({ where: { id: flag.body.flagId } })).status).toBe('actioned');
    expect((await post(mod.auth, `/staff/flags/${flag.body.flagId}/resolve`, { outcome: 'dismissed' })).status).toBe(409);
    expect((await post(mod.auth, `/staff/comments/${issue.id}/hide`, { reason: 'x' })).status).toBe(404);
  });
});

describe('merge (T-10-07)', () => {
  it('moves distinct me-toos and followers, reporter follows target, invalid merges 422', async () => {
    const reporterA = await as('citizen');
    const a = await issueInWard(1, { reporterId: reporterA.user.id });
    const b = await issueInWard(1);
    const [u1, u2, both] = [await as('citizen'), await as('citizen'), await as('citizen')];
    await prisma.meToo.createMany({ data: [{ issueId: a.id, userId: u1.user.id }, { issueId: a.id, userId: both.user.id }, { issueId: b.id, userId: both.user.id }] });
    await prisma.follow.createMany({ data: [{ issueId: a.id, userId: u2.user.id }, { issueId: b.id, userId: both.user.id }] });
    const cands = await get(mod.auth, `/staff/issues/${a.id}/merge-candidates`).expect(200);
    expect(ids(cands.body)).toContain(b.id);

    await post(mod.auth, `/staff/issues/${a.id}/merge`, { targetIssueId: b.id }).expect(200);
    const src = await prisma.issue.findUniqueOrThrow({ where: { id: a.id } });
    expect(src).toMatchObject({ status: 'merged', mergedIntoId: b.id });
    const target = await prisma.issue.findUniqueOrThrow({ where: { id: b.id } });
    expect(target.meTooCount).toBe(2);
    expect(target.followerCount).toBe(3); // both, u2, reporter of A
    expect(await prisma.follow.count({ where: { issueId: b.id, userId: reporterA.user.id } })).toBe(1);
    expect(await prisma.issueEvent.count({ where: { issueId: b.id, type: 'merged' } })).toBe(1);
    expect(await prisma.issueEvent.count({ where: { issueId: a.id, type: 'merged' } })).toBe(1);

    const back = await post(mod.auth, `/staff/issues/${b.id}/merge`, { targetIssueId: a.id });
    expect(back.status).toBe(422);
    expect(back.body.error.code).toBe('MERGE_INVALID');
    expect((await post(mod.auth, `/staff/issues/${b.id}/merge`, { targetIssueId: b.id })).status).toBe(422);
    expect(await dbError(prisma.issue.update({ where: { id: b.id }, data: { mergedIntoId: b.id, status: 'merged' } }))).toContain('ck_issues_merged');
  });
});

describe('recategorise and change ward (T-10-08)', () => {
  it('updates category, ward and SLA from created_at with events', async () => {
    const roads = await makeCategory({ slaDays: 7 });
    const drainage = await makeCategory({ slaDays: 3 });
    const created = new Date('2026-09-01T06:00:00Z');
    const issue = await issueInWard(1, { categoryId: roads.id, createdAt: created });
    await post(mod.auth, `/staff/issues/${issue.id}/recategorise`, { categoryId: drainage.id, wardId: w.byNumber(2).id }).expect(200);
    const after = await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } });
    expect(after.categoryId).toBe(drainage.id);
    expect(after.wardId).toBe(w.byNumber(2).id);
    expect(after.slaDueAt.toISOString()).toBe(new Date(created.getTime() + 3 * 86_400_000).toISOString());
    const types = (await prisma.issueEvent.findMany({ where: { issueId: issue.id } })).map((e) => e.type).sort();
    expect(types).toEqual(['recategorised', 'ward_changed']);
    const inactive = await makeCategory({ isActive: false });
    expect((await post(mod.auth, `/staff/issues/${issue.id}/recategorise`, { categoryId: inactive.id })).status).toBe(422);
    expect((await post(mod.auth, `/staff/issues/${issue.id}/recategorise`, {})).status).toBe(400);
  });
});

describe('status changes from the console (via TASK-06 transition)', () => {
  it('acknowledges, then marks fixed with an after photo; stale and invalid changes 409', async () => {
    const issue = await makeIssue();
    await post(mod.auth, `/staff/issues/${issue.id}/status`, { to: 'acknowledged', expectedStatus: 'reported' }).expect(200);
    const stale = await post(mod.auth, `/staff/issues/${issue.id}/status`, { to: 'in_progress', expectedStatus: 'reported' });
    expect(stale.body.error.code).toBe('ISSUE_STATE_INVALID');
    const photo = await makePhoto({ uploadedByUserId: mod.user.id, attachedAt: null, purpose: 'after' });
    const res = await post(mod.auth, `/staff/issues/${issue.id}/status`, { to: 'marked_fixed', note: 'Patched', photoIds: [photo.id] }).expect(200);
    expect(res.body.status).toBe('marked_fixed');
    expect(res.body.photos).toEqual([expect.objectContaining({ id: photo.id, kind: 'after' })]);
    const event = await prisma.issueEvent.findFirstOrThrow({ where: { issueId: issue.id, toStatus: 'marked_fixed' } });
    expect(event).toMatchObject({ fromStatus: 'acknowledged', photoId: photo.id, actorRole: 'moderator' });
    const bad = await post(mod.auth, `/staff/issues/${issue.id}/status`, { to: 'acknowledged' });
    expect(bad.body.error.code).toBe('INVALID_TRANSITION');
    const other = await makePhoto({ attachedAt: null });
    const issue2 = await makeIssue();
    expect((await post(mod.auth, `/staff/issues/${issue2.id}/status`, { to: 'marked_fixed', photoIds: [other.id] })).status).toBe(422);
  });
});
