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

/** TASK-12 staff content actions (services, initiatives, tips, attendance). */
export type StaffAuditAction =
  | 'service.created'
  | 'service.updated'
  | 'service.deactivated'
  | 'service.link_checked'
  | 'initiative.created'
  | 'initiative.updated'
  | 'initiative.status_changed'
  | 'initiative.attendance_marked'
  | 'tip.created'
  | 'tip.updated'
  | 'tip.deleted';

/**
 * Staff audit line (TASK-12 §5.3): `{actor, role, action, targetType, targetId}` and small non-personal
 * extras only — never request bodies, names or phone numbers. TASK-10 may persist these lines.
 */
export function staffAudit(
  req: Request,
  action: StaffAuditAction,
  targetType: 'service' | 'initiative' | 'tip',
  targetId: string,
  extra?: Record<string, string | number | boolean | null>,
): void {
  logger.info(
    { requestId: req.id, actor: req.user?.id, role: req.user?.role, action, targetType, targetId, ...(extra ?? {}) },
    'staff_action',
  );
}
