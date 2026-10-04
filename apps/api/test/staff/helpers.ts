/** TASK-10 test helpers: identities, fixture wards, issues inside/outside wards, comments. */
import type { UserRole } from '@prisma/client';
import { prisma } from '../../src/lib/db';
import { signUserToken } from '../../src/lib/tokens';
import { api } from '../helpers/app';
import { createAdmin } from '../helpers/auth';
import { makeCategory, makeIssue, makeUser } from '../helpers/factories';
import { importFixtureWards, wardPoint } from '../geo/helpers';

export const PREFIX = '/api/v1';
export type Auth = Record<string, string>;

export async function as(role: UserRole, data: Parameters<typeof makeUser>[0] = {}) {
  const user = await makeUser({ role, displayName: `${role} person`, ...data });
  const { accessToken } = signUserToken(user);
  return { user, auth: { Authorization: `Bearer ${accessToken}` } as Auth };
}

/** Visitor, citizen, representative, moderator, admin, suspended moderator, v1 admin. */
export async function identities() {
  const citizen = await as('citizen');
  const representative = await as('representative');
  const moderator = await as('moderator');
  const admin = await as('admin');
  const suspended = await as('moderator');
  await prisma.user.update({ where: { id: suspended.user.id }, data: { status: 'suspended' } });
  const v1 = await createAdmin();
  return { citizen, representative, moderator, admin, suspended, v1 };
}

export async function wards() {
  await importFixtureWards();
  const list = await prisma.ward.findMany({ orderBy: { number: 'asc' } });
  return { list, byNumber: (n: number) => list.find((w) => w.number === n)! };
}

/** Issue inside fixture ward `n` (location from the ward's interior point). */
export async function issueInWard(n: number, data: Parameters<typeof makeIssue>[0] = {}) {
  const ward = await prisma.ward.findFirstOrThrow({ where: { number: n } });
  const p = await wardPoint(n);
  return makeIssue({ lat: p.lat, lng: p.lng, wardId: ward.id, zoneId: ward.zoneId, ...data });
}

/** Issue far outside every ward polygon. */
export const issueOutside = (data: Parameters<typeof makeIssue>[0] = {}) => makeIssue({ lat: 22.3, lng: 70.8, ...data });

export async function comment(issueId: string, userId: string, note = 'A comment') {
  return prisma.issueEvent.create({ data: { issueId, actorId: userId, actorRole: 'citizen', type: 'comment', note } });
}

export const post = (auth: Auth | undefined, path: string, body: object = {}) => {
  const req = api().post(`${PREFIX}${path}`);
  return (auth ? req.set(auth) : req).send(body);
};
export const get = (auth: Auth | undefined, path: string) => {
  const req = api().get(`${PREFIX}${path}`);
  return auth ? req.set(auth) : req;
};

export { makeCategory, makeIssue, makeUser };
