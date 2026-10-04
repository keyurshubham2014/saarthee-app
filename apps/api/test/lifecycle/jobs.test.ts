// T-06-08 (AC-7), T-06-10 (AC-9), T-06-16 (AC-7): sla-overdue, CCRS closed + reopen reminder, advisory lock.
import { Client } from 'pg';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { appJobs, clearJobs, registerJobs, runJob } from '../../src/jobs';
import { resetClock, setClock } from '../../src/lib/clock';
import { prisma } from '../../src/lib/db';
import { deriveIssue } from '../../src/modules/issues/derive';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { openIssue, seedReference, user } from './helpers';

const HOUR = 3_600_000;

beforeEach(async () => {
  await resetDb();
  await seedReference();
  clearJobs();
  registerJobs(appJobs());
});
afterEach(() => {
  resetClock();
  clearJobs();
});

describe('sla-overdue (T-06-08, AC-7)', () => {
  it('flags only the open overdue issue once: one system event, one notification per follower', async () => {
    const reporter = await user();
    const follower = await user();
    const past = new Date(Date.now() - HOUR);
    const open = await openIssue(reporter.user.id, { status: 'acknowledged', slaDueAt: past });
    await prisma.follow.create({ data: { issueId: open.id, userId: follower.user.id } });
    const closed = await openIssue(reporter.user.id, { status: 'verified', slaDueAt: past });
    expect(deriveIssue(open).isOverdue).toBe(true);
    expect(deriveIssue(closed).isOverdue).toBe(false);

    const first = await runJob('sla-overdue');
    expect(first).toMatchObject({ status: 'ran', result: { flagged: 1 } });
    const second = await runJob('sla-overdue');
    expect(second).toMatchObject({ status: 'ran', result: { flagged: 0 } });

    expect(await prisma.issueEvent.count({ where: { issueId: open.id, type: 'system', note: 'overdue' } })).toBe(1);
    expect(await prisma.issueEvent.count({ where: { issueId: closed.id } })).toBe(0);
    const rows = await prisma.notification.findMany({ where: { refId: open.id } });
    expect(rows.map((r) => r.userId).sort()).toEqual([reporter.user.id, follower.user.id].sort());
    expect(rows[0]!.titleEn).toBe('Past its target date');
    expect(rows[0]!.bodyEn).toContain("past Saarthee's 7-day target");
  });

  it('a reopen clears overdue_notified_at so the issue can be flagged again', async () => {
    const reporter = await user();
    const issue = await openIssue(reporter.user.id, { status: 'marked_fixed', markedFixedAt: new Date(), overdueNotifiedAt: new Date() });
    const { transition } = await import('../../src/modules/lifecycle/lifecycle.service');
    await transition(issue.id, 'reopened', { userId: null, kind: 'system' });
    const row = await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } });
    expect(row.overdueNotifiedAt).toBeNull();
    expect(row.slaDueAt.getTime()).toBeGreaterThan(Date.now());
  });
});

describe('CCRS closed + reminder (T-06-10, AC-9)', () => {
  it('records the close, reminds once after 20 h, never for a verified issue', async () => {
    const reporter = await user();
    const linked = await openIssue(reporter.user.id, { status: 'sent', ccrsNumber: 'AMC123', ccrsFiledAt: new Date(Date.now() - 2 * HOUR) });
    const unlinked = await openIssue(reporter.user.id);
    const no = await api().post(`/api/v1/issues/${unlinked.id}/ccrs/closed`).set(reporter.auth).send({});
    expect(no.status).toBe(409);
    expect(no.body.error.code).toBe('CCRS_NOT_LINKED');
    const other = await user();
    expect((await api().post(`/api/v1/issues/${linked.id}/ccrs/closed`).set(other.auth).send({})).status).toBe(403);

    const res = await api().post(`/api/v1/issues/${linked.id}/ccrs/closed`).set(reporter.auth).send({});
    expect(res.status).toBe(200);
    const closedAt = new Date(res.body.ccrsClosedAt);
    expect(new Date(res.body.reopenDeadline).getTime() - closedAt.getTime()).toBe(24 * HOUR);
    expect((await prisma.issue.findUniqueOrThrow({ where: { id: linked.id } })).status).toBe('sent');
    expect(await prisma.issueEvent.count({ where: { issueId: linked.id, type: 'ccrs_closed' } })).toBe(1);

    const verified = await openIssue(reporter.user.id, { status: 'verified', ccrsNumber: 'AMC9', ccrsFiledAt: closedAt, ccrsClosedAt: closedAt });

    expect(await runJob('ccrs-reopen-reminder', new Date(closedAt.getTime() + 19 * HOUR))).toMatchObject({ result: { reminded: 0 } });
    setClock(() => new Date(closedAt.getTime() + 20 * HOUR));
    expect(await runJob('ccrs-reopen-reminder', new Date(closedAt.getTime() + 20 * HOUR))).toMatchObject({ result: { reminded: 1 } });
    expect(await runJob('ccrs-reopen-reminder', new Date(closedAt.getTime() + 21 * HOUR))).toMatchObject({ result: { reminded: 0 } });
    const rows = await prisma.notification.findMany({ where: { kind: 'issue_update' } });
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ userId: reporter.user.id, refId: linked.id, titleEn: 'Reopen on AMC soon' });
    expect(await prisma.notification.count({ where: { refId: verified.id } })).toBe(0);
  });
});

describe('advisory lock (T-06-16)', () => {
  it('a second process holding sla-overdue’s lock makes the run exit without work', async () => {
    const reporter = await user();
    await openIssue(reporter.user.id, { slaDueAt: new Date(Date.now() - HOUR) });
    const other = new Client({ connectionString: process.env.DATABASE_URL });
    await other.connect();
    try {
      await other.query(`SELECT pg_advisory_lock(hashtext('saarthee.job:sla-overdue'))`);
      expect((await runJob('sla-overdue')).status).toBe('skipped_locked');
      expect(await prisma.issueEvent.count({ where: { type: 'system' } })).toBe(0);
    } finally {
      await other.end();
    }
    expect((await runJob('sla-overdue')).status).toBe('ran');
    expect(await prisma.issueEvent.count({ where: { type: 'system' } })).toBe(1);
  });
});
