// W-INT10: TASK-10 staff console status writes go through TASK-06 transitionInTx() (single writer),
// with afterCommit() follower notifications, v1 email admin actors, merge target and photo rules.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { resetDb } from '../helpers/db';
import { createAdmin } from '../helpers/auth';
import { makePhoto } from '../helpers/factories';
import { useMemoryPush } from '../auth/helpers';
import { as, issueInWard, post, wards } from './helpers';

useMemoryPush();
let mod: Awaited<ReturnType<typeof as>>;

beforeEach(async () => {
  await resetDb();
  await wards();
  mod = await as('moderator');
});

async function followedIssue() {
  const reporter = await as('citizen');
  const follower = await as('citizen');
  const issue = await issueInWard(1, { reporterId: reporter.user.id });
  await prisma.follow.createMany({ data: [{ issueId: issue.id, userId: reporter.user.id }, { issueId: issue.id, userId: follower.user.id }] });
  return { issue, reporter, follower };
}
const notes = (userId: string) => prisma.notification.findMany({ where: { userId }, orderBy: { createdAt: 'asc' } });

describe('staff status via transition()', () => {
  it('mark fixed bumps status_version, sets marked_fixed_at and notifies followers but not the actor', async () => {
    const { issue, reporter, follower } = await followedIssue();
    await prisma.follow.create({ data: { issueId: issue.id, userId: mod.user.id } });
    const photo = await makePhoto({ uploadedByUserId: mod.user.id, attachedAt: null, purpose: 'after' });
    await post(mod.auth, `/staff/issues/${issue.id}/status`, { to: 'marked_fixed', photoIds: [photo.id], expectedStatus: 'reported' }).expect(200);
    const after = await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } });
    expect(after).toMatchObject({ status: 'marked_fixed', statusVersion: issue.statusVersion + 1 });
    expect(after.markedFixedAt).not.toBeNull();
    expect(await prisma.issuePhoto.count({ where: { issueId: issue.id, kind: 'after' } })).toBe(1);
    for (const u of [reporter, follower]) expect((await notes(u.user.id)).map((n) => n.titleEn)).toEqual(['Is it fixed? Help check']);
    expect(await notes(mod.user.id)).toHaveLength(0);
  });

  it('keeps TASK-10 error codes: PHOTO_UNUSABLE for a report photo or a non-fix target, INVALID_TRANSITION', async () => {
    const issue = await issueInWard(1);
    const report = await makePhoto({ uploadedByUserId: mod.user.id, attachedAt: null, purpose: 'report' });
    const r1 = await post(mod.auth, `/staff/issues/${issue.id}/status`, { to: 'marked_fixed', photoIds: [report.id] });
    expect([r1.status, r1.body.error.code]).toEqual([422, 'PHOTO_UNUSABLE']);
    const after = await makePhoto({ uploadedByUserId: mod.user.id, attachedAt: null, purpose: 'after' });
    const r2 = await post(mod.auth, `/staff/issues/${issue.id}/status`, { to: 'acknowledged', photoIds: [after.id] });
    expect([r2.status, r2.body.error.code]).toEqual([422, 'PHOTO_UNUSABLE']);
    const fresh = await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } });
    expect(fresh.status).toBe('reported');
    expect((await prisma.photo.findUniqueOrThrow({ where: { id: report.id } })).attachedAt).toBeNull();
    await post(mod.auth, `/staff/issues/${issue.id}/status`, { to: 'in_progress' }).expect(200);
    const r3 = await post(mod.auth, `/staff/issues/${issue.id}/status`, { to: 'acknowledged' });
    expect([r3.status, r3.body.error.code]).toEqual([409, 'INVALID_TRANSITION']);
  });

  it('a v1 email admin (no users row) is recorded as actor_role admin with meta.adminUserId', async () => {
    const v1 = await createAdmin();
    const { issue, reporter } = await followedIssue();
    await post(v1.auth, `/staff/issues/${issue.id}/status`, { to: 'acknowledged' }).expect(200);
    const event = await prisma.issueEvent.findFirstOrThrow({ where: { issueId: issue.id, toStatus: 'acknowledged' } });
    expect(event).toMatchObject({ actorId: null, actorRole: 'admin', type: 'status_change', meta: { adminUserId: v1.admin.id } });
    expect(await notes(reporter.user.id)).toHaveLength(1);
    const photo = await makePhoto({ attachedAt: null, purpose: 'after' });
    const res = await post(v1.auth, `/staff/issues/${issue.id}/status`, { to: 'marked_fixed', photoIds: [photo.id] });
    expect(res.body.error.code).toBe('PHOTO_UNUSABLE');
  });
});

describe('reject and merge via transition()', () => {
  it('reject: reporter gets only the reason message, other followers get "Issue closed"', async () => {
    const { issue, reporter, follower } = await followedIssue();
    await post(mod.auth, `/staff/issues/${issue.id}/reject`, { reason: 'not_civic' }).expect(200);
    expect((await notes(reporter.user.id)).map((n) => n.bodyEn)).toEqual(["Your report wasn't accepted: Not a civic issue"]);
    expect((await notes(reporter.user.id)).map((n) => n.bodyGu)).toEqual(['તમારો રિપોર્ટ સ્વીકારાયો નથી. કારણ: નાગરિક સમસ્યા નથી.']);
    expect((await notes(follower.user.id)).map((n) => n.titleEn)).toEqual(['Issue closed']);
    expect((await notes(follower.user.id)).map((n) => n.titleGu)).toEqual(['સમસ્યા બંધ કરાઈ']);
    const after = await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } });
    expect(after).toMatchObject({ status: 'rejected', moderatedBy: mod.user.id, statusVersion: issue.statusVersion + 1 });
  });

  it('merge: merged_into_id set with the status, event type from transition, no follower push', async () => {
    const { issue, follower } = await followedIssue();
    const target = await issueInWard(1);
    await post(mod.auth, `/staff/issues/${issue.id}/merge`, { targetIssueId: target.id }).expect(200);
    const after = await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } });
    expect(after).toMatchObject({ status: 'merged', mergedIntoId: target.id });
    const event = await prisma.issueEvent.findFirstOrThrow({ where: { issueId: issue.id, toStatus: 'merged' } });
    expect(event).toMatchObject({ type: 'merged', fromStatus: 'reported', actorRole: 'moderator' });
    expect(await notes(follower.user.id)).toHaveLength(0);
  });
});
