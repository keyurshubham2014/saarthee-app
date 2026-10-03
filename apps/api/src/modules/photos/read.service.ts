import type { Readable } from 'node:stream';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { storage } from '../../lib/storage';

/** Opens a stored photo by row id: 404 if missing, 410 PHOTO_DELETED if removed by anonymization. */
export async function openPhoto(photoId: string): Promise<Readable> {
  const photo = await prisma.photo.findUnique({ where: { id: photoId }, select: { storageKey: true, deletedAt: true } });
  if (!photo) throw new AppError('NOT_FOUND');
  if (photo.deletedAt) throw new AppError('PHOTO_DELETED');
  try {
    return await storage.open(photo.storageKey);
  } catch (err) {
    logger.error({ photoId, err }, 'photo file missing from storage');
    throw new AppError('NOT_FOUND');
  }
}

/** Report photo of a complaint. */
export async function openComplaintPhoto(complaintId: string): Promise<Readable> {
  const c = await prisma.complaint.findUnique({ where: { id: complaintId }, select: { photoId: true } });
  if (!c) throw new AppError('NOT_FOUND');
  return openPhoto(c.photoId);
}

/** Photo of a verification. */
export async function openVerificationPhoto(verificationId: string): Promise<Readable> {
  const v = await prisma.verification.findUnique({ where: { id: verificationId }, select: { photoId: true } });
  if (!v) throw new AppError('NOT_FOUND');
  return openPhoto(v.photoId);
}
