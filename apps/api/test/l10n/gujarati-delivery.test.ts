// Gujarati server text end to end: recipient language for push/inbox, Accept-Language fallback, share page,
// localized rejection and claim reasons.
import { randomUUID } from 'node:crypto';
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { notifyTopic } from '../../src/lib/push';
import { notifyIssue } from '../../src/modules/lifecycle/notify';
import { AUTO_REJECT_REASON, decideClaim } from '../../src/modules/rep-claims/review.service';
import { useMemoryPush } from '../auth/helpers';
import { resetDb } from '../helpers/db';
import { api, get, photoIssue, seedReference, user } from '../discovery/helpers';

const driver = useMemoryPush();
beforeEach(async () => {
  await resetDb();
  await seedReference();
  driver.sent.length = 0;
});

async function device(userId: string, language: 'gu' | 'en') {
  await prisma.device.create({ data: { installId: randomUUID(), userId, fcmToken: `tok-${randomUUID()}`, platform: 'android', appVersion: '2', language } });
}

describe('issue updates in the recipient language', () => {
  it('a Gujarati follower gets Gujarati push and inbox; an English follower gets English', async () => {
    const gu = await user('citizen', { language: 'gu' });
    const en = await user('citizen', { language: 'en' });
    const { issue } = await photoIssue(gu.user.id);
    await prisma.follow.createMany({ data: [{ issueId: issue.id, userId: gu.user.id }, { issueId: issue.id, userId: en.user.id }], skipDuplicates: true });
    await device(gu.user.id, 'gu');
    await device(en.user.id, 'en');

    expect(await notifyIssue(issue.id, 'acknowledged', { ignoreQuietHours: true })).toBe(2);
    const titles = driver.sent.map((s) => s.payload.title).sort();
    expect(titles).toEqual(['Your issue was acknowledged', 'તમારી સમસ્યા સ્વીકારાઈ'].sort());

    const guInbox = await get('/api/v1/me/notifications', gu.auth);
    expect(guInbox.body.items[0]).toMatchObject({ title: 'તમારી સમસ્યા સ્વીકારાઈ' });
    expect(guInbox.body.items[0].body).toMatch(/^આલ્ફામાં ‘.+’ની સમસ્યા હવે સ્વીકારાઈ છે\.$/);
    const enInbox = await get('/api/v1/me/notifications', en.auth);
    expect(enInbox.body.items[0]).toMatchObject({ title: 'Your issue was acknowledged' });
  });

  it('a topic send with an empty Gujarati text falls back to English on the Gujarati topic', async () => {
    await notifyTopic('city_all', { kind: 'alert', channel: 'alerts', title: { en: 'Heat wave likely', gu: '' }, body: { en: 'Stay indoors.', gu: '' } });
    expect(driver.sent.map((s) => [s.topic, s.payload.title, s.payload.body])).toEqual([
      ['city_all__gu', 'Heat wave likely', 'Stay indoors.'],
      ['city_all__en', 'Heat wave likely', 'Stay indoors.'],
    ]);
  });
});

describe('Accept-Language when ?lang= is absent', () => {
  it('issue detail: header picks Gujarati, ?lang wins, Vary is set; structured reasons and reject reasons localized', async () => {
    const r = await user('citizen', { language: 'gu' });
    const { issue } = await photoIssue(r.user.id, { category: 'encroachment', description: 'Blocking the footpath' });
    const gu = await api().get(`/api/v1/issues/${issue.id}`).set('Accept-Language', 'gu-IN,gu;q=0.9,en;q=0.5');
    expect(gu.status).toBe(200);
    expect(gu.body.issue.title).toMatch(/^દબાણ · /);
    expect(gu.body.issue.description).toBe('ફૂટપાથ રોકે છે');
    expect(gu.headers.vary).toMatch(/Accept-Language/i);
    const en = await api().get(`/api/v1/issues/${issue.id}?lang=en`).set('Accept-Language', 'gu');
    expect(en.body.issue.title).toMatch(/^Encroachment · /);
    expect(en.body.issue.description).toBe('Blocking the footpath');
    expect((await api().get(`/api/v1/issues/${issue.id}`)).body.issue.title).toMatch(/^Encroachment/);

    await prisma.issue.update({ where: { id: issue.id }, data: { status: 'rejected' } });
    await prisma.issueEvent.create({ data: { issueId: issue.id, actorRole: 'moderator', type: 'status_change', fromStatus: 'reported', toStatus: 'rejected', note: 'duplicate: same pole as the other report' } });
    const mine = await get(`/api/v1/issues/${issue.id}?lang=gu`, r.auth);
    expect(mine.body.issue.rejectionReason).toBe('ડુપ્લિકેટ: same pole as the other report');
  });
});

