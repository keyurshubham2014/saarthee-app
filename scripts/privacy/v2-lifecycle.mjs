// P2-06 account deletion, P2-04 log grep, P2-12 HTTPS (staging), P2-11 rate limits (run last).
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { containsAny, containsToken, env, phoneForms } from './lib.mjs';
import { freshCitizen } from './auth.mjs';
import { PHONES } from './v2-setup.mjs';

export async function p206(ctx, f, db) {
  const c = ctx.checker('P2-06', 'DELETE /me erases identity, anonymises issues, removes photos, revokes session');
  const { request } = ctx;
  const photosOf = async (uid) =>
    db ? (await db.query('SELECT id, storage_driver, storage_key FROM photos WHERE uploaded_by_user_id = $1', [uid])).rows : [];
  const before = [...(await photosOf(f.a.user.id)), ...(await photosOf(f.b.user.id))];
  const ids = new Set([f.reportPhotoId, f.evidencePhotoId, ...before.map((p) => p.id)].filter(Boolean));
  const delA = await request('DELETE', '/me', { token: f.a.token, body: { confirm: 'DELETE' } });
  const delB = await request('DELETE', '/me', { token: f.b.token, body: { confirm: 'DELETE' } });
  c.assert(delA.status === 204 && delB.status === 204, `DELETE /me → A ${delA.status}, B ${delB.status}`);
  const me = await request('GET', '/me', { token: f.a.token });
  c.assert(me.status === 401, `old session after delete → ${me.status}`);
  const detail = await request('GET', `/issues/${f.issueId}`);
  c.assert(detail.status === 200, `anonymised issue detail → ${detail.status}`);
  c.assert(!detail.text.includes(f.reportPhotoId) && !detail.text.includes('Privacy probe'), 'issue still shows the report photo or description');
  for (const id of ids) {
    const r = await request('GET', `/media/photos/${id}`, { raw: true });
    c.assert(r.status === 404, `photo ${id.slice(0, 8)} via public URL → ${r.status}`);
  }
  const ev = await request('GET', `/staff/rep-claims/${f.claimId}/evidence/${f.evidencePhotoId}`, { token: f.admin, raw: true });
  c.assert(ev.status !== 200, `claim evidence still served to admin after delete (${ev.status})`);
  if (db) {
    const u = (await db.query('SELECT id, status, phone_e164, firebase_uid, display_name FROM users WHERE id = ANY($1)', [[f.a.user.id, f.b.user.id]])).rows;
    c.assert(u.length === 2 && u.every((x) => x.status === 'deleted' && !x.phone_e164 && !x.firebase_uid && !x.display_name), 'user rows not tombstoned');
    const i = (await db.query('SELECT i.reporter_id, i.description, u.status FROM issues i LEFT JOIN users u ON u.id = i.reporter_id WHERE i.id = $1', [f.issueId])).rows[0];
    c.assert(i && (i.reporter_id === null || i.status === 'deleted') && i.description === null, 'issue not anonymised (reporter / description)');
    const live = (await db.query('SELECT id FROM photos WHERE id = ANY($1) AND deleted_at IS NULL', [[...ids]])).rows;
    c.assert(live.length === 0, `${live.length} photo row(s) not marked deleted`);
    for (const p of before.filter((x) => x.storage_driver === 'local' && env.PHOTO_STORAGE_DIR)) {
      c.assert(!existsSync(path.join(env.PHOTO_STORAGE_DIR, p.storage_key)), `photo file ${p.id.slice(0, 8)} still on disk`);
    }
    c.note(`${ids.size} photos checked`);
  } else c.note('database not reachable — API-side checks only');
  return c.done();
}

