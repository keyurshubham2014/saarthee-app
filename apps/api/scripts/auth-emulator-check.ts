/**
 * End-to-end check against the Firebase Auth Emulator (TASK-04). Run from the repo root:
 *   npx firebase-tools@15.32.1 emulators:exec --only auth --project demo-saarthee \
 *     "npm --prefix apps/api run auth:emulator-check"
 * Phone OTP on the emulator → ID token → POST /auth/firebase → GET /me → DELETE /me (deletes the emulator user).
 * Uses the dev database from apps/api/.env. Prints statuses only — never the code, tokens or phone number.
 */
import type { AddressInfo } from 'node:net';
import { createApp } from '../src/app';
import { config } from '../src/config';
import { prisma } from '../src/lib/db';

const PHONE = process.env.CHECK_PHONE ?? '+919000000001';
const emu = `http://${config.FIREBASE_AUTH_EMULATOR_HOST}`;
const project = config.FIREBASE_PROJECT_ID;

async function json(url: string, init?: RequestInit): Promise<Record<string, unknown>> {
  const res = await fetch(url, { ...init, headers: { 'content-type': 'application/json', ...(init?.headers ?? {}) } });
  const body = (await res.json().catch(() => ({}))) as Record<string, unknown>;
  if (!res.ok) throw new Error(`${new URL(url).pathname} → ${res.status}`);
  return body;
}

async function main() {
  if (config.FIREBASE_AUTH_MODE !== 'emulator') throw new Error('set FIREBASE_AUTH_MODE=emulator');
  const idt = `${emu}/identitytoolkit.googleapis.com/v1`;
  const send = await json(`${idt}/accounts:sendVerificationCode?key=demo-key`, {
    method: 'POST',
    body: JSON.stringify({ phoneNumber: PHONE, recaptchaToken: 'emulator' }),
  });
  const codes = await json(`${emu}/emulator/v1/projects/${project}/verificationCodes`);
  const entry = (codes.verificationCodes as { sessionInfo: string; code: string }[]).find((c) => c.sessionInfo === send.sessionInfo);
  if (!entry) throw new Error('no verification code on the emulator');
  const signIn = await json(`${idt}/accounts:signInWithPhoneNumber?key=demo-key`, {
    method: 'POST',
    body: JSON.stringify({ sessionInfo: send.sessionInfo, code: entry.code }),
  });
  console.log('emulator: phone sign-in ok (id token received)');

  const server = createApp().listen(0, '127.0.0.1');
  await new Promise((r) => server.once('listening', r));
  const api = `http://127.0.0.1:${(server.address() as AddressInfo).port}/api/v1`;
  try {
    const body = { idToken: signIn.idToken, ageConfirmed: true, consents: [{ purpose: 'core_service', textVersion: 'v2-1' }], language: 'gu' };
    const ex = await fetch(`${api}/auth/firebase`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
    const exBody = (await ex.json()) as { accessToken?: string; isNew?: boolean; user?: { phoneMasked?: string } };
    console.log(`POST /auth/firebase → ${ex.status} isNew=${exBody.isNew} phoneMasked=${exBody.user?.phoneMasked}`);
    const auth = { authorization: `Bearer ${exBody.accessToken}` };
    console.log(`GET /me → ${(await fetch(`${api}/me`, { headers: auth })).status}`);
    const del = await fetch(`${api}/me`, { method: 'DELETE', headers: { ...auth, 'content-type': 'application/json' }, body: '{"confirm":"DELETE"}' });
    console.log(`DELETE /me → ${del.status}`);
    const lookup = await fetch(`${idt}/projects/${project}/accounts:lookup`, {
      method: 'POST',
      headers: { authorization: 'Bearer owner', 'content-type': 'application/json' },
      body: JSON.stringify({ localId: [signIn.localId] }),
    }).then((r) => r.json() as Promise<{ users?: unknown[] }>);
    console.log(`emulator user after delete: ${lookup.users?.length ? 'still present (FAIL)' : 'deleted'}`);
    if (ex.status >= 300 || del.status !== 204 || lookup.users?.length) process.exitCode = 1;
  } finally {
    server.close();
  }
}

main()
  .catch((err: unknown) => {
    console.error(`auth:emulator-check failed: ${(err as Error).message}`);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
