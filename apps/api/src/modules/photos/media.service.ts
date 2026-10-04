/**
 * GET /media/photos/{id} (V2 TASK-05 §5.3): issue photos for the public. A photo is readable by anyone when
 * it is attached to a `public` issue; the uploader / reporter and staff (moderator, admin) also see hidden
 * or unattached ones. Everything else answers 404 (no existence leak). Resized copies (320/1024 px wide)
 * are cached in memory; the stored original already has no metadata (v1 cleanJpeg pipeline).
 */
import { buffer } from 'node:stream/consumers';
import type { Response } from 'express';
import sharp from 'sharp';
import type { AuthenticatedUser } from '../../middleware/requireUser';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { openPhoto } from './read.service';

const CACHE_MAX = 200;
const cache = new Map<string, Buffer>();

function remember(key: string, bytes: Buffer) {
  if (cache.size >= CACHE_MAX) cache.delete(cache.keys().next().value as string);
  cache.set(key, bytes);
}

/** Tests only. */
export const clearMediaCache = () => cache.clear();

async function canRead(photoId: string, user: AuthenticatedUser | undefined): Promise<boolean> {
  const photo = await prisma.photo.findUnique({
    where: { id: photoId },
    select: { uploadedByUserId: true, deletedAt: true, purpose: true, issuePhoto: { select: { issue: { select: { visibility: true, reporterId: true } } } } },
  });
  if (!photo || photo.deletedAt) return false;
  // TASK-11: claim evidence is private — only its uploader here; admins use /staff/rep-claims/{id}/evidence.
  if (photo.purpose === 'rep_evidence') return !!user && photo.uploadedByUserId === user.id;
  const issue = photo.issuePhoto?.issue;
  if (issue?.visibility === 'public') return true;
  if (!user) return false;
  if (user.role === 'moderator' || user.role === 'admin') return true;
  return photo.uploadedByUserId === user.id || (issue?.reporterId ?? null) === user.id;
}

export async function sendPublicPhoto(res: Response, photoId: string, width: number | null, user?: AuthenticatedUser): Promise<void> {
  if (!(await canRead(photoId, user))) throw new AppError('NOT_FOUND');
  const key = `${photoId}:${width ?? 'orig'}`;
  let bytes = cache.get(key);
  if (!bytes) {
    const original = await buffer(await openPhoto(photoId));
    bytes = width
      ? await sharp(original).resize({ width, withoutEnlargement: true }).jpeg({ quality: 80 }).toBuffer()
      : original;
    remember(key, bytes);
  }
  res.setHeader('Content-Type', 'image/jpeg');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  // Visibility can change (moderation), so shared caches must revalidate; the app keeps its own cache.
  res.setHeader('Cache-Control', 'private, max-age=300');
  res.status(200).end(bytes);
}