export async function p204(ctx) {
  const c = ctx.checker('P2-04', 'API log holds no phone, token, OTP, relay body or comment');
  const dir = env.LOG_FILE_DIR;
  if (!dir || !existsSync(dir)) {
    c.assert(false, 'LOG_FILE_DIR not set or missing (run against a local API with a file log)');
    return c.done();
  }
  let log = '';
  for (const n of readdirSync(dir)) log += readFileSync(path.join(dir, n), 'utf8');
  c.assert(log.length > 0 && log.includes('"request"'), 'log is empty');
  const phones = Object.values(PHONES).flatMap(phoneForms);
  c.assert(!containsAny(log, phones), 'a test phone number (some format) is in the log');
  for (const [k, v] of ctx.secrets) {
    const kind = k.split(':')[0];
    const hit = kind === 'otp' ? containsToken(log, v) : log.includes(v);
    c.assert(!hit, `${kind} found in the log`);
  }
  c.assert(!/Bearer\s+[A-Za-z0-9._-]{20,}/.test(log), 'an Authorization header value is in the log');
  c.note(`${(log.length / 1024).toFixed(0)} KiB of log, ${ctx.secrets.size} secrets checked`);
  return c.done();
}

export async function p212(ctx) {
  const c = ctx.checker('P2-12', 'HTTPS only on staging');
  const u = new URL(ctx.base);
  if (u.protocol !== 'https:') return c.skip('local run over http — staging only (Deferred: needs hosting)');
  const r = await fetch(`${ctx.base}/health`).catch(() => null);
  c.assert(r?.status === 200, `https health → ${r?.status}`);
  const plain = await fetch(`http://${u.host}${u.pathname}/health`, { redirect: 'manual' }).catch(() => null);
  c.assert(!plain || [301, 302, 307, 308].includes(plain.status) && plain.headers.get('location')?.startsWith('https://'), `http → ${plain?.status}`);
  return c.done();
}

export async function p211(ctx, f) {
  const c = ctx.checker('P2-11', 'public reads 429 after 120/IP/min; 11th issue in a day 429');
  const { request, upload } = ctx;
  for (const url of ['/categories', `/issues?ward=${f.ward.id}&limit=1`]) {
    const codes = [];
    for (let i = 0; i < 125 && !codes.includes(429); i++) codes.push((await request('GET', url)).status);
    const first = codes.indexOf(429) + 1;
    c.assert(first > 0, `${url}: no 429 within 125 requests`);
    c.assert(codes.slice(0, Math.min(100, codes.length - 1)).every((s) => s === 200), `${url}: early non-200`);
    c.note(`${url.split('?')[0]} first 429 at #${first}`);
  }
  const cz = await freshCitizen(ctx, PHONES.c, { homeWardId: f.ward.id });
  const statuses = [];
  for (let i = 0; i < 11; i++) {
    const p = await upload('/photos', f.jpeg, { purpose: 'report' }, cz.token);
    const r = await request('POST', '/issues', {
      token: cz.token,
      body: {
        clientSubmissionId: randomUUID(), categorySlug: i % 2 ? 'garbage' : 'streetlight', photoIds: p.data?.photoId ? [p.data.photoId] : [],
        latitude: f.lat0 + (i - 5) * 0.0004, longitude: f.lng0 + (i - 5) * 0.0004, gpsAccuracyM: 8, pinAdjusted: false,
        deviceCapturedAt: new Date().toISOString(), description: `Privacy quota probe ${f.run} #${i + 1}`, platform: 'android', appVersion: '2.0.0',
      },
    });
    statuses.push(r.status === 429 ? `429:${r.data?.error?.code}` : r.status);
  }
  c.assert(statuses.slice(0, 10).every((s) => s === 201 || s === 200), `first 10 issues: ${statuses.slice(0, 10).join(',')}`);
  c.assert(String(statuses[10]).startsWith('429:RATE_LIMITED'), `11th issue → ${statuses[10]}`);
  c.note(`issues: ${statuses.join(',')}`);
  const del = await request('DELETE', '/me', { token: cz.token, body: { confirm: 'DELETE' } });
  if (del.status !== 204) c.note(`cleanup DELETE /me C → ${del.status}`);
  return c.done();
}
