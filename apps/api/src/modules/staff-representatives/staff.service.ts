/**
 * Staff roster CRUD (TASK-09 §5.3, REQ-F-045). Same row rules as the importer (roster.validate.ts):
 * a mobile number → 400 REP_PERSONAL_NUMBER; other problems → 400 VALIDATION_FAILED with field details.
 */
import { Prisma } from '@prisma/client';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { MAX_CORPORATORS_PER_WARD, validateRosterRow, type RosterRecord } from './roster.validate';

export interface RepInput {
  nameEn: string;
  nameGu: string;
  role: 'corporator' | 'mla' | 'mp';
  partyText?: string | null;
  termStart: string;
  termEnd?: string | null;
  wardNumber?: number | null;
  acNumbers?: number[];
  officePhone?: string | null;
  publicEmail?: string | null;
  sourceUrl: string;
  lastVerifiedAt: string;
}

const RECHECK_DAYS = 180;
const include = { areas: { include: { ward: { select: { number: true, nameEn: true } }, assemblyConstituency: { select: { number: true, nameEn: true } } } } };
type Row = Prisma.RepresentativeGetPayload<{ include: typeof include }>;

const iso = (d: Date | null) => (d ? d.toISOString().slice(0, 10) : null);

export function staffView(r: Row, now = new Date()) {
  return {
    id: r.id, nameEn: r.nameEn, nameGu: r.nameGu, role: r.role, partyText: r.partyText,
    termStart: iso(r.termStart), termEnd: iso(r.termEnd), officePhone: r.publicPhone, publicEmail: r.publicEmail,
    sourceUrl: r.sourceUrl, lastVerifiedAt: iso(r.lastVerifiedAt), isActive: r.isActive, verified: r.verifiedAt !== null,
    wardNumber: r.areas.find((a) => a.ward)?.ward?.number ?? null,
    acNumbers: r.areas.flatMap((a) => (a.assemblyConstituency ? [a.assemblyConstituency.number] : [])),
    needsRecheck: now.getTime() - r.lastVerifiedAt.getTime() > RECHECK_DAYS * 86_400_000,
  };
}

function toRaw(i: RepInput): Record<string, string> {
  return {
    name_en: i.nameEn, name_gu: i.nameGu, role: i.role, party_text: i.partyText ?? '', term_start: i.termStart, term_end: i.termEnd ?? '',
    ward_number: i.wardNumber != null ? String(i.wardNumber) : '', ac_number: (i.acNumbers ?? []).join(';'),
    office_phone: i.officePhone ?? '', public_email: i.publicEmail ?? '', source_url: i.sourceUrl, last_verified_at: i.lastVerifiedAt,
  };
}

function check(input: RepInput): RosterRecord {
  const res = validateRosterRow(toRaw(input));
  if (res.ok) return res.record;
  if (res.errors.some((e) => e.startsWith('office_phone:') && e.includes('Mobile'))) throw new AppError('REP_PERSONAL_NUMBER');
  throw new AppError('VALIDATION_FAILED', { details: res.errors.map((e) => ({ field: e.split(':')[0]!, issue: e.slice(e.indexOf(':') + 1).trim() })) });
}

async function areaData(tx: Prisma.TransactionClient, r: RosterRecord, selfId?: string) {
  if (r.wardNumber !== null) {
    const ward = await tx.ward.findUnique({ where: { number: r.wardNumber }, select: { id: true } });
    if (!ward) throw new AppError('VALIDATION_FAILED', { details: [{ field: 'wardNumber', issue: 'Unknown ward.' }] });
    const seats = await tx.representative.count({
      where: { role: 'corporator', isActive: true, areas: { some: { wardId: ward.id } }, ...(selfId ? { id: { not: selfId } } : {}) },
    });
    if (seats >= MAX_CORPORATORS_PER_WARD) {
      throw new AppError('VALIDATION_FAILED', { details: [{ field: 'wardNumber', issue: `Ward ${r.wardNumber} already has 4 active corporators.` }] });
    }
    return [{ wardId: ward.id }];
  }
  const acs = await tx.assemblyConstituency.findMany({ where: { number: { in: r.acNumbers } }, select: { id: true } });
  if (acs.length !== r.acNumbers.length) throw new AppError('VALIDATION_FAILED', { details: [{ field: 'acNumbers', issue: 'Unknown constituency.' }] });
  return acs.map((a) => ({ assemblyConstituencyId: a.id }));
}

function fields(r: RosterRecord) {
  return {
    nameEn: r.nameEn, nameGu: r.nameGu, role: r.role, partyText: r.partyText, termStart: r.termStart, termEnd: r.termEnd,
    publicPhone: r.publicPhone, publicEmail: r.publicEmail, sourceUrl: r.sourceUrl, lastVerifiedAt: r.lastVerifiedAt,
  };
}

