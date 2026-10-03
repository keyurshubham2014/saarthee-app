import type { Readable } from 'node:stream';
import { Prisma, type Platform } from '@prisma/client';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { recordServerEvent } from '../../lib/events';
import type { VerifyContext } from '../../lib/verifyToken';
import { openPhoto } from '../photos/read.service';

/** Verify-screen summary (03 §2.3). Never phone, coordinates, invite code or source tag. */
export async function getVerifySummary(ctx: VerifyContext, installId: string | null) {
  const c = await prisma.complaint.findUnique({
    where: { id: ctx.complaintId },
    select: {
      id: true,
      ccrsNumberRaw: true,
      createdAt: true,
      category: { select: { name: true } },
      photo: { select: { deletedAt: true } },
      _count: { select: { verifications: true } },
    },
  });
  if (!c) throw new AppError('NOT_FOUND');
  await recordServerEvent({ name: 'verify_opened', complaintId: c.id, installId });
  return {
    complaintId: c.id,
    categoryName: c.category.name,
    ccrsNumber: c.ccrsNumberRaw,
    reportedAt: c.createdAt.toISOString(),
    hasPhoto: c.photo.deletedAt === null,
    previousVerificationCount: c._count.verifications,
  };
}

/** The token's complaint report photo; a deleted photo is 404 here (TASK-07 §5.6). */
export async function openVerifyReportPhoto(ctx: VerifyContext): Promise<Readable> {
  const c = await prisma.complaint.findUnique({ where: { id: ctx.complaintId }, select: { photoId: true } });
  if (!c) throw new AppError('NOT_FOUND');
  try {
    return await openPhoto(c.photoId);
  } catch (err) {
    if (err instanceof AppError && err.code === 'PHOTO_DELETED') throw new AppError('NOT_FOUND');
    throw err;
  }
}

export interface VerificationInput {
  clientSubmissionId: string;
  result: 'fixed' | 'not_fixed';
  photoId: string;
  latitude: number;
  longitude: number;
  gpsAccuracyM?: number;
  deviceCapturedAt: Date;
  note?: string;
  platform: Platform;
  appVersion: string;
}

/** Great-circle distance in metres (haversine, mean Earth radius). */
export function haversineM(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6_371_008.8;
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(a)));
}

async function findBySubmission(clientSubmissionId: string) {
  return prisma.verification.findUnique({
    where: { clientSubmissionId },
    select: { id: true, createdAt: true, complaintId: true },
  });
}

function existingResult(v: { id: string; createdAt: Date; complaintId: string }, ctx: VerifyContext) {
  // An ID already used for a different complaint is never returned through another complaint's token.
  if (v.complaintId !== ctx.complaintId) {
    throw new AppError('VALIDATION_FAILED', {
      status: 409,
      details: [{ field: 'clientSubmissionId', issue: 'Already used for another answer.' }],
    });
  }
  return { created: false, verificationId: v.id, createdAt: v.createdAt };
}

/** Verify submission (03 §4.5). Idempotent on clientSubmissionId; repeat answers are new rows. */
export async function submitVerification(input: VerificationInput, ctx: VerifyContext, installId: string | null) {
  const existing = await findBySubmission(input.clientSubmissionId);
  if (existing) return existingResult(existing, ctx);
  try {
    return await createVerification(input, ctx, installId);
  } catch (err) {
    const winner = await findBySubmission(input.clientSubmissionId);
    if (winner) return existingResult(winner, ctx);
    throw err;
  }
}

async function createVerification(input: VerificationInput, ctx: VerifyContext, installId: string | null) {
  const photo = await prisma.photo.findUnique({
    where: { id: input.photoId },
    select: { purpose: true, uploadedForComplaintId: true, attachedAt: true, deletedAt: true },
  });
  if (!photo || photo.purpose !== 'verification' || photo.uploadedForComplaintId !== ctx.complaintId || photo.attachedAt || photo.deletedAt) {
    throw new AppError('PHOTO_UNUSABLE');
  }
  const complaint = await prisma.complaint.findUnique({
    where: { id: ctx.complaintId },
    select: { latitude: true, longitude: true, sourceTag: true },
  });
  if (!complaint) throw new AppError('NOT_FOUND');
  const distance = haversineM(complaint.latitude.toNumber(), complaint.longitude.toNumber(), input.latitude, input.longitude);
  const note = input.note?.trim() ? input.note.trim() : null;

  const v = await prisma.$transaction(async (tx) => {
    const attached = await tx.photo.updateMany({
      where: { id: input.photoId, purpose: 'verification', uploadedForComplaintId: ctx.complaintId, attachedAt: null, deletedAt: null },
      data: { attachedAt: new Date() },
    });
    if (attached.count !== 1) throw new AppError('PHOTO_UNUSABLE');
    return tx.verification.create({
      data: {
        clientSubmissionId: input.clientSubmissionId,
        complaintId: ctx.complaintId,
        reminderId: ctx.reminderId,
        result: input.result,
        photoId: input.photoId,
        latitude: new Prisma.Decimal(input.latitude),
        longitude: new Prisma.Decimal(input.longitude),
        gpsAccuracyM: input.gpsAccuracyM === undefined ? null : new Prisma.Decimal(input.gpsAccuracyM.toFixed(2)),
        deviceCapturedAt: input.deviceCapturedAt,
        distanceFromReportM: new Prisma.Decimal(distance.toFixed(2)),
        note,
        appPlatform: input.platform,
        appVersion: input.appVersion,
      },
      select: { id: true, createdAt: true },
    });
  });
  await recordServerEvent({
    name: 'verify_submitted',
    complaintId: ctx.complaintId,
    sourceTag: complaint.sourceTag,
    installId,
    platform: input.platform,
    appVersion: input.appVersion,
    properties: { result: input.result },
  });
  return { created: true, verificationId: v.id, createdAt: v.createdAt };
}
