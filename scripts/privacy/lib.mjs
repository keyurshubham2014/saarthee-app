// Shared helpers for scripts/privacy-checks.mjs (v1 and v2 checks).
// Never prints phone numbers, OTPs, ID tokens, session tokens, FCM tokens or message bodies.
import { createRequire } from 'node:module';
import { existsSync, readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export const apiRequire = createRequire(path.join(ROOT, 'apps/api/package.json'));

const envFile = path.join(ROOT, 'apps/api/.env');
const fileEnv = existsSync(envFile)
  ? Object.fromEntries(
      readFileSync(envFile, 'utf8')
        .split('\n')
        .filter((l) => l.includes('=') && !l.trimStart().startsWith('#'))
        .map((l) => [l.slice(0, l.indexOf('=')).trim(), l.slice(l.indexOf('=') + 1).trim()]),
    )
  : {};
/** apps/api/.env overlaid by the process environment (so staging runs can pass values explicitly). */
export const env = { ...fileEnv, ...Object.fromEntries(Object.entries(process.env).filter(([, v]) => v !== undefined)) };

export function createContext(base) {
  const results = [];
  /** Secrets seen during the run (tokens, OTPs, bodies) — grepped for in the API log by P2-04, never printed. */
  const secrets = new Map();
  const hdr = { 'X-Install-Id': randomUUID(), 'X-Platform': 'android', 'X-App-Version': '2.0.0' };

  async function request(method, url, { body, token, headers = {}, raw = false } = {}) {
    const res = await fetch(url.startsWith('http') ? url : base + url, {
      method,
      headers: {
        ...hdr,
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...(body !== undefined ? { 'Content-Type': 'application/json' } : {}),
        ...headers,
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
      redirect: 'manual',
    });
    if (raw) return { status: res.status, headers: res.headers, buf: Buffer.from(await res.arrayBuffer()) };
    const text = await res.text();
    let data;
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
    return { status: res.status, data, text, headers: res.headers };
  }

  async function upload(url, buf, fields, token) {
    const fd = new FormData();
    for (const [k, v] of Object.entries(fields)) fd.append(k, v);
    fd.append('photo', new Blob([buf], { type: 'image/jpeg' }), 'p.jpg');
    const res = await fetch(base + url, { method: 'POST', headers: { ...hdr, Authorization: `Bearer ${token}` }, body: fd });
    return { status: res.status, data: await res.json().catch(() => null) };
  }

  /** One PASS/FAIL line per check ID; sub-assertions are collected and the failing ones listed. */
  function checker(id, title) {
    const failed = [];
    const notes = [];
    return {
      assert(ok, label) {
        if (!ok) failed.push(label);
        return Boolean(ok);
      },
      note(s) {
        notes.push(s);
      },
      done() {
        const ok = failed.length === 0;
        results.push({ id, title, ok, status: ok ? 'PASS' : 'FAIL' });
        const info = ok ? notes.join('; ') : `failed: ${failed.join(' | ')}`;
        console.log(`${ok ? 'PASS' : 'FAIL'}  ${id} ${title}${info ? ` — ${info}` : ''}`);
        return ok;
      },
      skip(reason) {
        results.push({ id, title, ok: true, status: 'SKIP' });
        console.log(`SKIP  ${id} ${title} — ${reason}`);
      },
    };
  }

  /** Legacy single-line check (v1). */
  function check(name, ok, info = '') {
    results.push({ id: name, title: '', ok: Boolean(ok), status: ok ? 'PASS' : 'FAIL' });
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${info ? ` — ${info}` : ''}`);
  }

  return { base, results, secrets, request, upload, checker, check };
}

/** National 10-digit number and common written forms of an E.164 +91 number. */
export function phoneForms(e164) {
  const n = e164.replace(/^\+91/, '');
  return [e164, n, `${n.slice(0, 5)} ${n.slice(5)}`, `+91 ${n}`, `+91-${n}`, `+91 ${n.slice(0, 5)} ${n.slice(5)}`, `91${n}`];
}

export const containsAny = (text, needles) => needles.some((s) => s && text.includes(s));

/** True when `code` (e.g. an OTP) appears as a standalone token, not inside a longer number/UUID. */
export function containsToken(text, code) {
  if (!code) return false;
  const esc = code.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`(?<![0-9A-Za-z-])${esc}(?![0-9A-Za-z-])`).test(text);
}
