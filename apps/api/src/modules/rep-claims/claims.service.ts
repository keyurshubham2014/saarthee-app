/**
 * Citizen side of the representative claim (TASK-11 §5.3, REQ-F-053): submit with 1–3 private evidence photos,
 * list own claims, withdraw a pending claim. The OTP phone is compared with the record's public phone and only
 * the boolean `phone_match` is stored — the number is never copied into the claim or shown to reviewers.
 */
import { Prisma } from '@prisma/client';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';

const DAY = 86_400_000;

/** Digits only, Indian numbers reduced to their last 10 digits (so +9179…, 079… and 79… compare equal). */
export function normalisePhone(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const d = raw.replace(/\D/g, '');
  if (d.length < 10) return null;
  return d.slice(-10);
}

/** Start of today in IST, as a UTC instant (term_end is a calendar date in IST). */
export function istToday(at: Date): Date {
  const ist = new Date(at.getTime() + 330 * 60_000);
  return new Date(Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()));
}

export const termEnded = (termEnd: Date | null, at: Date) => termEnd !== null && termEnd.getTime() < istToday(at).getTime();

export interface ClaimInput {
  evidencePhotoIds: string[];
  note?: string;
}

export async function submitClaim(userId: string, representativeId: string, input: ClaimInput) {
  const at = clockNow();
  const [user, rep] = await Promise.all([
    prisma.user.findUnique({ where: { id: userId }, select: { role: true, phoneE164: true, firebaseUid: true } }),
    prisma.representative.findFirst({ where: { id: representativeId, isActive: true }, select: { id: true, termEnd: true, verifiedAt: true, userId: true, publicPhone: true } }),
  ]);
  if (!user || !rep) throw new AppError('NOT_FOUND');
  if (user.role === 'moderator' || user.role === 'admin') throw new AppError('ROLE_CONFLICT');
  if (termEnded(rep.termEnd, at)) throw new AppError('REPRESENTATIVE_TERM_ENDED');
  if (rep.verifiedAt && rep.userId) throw new AppError('REPRESENTATIVE_ALREADY_VERIFIED');
  if (user.role === 'representative') throw new AppError('ROLE_CONFLICT', { message: 'This account is already linked to a representative profile.' });

  const ids = [...new Set(input.evidencePhotoIds)];
  if (ids.length !== input.evidencePhotoIds.length) throw new AppError('PHOTO_UNUSABLE');
  const ok = await prisma.photo.count({
    where: { id: { in: ids }, purpose: 'rep_evidence', uploadedByUserId: userId, attachedAt: null, deletedAt: null, uploadedAt: { gt: new Date(at.getTime() - DAY) } },
  });
  if (ok !== ids.length) throw new AppError('PHOTO_UNUSABLE');

  const phoneMatch = normalisePhone(user.phoneE164) !== null && normalisePhone(user.phoneE164) === normalisePhone(rep.publicPhone);
  try {
    return await prisma.$transaction(async (tx) => {
      const claim = await tx.repClaim.create({
        data: {
          representativeId, userId, evidencePhotoIds: ids, otpVerified: Boolean(user.phoneE164 && user.firebaseUid),
          phoneMatch, claimantNote: input.note?.trim() || null, createdAt: at,
        },
        select: { id: true, status: true },
      });
      // Evidence is "attached" to the claim so the unattached-photo cleanup leaves it; it is never on an issue.
      await tx.photo.updateMany({ where: { id: { in: ids } }, data: { attachedAt: at } });
      return claim;
    });
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') throw new AppError('CLAIM_ALREADY_PENDING');
    throw err;
  }
}

export const AUTO_REJECT_REASON = 'Another claim was approved';
export const AUTO_REJECT_REASON_GU = 'આ પ્રતિનિધિ માટે બીજો દાવો મંજૂર થયો';

/** The stored reject reason in the reader's language: the automatic one is translated, staff text is as written. */
export function localRejectReason(reason: string | null, lang: 'en' | 'gu'): string | null {
  return lang === 'gu' && reason === AUTO_REJECT_REASON ? AUTO_REJECT_REASON_GU : reason;
}

export async function myClaims(userId: string, lang: 'en' | 'gu' = 'en') {
  const rows = await prisma.repClaim.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
    select: {
      id: true, status: true, createdAt: true, decidedAt: true, rejectReason: true,
      representative: { select: { id: true, nameEn: true, nameGu: true, role: true } },
    },
  });
  return {
    items: rows.map((c) => ({
      claimId: c.id, representative: c.representative, status: c.status, createdAt: c.createdAt.toISOString(),
      decidedAt: c.decidedAt?.toISOString() ?? null, rejectReason: localRejectReason(c.rejectReason, lang),
    })),
  };
}

export async function withdrawClaim(userId: string, claimId: string): Promise<void> {
  const claim = await prisma.repClaim.findFirst({ where: { id: claimId, userId }, select: { status: true } });
  if (!claim) throw new AppError('NOT_FOUND');
  const n = await prisma.repClaim.updateMany({ where: { id: claimId, status: 'pending' }, data: { status: 'withdrawn', decidedAt: clockNow() } });
  if (n.count !== 1) throw new AppError('CLAIM_NOT_PENDING');
}
