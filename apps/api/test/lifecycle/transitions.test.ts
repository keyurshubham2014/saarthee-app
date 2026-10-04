// T-06-01, T-06-02 (AC-1): every (from, to, actor) through POST /issues/{id}/status; representative ward scope.
import type { IssueStatus } from '@prisma/client';
import { beforeAll, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { checkTransition } from '../../src/modules/lifecycle/transitions';
import { resetDb } from '../helpers/db';
import { openIssue, postStatus, representative, seedReference, user, ward, type Auth } from './helpers';

const ALL: IssueStatus[] = ['reported', 'sent', 'acknowledged', 'in_progress', 'marked_fixed', 'verified', 'reopened', 'rejected', 'merged'];
const OPEN: IssueStatus[] = ['reported', 'sent', 'acknowledged', 'in_progress', 'reopened'];
type Actor = 'reporter' | 'reporterCcrs' | 'citizen' | 'rep' | 'moderator' | 'admin';

/** Hand-written from TASK-06 §5.3 (not derived from the code under test). */
const FROM: Record<string, IssueStatus[]> = {
  acknowledged: ['reported', 'sent', 'reopened'],
  in_progress: ['reported', 'sent', 'acknowledged', 'reopened'],
  marked_fixed: OPEN,
  rejected: [...OPEN, 'marked_fixed'],
};
const WHO: Record<string, Actor[]> = {
  acknowledged: ['reporterCcrs', 'rep', 'moderator', 'admin'],
  in_progress: ['rep', 'moderator', 'admin'],
  marked_fixed: ['reporter', 'reporterCcrs', 'rep', 'moderator', 'admin'],
  rejected: ['moderator', 'admin'],
};

function expected(from: IssueStatus, to: string, actor: Actor): [number, string | null] {
  if (actor === 'citizen') return [403, 'FORBIDDEN_ROLE'];
  if (!FROM[to]!.includes(from)) return [409, 'INVALID_TRANSITION'];
  if (!WHO[to]!.includes(actor)) return [403, 'FORBIDDEN_ROLE'];
  return [200, null];
}

let reporter: Awaited<ReturnType<typeof user>>;
const auths = {} as Record<Exclude<Actor, 'reporter' | 'reporterCcrs'>, Auth>;
let ward1: string;
let ward2: string;

beforeAll(async () => {
  await resetDb();
  await seedReference();
  ward1 = (await ward(1)).id;
  ward2 = (await ward(2)).id;
  reporter = await user();
  auths.citizen = (await user()).auth;
  auths.rep = (await representative([ward1])).auth;
  auths.moderator = (await user('moderator')).auth;
  auths.admin = (await user('admin')).auth;
});

describe('transition table via POST /status (T-06-01)', () => {
  it('only table rows succeed; each success writes exactly one event', async () => {
    const failures: string[] = [];
    for (const to of Object.keys(FROM)) {
      for (const from of ALL) {
        for (const actor of ['reporter', 'reporterCcrs', 'citizen', 'rep', 'moderator', 'admin'] as Actor[]) {
          const issue = await openIssue(reporter.user.id, { status: from, ...(actor === 'reporterCcrs' ? { ccrsNumber: 'AMC1', ccrsFiledAt: new Date() } : {}) });
          const auth = actor.startsWith('reporter') ? reporter.auth : auths[actor as keyof typeof auths];
          const res = await postStatus(auth, issue.id, to, from, { note: 'Checked on site' });
          const [status, code] = expected(from, to, actor);
          if (res.status !== status || (code && res.body.error?.code !== code)) {
            failures.push(`${from}→${to} by ${actor}: got ${res.status} ${res.body.error?.code ?? ''}, want ${status} ${code ?? ''}`);
            continue;
          }
          const events = await prisma.issueEvent.findMany({ where: { issueId: issue.id } });
          if (status === 200) {
            const role = actor.startsWith('reporter') ? 'citizen' : actor === 'rep' ? 'representative' : actor;
            expect(events).toHaveLength(1);
            expect(events[0]).toMatchObject({ actorRole: role, fromStatus: from, toStatus: to, note: 'Checked on site' });
            expect((await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } })).status).toBe(to);
          } else {
            expect(events).toHaveLength(0);
          }
        }
      }
    }
    expect(failures).toEqual([]);
  }, 120_000);

  it('system-only rows: verified/reopened only by system; sent by reporter or system', () => {
    expect(checkTransition('marked_fixed', 'verified', 'system').ok).toBe(true);
    expect(checkTransition('marked_fixed', 'verified', 'moderator')).toEqual({ ok: false, code: 'FORBIDDEN_ROLE' });
    expect(checkTransition('verified', 'reopened', 'system').ok).toBe(true);
    expect(checkTransition('in_progress', 'reopened', 'system')).toEqual({ ok: false, code: 'INVALID_TRANSITION' });
    expect(checkTransition('reported', 'sent', 'reporter').ok).toBe(true);
    expect(checkTransition('sent', 'sent', 'reporter')).toEqual({ ok: false, code: 'INVALID_TRANSITION' });
    expect(checkTransition('marked_fixed', 'merged', 'admin').ok).toBe(true);
  });

  it('reject needs a note; to=verified is not accepted from clients', async () => {
    const issue = await openIssue(reporter.user.id);
    const noNote = await postStatus(auths.moderator, issue.id, 'rejected', 'reported');
    expect(noNote.status).toBe(400);
    expect((await postStatus(auths.moderator, issue.id, 'verified', 'reported')).status).toBe(400);
  });
});

describe('representative ward scope (T-06-02)', () => {
  it('own ward 200, other ward 403 OUT_OF_WARD, unverified representative 403', async () => {
    const own = await openIssue(reporter.user.id, { wardNumber: 1 });
    const other = await openIssue(reporter.user.id, { wardNumber: 2 });
    expect((await postStatus(auths.rep, own.id, 'acknowledged', 'reported')).status).toBe(200);
    const res = await postStatus(auths.rep, other.id, 'acknowledged', 'reported');
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('OUT_OF_WARD');
    const unverified = await representative([ward1, ward2], false);
    const r2 = await postStatus(unverified.auth, own.id, 'in_progress', 'acknowledged');
    expect(r2.status).toBe(403);
    expect(r2.body.error.code).toBe('OUT_OF_WARD');
  });
});
