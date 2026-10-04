import { prisma } from '../../lib/db';
import { firebaseGateway } from '../../lib/firebase';
import { userAudit } from '../../lib/audit';
import { logger } from '../../lib/logger';
import { deletePhotoFiles } from '../photos/cleanup.service';
import { listErasureSteps, listExportSections, type ErasureContext } from './privacy.registry';
import './privacy.sections';

/** GET /me/export: every registered section for this user only, read in one snapshot. */
export async function exportData(userId: string): Promise<Record<string, unknown>> {
  return prisma.$transaction(
    async (tx) => {
      const out: Record<string, unknown> = { exportedAt: new Date().toISOString(), format: 'saarthee-my-data-v1' };
      for (const [name, fn] of listExportSections()) out[name] = await fn(userId, tx);
      return out;
    },
    { timeout: 30_000 },
  );
}

/**
 * DELETE /me erasure (TASK-04 §5.2): one transaction for the database, then storage and Firebase deletions
 * after the commit. Storage/Firebase failures are logged with ids only; `photos:cleanup` retries photos.
 */
export async function deleteAccount(userId: string, requestId?: string): Promise<void> {
  const ctx: ErasureContext = { photoIds: new Set() };
  const firebaseUid = await prisma.$transaction(
    async (tx) => {
      const user = await tx.user.findUniqueOrThrow({ where: { id: userId }, select: { firebaseUid: true } });
      // 1. Photos uploaded by the user: report photos of their issues, their verification photos.
      const reportPhotos = await tx.issuePhoto.findMany({ where: { kind: 'report', issue: { reporterId: userId } }, select: { photoId: true } });
      const verificationPhotos = await tx.issueVerification.findMany({ where: { userId, photoId: { not: null } }, select: { photoId: true } });
      for (const p of [...reportPhotos, ...verificationPhotos]) if (p.photoId) ctx.photoIds.add(p.photoId);
      // 2. Their issues stay public (aggregate kept) without description or report photos.
      await tx.issue.updateMany({ where: { reporterId: userId }, data: { description: null } });
      await tx.issuePhoto.deleteMany({ where: { kind: 'report', issue: { reporterId: userId } } });
      // 3. Me-toos, follows, devices removed (issue counters unchanged); verifications keep answer/distance/time.
      await tx.meToo.deleteMany({ where: { userId } });
      await tx.follow.deleteMany({ where: { userId } });
      await tx.device.deleteMany({ where: { userId } });
      await tx.issueVerification.updateMany({ where: { userId }, data: { photoId: null } });
      // 4. Consents withdrawn (rows kept as evidence of past consent).
      const now = new Date();
      await tx.consent.updateMany({ where: { userId, withdrawnAt: null }, data: { withdrawnAt: now } });
      // 5. Identifiers removed; token_version bump revokes every session.
      await tx.user.update({
        where: { id: userId },
        data: {
          phoneE164: null,
          firebaseUid: null,
          displayName: null,
          homeWardId: null,
          status: 'deleted',
          deletedAt: now,
          tokenVersion: { increment: 1 },
        },
      });
      // 6. Steps registered by later tasks.
      for (const [, step] of listErasureSteps()) await step(userId, tx, ctx);
      return user.firebaseUid;
    },
    { timeout: 60_000 },
  );
  userAudit(requestId, 'user.deleted', userId);

  // 7. After commit: photo files, then the Firebase user.
  const photos = await prisma.photo.findMany({ where: { id: { in: [...ctx.photoIds] }, deletedAt: null }, select: { id: true, storageKey: true, storageDriver: true } });
  await deletePhotoFiles(photos);
  if (firebaseUid) {
    try {
      await firebaseGateway().deleteUser(firebaseUid);
    } catch (err) {
      logger.warn({ requestId, userId, firebaseCode: (err as { code?: string }).code ?? 'unknown' }, 'erasure: firebase delete failed');
    }
  }
}
