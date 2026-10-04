import type { Request } from 'express';
import { logger } from '../logger';
import { writeAudit } from './staff';

export { auditStaff, captureAudit, STAFF_AUDIT_ACTIONS, type StaffAuditActionV2 } from './staff';

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
  // TASK-08 staff alert actions (actor, role, alert id only — never titles or bodies).
  'alert_created',
  'alert_updated',
  'alert_submitted',
  'alert_approved',
  'alert_published',
  'alert_retracted',
  'alert_superseded',
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

/** Staff action audit line (TASK-08/10 staff identity contract): actor id, kind, role, action, target id only. */
export function staffAudit(
  req: Request,
  action: AuditAction,
  targetId: string,
  extra?: Record<string, string | number | boolean | null>,
): void {
  const staff = req.staff;
  // TASK-10: routed through the audit destination too.
  writeAudit({ requestId: req.id, actorId: staff?.actorId, actorKind: staff?.actorKind, role: staff?.role, action, targetId, ...(extra ?? {}) });
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
export function staffContentAudit(
  req: Request,
  action: StaffAuditAction,
  targetType: 'service' | 'initiative' | 'tip',
  targetId: string,
  extra?: Record<string, string | number | boolean | null>,
): void {
  // TASK-10: routed through the audit destination too (actorId/actorKind added for the v2 line shape).
  // TASK-14 sweep: the actor comes from the staff guard (v2 user or v1 admin login).
  const actorId = req.staff?.actorId ?? req.user?.id;
  writeAudit({ requestId: req.id, actor: actorId, actorId, actorKind: req.staff?.actorKind ?? 'user', role: req.staff?.role ?? req.user?.role, action, targetType, targetId, ...(extra ?? {}) });
}
