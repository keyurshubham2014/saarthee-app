// T-09-03..07, T-09-13, T-09-14: message relay (AC-3, AC-4, AC-5, AC-6, AC-12).
import { randomUUID } from 'node:crypto';
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { captureLogs } from '../../src/lib/logger';
import { containsProfanity } from '../../src/lib/profanity';
import { flushRelayOutbox, istDay } from '../../src/modules/representatives/relay.service';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { makeIssue } from '../helpers/factories';
import { fixtureWards, makeRep, useMemoryMail, userWithToken } from './helpers';

const mail = useMemoryMail();
let wards: Map<number, string>;
beforeEach(async () => {
  await resetDb();
  mail.reset();
  wards = await fixtureWards();
});

const msg = (extra: Record<string, unknown> = {}) => ({
  clientMessageId: randomUUID(),
  subject: 'Streetlight out on our lane',
  body: 'The streetlight near the temple has been off for two weeks. Please get it fixed.',
  sharePhone: false,
  ...extra,
});

describe('relay happy path (T-09-03, AC-3)', () => {
  it('queues, emails the public address with the issue link and no phone, marks sent, logs no text', async () => {
    const rep = await makeRep({ publicEmail: 'office.test@example.org' }, [{ wardId: wards.get(1)! }]);
    const c = await userWithToken({ relayConsent: true, data: { homeWardId: wards.get(1)! } });
    const issue = await makeIssue({ reporterId: c.user.id });
    const logs = captureLogs();
    const body = msg({ issueId: issue.id });
    const res = await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(body);
    logs.stop();
    expect(res.status).toBe(202);
    expect(res.body).toEqual({ messageId: expect.any(String), status: 'queued' });
    expect(mail.sent).toHaveLength(1);
    const m = mail.sent[0]!;
    expect(m.to).toBe('office.test@example.org');
    expect(m.replyTo).toBe('ops@saarthee.in');
    expect(m.subject).toBe('[Saarthee] Message from a resident of Ward 1 Alpha: Streetlight out on our lane');
    expect(m.text).toContain(`/issues/${issue.id}`);
    expect(m.text).toContain('The resident chose not to share their phone number.');
    expect(m.text).toContain('Independent citizen app. Not run by or linked to AMC.');
    expect(m.text + m.html).not.toContain(c.user.phoneE164!.slice(3));
    const row = await prisma.repMessage.findUniqueOrThrow({ where: { id: res.body.messageId } });
    expect(row).toMatchObject({ status: 'sent', attempts: 1, citizenId: c.user.id });
    // T-09-14: no subject, body, phone or address in the logs.
    const all = logs.lines.join('\n');
    for (const secret of ['Streetlight', 'temple', 'office.test@example.org', c.user.phoneE164!.slice(3)]) expect(all).not.toContain(secret);
  });

  it('escapes user text in the HTML body', async () => {
    const rep = await makeRep({}, [{ wardId: wards.get(1)! }]);
    const c = await userWithToken({ relayConsent: true });
    await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(msg({ body: '<script>alert(1)</script> please fix the drain' }));
    expect(mail.sent[0]!.html).toContain('&lt;script&gt;');
    expect(mail.sent[0]!.html).not.toContain('<script>');
    expect(mail.sent[0]!.subject).toContain('a resident of Ahmedabad');
  });
});

