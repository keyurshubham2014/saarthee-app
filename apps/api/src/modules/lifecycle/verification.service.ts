/**
 * Neighbour verification (V2 TASK-06 §5.3 rules 1–7, REQ-F-022). Photo at the spot within VERIFY_RADIUS_M,
 * accuracy ≤ VERIFY_MAX_ACCURACY_M, one answer per user per IST day, idempotent by clientSubmissionId.
 * Fixed → verified; reporter's Not fixed, or NOT_FIXED_THRESHOLD distinct others → reopened (reopened wins).
 * Rejected attempts store nothing.
 */
import { Prisma, type IssueVerification } from '@prisma/client';
import type { Response } from 'express';
import { config } from '../../config';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError, type ErrorDetail } from '../../lib/errors';
import { distanceToIssueM } from '../../lib/geo/distance';
import { assertDailyQuota } from '../../lib/quota';
import type { AuthenticatedUser } from '../../middleware/requireUser';
import { deriveIssue, verifyWindowClosesAt } from '../issues/derive';
import { transitionInTx, type TransitionResult } from './lifecycle.service';
import { VERIFIABLE_STATUSES } from './transitions';

const DAY_MS = 86_400_000;

export interface VerifyInput {
  clientSubmissionId: string;
  answer: 'fixed' | 'not_fixed';
  photoId: string;
  latitude: number;
  longitude: number;
  gpsAccuracyM: number;
  deviceCapturedAt: string;
  note?: string | null;
}

/** Asia/Kolkata calendar day (fixed +05:30) as a UTC-midnight Date for the `@db.Date` column. */
export function istDay(at: Date): Date {
  const local = new Date(at.getTime() + 330 * 60_000);
  return new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()));
}

async function respond(v: IssueVerification, created: boolean) {
  const issue = await prisma.issue.findUniqueOrThrow({ where: { id: v.issueId } });
  return { created, body: { verificationId: v.id, distanceM: Math.round(Number(v.distanceM ?? 0)), issue: { status: issue.status, displayStatus: deriveIssue(issue).displayStatus } } };
}

function assertOpen(issue: { status: string; slaDueAt: Date; markedFixedAt: Date | null }, at: Date): void {
  const closes = verifyWindowClosesAt(issue as Parameters<typeof verifyWindowClosesAt>[0]);
  if (!VERIFIABLE_STATUSES.includes(issue.status as never) || !closes || at.getTime() > closes.getTime()) throw new AppError('VERIFY_NOT_OPEN');
}

