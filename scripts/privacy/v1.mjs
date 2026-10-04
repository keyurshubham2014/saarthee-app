// v1 (TASK-10, 06 §12.3) privacy checks for the legacy read-only tables — unchanged behaviour, run with --v1.
import { readFileSync, readdirSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { apiRequire, env } from './lib.mjs';

const TEST_PHONE_DIGITS = '9876543210';

export async function runV1(ctx) {
  const { check, request, base } = ctx;
  const sharp = apiRequire('sharp');
  const json = (method, url, body, headers = {}) => request(method, url, { body, headers });
  async function upload(url, buf, fields) {
    const fd = new FormData();
    for (const [k, v] of Object.entries(fields)) fd.append(k, v);
    fd.append('photo', new Blob([buf], { type: 'image/jpeg' }), 'p.jpg');
    const res = await fetch(base + url, { method: 'POST', body: fd });
    return { status: res.status, data: await res.json().catch(() => null) };
  }

  const exifJpeg = await sharp({ create: { width: 800, height: 600, channels: 3, background: '#556677' } })
    .withExif({ IFD0: { Make: 'LeakyCamCo', Model: 'SpyPhone 9', ImageDescription: 'GPS 23.0225 72.5714' } })
    .jpeg()
    .toBuffer();
  check('test JPEG really contains EXIF before upload', exifJpeg.includes(Buffer.from('LeakyCamCo')));

  const login = await json('POST', '/admin/auth/login', { email: env.SEED_ADMIN_EMAIL, password: env.SEED_ADMIN_PASSWORD });
  check('admin login works', login.status === 200, `status ${login.status}`);
  const auth = { Authorization: `Bearer ${login.data?.accessToken}` };

  const cats = await json('GET', '/categories');
  const photo = await upload('/photos', exifJpeg, { purpose: 'report' });
  const report = await json('POST', '/reports', {
    clientSubmissionId: randomUUID(),
    inviteCode: 'RWATEST01',
    categoryId: cats.data?.items?.[0]?.id,
    ccrsNumber: 'PRIV-CHECK-1',
    photoId: photo.data?.photoId,
    latitude: 23.0225,
    longitude: 72.5714,
    gpsAccuracyM: 9,
    deviceCapturedAt: new Date().toISOString(),
    platform: 'android',
    appVersion: '1.0.0',
    phone: TEST_PHONE_DIGITS,
    consentGivenAt: new Date().toISOString(),
    consentTextVersion: 'v1',
  });
  check('report created with test phone', [200, 201].includes(report.status), `status ${report.status}`);
  const complaintId = report.data?.complaintId;

  const stored = await fetch(`${base}/admin/complaints/${complaintId}/photo`, { headers: auth });
  const storedBuf = Buffer.from(await stored.arrayBuffer());
  const meta = await sharp(storedBuf).metadata().catch(() => ({}));
  check(
    'stored photo has no EXIF / device metadata',
    stored.status === 200 && !meta.exif && !storedBuf.includes(Buffer.from('LeakyCamCo')) && !storedBuf.includes(Buffer.from('Exif')),
    `status ${stored.status}, exif=${meta.exif ? 'present' : 'none'}`,
  );

  const list = await json('GET', '/admin/complaints?limit=200', undefined, auth);
  check('GET /admin/complaints contains no phone', list.status === 200 && !list.text.includes(TEST_PHONE_DIGITS) && !/phone/i.test(list.text), `status ${list.status}`);

  const rem = await json('POST', `/admin/complaints/${complaintId}/reminders`, {}, auth);
  check('reminder created with verify link', rem.status === 201 && /saarthee:\/\/verify\?t=/.test(rem.data?.verifyLink ?? ''), `status ${rem.status}`);
  const token = rem.data?.verifyLink ? new URL(rem.data.verifyLink.replace('saarthee://', 'https://x/')).searchParams.get('t') : null;
  const v = await json('GET', '/verify/complaint', undefined, { 'X-Verify-Token': token ?? '' });
  check(
    'verify summary has no phone, coordinates, source or invite code',
    v.status === 200 && !/phone|latitude|longitude|sourceTag|inviteCode|RWATEST01|9876543210/i.test(v.text),
    `status ${v.status}`,
  );
  const vq = await json('GET', `/verify/complaint?t=${token}`);
  check('verify token in URL query is NOT accepted (header only)', vq.status === 401, `status ${vq.status}`);
  const revoke = await json('POST', `/admin/reminders/${rem.data?.reminderId}/revoke`, {}, auth);
  const after = await json('GET', '/verify/complaint', undefined, { 'X-Verify-Token': token ?? '' });
  check('revoked link rejected (410 VERIFY_TOKEN_REVOKED)', revoke.status === 200 && after.status === 410 && after.data?.error?.code === 'VERIFY_TOKEN_REVOKED', `revoke ${revoke.status}, after ${after.status}`);

  const csv = await fetch(`${base}/admin/export?type=complaints`, { headers: auth });
  const csvText = await csv.text();
  const header = csvText.split(/\r?\n/)[0] ?? '';
  check('CSV export without includePhone has no phone column/value', csv.status === 200 && !/phone/i.test(header) && !csvText.includes(TEST_PHONE_DIGITS), `status ${csv.status}`);

  const logDir = env.LOG_FILE_DIR;
  let logText = '';
  if (logDir) for (const f of readdirSync(logDir)) logText += readFileSync(path.join(logDir, f), 'utf8');
  check('API log file exists and is non-empty', logText.length > 0, logDir ? 'LOG_FILE_DIR set' : 'LOG_FILE_DIR not set');
  check('API log contains no test phone number', !logText.includes(TEST_PHONE_DIGITS) && !logText.includes('98765 43210'));
  check('API log contains no verify token', token && !logText.includes(token));

  // Five bad logins → 429 (run last; it locks this IP+email for the window).
  const codes = [];
  for (let i = 0; i < 6; i++) {
    const r = await json('POST', '/admin/auth/login', { email: 'nobody@saarthee.local', password: `wrong-password-${i}` });
    codes.push(r.status);
  }
  check('5 bad logins then 429 RATE_LIMITED', codes.slice(0, 5).every((c) => c === 401) && codes[5] === 429, codes.join(','));
}
