import type { Request } from 'express';
import { logger } from '../logger';

export const AUDIT_ACTIONS = [
  'logout_all',
  'password_reset',
  'reminder_created',
  'reminder_revoked',
  'exclusion_changed',
  'anonymized',
  'export',
  'invite_code_created',
  'invite_code_updated',
  'category_created',
  'category_updated',
  // v2 (append below)
  'retention_run',
  // TASK-04 citizen actions (actor = the user; id only, no PII).
  'user.signed_in',
  'user.deleted',
  // TASK-09 staff roster actions (actor = staff user id; counts only for imports).
  'rep_created',
  'rep_updated',
  'rep_deactivated',
  'rep_roster_imported',
  'ward_constituencies_updated',
  'election_mode_set',
] as const;

export type AuditAction = (typeof AUDIT_ACTIONS)[number];

/**
 * Admin action audit line (03 §9.2): admin ID, action, target ID and small non-personal extras only.
 * Never pass phone numbers, emails, tokens or body content.
 */
export function auditLog(
  req: Request | null,
  action: AuditAction,
  targetId?: string | null,
  extra?: Record<string, string | number | boolean | null>,
): void {
  logger.info(
    { requestId: req?.id, adminId: req?.admin?.id, action, targetId: targetId ?? undefined, ...(extra ?? {}) },
    'admin_action',
  );
}

/** Citizen self-action audit line (TASK-04): action + user id only — never phone, name or tokens. */
export function userAudit(requestId: string | undefined, action: 'user.signed_in' | 'user.deleted', userId: string): void {
  logger.info({ requestId, actorId: userId, action, targetId: userId }, 'user_action');
}
