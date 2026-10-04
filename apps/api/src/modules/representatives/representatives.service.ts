/**
 * Public representative reads (TASK-09 §5.3, REQ-F-042/043, REQ-S-012). Only official/consented fields leave
 * this file: never user_id, contact_consent_at, claims or message counts.
 */
import type { Prisma, RepRole } from '@prisma/client';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { electionStatus } from '../settings/electionMode';

const repInclude = {
  areas: {
    include: {
      ward: { select: { id: true, number: true, nameEn: true, nameGu: true } },
      assemblyConstituency: { select: { id: true, number: true, nameEn: true, nameGu: true, pcNameEn: true, pcNameGu: true } },
    },
  },
} satisfies Prisma.RepresentativeInclude;

type RepRow = Prisma.RepresentativeGetPayload<{ include: typeof repInclude }>;

export function initials(nameEn: string): string {
  const words = nameEn.replace(/[^\p{L}\s]/gu, ' ').trim().split(/\s+/).filter(Boolean);
  if (words.length === 0) return '?';
  const first = words[0]![0]!;
  const last = words.length > 1 ? words[words.length - 1]![0]! : '';
  return (first + last).toUpperCase();
}

const isoDate = (d: Date | null) => (d ? d.toISOString().slice(0, 10) : null);

/** TASK-11: verification is per term — it ends at term_end (IST calendar date) even before reps:expire runs. */
function termOver(termEnd: Date | null, at = new Date()): boolean {
  if (!termEnd) return false;
  const ist = new Date(at.getTime() + 330 * 60_000);
  return termEnd.getTime() < Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate());
}

/** TASK-11 public verification block (method, date, valid until) — never the linked user or claimant. */
export async function verificationOf(r: { id: string; verifiedAt: Date | null; verifiedMethod: string | null; termEnd: Date | null }) {
  if (r.verifiedAt && !termOver(r.termEnd)) {
    return { status: 'verified' as const, method: r.verifiedMethod, verifiedAt: r.verifiedAt.toISOString(), validUntil: isoDate(r.termEnd) };
  }
  const ended = r.verifiedAt !== null || (await prisma.repClaim.count({ where: { representativeId: r.id, status: 'expired' } })) > 0;
  return { status: ended ? ('expired' as const) : ('unverified' as const), method: null, verifiedAt: null, validUntil: null };
}

export function summary(r: RepRow, wardNumber?: number) {
  const ac = r.areas.find((a) => a.assemblyConstituency)?.assemblyConstituency;
  const ward = r.areas.find((a) => a.ward)?.ward;
  return {
    id: r.id,
    nameEn: r.nameEn,
    nameGu: r.nameGu,
    role: r.role,
    partyText: r.partyText,
    wardNumber: r.role === 'corporator' ? (wardNumber ?? ward?.number ?? null) : null,
    acNameEn: r.role === 'mla' ? (ac?.nameEn ?? null) : r.role === 'mp' ? (ac?.pcNameEn ?? null) : null,
    acNameGu: r.role === 'mla' ? (ac?.nameGu ?? null) : r.role === 'mp' ? (ac?.pcNameGu ?? null) : null,
    initials: initials(r.nameEn),
    canMessage: r.isActive && r.publicEmail !== null,
    verified: r.verifiedAt !== null && !termOver(r.termEnd),
  };
}

function byName(a: RepRow, b: RepRow) {
  return a.nameEn.localeCompare(b.nameEn);
}

export async function wardRepresentatives(wardId: string) {
  const ward = await prisma.ward.findUnique({
    where: { id: wardId },
    select: {
      id: true, number: true, nameEn: true, nameGu: true, officeAddressEn: true, officeAddressGu: true, officePhone: true,
      zone: { select: { id: true, code: true, nameEn: true, nameGu: true } },
      constituencies: { select: { assemblyConstituencyId: true } },
    },
  });
  if (!ward) throw new AppError('NOT_FOUND');
  const acIds = ward.constituencies.map((c) => c.assemblyConstituencyId);
  const reps = await prisma.representative.findMany({
    where: {
      isActive: true,
      OR: [
        { role: 'corporator', areas: { some: { wardId } } },
        ...(acIds.length > 0 ? [{ role: { in: ['mla', 'mp'] as RepRole[] }, areas: { some: { assemblyConstituencyId: { in: acIds } } } }] : []),
      ],
    },
    include: repInclude,
  });
  const pick = (role: RepRole) => reps.filter((r) => r.role === role).sort(byName).map((r) => summary(r, ward.number));
  return {
    ward: {
      id: ward.id,
      number: ward.number,
      nameEn: ward.nameEn,
      nameGu: ward.nameGu,
      zone: ward.zone,
      officeAddressEn: ward.officeAddressEn,
      officeAddressGu: ward.officeAddressGu,
      officePhone: ward.officePhone,
      assemblyConstituencyCount: acIds.length,
    },
    corporators: pick('corporator'),
    mlas: pick('mla'),
    mps: pick('mp'),
    electionMode: await electionStatus(ward.id),
  };
}

export async function representativeDetail(id: string) {
  const r = await prisma.representative.findFirst({ where: { id, isActive: true }, include: repInclude });
  if (!r) throw new AppError('NOT_FOUND');
  const wardIds = r.areas.flatMap((a) => (a.ward ? [a.ward.id] : []));
  return {
    ...summary(r),
    termStart: isoDate(r.termStart),
    termEnd: isoDate(r.termEnd),
    ...(r.publicPhone ? { officePhone: r.publicPhone } : {}),
    ...(r.publicEmail ? { publicEmail: r.publicEmail } : {}),
    sourceUrl: r.sourceUrl,
    lastVerifiedAt: isoDate(r.lastVerifiedAt),
    areas: r.areas.map((a) =>
      a.ward
        ? { kind: 'ward' as const, wardId: a.ward.id, wardNumber: a.ward.number, nameEn: a.ward.nameEn, nameGu: a.ward.nameGu }
        : {
            kind: 'ac' as const,
            acNumber: a.assemblyConstituency!.number,
            nameEn: a.assemblyConstituency!.nameEn,
            nameGu: a.assemblyConstituency!.nameGu,
            pcNameEn: a.assemblyConstituency!.pcNameEn,
            pcNameGu: a.assemblyConstituency!.pcNameGu,
          },
    ),
    electionMode: await electionStatus(wardIds[0]),
    verification: await verificationOf(r),
  };
}
