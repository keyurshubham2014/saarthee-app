// Sign-in helpers: Firebase Auth Emulator phone OTP → POST /auth/firebase; v1 admin email login.
// OTPs, ID tokens, session tokens and phone numbers are never printed.
import { readdirSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { apiRequire, env, EMU, PROJECT, post, sleep } from './lib.mjs';

const IDT = `${EMU}/identitytoolkit.googleapis.com/v1`;

async function emu(url, body) {
  const res = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`emulator ${new URL(url).pathname} → ${res.status}`);
  return data;
}

/** Phone OTP sign-in on the emulator; returns { idToken, localId }. */
export async function emulatorIdToken(phone) {
  const send = await emu(`${IDT}/accounts:sendVerificationCode?key=demo-key`, { phoneNumber: phone, recaptchaToken: 'emulator' });
  const codes = await fetch(`${EMU}/emulator/v1/projects/${PROJECT}/verificationCodes`).then((r) => r.json());
  const entry = (codes.verificationCodes ?? []).find((c) => c.sessionInfo === send.sessionInfo);
  if (!entry) throw new Error('no verification code on the emulator');
  const signIn = await emu(`${IDT}/accounts:signInWithPhoneNumber?key=demo-key`, { sessionInfo: send.sessionInfo, code: entry.code });
  return { idToken: signIn.idToken, localId: signIn.localId };
}

/** Deletes an emulator account (cleanup for accounts the API never saw). */
export async function emulatorDelete(localId) {
  await fetch(`${IDT}/projects/${PROJECT}/accounts:delete`, {
    method: 'POST',
    headers: { authorization: 'Bearer owner', 'content-type': 'application/json' },
    body: JSON.stringify({ localId }),
  }).catch(() => undefined);
}

// POST /auth/firebase allows 10/IP/min: keep at most 9 exchanges in any rolling minute.
const exchanges = [];
async function throttle() {
  for (;;) {
    const now = Date.now();
    while (exchanges.length && now - exchanges[0] > 61_000) exchanges.shift();
    if (exchanges.length < 9) break;
    const wait = 61_000 - (now - exchanges[0]) + 250;
    console.log(`   (waiting ${Math.ceil(wait / 1000)} s for the sign-in rate window)`);
    await sleep(wait);
  }
  exchanges.push(Date.now());
}

export const CONSENTS = [{ purpose: 'core_service', textVersion: 'v2-1' }];

/** Raw exchange (for negative checks). */
export async function exchange(body) {
  await throttle();
  return post('/auth/firebase', body);
}

/** Full sign-in. Returns { token, user, localId, res }. */
export async function signIn(phone, extra = {}) {
  const { idToken, localId } = await emulatorIdToken(phone);
  const res = await exchange({ idToken, ageConfirmed: true, consents: CONSENTS, language: 'en', ...extra });
  return { token: res.data?.accessToken, user: res.data?.user, localId, res };
}

/** v1 admin email login from SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD (values never printed). */
export async function adminLogin() {
  const res = await post('/admin/auth/login', { email: env.SEED_ADMIN_EMAIL, password: env.SEED_ADMIN_PASSWORD });
  return { token: res.data?.accessToken, res };
}

// ---- database (setup/cleanup of the sweep's own rows only) ---------------------------------------------------
let prisma;
export function db() {
  if (!prisma) {
    const { PrismaClient } = apiRequire('@prisma/client');
    prisma = new PrismaClient({ datasources: { db: { url: env.DATABASE_URL } }, log: [] });
  }
  return prisma;
}
export async function closeDb() {
  await prisma?.$disconnect();
}

// ---- audit / log files -------------------------------------------------------------------------------------
function filesIn(dirOrFile) {
  if (!dirOrFile) return [];
  const dir = path.dirname(dirOrFile);
  const base = path.basename(dirOrFile).replace(/\.log$/, '');
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter((f) => f.startsWith(base)).map((f) => path.join(dir, f));
}
export const auditFiles = () => filesIn(env.AUDIT_LOG_FILE);
export function logFiles() {
  const dir = env.LOG_FILE_DIR;
  return dir && existsSync(dir) ? readdirSync(dir).map((f) => path.join(dir, f)) : [];
}
export function readLines(files) {
  return files.flatMap((f) => readFileSync(f, 'utf8').split('\n').filter(Boolean));
}
export function auditLines() {
  return readLines(auditFiles()).map((l) => {
    try {
      return JSON.parse(l);
    } catch {
      return { raw: l };
    }
  });
}

/** Waits (≤ 3 s) for audit lines for `action` + `targetId` and returns them. */
export async function auditFor(action, targetId, since) {
  for (let i = 0; i < 15; i++) {
    const hits = auditLines().filter((l) => l.action === action && l.targetId === targetId && (!since || l.time >= since || l.ts >= since));
    if (hits.length) {
      await sleep(300);
      return auditLines().filter((l) => l.action === action && l.targetId === targetId && (!since || l.time >= since || l.ts >= since));
    }
    await sleep(200);
  }
  return [];
}
