import type { Alert, AlertSeverity, Prisma } from '@prisma/client';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { alertInclude, effectiveStatus, type AlertWithRefs } from '../alerts/dto';
import type { StaffIdentity } from '../../middleware/requireStaff';
import { windowIssues, type TargetInput } from './schemas';

type Tx = Prisma.TransactionClient;

export const approvalsNeeded = (severity: AlertSeverity) => (severity === 'warning' || severity === 'critical' ? 2 : 1);

/** Concrete wards for a target: the listed wards, the zone's wards, or all wards (§5.2 alert_wards). */
export async function expandTarget(tx: Tx, target: TargetInput): Promise<{ wardIds: string[]; zoneId: string | null }> {
  if (target.scope === 'wards') {
    const ids = [...new Set(target.wardIds)];
    const found = await tx.ward.count({ where: { id: { in: ids } } });
    if (found !== ids.length) throw new AppError('VALIDATION_FAILED', { details: [{ field: 'target.wardIds', issue: 'Unknown ward.' }] });
    return { wardIds: ids, zoneId: null };
  }
  if (target.scope === 'zone') {
    const wards = await tx.ward.findMany({ where: { zoneId: target.zoneId }, select: { id: true } });
    if (wards.length === 0) throw new AppError('VALIDATION_FAILED', { details: [{ field: 'target.zoneId', issue: 'Unknown zone.' }] });
    return { wardIds: wards.map((w) => w.id), zoneId: target.zoneId };
  }
  const wards = await tx.ward.findMany({ select: { id: true } });
  return { wardIds: wards.map((w) => w.id), zoneId: null };
}

export async function setWards(tx: Tx, alertId: string, wardIds: string[]): Promise<void> {
  await tx.alertWard.deleteMany({ where: { alertId } });
  await tx.alertWard.createMany({ data: wardIds.map((wardId) => ({ alertId, wardId })) });
}

/** Locks the alert row for the rest of the transaction (stops two approvals racing). */
export async function lockAlert(tx: Tx, id: string): Promise<Alert> {
  await tx.$queryRaw`SELECT id FROM alerts WHERE id = ${id}::uuid FOR UPDATE`;
  const a = await tx.alert.findUnique({ where: { id } });
  if (!a) throw new AppError('NOT_FOUND');
  return a;
}

/** Submit/publish completeness (422 ALERT_INCOMPLETE): both languages within the DB lengths, valid window. */
export function assertComplete(a: Alert, at: Date): void {
  const details: { field: string; issue: string }[] = [];
  const len = (field: string, v: string, min: number, max: number) => {
    if (v.trim().length < min || v.length > max) details.push({ field, issue: `Needs ${min}–${max} characters.` });
  };
  len('titleEn', a.titleEn, 5, 80);
  len('titleGu', a.titleGu, 5, 80);
  len('bodyEn', a.bodyEn, 10, 500);
  len('bodyGu', a.bodyGu, 10, 500);
  details.push(...windowIssues(a.validFrom, a.validTo, at, false));
  if (details.length > 0) throw new AppError('ALERT_INCOMPLETE', { details });
}

interface Approver {
  actorId: string;
  name: string | null;
  role: string;
}

/** Display names for the approval panel (v2 users or v1 admin_users). */
async function approvers(ids: string[]): Promise<Map<string, Approver>> {
  if (ids.length === 0) return new Map();
  const [users, admins] = await Promise.all([
    prisma.user.findMany({ where: { id: { in: ids } }, select: { id: true, displayName: true, role: true } }),
    prisma.adminUser.findMany({ where: { id: { in: ids } }, select: { id: true, displayName: true } }),
  ]);
  const out = new Map<string, Approver>();
  for (const u of users) out.set(u.id, { actorId: u.id, name: u.displayName, role: u.role });
  for (const a of admins) out.set(a.id, { actorId: a.id, name: a.displayName, role: 'admin' });
  return out;
}

export async function loadStaffAlert(id: string): Promise<AlertWithRefs> {
  const a = await prisma.alert.findUnique({ where: { id }, include: alertInclude });
  if (!a) throw new AppError('NOT_FOUND');
  return a;
}

/** StaffAlertDto: every column the composer and approval panel need (never logged). */
export async function toStaffDto(a: AlertWithRefs, at: Date, extra: Record<string, unknown> = {}) {
  const who = await approvers(a.approvedBy);
  const wards = a.wards.map((w) => w.ward).sort((x, y) => x.number - y.number);
  return {
    id: a.id,
    type: a.type,
    severity: a.severity,
    titleEn: a.titleEn,
    titleGu: a.titleGu,
    bodyEn: a.bodyEn,
    bodyGu: a.bodyGu,
    sourceName: a.sourceName,
    sourceUrl: a.sourceUrl,
    validFrom: a.validFrom.toISOString(),
    validTo: a.validTo.toISOString(),
    target:
      a.targetScope === 'wards'
        ? { scope: 'wards', wardIds: wards.map((w) => w.id) }
        : a.targetScope === 'zone'
          ? { scope: 'zone', zoneId: a.targetZoneId }
          : { scope: 'city' },
    wards,
    zone: a.targetZone,
    status: a.status,
    effectiveStatus: effectiveStatus(a, at),
    origin: a.origin,
    originRef: a.originRef,
    createdBy: a.createdBy,
    approvedBy: a.approvedBy,
    approvals: a.approvedBy.map((id) => who.get(id) ?? { actorId: id, name: null, role: 'unknown' }),
    approvalsNeeded: approvalsNeeded(a.severity),
    submittedAt: a.submittedAt?.toISOString() ?? null,
    publishedAt: a.publishedAt?.toISOString() ?? null,
    retractedAt: a.retractedAt?.toISOString() ?? null,
    retractionReason: a.retractionReason,
    supersedesId: a.supersedesId,
    supersededById: a.supersededBy?.id ?? null,
    createdAt: a.createdAt.toISOString(),
    updatedAt: a.updatedAt.toISOString(),
    ...extra,
  };
}

export type Staff = StaffIdentity;
