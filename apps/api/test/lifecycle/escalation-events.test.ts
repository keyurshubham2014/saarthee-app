// T-06-09 (AC-8) escalation messages; T-06-11 (AC-10) timeline privacy.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { recommendLevel } from '../../src/modules/escalation/escalation.service';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { DAY, openIssue, postStatus, postVerify, representative, seedReference, user, verifyBody, ward } from './helpers';

beforeEach(async () => {
  await resetDb();
  await seedReference();
});

const escalate = (auth: Record<string, string> | null, id: string, level: string, language: 'gu' | 'en') => {
  const req = api().post(`/api/v1/issues/${id}/escalations`);
  return (auth ? req.set(auth) : req).send({ level, language });
};

describe('escalation (T-06-09, AC-8)', () => {
  it('four levels in gu and en with evidence link, targets, event and reported → sent', async () => {
    const w1 = await ward(1);
    await representative([w1.id]);
    await representative([w1.id]);
    await prisma.ward.update({ where: { id: w1.id }, data: { officePhone: '07900000001' } });
    await prisma.escalationContact.createMany({
      data: [
        { level: 'zone_office', zoneId: w1.zoneId, titleEn: 'Zone office', titleGu: 'ઝોન કચેરી', email: 'zone@example.org', sourceUrl: 'https://example.org/z', lastVerifiedAt: new Date() },
        { level: 'deputy_commissioner', zoneId: w1.zoneId, titleEn: 'DMC', titleGu: 'ડીએમસી', email: 'dmc@example.org', sourceUrl: 'https://example.org/d', lastVerifiedAt: new Date() },
        { level: 'commissioner', zoneId: null, titleEn: 'Commissioner', titleGu: 'કમિશનર', email: 'mc@example.org', sourceUrl: 'https://example.org/c', lastVerifiedAt: new Date() },
      ],
    });
    const reporter = await user();
    const issue = await openIssue(reporter.user.id, { createdAt: new Date(Date.now() - 12 * DAY), slaDueAt: new Date(Date.now() - 5 * DAY), meTooCount: 4 });

    const first = await escalate(reporter.auth, issue.id, 'corporators', 'en');
    expect(first.status).toBe(200);
    expect(first.body).toMatchObject({ level: 'corporators', recommendedLevel: 'corporators', evidenceUrl: `https://saarthee.in/i/${issue.id}` });
    const sla = (await prisma.category.findUniqueOrThrow({ where: { slug: 'roads' } })).slaDays;
    expect(first.body.subject).toBe(`Overdue civic issue in ward ${w1.nameEn} — Roads & potholes`);
    expect(first.body.message).toContain(`after 12 days (Saarthee target: ${sla} days). 4 residents are affected.`);
    expect(first.body.message).toContain(`https://saarthee.in/i/${issue.id}`);
    expect(first.body.targets).toHaveLength(2);
    expect(first.body.targets.every((t: { kind: string; representativeId: string }) => t.kind === 'relay' && t.representativeId)).toBe(true);
    expect(first.body.independenceNote).toMatch(/not an official complaint/);
    expect((await prisma.issue.findUniqueOrThrow({ where: { id: issue.id } })).status).toBe('sent');
    expect(await prisma.issueEvent.findFirst({ where: { issueId: issue.id, type: 'escalated' } })).toMatchObject({ meta: { level: 'corporators' } });

    const zone = await escalate(reporter.auth, issue.id, 'zone_office', 'gu');
    expect(zone.body.subject).toContain(w1.nameGu);
    expect(zone.body.message).toContain('સારથી');
    expect(zone.body.targets).toEqual(expect.arrayContaining([
      expect.objectContaining({ kind: 'phone', phone: '07900000001' }),
      expect.objectContaining({ kind: 'email', email: 'zone@example.org', sourceUrl: 'https://example.org/z' }),
    ]));
    const dmc = await escalate(reporter.auth, issue.id, 'deputy_commissioner', 'en');
    expect(dmc.body.targets).toEqual([expect.objectContaining({ email: 'dmc@example.org' })]);
    expect(dmc.body.message.startsWith('Dear Deputy Municipal Commissioner')).toBe(true);
    const mc = await escalate(reporter.auth, issue.id, 'commissioner', 'gu');
    expect(mc.body.targets).toEqual([expect.objectContaining({ email: 'mc@example.org', label: 'કમિશનર' })]);
    expect(await prisma.issueEvent.count({ where: { issueId: issue.id, type: 'escalated' } })).toBe(4);
  });

  it('visitor 401, non-follower 403, follower allowed, closed issue 409; no corporators → empty targets', async () => {
    const reporter = await user();
    const issue = await openIssue(reporter.user.id);
    expect((await escalate(null, issue.id, 'corporators', 'en')).status).toBe(401);
    const stranger = await user();
    expect((await escalate(stranger.auth, issue.id, 'corporators', 'en')).status).toBe(403);
    await prisma.follow.create({ data: { issueId: issue.id, userId: stranger.user.id } });
    const ok = await escalate(stranger.auth, issue.id, 'corporators', 'en');
    expect(ok.status).toBe(200);
    expect(ok.body.targets).toEqual([]);
    const closed = await openIssue(reporter.user.id, { status: 'verified' });
    expect((await escalate(reporter.auth, closed.id, 'corporators', 'en')).body.error.code).toBe('ISSUE_NOT_OPEN');
  });

  it('recommends the next level once the previous one is a week old and the issue is overdue', () => {
    const now = new Date();
    expect(recommendLevel([], true, now)).toBe('corporators');
    expect(recommendLevel([{ level: 'corporators', at: new Date(now.getTime() - 3 * DAY) }], true, now)).toBe('corporators');
    expect(recommendLevel([{ level: 'corporators', at: new Date(now.getTime() - 8 * DAY) }], true, now)).toBe('zone_office');
    expect(recommendLevel([{ level: 'corporators', at: new Date(now.getTime() - 8 * DAY) }], false, now)).toBe('corporators');
    expect(recommendLevel([{ level: 'commissioner', at: new Date(now.getTime() - 30 * DAY) }], true, now)).toBe('commissioner');
  });
});

