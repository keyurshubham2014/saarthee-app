// T-07-08 capabilities, T-07-09 hidden/rejected/merged, T-07-10 me-too/follow consistency, T-07-13 reporter label.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { resetDb } from '../helpers/db';
import { markedFixedIssue, representative } from '../lifecycle/helpers';
import { api, DAY, get, photoIssue, seedReference, user, ward } from './helpers';

beforeEach(async () => {
  await resetDb();
  await seedReference();
});

const detail = (id: string, auth?: Record<string, string>, lang = 'en') => get(`/api/v1/issues/${id}?lang=${lang}`, auth);
const meToo = (id: string, auth: Record<string, string>, on = true) =>
  (on ? api().post(`/api/v1/issues/${id}/me-too`) : api().delete(`/api/v1/issues/${id}/me-too`)).set(auth);
const follow = (id: string, auth: Record<string, string>, on = true) =>
  (on ? api().post(`/api/v1/issues/${id}/follow`) : api().delete(`/api/v1/issues/${id}/follow`)).set(auth);

describe('GET /issues/{id}', () => {
  it('public shape, reporter label en/gu, before/after photos, capabilities by role', async () => {
    const reporter = await user();
    const { issue } = await photoIssue(reporter.user.id, { slaDueAt: new Date(Date.now() - DAY) });
    const w = await ward(1);
    const anon = await detail(issue.id);
    expect(anon.status).toBe(200);
    expect(anon.body.issue).toMatchObject({
      id: issue.id, status: 'reported', isOverdue: true, blurApplied: true, meTooCount: 0,
      reporterLabel: { en: `A resident of ${w.nameEn}`, gu: `${w.nameGu}ના રહેવાસી` },
      ward: { nameEn: w.nameEn }, category: { slug: 'roads' },
    });
    expect(anon.body.issue.photos.report).toHaveLength(1);
    expect(anon.body.viewer).toMatchObject({ signedIn: false, canMeToo: true, canEscalate: false, canVerify: false, hasMeToo: false });
    expect(anon.body.ccrs).toEqual({ linked: false, closedAt: null });
    expect(JSON.stringify(anon.body)).not.toContain(reporter.user.id);
    expect((await detail(issue.id, undefined, 'gu')).body.issue.title).toContain(w.nameGu);

    const own = (await detail(issue.id, reporter.auth)).body.viewer;
    expect(own).toMatchObject({ isReporter: true, canMeToo: false, canLinkCcrs: true, isFollowing: true, canEscalate: true });
    const neighbour = await user();
    expect((await detail(issue.id, neighbour.auth)).body.viewer).toMatchObject({ isReporter: false, canMeToo: true, canLinkCcrs: false, canEscalate: false });
    expect((await detail(issue.id, (await user('moderator')).auth)).body.viewer).toMatchObject({ canAcknowledge: true, canMarkFixed: true });
    const rep = await representative([w.id]);
    expect((await detail(issue.id, rep.auth)).body.viewer).toMatchObject({ canAcknowledge: true });

    const fixed = await markedFixedIssue(reporter.user.id);
    const f = (await detail(fixed.id, neighbour.auth)).body;
    expect(f.viewer).toMatchObject({ canVerify: true, canMeToo: false });
    expect(f.issue.verifyWindowClosesAt).toBeTruthy();
    expect(f.timelinePreview.length).toBeGreaterThan(0);
  });

  it('CCRS number only for the reporter', async () => {
    const reporter = await user();
    const { issue } = await photoIssue(reporter.user.id, { ccrsNumber: 'AMC-123', status: 'sent' });
    expect((await detail(issue.id, reporter.auth)).body.ccrs).toMatchObject({ linked: true, number: 'AMC-123' });
    const other = (await detail(issue.id, (await user()).auth)).body;
    expect(other.ccrs).toEqual({ linked: true, closedAt: null });
    expect(JSON.stringify(other)).not.toContain('AMC-123');
  });

  it('hidden and rejected: 404 for public, 200 for reporter and staff; merged carries mergedIntoId', async () => {
    const reporter = await user();
    const hidden = await photoIssue(reporter.user.id, { visibility: 'hidden' });
    const rejected = await photoIssue(reporter.user.id, { status: 'rejected' });
    await prisma.issueEvent.create({ data: { issueId: rejected.issue.id, actorRole: 'moderator', type: 'status_change', toStatus: 'rejected', note: 'Duplicate photo' } });
    for (const i of [hidden.issue, rejected.issue]) {
      expect((await detail(i.id)).status).toBe(404);
      expect((await detail(i.id, (await user()).auth)).status).toBe(404);
      expect((await detail(i.id, reporter.auth)).status).toBe(200);
      expect((await detail(i.id, (await user('moderator')).auth)).status).toBe(200);
    }
    expect((await detail(rejected.issue.id, reporter.auth)).body.issue.rejectionReason).toBe('Duplicate photo');
    const merged = await photoIssue(reporter.user.id, { status: 'merged' });
    const m = await detail(merged.issue.id);
    expect(m.status).toBe(200);
    expect(m.body.issue.mergedIntoId).toBeTruthy();
    expect((await detail('00000000-0000-4000-8000-000000000000')).status).toBe(404);
  });
});

