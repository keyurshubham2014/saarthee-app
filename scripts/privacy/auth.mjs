// Sign-in helpers for the v2 privacy checks: Firebase Auth Emulator phone OTP → POST /auth/firebase,
// and the v1 email login for the admin. Tokens and OTPs are kept in ctx.secrets, never printed.
import { env } from './lib.mjs';

const emuHost = () => env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const project = () => env.FIREBASE_PROJECT_ID || 'demo-saarthee';

async function emuJson(url, init) {
  const res = await fetch(url, { ...init, headers: { 'content-type': 'application/json', ...(init?.headers ?? {}) } });
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(`auth emulator ${new URL(url).pathname} → ${res.status}`);
  return body;
}

/** Phone OTP sign-in on the Auth Emulator; returns the Firebase ID token. */
export async function emulatorIdToken(ctx, phone) {
  const emu = `http://${emuHost()}`;
  const idt = `${emu}/identitytoolkit.googleapis.com/v1`;
  const send = await emuJson(`${idt}/accounts:sendVerificationCode?key=demo-key`, {
    method: 'POST',
    body: JSON.stringify({ phoneNumber: phone, recaptchaToken: 'emulator' }),
  });
  const codes = await emuJson(`${emu}/emulator/v1/projects/${project()}/verificationCodes`);
  const entry = (codes.verificationCodes ?? []).find((c) => c.sessionInfo === send.sessionInfo);
  if (!entry) throw new Error('no verification code on the auth emulator');
  ctx.secrets.set(`otp:${phone}`, entry.code);
  const signIn = await emuJson(`${idt}/accounts:signInWithPhoneNumber?key=demo-key`, {
    method: 'POST',
    body: JSON.stringify({ sessionInfo: send.sessionInfo, code: entry.code }),
  });
  ctx.secrets.set(`idToken:${phone}`, signIn.idToken);
  return signIn.idToken;
}

const CONSENTS = [
  { purpose: 'core_service', textVersion: 'v2-1' },
  { purpose: 'share_with_representatives', textVersion: 'v2-1' },
];

/** Signs in through the API; returns { token, user, isNew }. Retries once after a 429 (exchange limit 10/min/IP). */
export async function apiSignIn(ctx, phone, { homeWardId } = {}) {
  const idToken = await emulatorIdToken(ctx, phone);
  const body = { idToken, ageConfirmed: true, consents: CONSENTS, language: 'en', ...(homeWardId ? { homeWardId } : {}) };
  let r = await ctx.request('POST', '/auth/firebase', { body });
  if (r.status === 429) {
    const wait = Math.min(Number(r.headers.get('retry-after') ?? 60), 65);
    await new Promise((res) => setTimeout(res, wait * 1000));
    r = await ctx.request('POST', '/auth/firebase', { body: { ...body, idToken: await emulatorIdToken(ctx, phone) } });
  }
  if (r.status !== 200 && r.status !== 201) throw new Error(`POST /auth/firebase → ${r.status} ${r.data?.error?.code ?? ''}`);
  ctx.secrets.set(`session:${phone}`, r.data.accessToken);
  return { token: r.data.accessToken, user: r.data.user, isNew: r.data.isNew };
}

/** A brand-new citizen for this run: an existing account on the number is deleted first (DELETE /me). */
export async function freshCitizen(ctx, phone, opts) {
  let s = await apiSignIn(ctx, phone, opts);
  if (!s.isNew) {
    await ctx.request('DELETE', '/me', { token: s.token, body: { confirm: 'DELETE' } });
    s = await apiSignIn(ctx, phone, opts);
  }
  return s;
}

/** v1 email login (admin_users) — accepted by the staff guard as role admin. */
export async function adminToken(ctx) {
  if (!env.SEED_ADMIN_EMAIL || !env.SEED_ADMIN_PASSWORD) throw new Error('SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD not set');
  const r = await ctx.request('POST', '/admin/auth/login', { body: { email: env.SEED_ADMIN_EMAIL, password: env.SEED_ADMIN_PASSWORD } });
  if (r.status !== 200) throw new Error(`admin login → ${r.status}`);
  ctx.secrets.set('session:admin', r.data.accessToken);
  return r.data.accessToken;
}
