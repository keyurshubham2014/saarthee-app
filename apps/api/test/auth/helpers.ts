import { randomUUID } from 'node:crypto';
import { FakeFirebaseGateway, setFirebaseGateway } from '../../src/lib/firebase';
import { MemoryPushDriver, setPushDriver } from '../../src/lib/push';
import { api } from '../helpers/app';

/** Fake Firebase for the current file (TASK-04 tests never reach Google or the emulator). */
export function useFakeFirebase(): FakeFirebaseGateway {
  const gw = new FakeFirebaseGateway('demo-saarthee');
  setFirebaseGateway(gw);
  return gw;
}

export function useMemoryPush(): MemoryPushDriver {
  const d = new MemoryPushDriver();
  setPushDriver(d);
  return d;
}

let n = 0;
/** Fictional test numbers only: +9190000000NN. */
export function testPhone(): string {
  n += 1;
  return `+91900000${String(n).padStart(4, '0')}`;
}

export const CORE = { purpose: 'core_service', textVersion: 'v2-1' };

export function signInBody(idToken: string, extra: Record<string, unknown> = {}) {
  return { idToken, ageConfirmed: true, consents: [CORE], language: 'gu', ...extra };
}

/** Signs a new citizen in through the real endpoint; returns token, user and the Firebase identity. */
export async function signIn(gw: FakeFirebaseGateway, opts: { phone?: string; uid?: string; extra?: Record<string, unknown> } = {}) {
  const phone = opts.phone ?? testPhone();
  const uid = opts.uid ?? `uid-${randomUUID()}`;
  const idToken = gw.issueToken({ uid, phone });
  const res = await api().post('/api/v1/auth/firebase').send(signInBody(idToken, opts.extra));
  if (res.status !== 201 && res.status !== 200) throw new Error(`sign-in failed: ${res.status} ${JSON.stringify(res.body)}`);
  const token = res.body.accessToken as string;
  return { token, auth: { Authorization: `Bearer ${token}` }, user: res.body.user, phone, uid, idToken, res };
}
