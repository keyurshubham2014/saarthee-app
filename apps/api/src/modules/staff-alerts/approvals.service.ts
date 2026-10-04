import type { Alert } from '@prisma/client';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { logger } from '../../lib/logger';
import { withdrawQueued } from '../../lib/push';
import { fanOutInbox, pushAlert, pushRetraction, type Delivery } from '../alerts/publish';
import { approvalsNeeded, assertComplete, lockAlert, type Staff } from './common';

/**
 * Approval rules (§5.5): Info/Advisory need one approval (the creator may give it); Warning/Critical need
 * two different people and the second must be an admin. The row lock stops two approvals racing.
 */
export async function approveAlert(staff: Staff, id: string): Promise<void> {
  await prisma.$transaction(async (tx) => {
    const a = await lockAlert(tx, id);
    if (a.status !== 'pending_approval') throw new AppError('ALERT_STATE_INVALID');
    const needed = approvalsNeeded(a.severity);
    if (a.approvedBy.includes(staff.actorId)) throw new AppError('ALERT_ALREADY_APPROVED');
    if (a.approvedBy.length >= needed) throw new AppError('ALERT_STATE_INVALID');
    if (needed === 2 && a.approvedBy.length === 1 && staff.role !== 'admin') throw new AppError('ALERT_SECOND_APPROVER_ADMIN');
    await tx.alert.update({ where: { id }, data: { approvedBy: [...a.approvedBy, staff.actorId] } });
  });
}

/**
 * Publish (§5.3 pipeline): one transaction sets `published`, expires a superseded alert and fans out inbox
 * rows; pushes go out after commit through the TASK-04 push service.
 */
export async function publishAlert(staff: Staff, id: string, at: Date): Promise<{ delivery: Delivery }> {
  const { alert, superseded } = await prisma.$transaction(
    async (tx) => {
      const a = await lockAlert(tx, id);
      if (a.status !== 'pending_approval') throw new AppError('ALERT_STATE_INVALID');
      if (a.approvedBy.length < approvalsNeeded(a.severity)) throw new AppError('ALERT_APPROVALS_MISSING');
      if ((a.severity === 'warning' || a.severity === 'critical') && staff.role !== 'admin') throw new AppError('FORBIDDEN');
      assertComplete(a, at);
      let old: Alert | null = null;
      if (a.supersedesId) {
        old = await lockAlert(tx, a.supersedesId);
        if (old.status !== 'published') throw new AppError('ALERT_STATE_INVALID');
        await tx.alert.update({ where: { id: old.id }, data: { status: 'expired', validTo: at > old.validFrom ? at : new Date(old.validFrom.getTime() + 1) } });
      }
      const published = await tx.alert.update({ where: { id }, data: { status: 'published', publishedAt: at } });
      await fanOutInbox(tx, published, at);
      return { alert: published, superseded: old };
    },
    { timeout: 30_000 },
  );
  if (superseded) await withdrawQueued('alert', superseded.id);
  try {
    return { delivery: await pushAlert(alert, at) };
  } catch (err) {
    // The alert is published and in every inbox; a push failure must not undo that.
    logger.error({ alertId: alert.id, reason: err instanceof Error ? err.name : 'unknown' }, 'alert push failed');
    return { delivery: { held: false, topics: [], deviceCount: 0 } };
  }
}

/** Retract a published alert with a reason; withdraws held sends and pushes "Cancelled: …" if already sent. */
export async function retractAlert(staff: Staff, id: string, reason: string, at: Date): Promise<{ cancelPushed: boolean }> {
  const alert = await prisma.$transaction(async (tx) => {
    const a = await lockAlert(tx, id);
    if (a.status !== 'published') throw new AppError('ALERT_STATE_INVALID');
    return tx.alert.update({
      where: { id },
      data: { status: 'retracted', retractedAt: at, retractedBy: staff.actorId, retractionReason: reason },
    });
  });
  return { cancelPushed: await pushRetraction(alert, at, reason) };
}
