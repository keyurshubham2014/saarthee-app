/** TASK-09 test helpers: fixture wards, signed users, fictional representatives (never real people or numbers). */
import type { Prisma, UserRole } from '@prisma/client';
import { prisma } from '../../src/lib/db';
import { MemoryMailDriver, setMailDriver } from '../../src/lib/mail';
import { signUserToken } from '../../src/lib/tokens';
import { invalidateElectionModeCache } from '../../src/modules/settings/electionMode';
import { makeUser } from '../helpers/factories';
import { importFixtureWards } from '../geo/helpers';

export const SRC = 'https://example.org/test-roster';

export function useMemoryMail(): MemoryMailDriver {
  const d = new MemoryMailDriver();
  setMailDriver(d);
  return d;
}

/** Imports the 3-ward fixture (wards 1, 2, 3) and returns ward ids by number. */
export async function fixtureWards(): Promise<Map<number, string>> {
  await importFixtureWards();
  invalidateElectionModeCache();
  const wards = await prisma.ward.findMany({ select: { id: true, number: true } });
  return new Map(wards.map((w) => [w.number, w.id]));
}

let seq = 0;
/** A user with a fictional +9190000000NN-style phone and a valid session token. */
export async function userWithToken(opts: { role?: UserRole; relayConsent?: boolean; data?: Partial<Prisma.UserUncheckedCreateInput> } = {}) {
  seq += 1;
  const user = await makeUser({ role: opts.role ?? 'citizen', phoneE164: `+91900009${String(seq).padStart(4, '0')}`, ...opts.data });
  if (opts.relayConsent) {
    await prisma.consent.create({ data: { userId: user.id, purpose: 'share_with_representatives', textVersion: 'v2-1' } });
  }
  const { accessToken } = signUserToken(user);
  return { user, auth: { Authorization: `Bearer ${accessToken}` } };
}

export async function makeAc(number: number, wardIds: string[] = []) {
  const ac = await prisma.assemblyConstituency.create({
    data: { number, nameEn: `Test AC ${number}`, nameGu: `ટેસ્ટ ${number}`, pcNameEn: 'Test Seat', pcNameGu: 'ટેસ્ટ બેઠક', sourceUrl: SRC },
  });
  for (const wardId of wardIds) await prisma.wardConstituency.create({ data: { wardId, assemblyConstituencyId: ac.id, sourceUrl: SRC } });
  return ac;
}

let repSeq = 0;
export async function makeRep(
  data: Partial<Prisma.RepresentativeUncheckedCreateInput> & { role?: 'corporator' | 'mla' | 'mp' },
  areas: { wardId?: string; assemblyConstituencyId?: number }[] = [],
) {
  repSeq += 1;
  return prisma.representative.create({
    data: {
      nameEn: `Test Person ${repSeq}`,
      nameGu: `ટેસ્ટ વ્યક્તિ ${repSeq}`,
      role: 'corporator',
      partyText: 'Test Party',
      termStart: new Date('2026-03-01'),
      termEnd: new Date('2031-02-28'),
      publicEmail: `rep${repSeq}@example.org`,
      sourceUrl: SRC,
      lastVerifiedAt: new Date('2026-09-12'),
      ...data,
      areas: { create: areas },
    },
  });
}
