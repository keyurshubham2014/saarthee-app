/**
 * TASK-10 audit v2 (REQ-S-010): one line per staff action with actor, kind, role, action and target — ids and
 * enums only. Lines go to the main logger AND a dedicated audit destination (`AUDIT_LOG_FILE`, pino-roll daily,
 * `AUDIT_RETENTION_DAYS` files kept), separate from the 14-day application logs.
 */
import type { Request } from 'express';
import pino from 'pino';
import { config } from '../../config';
import { logger } from '../logger';

export const STAFF_AUDIT_ACTIONS = [
  'issue_rejected',
  'issue_merged',
  'issue_recategorised',
  'issue_ward_changed',
  'issue_hidden',
  'issue_unhidden',
  'issue_reviewed',
  'issue_status_changed',
  'comment_hidden',
  'flag_resolved',
  'user_suspended',
  'user_unsuspended',
  'role_changed',
  'category_created',
  'category_updated',
  'setting_changed',
  'export_downloaded',
] as const;

export type StaffAuditActionV2 = (typeof STAFF_AUDIT_ACTIONS)[number];

export type AuditTargetType = 'issue' | 'issue_event' | 'flag' | 'user' | 'category' | 'setting' | 'export';

/** Only enums, counts and booleans are allowed in `extra` (never names, phones, notes or free text). */
export type AuditExtra = Record<string, number | boolean | null | `${string}`>;

type Tap = (line: Record<string, unknown>) => void;
const taps = new Set<Tap>();

function destination(): pino.DestinationStream | undefined {
  if (!config.AUDIT_LOG_FILE) return undefined;
  return pino.transport({
    target: 'pino-roll',
    options: { file: config.AUDIT_LOG_FILE, frequency: 'daily', limit: { count: config.AUDIT_RETENTION_DAYS }, mkdir: true },
  });
}

let auditFile: pino.Logger | undefined | null = null;
function fileLogger(): pino.Logger | undefined {
  if (auditFile === null) {
    const dest = destination();
    auditFile = dest ? pino({ base: { service: 'saarthee-audit' }, timestamp: pino.stdTimeFunctions.isoTime }, dest) : undefined;
  }
  return auditFile;
}

/** Writes one audit record to the main logger and the audit destination (also used by v1/TASK-08/12 helpers). */
export function writeAudit(line: Record<string, unknown>): void {
  for (const tap of taps) tap(line);
  logger.info(line, 'staff_action');
  fileLogger()?.info(line, 'staff_action');
}

/** Staff action audit (TASK-10 §5.3). Call after a successful mutation, exactly once. */
export function auditStaff(
  req: Request,
  action: StaffAuditActionV2,
  target: { targetType: AuditTargetType; targetId: string; extra?: AuditExtra },
): void {
  const staff = req.staff;
  writeAudit({
    ts: new Date().toISOString(),
    requestId: req.id,
    actorId: staff?.actorId ?? req.user?.id,
    actorKind: staff?.actorKind ?? 'user',
    role: staff?.role ?? req.user?.role,
    action,
    targetType: target.targetType,
    targetId: target.targetId,
    ...(target.extra ? { extra: target.extra } : {}),
  });
}

/** Tests only: records every audit record (as objects) until `stop()`. */
export function captureAudit(): { lines: Record<string, unknown>[]; stop: () => void } {
  const lines: Record<string, unknown>[] = [];
  const tap: Tap = (l) => lines.push(l);
  taps.add(tap);
  return { lines, stop: () => taps.delete(tap) };
}