export async function submitVerification(user: AuthenticatedUser, issueId: string, b: VerifyInput, res?: Response) {
  const prev = await prisma.issueVerification.findUnique({ where: { clientSubmissionId: b.clientSubmissionId } });
  if (prev) {
    if (prev.userId !== user.id || prev.issueId !== issueId) throw new AppError('IDEMPOTENCY_KEY_REUSED');
    return respond(prev, false);
  }
  const at = clockNow();
  const issue = await prisma.issue.findUnique({ where: { id: issueId } });
  if (!issue || (issue.visibility === 'hidden' && issue.reporterId !== user.id)) throw new AppError('NOT_FOUND');
  assertOpen(issue, at);
  await assertDailyQuota(user.id, 'verifications', { res });

  if (b.gpsAccuracyM > config.VERIFY_MAX_ACCURACY_M) throw new AppError('LOCATION_TOO_INACCURATE');
  const photoOk = await prisma.photo.count({
    where: { id: b.photoId, purpose: 'verification', uploadedByUserId: user.id, attachedAt: null, deletedAt: null, uploadedAt: { gt: new Date(Date.now() - DAY_MS) } },
  });
  if (photoOk !== 1) throw new AppError('PHOTO_UNUSABLE');
  const distanceM = (await distanceToIssueM(issueId, b.latitude, b.longitude)) ?? Infinity;
  if (distanceM > config.VERIFY_RADIUS_M) {
    const d = Math.round(distanceM);
    const detail = { field: 'location', issue: `You're about ${d} m away.`, distanceM: d, radiusM: config.VERIFY_RADIUS_M };
    throw new AppError('TOO_FAR_FROM_ISSUE', {
      message: `You need to be within ${config.VERIFY_RADIUS_M} m of the problem to verify. You're about ${d} m away.`,
      details: [detail as ErrorDetail],
    });
  }

  const day = istDay(at);
  let pending: TransitionResult | null = null;
  let row: IssueVerification;
  try {
    row = await prisma.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM issues WHERE id = ${issueId}::uuid FOR UPDATE`;
      const locked = await tx.issue.findUniqueOrThrow({ where: { id: issueId } });
      assertOpen(locked, at);
      const today = await tx.issueVerification.findFirst({ where: { issueId, userId: user.id, createdDay: day } });
      if (today) throw new AppError('ALREADY_ANSWERED_TODAY');
      const v = await tx.issueVerification.create({
        data: {
          issueId, userId: user.id, answer: b.answer, photoId: b.photoId, lat: b.latitude, lng: b.longitude,
          distanceM: Math.round(distanceM * 10) / 10, gpsAccuracyM: b.gpsAccuracyM, createdDay: day, clientSubmissionId: b.clientSubmissionId, createdAt: at,
        },
      });
      const position = await tx.issuePhoto.count({ where: { issueId, kind: 'verification' } });
      await tx.issuePhoto.create({ data: { issueId, photoId: b.photoId, kind: 'verification', position } });
      const attached = await tx.photo.updateMany({ where: { id: b.photoId, attachedAt: null }, data: { attachedAt: at } });
      if (attached.count !== 1) throw new AppError('PHOTO_UNUSABLE');
      await tx.issueEvent.create({
        data: {
          issueId, actorId: user.id, actorRole: 'citizen', type: 'verification', note: b.note?.trim() || null, photoId: b.photoId,
          meta: { answer: b.answer, distanceM: Math.round(distanceM) }, createdAt: at,
        },
      });

      const system = { userId: null, kind: 'system' as const };
      const isReporter = locked.reporterId === user.id;
      let reopen = b.answer === 'not_fixed' && isReporter;
      if (b.answer === 'not_fixed' && !isReporter && locked.markedFixedAt) {
        const others = await tx.issueVerification.findMany({
          where: { issueId, answer: 'not_fixed', createdAt: { gte: locked.markedFixedAt }, ...(locked.reporterId ? { userId: { not: locked.reporterId } } : {}) },
          distinct: ['userId'], select: { userId: true },
        });
        reopen = others.length >= config.NOT_FIXED_THRESHOLD;
      }
      if (reopen) {
        const note = isReporter ? 'Reporter says it is not fixed' : 'Neighbours say it is not fixed';
        pending = await transitionInTx(tx, issueId, 'reopened', system, { note });
      } else if (b.answer === 'fixed' && locked.status === 'marked_fixed' && !(await markedFixedBy(tx, issueId, user.id))) {
        pending = await transitionInTx(tx, issueId, 'verified', system);
      }
      return v;
    });
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
      const again = await prisma.issueVerification.findUnique({ where: { clientSubmissionId: b.clientSubmissionId } });
      if (again && again.userId === user.id) return respond(again, false);
      throw new AppError('ALREADY_ANSWERED_TODAY');
    }
    throw err;
  }
  if (pending) await (pending as TransitionResult).afterCommit();
  return respond(row, true);
}

/** True when this user made the latest marked_fixed change (their own "Fixed" does not verify it). */
async function markedFixedBy(tx: Prisma.TransactionClient, issueId: string, userId: string): Promise<boolean> {
  const e = await tx.issueEvent.findFirst({ where: { issueId, toStatus: 'marked_fixed' }, orderBy: { createdAt: 'desc' }, select: { actorId: true } });
  return e?.actorId === userId;
}
