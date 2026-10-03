import { config } from '../../config';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { recordServerEvent } from '../../lib/events';
import { newVerifyToken } from '../../lib/tokens';

/** Server-side reminder templates (English, v1 — TASK-06 §5.3). Selected by REMINDER_TEMPLATE_VERSION. */
export const REMINDER_TEMPLATES: Record<string, (v: { ccrsNumber: string; verifyLink: string }) => string> = {
  v1: ({ ccrsNumber, verifyLink }) =>
    `Hello! About a week ago you recorded AMC complaint ${ccrsNumber} in our app. Has it been fixed? ` +
    `Tap to answer (less than a minute): ${verifyLink}. If the link doesn't open, open the app and tap ` +
    `'Answer a follow-up'. — Saarthee, an independent citizen project (not AMC).`,
};

export interface ReminderResult {
  reminderId: string;
  sentAt: string;
  verifyLink: string;
  messageText: string;
  phoneE164: string | null;
}

/**
 * Send-a-reminder workflow (03 §4.4). The raw token exists only in the returned value; only its SHA-256
 * is stored. Callers must never log the result.
 */
export async function createReminder(adminId: string, complaintId: string): Promise<ReminderResult> {
  const complaint = await prisma.complaint.findUnique({
    where: { id: complaintId },
    select: { id: true, isExcluded: true, anonymizedAt: true, ccrsNumberRaw: true, phoneE164: true, sourceTag: true },
  });
  if (!complaint) throw new AppError('NOT_FOUND');
  if (complaint.anonymizedAt) throw new AppError('COMPLAINT_ANONYMIZED');
  if (complaint.isExcluded) throw new AppError('COMPLAINT_EXCLUDED');

  const token = newVerifyToken();
  const reminder = await prisma.reminder.create({
    data: { complaintId, tokenHash: token.hash, channel: 'whatsapp_manual', sentBy: adminId, expiresAt: null },
    select: { id: true, sentAt: true },
  });
  const verifyLink = `${config.VERIFY_LINK_BASE}${token.raw}`;
  const template = REMINDER_TEMPLATES[config.REMINDER_TEMPLATE_VERSION];
  if (!template) throw new AppError('INTERNAL_ERROR');
  await recordServerEvent({ name: 'reminder_sent', complaintId, adminUserId: adminId, sourceTag: complaint.sourceTag });
  return {
    reminderId: reminder.id,
    sentAt: reminder.sentAt.toISOString(),
    verifyLink,
    messageText: template({ ccrsNumber: complaint.ccrsNumberRaw, verifyLink }),
    phoneE164: complaint.phoneE164,
  };
}

/** Revokes a reminder's token (idempotent: an already revoked reminder keeps its first revokedAt). */
export async function revokeReminder(reminderId: string): Promise<{ revokedAt: string }> {
  const r = await prisma.reminder.findUnique({ where: { id: reminderId }, select: { revokedAt: true } });
  if (!r) throw new AppError('NOT_FOUND');
  if (r.revokedAt) return { revokedAt: r.revokedAt.toISOString() };
  const updated = await prisma.reminder.update({ where: { id: reminderId }, data: { revokedAt: new Date() }, select: { revokedAt: true } });
  return { revokedAt: updated.revokedAt!.toISOString() };
}