describe('timeline privacy (T-06-11, AC-10)', () => {
  it('anonymous read: residents by ward only, representative by role + name, moderator generic; no ids/phones/names', async () => {
    const w1 = await ward(1);
    const reporter = await user('citizen', { displayName: 'Reporter Secretname' });
    const rep = await representative([w1.id]);
    const mod = await user('moderator', { displayName: 'Moderator Hiddenname' });
    const verifier = await user('citizen', { displayName: 'Verifier Privatename' });
    const issue = await openIssue(reporter.user.id);
    await prisma.issueEvent.create({ data: { issueId: issue.id, actorId: reporter.user.id, actorRole: 'citizen', type: 'status_change', toStatus: 'reported' } });
    expect((await postStatus(rep.auth, issue.id, 'acknowledged', 'reported')).status).toBe(200);
    expect((await postStatus(mod.auth, issue.id, 'marked_fixed', 'acknowledged', { note: 'Filled the pothole' })).status).toBe(200);
    expect((await postVerify(verifier.auth, issue.id, await verifyBody(verifier.user.id, 'fixed', 30, { note: 'My lane' }))).status).toBe(201);

    const res = await api().get(`/api/v1/issues/${issue.id}/events`);
    expect(res.status).toBe(200);
    const kinds = res.body.items.map((e: { actorLabel: { kind: string } }) => e.actorLabel.kind);
    expect(kinds).toEqual(['resident', 'representative', 'moderator', 'resident', 'system']);
    expect(res.body.items[0].actorLabel).toEqual({ kind: 'resident', wardNameEn: w1.nameEn, wardNameGu: w1.nameGu });
    expect(res.body.items[1].actorLabel).toMatchObject({ kind: 'representative', name: { en: rep.rep.nameEn }, repRole: 'corporator' });
    expect(res.body.items[3]).toMatchObject({ type: 'verification', note: null, meta: { answer: 'fixed' } });
    expect(res.body.items[4]).toMatchObject({ toStatus: 'verified' });
    const text = JSON.stringify(res.body);
    for (const u of [reporter, rep, mod, verifier]) {
      expect(text).not.toContain(u.user.id);
      expect(text).not.toContain(u.user.phoneE164!);
    }
    expect(text).not.toMatch(/Secretname|Hiddenname|Privatename/);

    const page = await api().get(`/api/v1/issues/${issue.id}/events?limit=2`);
    expect(page.body.items).toHaveLength(2);
    const rest = await api().get(`/api/v1/issues/${issue.id}/events?limit=50&cursor=${page.body.nextCursor}`);
    expect(rest.body.items).toHaveLength(3);
    expect(rest.body.nextCursor).toBeNull();
  });

  it('a hidden issue’s timeline is 404 for visitors and visible to its reporter', async () => {
    const reporter = await user();
    const issue = await openIssue(reporter.user.id, { visibility: 'hidden' });
    expect((await api().get(`/api/v1/issues/${issue.id}/events`)).status).toBe(404);
    expect((await api().get(`/api/v1/issues/${issue.id}/events`).set(reporter.auth)).status).toBe(200);
  });
});