describe('GET /i/{id} share page', () => {
  it('Gujarati via ?lang=gu or Accept-Language: html lang, OG tags, status, ward, independence line', async () => {
    const r = await user();
    const { issue } = await photoIssue(r.user.id);
    await prisma.issue.update({ where: { id: issue.id }, data: { meTooCount: 3, status: 'in_progress' } });
    for (const res of [await api().get(`/i/${issue.id}?lang=gu`), await api().get(`/i/${issue.id}`).set('Accept-Language', 'gu-IN')]) {
      expect(res.status).toBe(200);
      expect(res.text).toContain('<html lang="gu">');
      expect(res.text).toContain('<meta property="og:locale" content="gu_IN">');
      expect(res.text).toMatch(/og:description" content="કામ ચાલુ · વોર્ડ 1 · આલ્ફા · આજે નોંધાઈ\. 3 રહેવાસીઓ અસરગ્રસ્ત\."/);
      expect(res.text).toContain('આલ્ફાના રહેવાસીએ આ સમસ્યા નોંધાવી.');
      expect(res.text).toContain('સારથીમાં ખોલો');
      expect(res.text).toContain('AMC દ્વારા ચલાવાતી નથી');
      expect(res.text).toContain('View in English');
      expect(res.text).not.toContain('Open in Saarthee');
      expect(res.headers.vary).toMatch(/Accept-Language/i);
    }
    const en = await api().get(`/i/${issue.id}`);
    expect(en.text).toContain('<html lang="en">');
    expect(en.text).toContain('In progress · Ward 1 · Alpha · reported today. 3 residents affected.');
    expect(en.text).toContain('ગુજરાતીમાં જુઓ');
    const missing = await api().get(`/i/${randomUUID()}?lang=gu`);
    expect(missing.status).toBe(404);
    expect(missing.text).toContain('આ સમસ્યા ઉપલબ્ધ નથી.');
  });
});

describe('representative claims', () => {
  it('auto-reject reason shown in the reader language; a long staff reason no longer breaks the push', async () => {
    const gu = await user('citizen', { language: 'gu' });
    const en = await user('citizen', { language: 'en' });
    await device(gu.user.id, 'gu');
    const rep = await prisma.representative.create({
      data: { nameEn: 'Sample Corporator Test', nameGu: 'નમૂના કોર્પોરેટર ટેસ્ટ', role: 'corporator', termStart: new Date('2026-03-01'), sourceUrl: 'https://example.org/r', lastVerifiedAt: new Date('2026-10-01') },
    });
    for (const u of [gu, en]) {
      await prisma.repClaim.create({ data: { representativeId: rep.id, userId: u.user.id, status: 'rejected', rejectReason: AUTO_REJECT_REASON, decidedAt: new Date() } });
    }
    expect((await get('/api/v1/me/rep-claims', gu.auth)).body.items[0].rejectReason).toBe('આ પ્રતિનિધિ માટે બીજો દાવો મંજૂર થયો');
    expect((await get('/api/v1/me/rep-claims', en.auth)).body.items[0].rejectReason).toBe(AUTO_REJECT_REASON);

    const pending = await prisma.repClaim.create({ data: { representativeId: rep.id, userId: gu.user.id } });
    await decideClaim(pending.id, null, { decision: 'reject', reason: 'x'.repeat(300) });
    const row = await prisma.notification.findFirstOrThrow({ where: { userId: gu.user.id, refId: pending.id } });
    expect(row.titleGu).toBe('નમૂના કોર્પોરેટર ટેસ્ટ માટેનો તમારો દાવો મંજૂર ન થયો');
    expect(row.bodyGu.startsWith(`કારણ: ${'x'.repeat(300)}. `)).toBe(true);
    expect(row.bodyGu).toContain('સારથી ખોલો.');
    expect(driver.sent[0]!.payload.title).toBe('નમૂના કોર્પોરેટર ટેસ્ટ માટેનો તમારો દાવો મંજૂર ન થયો');
  });
});