function duplicate(err: unknown): never {
  if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') throw new AppError('REP_DUPLICATE');
  if (err instanceof Prisma.PrismaClientUnknownRequestError && /uq_representatives_import_key/.test(err.message)) throw new AppError('REP_DUPLICATE');
  if (err instanceof Prisma.PrismaClientKnownRequestError && /uq_representatives_import_key/.test(JSON.stringify(err.meta ?? {}))) throw new AppError('REP_DUPLICATE');
  throw err;
}

export async function listReps(f: { ward?: number; role?: 'corporator' | 'mla' | 'mp'; q?: string; active?: boolean }) {
  const rows = await prisma.representative.findMany({
    where: {
      ...(f.role ? { role: f.role } : {}),
      ...(f.active !== undefined ? { isActive: f.active } : {}),
      AND: [
        ...(f.q ? [{ OR: [{ nameEn: { contains: f.q, mode: 'insensitive' as const } }, { nameGu: { contains: f.q } }] }] : []),
        ...(f.ward !== undefined
          ? [{ OR: [{ areas: { some: { ward: { number: f.ward } } } }, { areas: { some: { assemblyConstituency: { wards: { some: { ward: { number: f.ward } } } } } } }] }]
          : []),
      ],
    },
    include,
    orderBy: [{ role: 'asc' }, { nameEn: 'asc' }],
    take: 500,
  });
  return rows.map((r) => staffView(r));
}

export async function getRep(id: string) {
  const r = await prisma.representative.findUnique({ where: { id }, include });
  if (!r) throw new AppError('NOT_FOUND');
  return staffView(r);
}

export async function createRep(input: RepInput) {
  const r = check(input);
  return prisma
    .$transaction(async (tx) => {
      const areas = await areaData(tx, r);
      const created = await tx.representative.create({ data: { ...fields(r), areas: { create: areas } }, include });
      return staffView(created);
    })
    .catch(duplicate);
}

export async function updateRep(id: string, patch: Partial<RepInput>) {
  const cur = await getRep(id);
  const merged: RepInput = {
    nameEn: cur.nameEn, nameGu: cur.nameGu, role: cur.role, partyText: cur.partyText, termStart: cur.termStart!, termEnd: cur.termEnd,
    wardNumber: cur.wardNumber, acNumbers: cur.acNumbers, officePhone: cur.officePhone, publicEmail: cur.publicEmail,
    sourceUrl: cur.sourceUrl, lastVerifiedAt: cur.lastVerifiedAt!, ...patch,
  };
  const r = check(merged);
  return prisma
    .$transaction(async (tx) => {
      const areas = await areaData(tx, r, id);
      await tx.representativeArea.deleteMany({ where: { representativeId: id } });
      const saved = await tx.representative.update({ where: { id }, data: { ...fields(r), areas: { create: areas } }, include });
      return staffView(saved);
    })
    .catch(duplicate);
}

export async function deactivateRep(id: string) {
  await getRep(id);
  const saved = await prisma.representative.update({ where: { id }, data: { isActive: false }, include });
  return staffView(saved);
}

export async function listConstituencies() {
  const acs = await prisma.assemblyConstituency.findMany({ include: { wards: { include: { ward: { select: { number: true } } } } }, orderBy: { number: 'asc' } });
  return acs.map((a) => ({
    id: a.id, number: a.number, nameEn: a.nameEn, nameGu: a.nameGu, pcNameEn: a.pcNameEn, pcNameGu: a.pcNameGu, sourceUrl: a.sourceUrl,
    wardNumbers: a.wards.map((w) => w.ward.number).sort((x, y) => x - y),
  }));
}

export async function setWardConstituencies(wardId: string, items: { acId: number; sourceUrl: string }[]) {
  const ward = await prisma.ward.findUnique({ where: { id: wardId }, select: { id: true } });
  if (!ward) throw new AppError('NOT_FOUND');
  const found = await prisma.assemblyConstituency.count({ where: { id: { in: items.map((i) => i.acId) } } });
  if (found !== new Set(items.map((i) => i.acId)).size || found !== items.length) {
    throw new AppError('VALIDATION_FAILED', { details: [{ field: 'items', issue: 'Unknown or repeated constituency.' }] });
  }
  await prisma.$transaction([
    prisma.wardConstituency.deleteMany({ where: { wardId } }),
    prisma.wardConstituency.createMany({ data: items.map((i) => ({ wardId, assemblyConstituencyId: i.acId, sourceUrl: i.sourceUrl })) }),
  ]);
  return { wardId, items };
}
