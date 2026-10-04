// T-10-09 (AC-8) suspension, T-10-10 (AC-9) flags, T-10-11 (AC-10) roles.
import { beforeEach, describe, expect, it } from 'vitest';
import { setClock, resetClock } from '../../src/lib/clock';
import { prisma } from '../../src/lib/db';
import { resetDb } from '../helpers/db';
import { as, comment, get, makeIssue, post } from './helpers';

beforeEach(resetDb);

describe('suspend / unsuspend (T-10-09)', () => {
  it('moderator suspends a citizen (sessions end), cannot suspend an admin or themself', async () => {
    const mod = await as('moderator');
    const citizen = await as('citizen');
    const admin = await as('admin');
    expect((await get(citizen.auth, '/me')).status).toBe(200);
    await post(mod.auth, `/staff/users/${citizen.user.id}/suspend`, { reason: 'Abusive comments' }).expect(200);
    const after = await get(citizen.auth, '/me');
    expect([401, 403]).toContain(after.status);
    expect((await prisma.user.findUniqueOrThrow({ where: { id: citizen.user.id } })).tokenVersion).toBe(1);
    expect((await post(mod.auth, `/staff/users/${admin.user.id}/suspend`, { reason: 'x' })).status).toBe(403);
    expect((await post(mod.auth, `/staff/users/${mod.user.id}/suspend`, { reason: 'x' })).body.error.code).toBe('SELF_SUSPEND');
    expect((await post(mod.auth, `/staff/users/${citizen.user.id}/suspend`, { reason: 'x' })).status).toBe(409);
    await post(mod.auth, `/staff/users/${citizen.user.id}/unsuspend`, { reason: 'Appeal accepted' }).expect(200);
    // Admins may suspend staff.
    const other = await as('moderator');
    await post(admin.auth, `/staff/users/${other.user.id}/suspend`, { reason: 'Left the team' }).expect(200);
    expect((await post(mod.auth, `/staff/users/${other.user.id}/unsuspend`, { reason: 'x' })).status).toBe(403);
  });
});

describe('roles (T-10-11)', () => {
  it('grants and revokes moderator, refuses self and admin changes, masks phones', async () => {
    const admin = await as('admin');
    const citizen = await as('citizen', { phoneE164: '+919999903210', displayName: 'Asha Patel' });
    await post(admin.auth, `/staff/users/${citizen.user.id}/role`, { role: 'moderator' }).expect(200);
    let row = await prisma.user.findUniqueOrThrow({ where: { id: citizen.user.id } });
    expect(row).toMatchObject({ role: 'moderator', tokenVersion: 1 });
    expect((await get(citizen.auth, '/staff/me')).status).toBe(401); // old session ended
    await post(admin.auth, `/staff/users/${citizen.user.id}/role`, { role: 'citizen' }).expect(200);
    row = await prisma.user.findUniqueOrThrow({ where: { id: citizen.user.id } });
    expect(row).toMatchObject({ role: 'citizen', tokenVersion: 2 });
    const self = await post(admin.auth, `/staff/users/${admin.user.id}/role`, { role: 'citizen' });
    expect(self.status).toBe(409);
    expect(self.body.error.code).toBe('SELF_ROLE_CHANGE');
    expect((await post(admin.auth, `/staff/users/${citizen.user.id}/role`, { role: 'admin' })).status).toBe(400);
    const other = await as('admin');
    expect((await post(admin.auth, `/staff/users/${other.user.id}/role`, { role: 'citizen' })).status).toBe(422);

    const byDigits = await get(admin.auth, '/staff/users?q=3210').expect(200);
    expect(byDigits.body.items).toEqual([expect.objectContaining({ id: citizen.user.id, phoneMasked: '+91 ••••••3210' })]);
    const byName = await get(admin.auth, '/staff/users?q=asha').expect(200);
    expect(byName.body.items.map((u: { id: string }) => u.id)).toEqual([citizen.user.id]);
    expect(JSON.stringify(byName.body)).not.toContain('+919999903210');
  });
});

describe('citizen flags (T-10-10)', () => {
  it('creates, dedupes open flags, flags comments, limits 20 per day, requires sign-in', async () => {
    const citizen = await as('citizen');
    const issue = await makeIssue();
    const first = await post(citizen.auth, `/issues/${issue.id}/flags`, { reason: 'private_info' });
    expect(first.status).toBe(201);
    const again = await post(citizen.auth, `/issues/${issue.id}/flags`, { reason: 'private_info' });
    expect(again.status).toBe(200);
    expect(again.body).toEqual({ flagId: first.body.flagId, alreadyReported: true });
    const ev = await comment(issue.id, (await as('citizen')).user.id);
    const onComment = await post(citizen.auth, `/issues/${issue.id}/flags`, { reason: 'abusive', eventId: ev.id }).expect(201);
    const stored = await prisma.moderationFlag.findUniqueOrThrow({ where: { id: onComment.body.flagId } });
    expect(stored).toMatchObject({ targetType: 'issue_event', targetId: ev.id, issueId: issue.id });
    expect((await post(undefined, `/issues/${issue.id}/flags`, { reason: 'spam' })).status).toBe(401);
    expect((await post(citizen.auth, `/issues/${issue.id}/flags`, { reason: 'spam', note: 'x'.repeat(201) })).status).toBe(400);
  });

  it('returns 429 on the 21st flag of the IST day', async () => {
    setClock(() => new Date('2030-01-10T06:00:00Z'));
    try {
      const citizen = await as('citizen');
      for (let i = 0; i < 20; i++) {
        const issue = await makeIssue();
        await post(citizen.auth, `/issues/${issue.id}/flags`, { reason: 'spam' }).expect(201);
      }
      const issue = await makeIssue();
      const res = await post(citizen.auth, `/issues/${issue.id}/flags`, { reason: 'spam' });
      expect(res.status).toBe(429);
    } finally {
      resetClock();
    }
  });
});
