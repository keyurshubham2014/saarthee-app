import { Prisma, type Platform } from '@prisma/client';
import { config } from '../../config';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { recordServerEvent } from '../../lib/events';
import { logger } from '../../lib/logger';
import { MSG, normalizeCcrs } from '../../lib/validation';

export interface ReportInput {
  clientSubmissionId: string;
  inviteCode?: string;
  categoryId: string;
  ccrsNumber: string;
  photoId: string;
  latitude: number;
  longitude: number;
  gpsAccuracyM?: number;
  deviceCapturedAt: Date;
  phoneE164: string;
  consentGivenAt: Date;
  consentTextVersion: string;
  platform: Platform;
  appVersion: string;
}

export interface ReportResult {
  created: boolean;
  complaintId: string;
  createdAt: Date;
}

interface Ctx {
  requestId: string;
  installId: string | null;
}

async function findBySubmission(clientSubmissionId: string) {
  return prisma.complaint.findUnique({
    where: { clientSubmissionId },
    select: { id: true, createdAt: true },
  });
}

/** Unknown, inactive or malformed codes resolve to `unknown` — a report is never lost over a code (03 §4.1). */
async function resolveInvite(code: string | undefined, ctx: Ctx) {
  if (code === undefined) return { inviteCodeId: null, sourceTag: 'unknown' as const };
  const normalized = code.trim().toUpperCase();
  const invite = /^[A-Z0-9]{6,20}$/.test(normalized)
    ? await prisma.inviteCode.findUnique({ where: { code: normalized }, select: { id: true, sourceTag: true, isActive: true } })
    : null;
  if (!invite || !invite.isActive) {
    // The code value itself is never logged.
    logger.warn({ requestId: ctx.requestId }, 'unknown or inactive invite code at submission; stored as unknown');
    return { inviteCodeId: null, sourceTag: 'unknown' as const };
  }
  return { inviteCodeId: invite.id, sourceTag: invite.sourceTag };
}

/** Submit-a-report workflow (03 §4.1). Idempotent on clientSubmissionId. */
export async function submitReport(input: ReportInput, ctx: Ctx): Promise<ReportResult> {
  const existing = await findBySubmission(input.clientSubmissionId);
  if (existing) return { created: false, complaintId: existing.id, createdAt: existing.createdAt };
  try {
    return await createReport(input, ctx);
  } catch (err) {
    // Concurrent resend of the same submission: a loser fails on the photo check or the unique constraint,
    // then re-reads and returns the stored complaint with 200 (03 §4.1).
    const winner = await findBySubmission(input.clientSubmissionId);
    if (winner) return { created: false, complaintId: winner.id, createdAt: winner.createdAt };
    throw err;
  }
}

async function createReport(input: ReportInput, ctx: Ctx): Promise<ReportResult> {
  const { inviteCodeId, sourceTag } = await resolveInvite(input.inviteCode, ctx);

  const category = await prisma.ccrsCategory.findUnique({ where: { id: input.categoryId }, select: { isActive: true } });
  if (!category || !category.isActive) throw new AppError('CATEGORY_INACTIVE');

  const cutoff = new Date(Date.now() - config.UNATTACHED_PHOTO_TTL_HOURS * 3_600_000);
  const photo = await prisma.photo.findUnique({
    where: { id: input.photoId },
    select: { purpose: true, attachedAt: true, deletedAt: true, uploadedAt: true },
  });
  if (!photo || photo.purpose !== 'report' || photo.attachedAt || photo.deletedAt) throw new AppError('PHOTO_UNUSABLE');
  if (photo.uploadedAt < cutoff) throw new AppError('PHOTO_UNUSABLE', { message: MSG.photoExpired });

  const ccrsNumberRaw = input.ccrsNumber.trim();
  const ccrsNumberNormalized = normalizeCcrs(ccrsNumberRaw);

  const complaint = await prisma.$transaction(async (tx) => {
    // Conditional attach: only one complaint can ever claim the photo, even under concurrency.
    const attached = await tx.photo.updateMany({
      where: { id: input.photoId, purpose: 'report', attachedAt: null, deletedAt: null, uploadedAt: { gte: cutoff } },
      data: { attachedAt: new Date() },
    });
    if (attached.count !== 1) throw new AppError('PHOTO_UNUSABLE');
    const duplicate = await tx.complaint.findFirst({ where: { ccrsNumberNormalized }, select: { id: true } });
    return tx.complaint.create({
      data: {
        clientSubmissionId: input.clientSubmissionId,
        inviteCodeId,
        sourceTag,
        categoryId: input.categoryId,
        ccrsNumberRaw,
        ccrsNumberNormalized,
        ccrsDuplicateFlag: duplicate !== null,
        photoId: input.photoId,
        latitude: new Prisma.Decimal(input.latitude),
        longitude: new Prisma.Decimal(input.longitude),
        gpsAccuracyM: input.gpsAccuracyM === undefined ? null : new Prisma.Decimal(input.gpsAccuracyM.toFixed(2)),
        deviceCapturedAt: input.deviceCapturedAt,
        phoneE164: input.phoneE164,
        consentGivenAt: input.consentGivenAt,
        consentTextVersion: input.consentTextVersion,
        appPlatform: input.platform,
        appVersion: input.appVersion,
      },
      select: { id: true, createdAt: true },
    });
  });

  await recordServerEvent({
    name: 'report_submitted',
    complaintId: complaint.id,
    sourceTag,
    installId: ctx.installId,
    platform: input.platform,
    appVersion: input.appVersion,
  });
  return { created: true, complaintId: complaint.id, createdAt: complaint.createdAt };
}
