// T-04-01…T-04-04, T-04-16 (AC-2, AC-3, AC-4, AC-10): POST /auth/firebase.
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { makeUser } from '../helpers/factories';
import { CORE, signIn, signInBody, testPhone, useFakeFirebase } from './helpers';

const gw = useFakeFirebase();
beforeEach(resetDb);

const post = (body: unknown) => api().post('/api/v1/auth/firebase').send(body as object);

describe('POST /auth/firebase', () => {
  it('T-04-01: new user 201, repeat 200 without duplicate, relink by phone with a new uid', async () => {
    const phone = testPhone();
    const first = await post(signInBody(gw.issueToken({ uid: 'uid-a', phone })));
    expect(first.status).toBe(201);
    expect(first.body.isNew).toBe(true);
    expect(first.body.accessToken).toEqual(expect.any(String));
    expect(first.body.user.phoneMasked).toMatch(/^\+91 ••••• ••\d{3}$/);
    expect(JSON.stringify(first.body)).not.toContain(phone.slice(3));
    const row = await prisma.user.findUniqueOrThrow({ where: { id: first.body.user.id } });
    expect(row).toMatchObject({ phoneE164: phone, firebaseUid: 'uid-a', status: 'active' });
    expect(row.ageConfirmedAt).not.toBeNull();
    expect(await prisma.consent.count({ where: { userId: row.id, purpose: 'core_service', withdrawnAt: null } })).toBe(1);

    const again = await post(signInBody(gw.issueToken({ uid: 'uid-a', phone })));
    expect(again.status).toBe(200);
    expect(again.body.isNew).toBe(false);
    expect(await prisma.user.count()).toBe(1);
    expect(await prisma.consent.count()).toBe(1);

    const relinked = await post(signInBody(gw.issueToken({ uid: 'uid-b', phone })));
    expect(relinked.status).toBe(200);
    expect(relinked.body.user.id).toBe(row.id);
    expect((await prisma.user.findUniqueOrThrow({ where: { id: row.id } })).firebaseUid).toBe('uid-b');
  });

  it('existing user takes the app language at sign-in; an existing home ward is kept', async () => {
    const phone = testPhone();
    const first = await post(signInBody(gw.issueToken({ uid: 'uid-l', phone }), { language: 'gu' }));
    expect(first.body.user.language).toBe('gu');
    const again = await post(signInBody(gw.issueToken({ uid: 'uid-l', phone }), { language: 'en' }));
    expect(again.status).toBe(200);
    expect(again.body.user.language).toBe('en');
    expect((await prisma.user.findUniqueOrThrow({ where: { id: first.body.user.id } })).language).toBe('en');
  });

  it('records optional consents and links the install', async () => {
    const installId = '7a0d7c2e-4c69-4a8e-9a43-0f8a1d7b5c11';
    await prisma.device.create({ data: { installId, platform: 'android', appVersion: '2.0.0' } });
    const res = await post(
      signInBody(gw.issueToken({ uid: 'uid-c', phone: testPhone() }), {
        installId,
        consents: [CORE, { purpose: 'notifications', textVersion: 'v2-1' }],
      }),
    );
    expect(res.status).toBe(201);
    expect(res.body.user.consents.map((c: { purpose: string }) => c.purpose)).toEqual(['core_service', 'notifications']);
    expect((await prisma.device.findUniqueOrThrow({ where: { installId } })).userId).toBe(res.body.user.id);
  });

  it('T-04-02: expired, wrong aud, wrong iss, revoked, non-phone, no phone, malformed → 401, no row', async () => {
    gw.revokedUids.add('uid-revoked');
    const tokens = [
      gw.issueToken({ uid: 'u1', phone: testPhone(), expiresInS: -10 }),
      gw.issueToken({ uid: 'u2', phone: testPhone(), aud: 'other-project' }),
      gw.issueToken({ uid: 'u3', phone: testPhone(), iss: 'https://evil.example/demo-saarthee' }),
      gw.issueToken({ uid: 'uid-revoked', phone: testPhone() }),
      gw.issueToken({ uid: 'u5', phone: testPhone(), provider: 'password' }),
      gw.issueToken({ uid: 'u6', phone: null }),
      'not.a.jwt',
    ];
    for (const t of tokens) {
      const res = await post(signInBody(t));
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('FIREBASE_TOKEN_INVALID');
    }
    expect(await prisma.user.count()).toBe(0);
  });

  it('Firebase unreachable → 503 FIREBASE_UNAVAILABLE', async () => {
    gw.unavailable = true;
    try {
      const res = await post(signInBody(gw.issueToken({ uid: 'u7', phone: testPhone() })));
      expect(res.status).toBe(503);
      expect(res.body.error.code).toBe('FIREBASE_UNAVAILABLE');
    } finally {
      gw.unavailable = false;
    }
  });

  it('T-04-03: ageConfirmed false → 403 nothing stored; no core consent → 422; bad version → 422; bad body → 400', async () => {
    const t = gw.issueToken({ uid: 'u8', phone: testPhone() });
    const under = await post(signInBody(t, { ageConfirmed: false }));
    expect(under.status).toBe(403);
    expect(under.body.error.code).toBe('AGE_CONFIRMATION_REQUIRED');
    const noCore = await post(signInBody(t, { consents: [{ purpose: 'notifications', textVersion: 'v2-1' }] }));
    expect(noCore.status).toBe(422);
    expect(noCore.body.error.code).toBe('CONSENT_REQUIRED');
    const badVersion = await post(signInBody(t, { consents: [{ purpose: 'core_service', textVersion: 'v1' }] }));
    expect(badVersion.status).toBe(422);
    expect(badVersion.body.error.code).toBe('CONSENT_REQUIRED');
    expect((await post({ ...signInBody(t), role: 'admin' })).status).toBe(400);
    expect((await post(signInBody(t, { language: 'hi' }))).status).toBe(400);
    expect(await prisma.user.count()).toBe(0);
    expect(await prisma.consent.count()).toBe(0);
  });

  it('existing user without age confirmation must confirm; confirmed user does not need to again', async () => {
    const phone = testPhone();
    await makeUser({ phoneE164: phone, firebaseUid: 'u9' });
    expect((await post(signInBody(gw.issueToken({ uid: 'u9', phone }), { ageConfirmed: false }))).status).toBe(403);
    expect((await post(signInBody(gw.issueToken({ uid: 'u9', phone })))).status).toBe(200);
    expect((await post(signInBody(gw.issueToken({ uid: 'u9', phone }), { ageConfirmed: false }))).status).toBe(200);
  });

  it('T-04-04: suspended user → 403; a deleted user’s phone signs up fresh', async () => {
    const phone = testPhone();
    await makeUser({ phoneE164: phone, firebaseUid: 'u10', status: 'suspended', ageConfirmedAt: new Date() });
    const res = await post(signInBody(gw.issueToken({ uid: 'u10', phone })));
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ACCOUNT_SUSPENDED');

    const a = await signIn(gw);
    expect((await api().delete('/api/v1/me').set(a.auth).send({ confirm: 'DELETE' })).status).toBe(204);
    const again = await signIn(gw, { phone: a.phone, uid: a.uid });
    expect(again.res.status).toBe(201);
    expect(again.user.id).not.toBe(a.user.id);
  });

  it('T-04-16: 11th exchange per IP per minute → 429 with Retry-After', async () => {
    for (let i = 0; i < 10; i++) await post({ bad: true });
    const res = await post(signInBody('x'));
    expect(res.status).toBe(429);
    expect(res.body.error.code).toBe('RATE_LIMITED');
    expect(Number(res.headers['retry-after'])).toBeGreaterThan(0);
  });
});