describe('Me too and Follow', () => {
  it('me too on/off, auto-follow, idempotent, own issue 409, follow/unfollow counts', async () => {
    const reporter = await user();
    const { issue } = await photoIssue(reporter.user.id);
    const n = await user();
    const on = await meToo(issue.id, n.auth);
    expect(on.status).toBe(201);
    expect(on.body).toEqual({ meTooCount: 1, followerCount: 2, isFollowing: true });
    expect((await meToo(issue.id, n.auth)).body).toEqual({ meTooCount: 1, followerCount: 2, isFollowing: true });
    expect((await detail(issue.id, n.auth)).body.viewer).toMatchObject({ hasMeToo: true, isFollowing: true });
    const off = await meToo(issue.id, n.auth, false);
    expect(off.status).toBe(200);
    expect(off.body).toEqual({ meTooCount: 0 });
    expect((await meToo(issue.id, n.auth, false)).body).toEqual({ meTooCount: 0 });
    // Removing Me too keeps the follow.
    expect((await detail(issue.id, n.auth)).body.viewer).toMatchObject({ hasMeToo: false, isFollowing: true });
    expect((await follow(issue.id, n.auth, false)).body).toEqual({ followerCount: 1, isFollowing: false });
    expect((await follow(issue.id, n.auth, false)).body).toEqual({ followerCount: 1, isFollowing: false });
    expect((await follow(issue.id, n.auth)).body).toEqual({ followerCount: 2, isFollowing: true });
    expect((await follow(issue.id, n.auth)).body).toEqual({ followerCount: 2, isFollowing: true });
    expect((await meToo(issue.id, reporter.auth)).body.error.code).toBe('OWN_ISSUE');
    // The reporter may unfollow their own issue.
    expect((await follow(issue.id, reporter.auth, false)).body).toEqual({ followerCount: 1, isFollowing: false });
    expect((await api().post(`/api/v1/issues/${issue.id}/follow`)).status).toBe(401);
    expect((await follow('00000000-0000-4000-8000-000000000000', n.auth)).status).toBe(404);
  });

  it('concurrent toggles keep counters equal to row counts', async () => {
    const reporter = await user();
    const { issue } = await photoIssue(reporter.user.id);
    const people = await Promise.all(Array.from({ length: 8 }, () => user()));
    await Promise.all(people.flatMap((p) => [meToo(issue.id, p.auth), meToo(issue.id, p.auth), follow(issue.id, p.auth)]));
    await Promise.all(people.slice(0, 3).flatMap((p) => [meToo(issue.id, p.auth, false), follow(issue.id, p.auth, false), follow(issue.id, p.auth, false)]));
    const row = await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } });
    expect(row.meTooCount).toBe(await prisma.meToo.count({ where: { issueId: issue.id } }));
    expect(row.followerCount).toBe(await prisma.follow.count({ where: { issueId: issue.id } }));
    expect(row.meTooCount).toBe(5);
  });
});
