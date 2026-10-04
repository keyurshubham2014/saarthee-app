// T-04-12 (AC-11): POST /devices upsert by install, token moves between installs, user linked/unlinked.
import { randomUUID } from 'node:crypto';
import { beforeEach, describe, expect, it } from 'vitest';
import { prisma } from '../../src/lib/db';
import { api } from '../helpers/app';
import { resetDb } from '../helpers/db';
import { signIn, useFakeFirebase } from '../auth/helpers';

const gw = useFakeFirebase();
beforeEach(resetDb);

const body = (installId: string, extra: Record<string, unknown> = {}) => ({
  installId,
  fcmToken: 'fcm-token-A',
  platform: 'android',
  appVersion: '2.0.0',
  language: 'gu',
  topics: ['ward_12__gu', 'city_all__gu'],
  ...extra,
});

describe('POST /devices', () => {
  it('upserts one row per install with the latest token and topics', async () => {
    const installId = randomUUID();
    const r1 = await api().post('/api/v1/devices').send(body(installId));
    expect(r1.status).toBe(200);
    expect(r1.body.deviceId).toEqual(expect.any(String));
    const r2 = await api().post('/api/v1/devices').send(body(installId, { fcmToken: 'fcm-token-B', language: 'en', topics: ['ward_12__en', 'city_all__en'] }));
    expect(r2.body.deviceId).toBe(r1.body.deviceId);
    expect(await prisma.device.count()).toBe(1);
    expect(await prisma.device.findUniqueOrThrow({ where: { installId } })).toMatchObject({
      fcmToken: 'fcm-token-B',
      language: 'en',
      topics: ['ward_12__en', 'city_all__en'],
      userId: null,
    });
  });

  it('clears the same token on another install (token moved)', async () => {
    const a = randomUUID();
    const b = randomUUID();
    await api().post('/api/v1/devices').send(body(a));
    await api().post('/api/v1/devices').send(body(b));
    expect((await prisma.device.findUniqueOrThrow({ where: { installId: a } })).fcmToken).toBeNull();
    expect((await prisma.device.findUniqueOrThrow({ where: { installId: b } })).fcmToken).toBe('fcm-token-A');
  });

  it('links the user when signed in, keeps the link on anonymous re-post, logout unlinks', async () => {
    const installId = randomUUID();
    await api().post('/api/v1/devices').send(body(installId));
    const a = await signIn(gw, { extra: { installId } });
    expect((await prisma.device.findUniqueOrThrow({ where: { installId } })).userId).toBe(a.user.id);
    await api().post('/api/v1/devices').set(a.auth).send(body(installId, { fcmToken: 'fcm-token-C' }));
    await api().post('/api/v1/devices').send(body(installId, { fcmToken: 'fcm-token-D' }));
    expect(await prisma.device.findUniqueOrThrow({ where: { installId } })).toMatchObject({ userId: a.user.id, fcmToken: 'fcm-token-D' });
    await api().post('/api/v1/auth/logout').set(a.auth).send({ installId });
    expect((await prisma.device.findUniqueOrThrow({ where: { installId } })).userId).toBeNull();
  });

  it('stores no token for a user who withdrew the notifications consent', async () => {
    const installId = randomUUID();
    const a = await signIn(gw, { extra: { consents: [{ purpose: 'core_service', textVersion: 'v2-1' }, { purpose: 'notifications', textVersion: 'v2-1' }] } });
    await api().post('/api/v1/me/consents').set(a.auth).send({ purpose: 'notifications', granted: false, textVersion: 'v2-1' });
    await api().post('/api/v1/devices').set(a.auth).send(body(installId));
    expect((await prisma.device.findUniqueOrThrow({ where: { installId } })).fcmToken).toBeNull();
  });

  it('validates the body and rejects an invalid token with 401', async () => {
    expect((await api().post('/api/v1/devices').send(body('not-a-uuid'))).status).toBe(400);
    expect((await api().post('/api/v1/devices').send(body(randomUUID(), { topics: ['Ward 12'] }))).status).toBe(400);
    expect((await api().post('/api/v1/devices').send(body(randomUUID(), { userId: randomUUID() }))).status).toBe(400);
    expect((await api().post('/api/v1/devices').set('Authorization', 'Bearer bad.token.x').send(body(randomUUID()))).status).toBe(401);
  });
});
