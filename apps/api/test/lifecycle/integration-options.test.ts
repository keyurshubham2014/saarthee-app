// W-INT10 lifecycle extensions: mergedIntoId (ck_issues_merged), notifyExcept, null-user admin actor.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { transition } from '../../src/modules/lifecycle/lifecycle.service';
import { checkTransition } from '../../src/modules/lifecycle/transitions';
import { resetDb } from '../helpers/db';
import { useMemoryPush } from '../auth/helpers';
import { openIssue, seedReference, user } from './helpers';

useMemoryPush();
beforeEach(async () => {
  await resetDb();
  await seedReference();
});

describe('transition() options added for the staff console', () => {
  it('rule table: moderator/admin may reject or merge any open or marked_fixed issue, nobody else', () => {
    for (const from of ['reported', 'sent', 'acknowledged', 'in_progress', 'reopened', 'marked_fixed'] as const) {
      for (const to of ['rejected', 'merged'] as const) {
        expect(checkTransition(from, to, 'moderator').ok).toBe(true);
        expect(checkTransition(from, to, 'admin').ok).toBe(true);
        expect(checkTransition(from, to, 'representative')).toEqual({ ok: false, code: 'FORBIDDEN_ROLE' });
      }
    }
    expect(checkTransition('verified', 'rejected', 'admin')).toEqual({ ok: false, code: 'INVALID_TRANSITION' });
  });

  it('merged needs mergedIntoId (set in the same update); other targets refuse it', async () => {
    const reporter = await user();
    const issue = await openIssue(reporter.user.id);
    const target = await openIssue(reporter.user.id);
    const admin = { userId: null, kind: 'admin' as const };
    await expect(transition(issue.id, 'merged', admin)).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
    await expect(transition(issue.id, 'merged', admin, { mergedIntoId: issue.id })).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
    await expect(transition(issue.id, 'acknowledged', admin, { mergedIntoId: target.id })).rejects.toMatchObject({ code: 'VALIDATION_FAILED' });
    const res = await transition(issue.id, 'merged', admin, { mergedIntoId: target.id, meta: { adminUserId: 'v1-admin' } });
    expect(res.issue).toMatchObject({ status: 'merged', mergedIntoId: target.id });
    expect(res.event).toMatchObject({ type: 'merged', actorId: null, actorRole: 'admin', meta: { adminUserId: 'v1-admin' } });
  });

  it('notifyExcept leaves the named followers out of the after-commit notification', async () => {
    const reporter = await user();
    const other = await user();
    const issue = await openIssue(reporter.user.id);
    await prisma.follow.create({ data: { issueId: issue.id, userId: other.user.id } });
    const mod = await user('moderator');
    await transition(issue.id, 'rejected', { userId: mod.user.id, kind: 'moderator' }, { note: 'spam', notifyExcept: [reporter.user.id] });
    expect(await prisma.notification.count({ where: { userId: reporter.user.id } })).toBe(0);
    expect(await prisma.notification.count({ where: { userId: other.user.id } })).toBe(1);
  });
});
