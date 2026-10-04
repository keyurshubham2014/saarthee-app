import type { AlertStatus, Prisma } from '@prisma/client';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { decodeCursor, encodeCursor } from '../../lib/pagination';
import { alertInclude } from '../alerts/dto';
import { assertComplete, expandTarget, lockAlert, setWards, toStaffDto, type Staff } from './common';
import { windowIssues, type ComposerInput, type PatchInput } from './schemas';

/** GET /staff/alerts: newest change first; counts for the tab badges. */
export async function listStaffAlerts(q: { status?: AlertStatus | 'ended'; origin?: 'manual' | 'sachet' | 'imd'; cursor?: string; limit: number }, at: Date) {
  const c = q.cursor ? decodeCursor(q.cursor) : undefined;
  const where: Prisma.AlertWhereInput = {
    ...(q.status === 'ended' ? { status: { in: ['expired', 'retracted'] } } : q.status ? { status: q.status } : {}),
    ...(q.origin ? { origin: q.origin } : {}),
    ...(c ? { OR: [{ updatedAt: { lt: new Date(c.k) } }, { updatedAt: new Date(c.k), id: { lt: c.id } }] } : {}),
  };
  const rows = await prisma.alert.findMany({ where, include: alertInclude, orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }], take: q.limit + 1 });
  const page = rows.slice(0, q.limit);
  const grouped = await prisma.alert.groupBy({ by: ['status'], _count: { _all: true }, where: { status: { in: ['draft', 'pending_approval', 'published'] } } });
  const counts = { draft: 0, pending_approval: 0, published: 0 };
  for (const g of grouped) counts[g.status as keyof typeof counts] = g._count._all;
  const last = page[page.length - 1];
  return {
    items: await Promise.all(page.map((a) => toStaffDto(a, at))),
    counts,
    nextCursor: rows.length > q.limit && last ? encodeCursor({ k: last.updatedAt.toISOString(), id: last.id }) : null,
  };
}

export async function createAlert(staff: Staff, input: ComposerInput) {
  const id = await prisma.$transaction(async (tx) => {
    const { wardIds, zoneId } = await expandTarget(tx, input.target);
    const a = await tx.alert.create({
      data: {
        type: input.type,
        severity: input.severity,
        titleEn: input.titleEn,
        titleGu: input.titleGu,
        bodyEn: input.bodyEn,
        bodyGu: input.bodyGu,
        sourceName: input.sourceName,
        sourceUrl: input.sourceUrl,
        validFrom: input.validFrom,
        validTo: input.validTo,
        targetScope: input.target.scope,
        targetZoneId: zoneId,
        createdBy: staff.actorId,
      },
    });
    await setWards(tx, a.id, wardIds);
    return a.id;
  });
  return id;
}

/** PATCH: only draft / pending_approval; editing a pending alert returns it to draft and clears approvals. */
export async function patchAlert(id: string, input: PatchInput, at: Date) {
  await prisma.$transaction(async (tx) => {
    const a = await lockAlert(tx, id);
    if (a.status !== 'draft' && a.status !== 'pending_approval') throw new AppError('ALERT_STATE_INVALID');
    const validFrom = input.validFrom ?? a.validFrom;
    const validTo = input.validTo ?? a.validTo;
    if (input.validFrom || input.validTo) {
      const issues = windowIssues(validFrom, validTo, at, !!input.validFrom);
      if (issues.length > 0) throw new AppError('VALIDATION_FAILED', { details: issues });
    }
    let zone: { targetScope?: 'wards' | 'zone' | 'city'; targetZoneId?: string | null } = {};
    if (input.target) {
      const { wardIds, zoneId } = await expandTarget(tx, input.target);
      await setWards(tx, id, wardIds);
      zone = { targetScope: input.target.scope, targetZoneId: zoneId };
    }
    const { target: _t, ...rest } = input;
    void _t;
    await tx.alert.update({
      where: { id },
      data: { ...rest, ...zone, status: 'draft', approvedBy: [], submittedAt: null },
    });
  });
}

export async function submitAlert(id: string, at: Date) {
  await prisma.$transaction(async (tx) => {
    const a = await lockAlert(tx, id);
    if (a.status !== 'draft') throw new AppError('ALERT_STATE_INVALID');
    assertComplete(a, at);
    await tx.alert.update({ where: { id }, data: { status: 'pending_approval', submittedAt: at, approvedBy: [] } });
  });
}

/** Supersede: a new draft copying a published alert, linked by supersedes_id (an alert is superseded once). */
export async function supersedeAlert(staff: Staff, id: string): Promise<string> {
  return prisma.$transaction(async (tx) => {
    const old = await lockAlert(tx, id);
    if (old.status !== 'published') throw new AppError('ALERT_STATE_INVALID');
    if (await tx.alert.findFirst({ where: { supersedesId: id }, select: { id: true } })) throw new AppError('ALERT_ALREADY_SUPERSEDED');
    const wards = await tx.alertWard.findMany({ where: { alertId: id }, select: { wardId: true } });
    const copy = await tx.alert.create({
      data: {
        type: old.type,
        severity: old.severity,
        titleEn: old.titleEn,
        titleGu: old.titleGu,
        bodyEn: old.bodyEn,
        bodyGu: old.bodyGu,
        sourceName: old.sourceName,
        sourceUrl: old.sourceUrl,
        validFrom: old.validFrom,
        validTo: old.validTo,
        targetScope: old.targetScope,
        targetZoneId: old.targetZoneId,
        createdBy: staff.actorId,
        supersedesId: id,
      },
    });
    await setWards(tx, copy.id, wards.map((w) => w.wardId));
    return copy.id;
  });
}