describe('consent and phone sharing (T-09-04, AC-4)', () => {
  it('403 CONSENT_REQUIRED without consent; sharePhone includes the +91 number after consent', async () => {
    const rep = await makeRep({}, [{ wardId: wards.get(1)! }]);
    const c = await userWithToken();
    const first = await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(msg());
    expect(first.status).toBe(403);
    expect(first.body.error.code).toBe('CONSENT_REQUIRED');
    expect(await prisma.repMessage.count()).toBe(0);
    await prisma.consent.create({ data: { userId: c.user.id, purpose: 'share_with_representatives', textVersion: 'v2-1' } });
    const ok = await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(msg({ sharePhone: true }));
    expect(ok.status).toBe(202);
    expect(mail.sent[0]!.text).toContain(`The resident agreed to share their phone number: ${c.user.phoneE164}`);
  });

  it('401 when signed out; 422 REP_NO_CONTACT without an email; 404 for inactive', async () => {
    const noMail = await makeRep({ publicEmail: null });
    const gone = await makeRep({ isActive: false });
    const c = await userWithToken({ relayConsent: true });
    expect((await api().post(`/api/v1/representatives/${noMail.id}/messages`).send(msg())).status).toBe(401);
    const r = await api().post(`/api/v1/representatives/${noMail.id}/messages`).set(c.auth).send(msg());
    expect(r.status).toBe(422);
    expect(r.body.error.code).toBe('REP_NO_CONTACT');
    expect((await api().post(`/api/v1/representatives/${gone.id}/messages`).set(c.auth).send(msg())).status).toBe(404);
  });

  it('400 for a short body or a hidden issue', async () => {
    const rep = await makeRep({});
    const c = await userWithToken({ relayConsent: true });
    expect((await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(msg({ body: 'short' }))).status).toBe(400);
    const hidden = await makeIssue({ visibility: 'hidden' });
    const r = await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(msg({ issueId: hidden.id }));
    expect(r.status).toBe(400);
    expect(r.body.error.details[0].field).toBe('issueId');
  });
});

describe('rate limits and idempotency (T-09-05, AC-5)', () => {
  it('5 per representative per IST day, Retry-After to IST midnight; same clientMessageId → 200, no 2nd email', async () => {
    const rep = await makeRep({});
    const c = await userWithToken({ relayConsent: true });
    const first = msg();
    expect((await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(first)).status).toBe(202);
    const again = await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(first);
    expect(again.status).toBe(200);
    expect(mail.sent).toHaveLength(1);
    for (let i = 0; i < 4; i++) expect((await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(msg())).status).toBe(202);
    const sixth = await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(msg());
    expect(sixth.status).toBe(429);
    expect(sixth.body.error.message).toBe("You've sent 5 messages to this representative today. You can send more tomorrow.");
    const retry = Number(sixth.headers['retry-after']);
    expect(retry).toBe(istDay(new Date()).secondsToMidnight);
    expect(retry).toBeGreaterThan(0);
    expect(retry).toBeLessThanOrEqual(86_400);
  });

  it('20 per citizen per day across representatives (DB-backed)', async () => {
    const c = await userWithToken({ relayConsent: true });
    const reps = await Promise.all(Array.from({ length: 21 }, () => makeRep({})));
    const old = new Date(Date.now() - 2 * 86_400_000);
    // 20 already today (inserted directly) + 1 yesterday that must not count.
    for (let i = 0; i < 20; i++) {
      await prisma.repMessage.create({ data: { clientMessageId: randomUUID(), representativeId: reps[i]!.id, citizenId: c.user.id, subject: 'Hello there', body: 'A message body text', status: 'sent' } });
    }
    await prisma.repMessage.create({ data: { clientMessageId: randomUUID(), representativeId: reps[20]!.id, citizenId: c.user.id, subject: 'Old one', body: 'A message body text', createdAt: old } });
    const r = await api().post(`/api/v1/representatives/${reps[20]!.id}/messages`).set(c.auth).send(msg());
    expect(r.status).toBe(429);
    expect(r.body.error.details[0].issue).toBe('daily');
  });

  it('istDay: 23:30 IST has 30 minutes to midnight', () => {
    const { start, secondsToMidnight } = istDay(new Date('2026-10-04T18:00:00.000Z'));
    expect(secondsToMidnight).toBe(1800);
    expect(start.toISOString()).toBe('2026-10-03T18:30:00.000Z');
  });
});

