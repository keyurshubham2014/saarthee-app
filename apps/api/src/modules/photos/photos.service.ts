import type { PhotoPurpose } from '@prisma/client';
import { prisma } from '../../lib/db';
import { cleanJpeg } from '../../lib/images';
import { logger } from '../../lib/logger';
import { storage } from '../../lib/storage';

/**
 * Cleans an uploaded photo (re-encode, strip metadata, resize, hash), stores it through the storage
 * interface and inserts an unattached `photos` row. Verification photos record the complaint they were
 * uploaded for (03 §4.5) so they can only be used for that complaint.
 */
export async function storeUploadedPhoto(
  input: Buffer,
  purpose: PhotoPurpose,
  uploadedForComplaintId: string | null = null,
  owner: { uploadedByUserId?: string; blurApplied?: boolean } = {},
): Promise<{ photoId: string }> {
  const clean = await cleanJpeg(input);
  const key = await storage.save(clean.bytes);
  try {
    const row = await prisma.photo.create({
      data: {
        storageDriver: storage.driver,
        storageKey: key,
        purpose,
        mimeType: 'image/jpeg',
        byteSize: clean.bytes.length,
        widthPx: clean.width,
        heightPx: clean.height,
        sha256: clean.sha256,
        uploadedForComplaintId,
        // V2 TASK-05: citizen uploads are owned and carry the app's on-device blur flag.
        uploadedByUserId: owner.uploadedByUserId ?? null,
        blurApplied: owner.blurApplied ?? false,
      },
      select: { id: true },
    });
    return { photoId: row.id };
  } catch (err) {
    // Do not leave an orphan file behind if the row could not be written.
    await storage.delete(key).catch((e: unknown) => logger.error({ err: e }, 'failed to remove orphan photo file'));
    throw err;
  }
}
