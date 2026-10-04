/**
 * Staff side of representative verification (TASK-11 §5.3, REQ-F-053): claim list/detail, decide (approve with
 * method / reject with reason), revoke, and the term-end expiry job. Decide, revoke and expire each run in one
 * transaction; losing the link sets the user's role back to citizen and bumps token_version (TOKEN_REVOKED).
 */
import type { Prisma, RepClaimStatus } from '@prisma/client';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { notifyUser } from '../../lib/push';
import { termEnded } from './claims.service';

type Tx = Prisma.TransactionClient;

export const VERIFIED_METHODS = ['certificate_of_election', 'official_gazette', 'in_person', 'official_email'] as const;
export type VerifiedMethod = (typeof VERIFIED_METHODS)[number];
export const AUTO_REJECT_REASON = 'Another claim was approved';

const claimSelect = {
  id: true, status: true, createdAt: true, decidedAt: true, phoneMatch: true, otpVerified: true, evidencePhotoIds: true,
  claimantNote: true, rejectReason: true, verifiedMethod: true, termEnd: true,
  representative: { select: { id: true, nameEn: true, nameGu: true, role: true, termStart: true, termEnd: true, sourceUrl: true, verifiedAt: true } },
  user: { select: { displayName: true, homeWard: { select: { number: true, nameEn: true, nameGu: true } } } },
} satisfies Prisma.RepClaimSelect;
type ClaimRow = Prisma.RepClaimGetPayload<{ select: typeof claimSelect }>;

const iso = (d: Date | null) => (d ? d.toISOString() : null);
const day = (d: Date | null) => (d ? d.toISOString().slice(0, 10) : null);

function card(c: ClaimRow) {
  return {
    claimId: c.id,
    representative: { id: c.representative.id, nameEn: c.representative.nameEn, nameGu: c.representative.nameGu, role: c.representative.role },
    claimant: { displayName: c.user.displayName, ward: c.user.homeWard },
    phoneMatch: c.phoneMatch,
    evidenceCount: c.evidencePhotoIds.length,
    createdAt: c.createdAt.toISOString(),
    status: c.status,
  };
}

export async function listClaims(status: RepClaimStatus | undefined, cursor: { k: string; id: string } | null, limit: number) {
  const rows = await prisma.repClaim.findMany({
    where: {
      ...(status ? { status } : {}),
      ...(cursor ? { OR: [{ createdAt: { lt: new Date(cursor.k) } }, { createdAt: new Date(cursor.k), id: { lt: cursor.id } }] } : {}),
    },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: limit + 1,
    select: claimSelect,
  });
  const page = rows.slice(0, limit);
  return { items: page.map(card), more: rows.length > limit, last: page[page.length - 1] };
}

export async function claimDetail(id: string) {
  const c = await prisma.repClaim.findUnique({ where: { id }, select: claimSelect });
  if (!c) throw new AppError('NOT_FOUND');
  const r = c.representative;
  return {
    ...card(c),
    evidence: c.evidencePhotoIds.map((photoId) => ({ photoId })),
    claimantNote: c.claimantNote,
    otpVerified: c.otpVerified,
    decidedAt: iso(c.decidedAt),
    rejectReason: c.rejectReason,
    verifiedMethod: c.verifiedMethod,
    representativeRecord: { ...card(c).representative, termStart: day(r.termStart), termEnd: day(r.termEnd), sourceUrl: r.sourceUrl, verified: r.verifiedAt !== null },
  };
}

/** Clears a representative's link (expiry or revocation) inside `tx`; returns the unlinked user id. */
async function unlink(tx: Tx, repId: string, claimStatus: 'expired' | 'revoked', at: Date): Promise<string | null> {
  const rep = await tx.representative.findUnique({ where: { id: repId }, select: { userId: true } });
  if (!rep?.userId) return null;
  await tx.representative.update({ where: { id: repId }, data: { userId: null, verifiedAt: null, verifiedMethod: null } });
  await tx.repClaim.updateMany({ where: { representativeId: repId, userId: rep.userId, status: 'approved' }, data: { status: claimStatus, decidedAt: at } });
  await tx.user.updateMany({ where: { id: rep.userId, role: 'representative' }, data: { role: 'citizen', tokenVersion: { increment: 1 } } });
  return rep.userId;
}

export type Decision = { decision: 'approve'; method: VerifiedMethod } | { decision: 'reject'; reason: string };

