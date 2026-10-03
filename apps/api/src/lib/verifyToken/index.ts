import { prisma } from '../db';
import { AppError } from '../errors';
import { logger } from '../logger';
import { hashVerifyToken } from '../tokens';

export interface VerifyContext {
  reminderId: string;
  complaintId: string;
}

declare module 'express-serve-static-core' {
  interface Request {
    verify?: VerifyContext;
  }
}

/**
 * Resolves a raw verify token (03 §3.1): SHA-256 → reminders.token_hash. Missing/unknown → 401
 * VERIFY_TOKEN_INVALID (identical body); revoked, expired or anonymized complaint → 410 VERIFY_TOKEN_REVOKED.
 */
export async function resolveVerifyToken(raw: string | undefined, requestId: string): Promise<VerifyContext> {
  const token = raw?.trim();
  if (!token || token.length > 200) throw new AppError('VERIFY_TOKEN_INVALID');
  const reminder = await prisma.reminder.findUnique({
    where: { tokenHash: hashVerifyToken(token) },
    select: { id: true, complaintId: true, revokedAt: true, expiresAt: true, complaint: { select: { anonymizedAt: true } } },
  });
  if (!reminder) throw new AppError('VERIFY_TOKEN_INVALID');
  if (reminder.revokedAt || (reminder.expiresAt && reminder.expiresAt <= new Date()) || reminder.complaint.anonymizedAt) {
    logger.warn({ requestId, reminderId: reminder.id }, 'revoked token presented');
    throw new AppError('VERIFY_TOKEN_REVOKED');
  }
  return { reminderId: reminder.id, complaintId: reminder.complaintId };
}
