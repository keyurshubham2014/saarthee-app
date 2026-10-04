// T-04-07, T-04-08, T-04-09 (AC-6, AC-8, AC-9): profile, consents, export.
import { randomUUID } from 'node:crypto';
import { beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { makeIssue } from '../helpers/factories';
import { signIn, useFakeFirebase } from '../auth/helpers';

const gw = useFakeFirebase();
const WARD_ID = randomUUID();
/** True when this file created a stand-in `wards` table (before TASK-02's migration is merged). */
let ownWards = false;

beforeAll(async () => {
  const exists = await prisma.$queryRaw<{ e: boolean }[]>`SELECT to_regclass('public.wards') IS NOT NULL AS e`;
  if (!exists[0]?.e) {
    await prisma.$executeRawUnsafe('CREATE TABLE wards (id uuid PRIMARY KEY, number smallint NOT NULL, name_en text NOT NULL, name_gu text NOT NULL)');
    ownWards = true;
  }
});
beforeEach(async () => {
  await resetDb();
  if (ownWards) await prisma.$executeRaw`INSERT INTO wards (id, number, name_en, name_gu) VALUES (${WARD_ID}::uuid, 12, 'Paldi', 'પાલડી')`;
});

describe('GET/PATCH /me (T-04-07)', () => {
  it('returns the masked profile and applies valid edits', async () => {
    const a = await signIn(gw, { phone: '+919000000210' });
    const me = await api().get('/api/v1/me').set(a.auth);
    expect(me.status).toBe(200);
    expect(me.body).toMatchObject({ id: a.user.id, displayName: null, phoneMasked: '+91 ••••• ••210', language: 'gu', role: 'citizen', homeWard: null });
    expect(JSON.stringify(me.body)).not.toContain('9000000210');

    const patch = { displayName: 'Asha', language: 'en', ...(ownWards ? { homeWardId: WARD_ID } : {}) };
    const res = await api().patch('/api/v1/me').set(a.auth).send(patch);
    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ displayName: 'Asha', language: 'en' });
    if (ownWards) expect(res.body.homeWard).toEqual({ id: WARD_ID, number: 12, nameEn: 'Paldi', nameGu: 'પાલડી' });
    expect((await api().get('/api/v1/me').set(a.auth)).body.displayName).toBe('Asha');
  });

  it('unknown ward 422, 41-char name 400, role 400, empty body 400', async () => {
    const a = await signIn(gw);
    const ward = await api().patch('/api/v1/me').set(a.auth).send({ homeWardId: randomUUID() });
    expect(ward.status).toBe(422);
    expect(ward.body.error.code).toBe('WARD_NOT_FOUND');
    expect((await api().patch('/api/v1/me').set(a.auth).send({ displayName: 'x'.repeat(41) })).status).toBe(400);
    expect((await api().patch('/api/v1/me').set(a.auth).send({ role: 'admin' })).status).toBe(400);
    expect((await api().patch('/api/v1/me').set(a.auth).send({ displayName: 'A', role: 'admin' })).status).toBe(400);
    expect((await api().patch('/api/v1/me').set(a.auth).send({})).status).toBe(400);
    expect((await prisma.user.findUniqueOrThrow({ where: { id: a.user.id } })).role).toBe('citizen');
  });
});

describe('POST /me/consents (T-04-08)', () => {
  it('withdraw and re-grant keeps history; core withdrawal 409; notifications withdrawal clears tokens', async () => {
    const a = await signIn(gw, { extra: { consents: [{ purpose: 'core_service', textVersion: 'v2-1' }, { purpose: 'notifications', textVersion: 'v2-1' }] } });
    await prisma.device.create({ data: { installId: randomUUID(), userId: a.user.id, fcmToken: 'fcm-test-token-1', platform: 'android', appVersion: '2' } });
    const send = (purpose: string, granted: boolean) =>
      api().post('/api/v1/me/consents').set(a.auth).send({ purpose, granted, textVersion: 'v2-1' });

    const off = await send('notifications', false);
    expect(off.status).toBe(200);
    expect(off.body.consents.find((c: { purpose: string }) => c.purpose === 'notifications')).toMatchObject({ granted: false });
    expect(await prisma.device.count({ where: { userId: a.user.id, fcmToken: { not: null } } })).toBe(0);

    const on = await send('notifications', true);
    expect(on.body.consents.find((c: { purpose: string }) => c.purpose === 'notifications')).toMatchObject({ granted: true, withdrawnAt: null });
    expect(await prisma.consent.count({ where: { userId: a.user.id, purpose: 'notifications' } })).toBe(2);

    const core = await send('core_service', false);
    expect(core.status).toBe(409);
    expect(core.body.error.code).toBe('CORE_CONSENT_REQUIRED');
    expect((await api().post('/api/v1/me/consents').set(a.auth).send({ purpose: 'notifications', granted: true, textVersion: 'v9' })).status).toBe(400);
  });
});

describe('GET /me/export (T-04-09)', () => {
  it('has every section, only own data, no tokens; 4th call in a day → 429', async () => {
    const a = await signIn(gw);
    const other = await signIn(gw);
    await prisma.device.create({ data: { installId: randomUUID(), userId: a.user.id, fcmToken: 'fcm-secret-token-abc', platform: 'android', appVersion: '2' } });
    const mine = await makeIssue({ reporterId: a.user.id, description: 'Pothole near my gate' });
    const theirs = await makeIssue({ reporterId: other.user.id, description: 'Other person text' });
    await prisma.meToo.create({ data: { issueId: theirs.id, userId: a.user.id } });
    await prisma.follow.create({ data: { issueId: theirs.id, userId: a.user.id } });
    await prisma.follow.create({ data: { issueId: mine.id, userId: other.user.id } });

    const res = await api().get('/api/v1/me/export').set(a.auth);
    expect(res.status).toBe(200);
    expect(res.headers['content-disposition']).toMatch(/^attachment; filename="saarthee-my-data-\d{4}-\d{2}-\d{2}\.json"$/);
    for (const s of ['profile', 'consents', 'devices', 'notifications', 'issues', 'me_toos', 'follows', 'issue_verifications']) {
      expect(res.body).toHaveProperty(s);
    }
    const text = JSON.stringify(res.body);
    expect(text).not.toContain('fcm-secret-token-abc');
    expect(text).not.toContain(a.phone.slice(3));
    expect(text).not.toContain('Other person text');
    expect(text).not.toContain(other.user.id);
    expect(res.body.issues).toHaveLength(1);
    expect(res.body.follows).toEqual([expect.objectContaining({ issueId: theirs.id })]);
    expect(res.body.devices[0]).toMatchObject({ pushEnabled: true });

    expect((await api().get('/api/v1/me/export').set(a.auth)).status).toBe(200);
    expect((await api().get('/api/v1/me/export').set(a.auth)).status).toBe(200);
    expect((await api().get('/api/v1/me/export').set(a.auth)).status).toBe(429);
  });
});