export async function decideClaim(claimId: string, reviewerUserId: string | null, d: Decision) {
  const at = clockNow();
  const out = await prisma.$transaction(async (tx) => {
    await tx.$queryRaw`SELECT id FROM rep_claims WHERE id = ${claimId}::uuid FOR UPDATE`;
    const claim = await tx.repClaim.findUnique({
      where: { id: claimId },
      select: { id: true, status: true, userId: true, representativeId: true, representative: { select: { nameEn: true, nameGu: true, termEnd: true, userId: true, verifiedAt: true } }, user: { select: { role: true } } },
    });
    if (!claim) throw new AppError('NOT_FOUND');
    if (claim.status !== 'pending') throw new AppError('CLAIM_NOT_PENDING');
    if (d.decision === 'reject') {
      await tx.repClaim.update({ where: { id: claimId }, data: { status: 'rejected', rejectReason: d.reason, reviewerId: reviewerUserId, decidedAt: at } });
      return { claim, others: [] as string[] };
    }
    const rep = claim.representative;
    if (termEnded(rep.termEnd, at)) throw new AppError('REPRESENTATIVE_TERM_ENDED');
    if (rep.userId && rep.verifiedAt) throw new AppError('REPRESENTATIVE_ALREADY_VERIFIED');
    if (claim.user.role === 'moderator' || claim.user.role === 'admin') throw new AppError('ROLE_CONFLICT');
    if (await tx.representative.findFirst({ where: { userId: claim.userId, NOT: { id: claim.representativeId } }, select: { id: true } })) {
      throw new AppError('ROLE_CONFLICT', { message: 'This account is already linked to a representative profile.' });
    }
    await tx.repClaim.update({ where: { id: claimId }, data: { status: 'approved', verifiedMethod: d.method, termEnd: rep.termEnd, reviewerId: reviewerUserId, decidedAt: at } });
    await tx.representative.update({ where: { id: claim.representativeId }, data: { userId: claim.userId, verifiedAt: at, verifiedMethod: d.method } });
    await tx.user.update({ where: { id: claim.userId }, data: { role: 'representative' } });
    const others = await tx.repClaim.findMany({ where: { representativeId: claim.representativeId, status: 'pending', NOT: { id: claimId } }, select: { id: true, userId: true } });
    await tx.repClaim.updateMany({ where: { id: { in: others.map((o) => o.id) } }, data: { status: 'rejected', rejectReason: AUTO_REJECT_REASON, reviewerId: reviewerUserId, decidedAt: at } });
    return { claim, others: others.map((o) => o.userId) };
  });
  const rep = out.claim.representative;
  const approved = d.decision === 'approve';
  await safeNotify(out.claim.userId, approved
    ? { en: `Your claim for ${rep.nameEn} was approved`, gu: `${rep.nameGu} માટેનો તમારો દાવો મંજૂર થયો` }
    : { en: `Your claim for ${rep.nameEn} was not approved: ${d.reason}`, gu: `${rep.nameGu} માટેનો તમારો દાવો મંજૂર ન થયો: ${d.reason}` }, claimId);
  for (const userId of out.others) {
    await safeNotify(userId, { en: `Your claim for ${rep.nameEn} was not approved: ${AUTO_REJECT_REASON}`, gu: `${rep.nameGu} માટેનો તમારો દાવો મંજૂર ન થયો: બીજો દાવો મંજૂર થયો` }, claimId);
  }
  return { claimId, status: approved ? 'approved' : 'rejected', autoRejected: out.others.length };
}

async function safeNotify(userId: string, title: { en: string; gu: string }, claimId: string) {
  try {
    await notifyUser(userId, {
      kind: 'system', refId: claimId, route: '/me', channel: 'updates', title,
      body: { en: 'Open Saarthee to see your representative claim.', gu: 'તમારો પ્રતિનિધિ દાવો જોવા સાર્થી ખોલો.' },
    });
  } catch (err) {
    logger.error({ claimId, reason: err instanceof Error ? err.message : 'unknown' }, 'claim notification failed');
  }
}

export async function revokeVerification(repId: string): Promise<{ userId: string }> {
  const at = clockNow();
  const userId = await prisma.$transaction(async (tx) => {
    const rep = await tx.representative.findUnique({ where: { id: repId }, select: { id: true } });
    if (!rep) throw new AppError('NOT_FOUND');
    return unlink(tx, repId, 'revoked', at);
  });
  if (!userId) throw new AppError('NOT_VERIFIED');
  return { userId };
}

/** `reps:expire` (daily 00:30 IST): ends every verification whose term_end is before today (IST). Idempotent. */
export async function expireVerifications(at: Date = clockNow()): Promise<{ expired: { representativeId: string; userId: string }[] }> {
  const due = await prisma.representative.findMany({
    where: { userId: { not: null }, termEnd: { not: null } },
    select: { id: true, termEnd: true },
  });
  const expired: { representativeId: string; userId: string }[] = [];
  for (const r of due.filter((x) => termEnded(x.termEnd, at))) {
    const userId = await prisma.$transaction((tx) => unlink(tx, r.id, 'expired', at));
    if (userId) expired.push({ representativeId: r.id, userId });
  }
  return { expired };
}
