/** TASK-11 test helpers: fictional representatives with a linked (verified) user, evidence photos, API calls. */
import type { Prisma, UserRole } from '@prisma/client';
import { prisma } from '../../src/lib/db';
import { signUserToken } from '../../src/lib/tokens';
import { invalidateElectionModeCache, setElectionMode } from '../../src/modules/settings/electionMode';
import { api } from '../helpers/app';
import { makePhoto, makeUser } from '../helpers/factories';
import { makeRep } from './helpers';

export const PREFIX = '/api/v1';
export type Auth = Record<string, string>;

export async function signed(role: UserRole = 'citizen', data: Partial<Prisma.UserUncheckedCreateInput> = {}) {
  const user = await makeUser({ role, displayName: `${role} person`, ...data });
  return { user, auth: { Authorization: `Bearer ${signUserToken(user).accessToken}` } as Auth };
}

/** Re-signs a user (after a role change the old token keeps its token_version). */
export async function resign(userId: string) {
  const user = await prisma.user.findUniqueOrThrow({ where: { id: userId } });
  return { Authorization: `Bearer ${signUserToken(user).accessToken}` } as Auth;
}

/** A verified, in-term corporator for `wardIds`, linked to a fresh representative user. */
export async function verifiedRep(wardIds: string[], data: Partial<Prisma.RepresentativeUncheckedCreateInput> = {}) {
  const u = await signed('representative');
  const rep = await makeRep({ userId: u.user.id, verifiedAt: new Date(), verifiedMethod: 'certificate_of_election', ...data }, wardIds.map((wardId) => ({ wardId })));
  await prisma.repClaim.create({ data: { representativeId: rep.id, userId: u.user.id, status: 'approved', otpVerified: true, decidedAt: new Date(), termEnd: rep.termEnd } });
  return { ...u, rep };
}

export async function evidence(userId: string, n = 1, data: Partial<Prisma.PhotoUncheckedCreateInput> = {}) {
  const ids: string[] = [];
  for (let i = 0; i < n; i++) ids.push((await makePhoto({ purpose: 'rep_evidence', uploadedByUserId: userId, attachedAt: null, ...data })).id);
  return ids;
}

export async function electionOn(wardIds: string[] | 'city') {
  const from = new Date(Date.now() - 86_400_000).toISOString();
  const to = new Date(Date.now() + 7 * 86_400_000).toISOString();
  await setElectionMode(
    { enabled: true, from, to, scope: wardIds === 'city' ? 'city' : 'wards', wardIds: wardIds === 'city' ? [] : wardIds, note_en: 'Polls', note_gu: 'ચૂંટણી' },
    (await signed('admin')).user.id,
  );
  invalidateElectionModeCache();
}

export async function electionOff() {
  await prisma.appSetting.deleteMany({ where: { key: 'election_mode' } });
  invalidateElectionModeCache();
}

export const post = (auth: Auth | undefined, path: string, body: object = {}) => {
  const req = api().post(`${PREFIX}${path}`);
  return (auth ? req.set(auth) : req).send(body);
};
export const get = (auth: Auth | undefined, path: string) => {
  const req = api().get(`${PREFIX}${path}`);
  return auth ? req.set(auth) : req;
};
export const del = (auth: Auth, path: string) => api().delete(`${PREFIX}${path}`).set(auth);
