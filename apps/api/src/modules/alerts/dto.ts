import type { Alert, AlertStatus, Prisma } from '@prisma/client';

export const alertInclude = {
  wards: { select: { ward: { select: { id: true, number: true, nameEn: true, nameGu: true } } } },
  targetZone: { select: { id: true, code: true, nameEn: true, nameGu: true } },
  supersededBy: { select: { id: true, status: true } },
} satisfies Prisma.AlertInclude;

export type AlertWithRefs = Alert & Prisma.AlertGetPayload<{ include: typeof alertInclude }>;

/** A published alert whose valid_to has passed reads as `expired` even before the job runs (§5.3). */
export function effectiveStatus(a: Pick<Alert, 'status' | 'validTo'>, now: Date): AlertStatus {
  return a.status === 'published' && a.validTo <= now ? 'expired' : a.status;
}

/** Public AlertDto (§5.3). */
export function toAlertDto(a: AlertWithRefs, now: Date) {
  const status = effectiveStatus(a, now);
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
    target: {
      scope: a.targetScope,
      wardIds: wards.map((w) => w.id),
      wardNumbers: wards.map((w) => w.number),
      ...(a.targetZone ? { zoneCode: a.targetZone.code } : {}),
    },
    status,
    isActive: status === 'published',
    publishedAt: a.publishedAt?.toISOString() ?? null,
    retractedAt: a.retractedAt?.toISOString() ?? null,
    retractionReason: a.retractionReason,
    supersedesId: a.supersedesId,
    supersededById: a.supersededBy && a.supersededBy.status !== 'draft' && a.supersededBy.status !== 'pending_approval' ? a.supersededBy.id : null,
    origin: a.origin,
    /** Ward names for ward-targeted alerts (area line); detail lists every ward. */
    wards: a.targetScope === 'wards' ? wards : [],
    zone: a.targetZone ? { id: a.targetZone.id, code: a.targetZone.code, nameEn: a.targetZone.nameEn, nameGu: a.targetZone.nameGu } : null,
  };
}

/** Detail adds the ward names and the zone. */
export function toAlertDetailDto(a: AlertWithRefs, now: Date) {
  return {
    ...toAlertDto(a, now),
    wards: a.wards.map((w) => w.ward).sort((x, y) => x.number - y.number),
    zone: a.targetZone ? { id: a.targetZone.id, code: a.targetZone.code, nameEn: a.targetZone.nameEn, nameGu: a.targetZone.nameGu } : null,
  };
}

export type AlertDto = ReturnType<typeof toAlertDto>;
