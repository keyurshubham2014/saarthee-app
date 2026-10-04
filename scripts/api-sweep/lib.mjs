// Shared helpers for scripts/api-sweep.mjs (V2 TASK-14 §5.3/§5.5). Never prints secrets, tokens, OTPs or phones.
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export const API_DIR = path.join(ROOT, 'apps/api');
export const apiRequire = createRequire(path.join(API_DIR, 'package.json'));

/** Parses a dotenv file (KEY=value lines only). */
export function readEnvFile(file) {
  return Object.fromEntries(
    readFileSync(file, 'utf8')
      .split('\n')
      .filter((l) => /^[A-Z][A-Z0-9_]*=/.test(l))
      .map((l) => [l.slice(0, l.indexOf('=')), l.slice(l.indexOf('=') + 1)]),
  );
}

export const ENV_FILE = process.env.SWEEP_ENV_FILE ?? path.join(API_DIR, '.env');
export const env = { ...readEnvFile(ENV_FILE) };
export const BASE = (process.argv.find((a) => /^https?:\/\//.test(a)) ?? `http://127.0.0.1:${env.API_PORT ?? 4200}/api/v1`).replace(/\/$/, '');
export const EMU = `http://${env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099'}`;
export const PROJECT = env.FIREBASE_PROJECT_ID || 'demo-saarthee';

// ---- results ----------------------------------------------------------------------------------------------
export const results = [];
/** Codes the sweep saw in error responses (for the error-code table). */
export const seenCodes = new Map();
let group = '';
export function section(name) {
  group = name;
  console.log(`\n== ${name}`);
}
export function check(name, ok, info = '') {
  results.push({ group, name, ok: Boolean(ok), info });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${info ? ` — ${info}` : ''}`);
  return Boolean(ok);
}
/** Asserts status (and optional error code) of a response; records the code as produced. */
export function expect(name, r, status, code) {
  const gotCode = r.data?.error?.code;
  const ok = r.status === status && (code === undefined || gotCode === code);
  if (ok && gotCode) seenCodes.set(gotCode, seenCodes.get(gotCode) ?? `sweep: ${name}`);
  return check(name, ok, `${r.status}${gotCode ? ` ${gotCode}` : ''}${ok ? '' : ` (want ${status}${code ? ` ${code}` : ''})`}`);
}

// ---- HTTP -------------------------------------------------------------------------------------------------
export const installId = randomUUID();
const clientHeaders = { 'X-Install-Id': installId, 'X-Platform': 'android', 'X-App-Version': '2.0.0' };
export const bearer = (token) => (token ? { Authorization: `Bearer ${token}` } : {});

export async function call(method, url, { body, token, headers = {}, raw } = {}) {
  const res = await fetch(url.startsWith('http') ? url : BASE + url, {
    method,
    headers: { ...clientHeaders, ...bearer(token), ...headers, ...(body !== undefined && !raw ? { 'Content-Type': 'application/json' } : {}) },
    body: raw ?? (body !== undefined ? JSON.stringify(body) : undefined),
    redirect: 'manual',
  });
  const buf = Buffer.from(await res.arrayBuffer());
  const text = buf.toString('utf8');
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = text;
  }
  return { status: res.status, data, text, headers: res.headers, buf };
}
export const get = (url, o) => call('GET', url, o);
export const post = (url, body, o = {}) => call('POST', url, { ...o, body });
export const put = (url, body, o = {}) => call('PUT', url, { ...o, body });
export const patch = (url, body, o = {}) => call('PATCH', url, { ...o, body });
export const del = (url, body, o = {}) => call('DELETE', url, { ...o, body });

/** Multipart photo upload (field `photo`). */
export async function upload(token, buf, fields, type = 'image/jpeg') {
  const fd = new FormData();
  for (const [k, v] of Object.entries(fields)) fd.append(k, v);
  fd.append('photo', new Blob([buf], { type }), type === 'image/jpeg' ? 'p.jpg' : 'p.bin');
  return call('POST', '/photos', { token, raw: fd });
}

let sharp;
/** A small JPEG (unique per call so photo hashes never collide). */
export async function jpeg(seed = Math.random()) {
  sharp ??= apiRequire('sharp');
  const c = Math.floor(seed * 0xffffff).toString(16).padStart(6, '0');
  return sharp({ create: { width: 640, height: 480, channels: 3, background: `#${c}` } })
    .composite([{ input: Buffer.from(`<svg width="640" height="480"><text x="20" y="60" font-size="40">${randomUUID()}</text></svg>`), top: 0, left: 0 }])
    .jpeg({ quality: 80 })
    .toBuffer();
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
export const uuid = () => randomUUID();
