import type { ExclusionReason } from '@prisma/client';
import { config } from '../../config';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { recordServerEvent } from '../../lib/events';
import { deletePhotoFiles, findAnonymizedPhotosPendingDeletion } from '../photos/cleanup.service';
import { getComplaintSummary, type ComplaintSummary } from './complaints.service';

const iso = (d: Date | null | undefined) => (d ? d.toISOString() : null);
const num = (d: { toNumber(): number } | null | undefined) => (d ? d.toNumber() : null);

/** Full complaint detail (TASK-08 §5.3). Phone only here; never token or token hash. */
export async function getComplaintDetail(id: string) {
  const summary = await getComplaintSummary(id);
  if (!summary) throw new AppError('NOT_FOUND');
  const c = await prisma.complaint.findUnique({
    where: { id },
    select: {
      categoryId: true,
      inviteCodeId: true,
      ccrsNumberNormalized: true,
      latitude: true,
      longitude: true,
      gpsAccuracyM: true,
      deviceCapturedAt: true,
      consentGivenAt: true,
      consentTextVersion: true,
      appPlatform: true,
      appVersion: true,
      exclusionNote: true,
      excludedAt: true,
      anonymizedAt: true,
      phoneE164: true,
      excluder: { select: { displayName: true } },
      photo: { select: { sha256: true, deletedAt: true } },
      reminders: {
        orderBy: [{ sentAt: 'desc' }, { id: 'desc' }],
        select: { id: true, sentAt: true, channel: true, revokedAt: true, sender: { select: { displayName: true } } },
      },
      verifications: {
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        select: {
          id: true,
          reminderId: true,
          result: true,
          createdAt: true,
          deviceCapturedAt: true,
          latitude: true,
          longitude: true,
          gpsAccuracyM: true,
          distanceFromReportM: true,
          note: true,
          appPlatform: true,
          appVersion: true,
          photo: { select: { sha256: true, deletedAt: true } },
        },
      },
    },
  });
  if (!c) throw new AppError('NOT_FOUND');
  const warnM = config.VERIFY_DISTANCE_WARN_M;
  return {
    ...summary,
    categoryId: c.categoryId,
    inviteCodeId: c.inviteCodeId,
    ccrsNumberNormalized: c.ccrsNumberNormalized,
    latitude: c.latitude.toNumber(),
    longitude: c.longitude.toNumber(),
    gpsAccuracyM: num(c.gpsAccuracyM),
    deviceCapturedAt: c.deviceCapturedAt.toISOString(),
    consentGivenAt: c.consentGivenAt.toISOString(),
    consentTextVersion: c.consentTextVersion,
    appPlatform: c.appPlatform,
    appVersion: c.appVersion,
    exclusionNote: c.exclusionNote,
    excludedBy: c.excluder?.displayName ?? null,
    excludedAt: iso(c.excludedAt),
    anonymizedAt: iso(c.anonymizedAt),
    phoneE164: c.phoneE164,
    hasPhoto: c.photo.deletedAt === null,
    reminders: c.reminders.map((r) => ({
      id: r.id,
      sentAt: r.sentAt.toISOString(),
      sentBy: r.sender.displayName,
      channel: r.channel,
      revokedAt: iso(r.revokedAt),
    })),
    verifications: c.verifications.map((v) => {
      const distance = num(v.distanceFromReportM);
      return {
        id: v.id,
        reminderId: v.reminderId,
        result: v.result,
        createdAt: v.createdAt.toISOString(),
        deviceCapturedAt: v.deviceCapturedAt.toISOString(),
        latitude: v.latitude.toNumber(),
        longitude: v.longitude.toNumber(),
        gpsAccuracyM: num(v.gpsAccuracyM),
        distanceFromReportM: distance,
        distanceWarning: warnM !== undefined && distance !== null && distance > warnM,
        sameImageAsReport: v.photo.sha256 === c.photo.sha256,
        note: v.note,
        hasPhoto: v.photo.deletedAt === null,
        appPlatform: v.appPlatform,
        appVersion: v.appVersion,
      };
    }),
  };
}

export interface ExclusionInput {
  isExcluded: boolean;
  reason?: ExclusionReason;
  note?: string;
}

/** Exclude or re-include (03 §4.6); re-including clears every exclusion field. Records record_flagged. */
export async function setExclusion(id: string, input: ExclusionInput, adminId: string): Promise<ComplaintSummary> {
  const c = await prisma.complaint.findUnique({ where: { id }, select: { sourceTag: true } });
  if (!c) throw new AppError('NOT_FOUND');
  const note = input.note?.trim() ? input.note.trim() : null;
  await prisma.complaint.update({
    where: { id },
    data: input.isExcluded
      ? { isExcluded: true, exclusionReason: input.reason!, exclusionNote: note, excludedBy: adminId, excludedAt: new Date() }
      : { isExcluded: false, exclusionReason: null, exclusionNote: null, excludedBy: null, excludedAt: null },
  });
  await recordServerEvent({
    name: 'record_flagged',
    complaintId: id,
    adminUserId: adminId,
    sourceTag: c.sourceTag,
    properties: { isExcluded: input.isExcluded, reason: input.isExcluded ? input.reason! : null },
  });
  const summary = await getComplaintSummary(id);
  if (!summary) throw new AppError('NOT_FOUND');
  return summary;
}

/**
 * Anonymize (03 §4.6): one transaction nulls the phone, sets anonymized_at and revokes all reminders;
 * then report + verification photo files are deleted and marked deleted_at. Re-running is safe and retries
 * any file deletion that failed before.
 */
export async function anonymizeComplaint(id: string): Promise<{ anonymizedAt: string }> {
  const existing = await prisma.complaint.findUnique({ where: { id }, select: { anonymizedAt: true } });
  if (!existing) throw new AppError('NOT_FOUND');
  let anonymizedAt = existing.anonymizedAt;
  if (!anonymizedAt) {
    const now = new Date();
    await prisma.$transaction([
      prisma.complaint.update({ where: { id }, data: { phoneE164: null, anonymizedAt: now } }),
      prisma.reminder.updateMany({ where: { complaintId: id, revokedAt: null }, data: { revokedAt: now } }),
    ]);
    anonymizedAt = now;
  }
  await deletePhotoFiles(await findAnonymizedPhotosPendingDeletion(id));
  return { anonymizedAt: anonymizedAt.toISOString() };
}