describe('profanity screen (T-09-06, AC-6)', () => {
  it('rejects English, Gujarati-script and transliterated abuse; allows harmless longer words', async () => {
    expect(containsProfanity('This is bullshit, fix it')).toBe(true);
    expect(containsProfanity('તમે હરામી છો')).toBe(true);
    expect(containsProfanity('Arre bhenchod road')).toBe(true);
    expect(containsProfanity('SHIT happens')).toBe(true);
    expect(containsProfanity('Shiitake and shitake mushrooms in Scunthorpe, assessment due')).toBe(false);
    expect(containsProfanity('This road is useless and the work is corrupt')).toBe(false);
    const rep = await makeRep({});
    const c = await userWithToken({ relayConsent: true });
    const logs = captureLogs();
    const r = await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(msg({ body: 'You are a harami, fix the road now' }));
    logs.stop();
    expect(r.status).toBe(422);
    expect(r.body.error.code).toBe('MESSAGE_LANGUAGE');
    expect(await prisma.repMessage.count()).toBe(0);
    expect(mail.sent).toHaveLength(0);
    expect(logs.lines.join('\n')).toContain('relay_rejected_language');
    expect(logs.lines.join('\n')).not.toContain('harami');
  });
});

describe('outbox retry (T-09-07)', () => {
  it('fails twice then succeeds on the third attempt', async () => {
    const rep = await makeRep({});
    const c = await userWithToken({ relayConsent: true });
    mail.failNext = 2;
    const r = await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(msg());
    expect(r.status).toBe(202);
    const id = r.body.messageId as string;
    expect((await prisma.repMessage.findUniqueOrThrow({ where: { id } })).status).toBe('queued');
    expect(await flushRelayOutbox(new Date())).toEqual({ sent: 0, failed: 0, retried: 0 }); // not due yet
    expect(await flushRelayOutbox(new Date(Date.now() + 60_000))).toMatchObject({ retried: 1 });
    expect(await flushRelayOutbox(new Date(Date.now() + 600_000))).toMatchObject({ sent: 1 });
    expect(await prisma.repMessage.findUniqueOrThrow({ where: { id } })).toMatchObject({ status: 'sent', attempts: 3 });
    expect(mail.sent).toHaveLength(1);
  });

  it('3 failures → failed and an ops alert log', async () => {
    const rep = await makeRep({});
    const c = await userWithToken({ relayConsent: true });
    mail.failNext = 3;
    const logs = captureLogs();
    const r = await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(msg());
    await flushRelayOutbox(new Date(Date.now() + 60_000));
    await flushRelayOutbox(new Date(Date.now() + 600_000));
    logs.stop();
    expect((await prisma.repMessage.findUniqueOrThrow({ where: { id: r.body.messageId } })).status).toBe('failed');
    expect(logs.lines.join('\n')).toContain('relay_send_failed');
    expect(await flushRelayOutbox(new Date(Date.now() + 3_600_000))).toEqual({ sent: 0, failed: 0, retried: 0 });
  });
});

describe('export and erasure (T-09-13, AC-12)', () => {
  it('export lists the messages; account deletion keeps them with citizen_id NULL', async () => {
    const rep = await makeRep({});
    const c = await userWithToken({ relayConsent: true });
    const sent = await api().post(`/api/v1/representatives/${rep.id}/messages`).set(c.auth).send(msg());
    const exp = await api().get('/api/v1/me/export').set(c.auth);
    expect(exp.status).toBe(200);
    const text = typeof exp.body === 'object' && Object.keys(exp.body).length ? JSON.stringify(exp.body) : exp.text;
    expect(text).toContain(sent.body.messageId);
    expect(text).toContain('rep_messages');
    const del = await api().delete('/api/v1/me').set(c.auth).send({ confirm: 'DELETE' });
    expect([200, 202, 204]).toContain(del.status);
    const row = await prisma.repMessage.findUniqueOrThrow({ where: { id: sent.body.messageId } });
    expect(row.citizenId).toBeNull();
  });
});
