// T-11-09 representative transitions + comments (AC-9), T-11-10 forbidden actions (AC-10), T-11-11 election mode (AC-11).
import { randomUUID } from 'node:crypto';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { captureAudit } from '../../src/lib/audit';
import { prisma } from '../../src/lib/db';
import { resetDb } from '../helpers/db';
import { makePhoto } from '../helpers/factories';
import { useMemoryPush } from '../auth/helpers';
import { issueInWard } from '../staff/helpers';
import { fixtureWards } from './helpers';
import { electionOff, electionOn, get, post, signed, verifiedRep } from './t11-helpers';

useMemoryPush();
let wards: Map<number, string>;
let rep: Awaited<ReturnType<typeof verifiedRep>>;
let reporter: Awaited<ReturnType<typeof signed>>;

const status = (auth: Record<string, string>, id: string, to: string, expectedStatus: string, extra: Record<string, unknown> = {}) =>
  post(auth, `/issues/${id}/status`, { to, expectedStatus, clientActionId: randomUUID(), ...extra });

beforeEach(async () => {
  await resetDb();
  wards = await fixtureWards();
  rep = await verifiedRep([wards.get(1)!]);
  reporter = await signed('citizen');
});
afterEach(() => electionOff());

async function issue(n = 1, s: 'reported' | 'marked_fixed' | 'in_progress' = 'reported') {
  const i = await issueInWard(n, { reporterId: reporter.user.id, status: s, followerCount: 1 });
  await prisma.follow.create({ data: { issueId: i.id, userId: reporter.user.id } });
  return i;
}

describe('representative actions in scope (T-11-09)', () => {
  it('acknowledge → mark fixed with after photo → comment; events, notifications, audit without note text', async () => {
    const i = await issue();
    const audit = captureAudit();
    expect((await status(rep.auth, i.id, 'acknowledged', 'reported')).status).toBe(200);
    const photo = await makePhoto({ purpose: 'after', uploadedByUserId: rep.user.id, attachedAt: null });
    const fixed = await status(rep.auth, i.id, 'marked_fixed', 'acknowledged', { photoIds: [photo.id], note: 'NOTE-SECRET resurfaced' });
    expect(fixed.status).toBe(200);
    const c = await post(rep.auth, `/staff/issues/${i.id}/comments`, { note: 'NOTE-SECRET crew booked' });
    audit.stop();
    expect(c.status).toBe(201);
    const events = await prisma.issueEvent.findMany({ where: { issueId: i.id }, orderBy: { createdAt: 'asc' } });
    expect(events.map((e) => [e.type, e.toStatus, e.actorRole])).toEqual([
      ['status_change', 'acknowledged', 'representative'],
      ['status_change', 'marked_fixed', 'representative'],
      ['comment', null, 'representative'],
    ]);
    expect(await prisma.notification.count({ where: { userId: reporter.user.id } })).toBeGreaterThanOrEqual(2);
    expect(audit.lines.map((l) => l.action)).toEqual(['rep_issue_status', 'rep_issue_status', 'rep_issue_comment']);
    expect(JSON.stringify(audit.lines)).not.toContain('NOTE-SECRET');
  });

  it('other ward → 403 WARD_OUT_OF_SCOPE for status and comment; issue unchanged', async () => {
    const other = await issue(2);
    for (const r of [await status(rep.auth, other.id, 'acknowledged', 'reported'), await post(rep.auth, `/staff/issues/${other.id}/comments`, { note: 'hi' })]) {
      expect([r.status, r.body.error.code]).toEqual([403, 'WARD_OUT_OF_SCOPE']);
    }
    expect((await prisma.issue.findUniqueOrThrow({ where: { id: other.id } })).status).toBe('reported');
    expect(await prisma.issueEvent.count({ where: { issueId: other.id } })).toBe(0);
  });
});

describe('never verify, reject, merge, hide (T-11-10)', () => {
  it('every forbidden call is refused and the issue is unchanged', async () => {
    const i = await issue(1, 'marked_fixed');
    const open = await issue(1, 'reported');
    const refused = [
      await status(rep.auth, open.id, 'in_progress', 'reported'),
      await status(rep.auth, i.id, 'rejected', 'marked_fixed', { note: 'spam' }),
      await post(rep.auth, `/issues/${i.id}/verifications`, { clientSubmissionId: randomUUID(), answer: 'fixed', photoId: randomUUID(), latitude: 23, longitude: 72.5, gpsAccuracyM: 5, deviceCapturedAt: new Date().toISOString() }),
      await post(rep.auth, `/staff/issues/${i.id}/reject`, { reason: 'spam' }),
      await post(rep.auth, `/staff/issues/${i.id}/merge`, { targetIssueId: open.id }),
      await post(rep.auth, `/staff/issues/${i.id}/hide`, { reason: 'x' }),
      await post(rep.auth, `/staff/issues/${i.id}/recategorise`, { wardId: wards.get(2) }),
    ];
    expect(refused.map((r) => r.status)).toEqual([403, 403, 403, 403, 403, 403, 403]);
    // `verified` and `merged` are not accepted targets of POST /status for anyone (400; see §5.6).
    for (const to of ['verified', 'merged']) expect((await status(rep.auth, i.id, to, 'marked_fixed')).status).toBe(400);
    expect((await prisma.issue.findUniqueOrThrow({ where: { id: i.id } })).status).toBe('marked_fixed');
    expect((await prisma.issue.findUniqueOrThrow({ where: { id: open.id } })).status).toBe('reported');
  });
});

describe('election mode (T-11-11)', () => {
  it('comment, note and in-ward note-less acknowledge', async () => {
    const a = await issue();
    const b = await issue();
    await prisma.issueEvent.create({ data: { issueId: a.id, actorId: rep.user.id, actorRole: 'representative', type: 'comment', note: 'Earlier comment' } });
    await electionOn([wards.get(1)!]);
    const c = await post(rep.auth, `/staff/issues/${a.id}/comments`, { note: 'Vote for progress' });
    expect([c.status, c.body.error.code]).toEqual([409, 'ELECTION_MODE_FROZEN']);
    const n = await status(rep.auth, b.id, 'marked_fixed', 'reported', { note: 'Fixed by my team' });
    expect([n.status, n.body.error.code]).toEqual([409, 'ELECTION_MODE_FROZEN']);
    expect((await status(rep.auth, a.id, 'acknowledged', 'reported')).status).toBe(200);
    const mod = await signed('moderator');
    expect((await post(mod.auth, `/staff/issues/${a.id}/comments`, { note: 'Staff note' })).status).toBe(201);
    expect(await prisma.issueEvent.count({ where: { issueId: a.id, type: 'comment', note: 'Earlier comment' } })).toBe(1);
    expect((await get(rep.auth, `/staff/ward-dashboard?ward=${wards.get(1)}`)).body.electionMode.active).toBe(true);
  });
});
