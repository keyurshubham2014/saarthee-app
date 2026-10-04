// v2 run fixtures: test citizens (fictional +91900000006x), staff tokens, one issue with an EXIF/GPS photo,
// a representative claim with private evidence, relay messages, a ward comment and a device FCM token.
import { randomUUID } from 'node:crypto';
import { apiRequire, env } from './lib.mjs';
import { adminToken, apiSignIn, freshCitizen } from './auth.mjs';

// ASSUMPTION (TASK-14): fictional test numbers in the reserved +9190000000NN range replace the contract's
// +91 98765 43210 (which may be a real subscriber). 60–79 avoid the seeded users.
export const PHONES = {
  a: env.PRIVACY_PHONE_A || '+919000000061',
  b: env.PRIVACY_PHONE_B || '+919000000062',
  c: env.PRIVACY_PHONE_C || '+919000000063',
  moderator: env.PRIVACY_PHONE_MODERATOR || '+919000000025',
  representative: env.PRIVACY_PHONE_REPRESENTATIVE || '+919000000027',
};
export const WARD_NAME = env.PRIVACY_WARD || 'Navrangpura';

export async function exifJpeg() {
  const sharp = apiRequire('sharp');
  return sharp({ create: { width: 800, height: 600, channels: 3, background: '#556677' } })
    .withExif({
      IFD0: { Make: 'LeakyCamCo', Model: 'SpyPhone 9', ImageDescription: 'GPS 23.0285 72.5532' },
      IFD3: { GPSLatitudeRef: 'N', GPSLatitude: '23/1 1/1 42/1', GPSLongitudeRef: 'E', GPSLongitude: '72/1 33/1 11/1' },
    })
    .jpeg()
    .toBuffer();
}

async function ok(r, what) {
  if (r.status >= 300) throw new Error(`${what} → ${r.status} ${r.data?.error?.code ?? ''}`);
  return r.data;
}

export async function setup(ctx) {
  const { request, upload } = ctx;
  const run = randomUUID().slice(0, 8);
  const wards = await ok(await request('GET', '/wards'), 'GET /wards');
  const ward = (wards.items ?? wards).find((w) => w.nameEn === WARD_NAME);
  if (!ward) throw new Error(`ward ${WARD_NAME} not found`);
  const centre = await request('GET', `/wards/${ward.id}`);
  const lat0 = Number(env.PRIVACY_LAT || centre.data?.centroid?.lat || 23.02859);
  const lng0 = Number(env.PRIVACY_LNG || centre.data?.centroid?.lng || 72.55322);

  const a = await freshCitizen(ctx, PHONES.a, { homeWardId: ward.id });
  const b = await freshCitizen(ctx, PHONES.b, { homeWardId: ward.id });
  a.name = `Probe Alpha ${run}`;
  b.name = `Probe Bravo ${run}`;
  await ok(await request('PATCH', '/me', { token: a.token, body: { displayName: a.name } }), 'PATCH /me A');
  await ok(await request('PATCH', '/me', { token: b.token, body: { displayName: b.name } }), 'PATCH /me B');
  const mod = await apiSignIn(ctx, PHONES.moderator);
  const rep = await apiSignIn(ctx, PHONES.representative);
  const admin = await adminToken(ctx);

  // A's device with an FCM token (must never reach the log).
  const fcm = `fcm-probe-${randomUUID()}-${randomUUID()}`;
  ctx.secrets.set('fcm:a', fcm);
  await ok(await request('POST', '/devices', { token: a.token, body: { installId: randomUUID(), fcmToken: fcm, platform: 'android', appVersion: '2.0.0', language: 'en' } }), 'POST /devices');

  // A reports a pothole with an EXIF/GPS photo.
  const jpeg = await exifJpeg();
  const photo = await upload('/photos', jpeg, { purpose: 'report' }, a.token);
  if (photo.status !== 201) throw new Error(`POST /photos → ${photo.status}`);
  const jitter = () => (Math.random() - 0.5) * 0.0006;
  const issue = await ok(
    await request('POST', '/issues', {
      token: a.token,
      body: {
        clientSubmissionId: randomUUID(),
        categorySlug: 'roads',
        photoIds: [photo.data.photoId],
        latitude: lat0 + jitter(),
        longitude: lng0 + jitter(),
        gpsAccuracyM: 8,
        pinAdjusted: false,
        deviceCapturedAt: new Date().toISOString(),
        description: `Privacy probe ${run}: pothole near the bus stop`,
        platform: 'android',
        appVersion: '2.0.0',
      },
    }),
    'POST /issues',
  );
  const issueId = issue.issueId ?? issue.id ?? issue.issue?.id;

  // B: Me too + follow on A's issue (other-user data that must not leak into A's export).
  await request('POST', `/issues/${issueId}/me-too`, { token: b.token, body: {} });
  await request('POST', `/issues/${issueId}/follow`, { token: b.token, body: {} });
  await request('POST', `/issues/${issueId}/follow`, { token: a.token, body: {} });

  return { run, ward, lat0, lng0, a, b, mod, rep, admin, jpeg, issueId, reportPhotoId: photo.data.photoId };
}
