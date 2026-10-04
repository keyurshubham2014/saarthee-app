import { config } from '../../config';
import { prisma } from '../../lib/db';
import { logger } from '../../lib/logger';
import { storage } from '../../lib/storage';

export interface CleanupResult {
  orphansDeleted: number;
  anonymizedFilesDeleted: number;
  failures: number;
}

/**
 * Maintenance (03 §5.3), safe to re-run:
 * 1. Orphans: photos never attached and older than UNATTACHED_PHOTO_TTL_HOURS → delete file, then row.
 * 2. Retry anonymization file deletions: photos of anonymized complaints still without deleted_at →
 *    delete file, then set deleted_at.
 */
export async function cleanupPhotos(): Promise<CleanupResult> {
  const result: CleanupResult = { orphansDeleted: 0, anonymizedFilesDeleted: 0, failures: 0 };
  const cutoff = new Date(Date.now() - config.UNATTACHED_PHOTO_TTL_HOURS * 3_600_000);

  const orphans = await prisma.photo.findMany({
    where: {
      attachedAt: null,
      deletedAt: null,
      uploadedAt: { lt: cutoff },
      complaint: null,
      verification: null,
      issuePhoto: null,
    },
    select: { id: true, storageKey: true },
  });
  for (const p of orphans) {
    try {
      await storage.delete(p.storageKey);
      await prisma.photo.delete({ where: { id: p.id } });
      result.orphansDeleted += 1;
    } catch (err) {
      result.failures += 1;
      logger.error({ photoId: p.id, err }, 'orphan photo cleanup failed');
    }
  }

  const pending = await findAnonymizedPhotosPendingDeletion();
  result.anonymizedFilesDeleted = (await deletePhotoFiles(pending)).deleted;
  result.failures += pending.length - result.anonymizedFilesDeleted;
  return result;
}

/** Photos (report + verification) of anonymized complaints whose files are not yet deleted. */
export async function findAnonymizedPhotosPendingDeletion(complaintId?: string) {
  const anonymized = { anonymizedAt: { not: null }, ...(complaintId ? { id: complaintId } : {}) };
  return prisma.photo.findMany({
    where: {
      deletedAt: null,
      OR: [{ complaint: anonymized }, { verification: { complaint: anonymized } }, { uploadedForComplaint: anonymized }],
    },
    select: { id: true, storageKey: true },
  });
}

/** Deletes files then marks rows deleted; failures are logged (error) and retried by the cleanup script. */
export async function deletePhotoFiles(photos: { id: string; storageKey: string }[]): Promise<{ deleted: number }> {
  let deleted = 0;
  for (const p of photos) {
    try {
      await storage.delete(p.storageKey);
      await prisma.photo.update({ where: { id: p.id }, data: { deletedAt: new Date() } });
      deleted += 1;
    } catch (err) {
      logger.error({ photoId: p.id, err }, 'photo file deletion failed; cleanup script will retry');
    }
  }
  return { deleted };
}
