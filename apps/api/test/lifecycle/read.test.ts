// GET /issues/{id}/lifecycle: derived fields and role-aware actions for the app (W-06-05 data source).
import { beforeEach, describe, expect, it } from 'vitest';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { DAY, markedFixedIssue, openIssue, representative, seedReference, user, ward } from './helpers';

beforeEach(async () => {
  await resetDb();
  await seedReference();
});

const read = (id: string, auth?: Record<string, string>) => {
  const r = api().get(`/api/v1/issues/${id}/lifecycle`);
  return auth ? r.set(auth) : r;
};

describe('GET /issues/{id}/lifecycle', () => {
  it('visitor: derived fields, no actions, no reporter data', async () => {
    const reporter = await user();
    const issue = await openIssue(reporter.user.id, { slaDueAt: new Date(Date.now() - DAY) });
    const res = await read(issue.id);
    expect(res.status).toBe(200);
    expect(res.body.issue).toMatchObject({ status: 'reported', displayStatus: 'reported', isOverdue: true, categorySlug: 'roads', verifyRadiusM: 100 });
    expect(res.body.viewer.can).toEqual({ acknowledge: false, start: false, markFixed: false, reject: false, verify: false, escalate: false, ccrsClosed: false });
    expect(JSON.stringify(res.body)).not.toContain(reporter.user.id);
  });

  it('actions by role: reporter, moderator, own-ward representative, other citizen on a fixed issue', async () => {
    const reporter = await user();
    const issue = await openIssue(reporter.user.id, { status: 'acknowledged' });
    expect((await read(issue.id, reporter.auth)).body.viewer.can).toMatchObject({ markFixed: true, start: false, escalate: true });
    expect((await read(issue.id, (await user('moderator')).auth)).body.viewer.can).toMatchObject({ start: true, markFixed: true, reject: true, escalate: false });
    const rep = await representative([(await ward(1)).id]);
    expect((await read(issue.id, rep.auth)).body.viewer.can).toMatchObject({ start: true, reject: false });
    const fixed = await markedFixedIssue(reporter.user.id);
    const neighbour = await user();
    const body = (await read(fixed.id, neighbour.auth)).body;
    expect(body.viewer.can).toMatchObject({ verify: true, markFixed: false });
    expect(body.issue.verifyWindowClosesAt).toBeTruthy();
  });
});
