import { config } from '../../config';
import { prisma } from '../../lib/db';
import { logger } from '../../lib/logger';
import type { StorageDriver } from '@prisma/client';
import { storageFor } from '../../lib/storage';

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
    select: { id: true, storageKey: true, storageDriver: true },
  });
  for (const p of orphans) {
    try {
      await storageFor(p.storageDriver).delete(p.storageKey);
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

  // TASK-04: retry account-erasure deletions — photos once attached, now linked to nothing, file not deleted.
  const detached = await prisma.photo.findMany({
    where: {
      attachedAt: { not: null },
      deletedAt: null,
      complaint: null,
      verification: null,
      uploadedForComplaint: null,
      issuePhoto: null,
      issueEvents: { none: {} },
      issueVerifications: { none: {} },
    },
    select: { id: true, storageKey: true, storageDriver: true },
  });
  const detachedDeleted = (await deletePhotoFiles(detached)).deleted;
  result.anonymizedFilesDeleted += detachedDeleted;
  result.failures += detached.length - detachedDeleted;
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
    select: { id: true, storageKey: true, storageDriver: true },
  });
}

/** Deletes files then marks rows deleted; failures are logged (error) and retried by the cleanup script. */
export async function deletePhotoFiles(
  photos: { id: string; storageKey: string; storageDriver: StorageDriver }[],
): Promise<{ deleted: number }> {
  let deleted = 0;
  for (const p of photos) {
    try {
      await storageFor(p.storageDriver).delete(p.storageKey);
      await prisma.photo.update({ where: { id: p.id }, data: { deletedAt: new Date() } });
      deleted += 1;
    } catch (err) {
      logger.error({ photoId: p.id, err }, 'photo file deletion failed; cleanup script will retry');
    }
  }
  return { deleted };
}
