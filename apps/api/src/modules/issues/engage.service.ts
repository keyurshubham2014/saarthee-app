/**
 * Duplicate suggestions, me-too (create) and CCRS link (V2 TASK-05 §5.3, REQ-F-015, REQ-F-018).
 * No reporter id, name or phone ever leaves these functions.
 */
import type { IssueStatus } from '@prisma/client';
import { config } from '../../config';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { pointSql } from '../../lib/geo';
import { assertDailyQuota } from '../../lib/quota';
import { normalizeCcrs } from '../../lib/validation';

export const OPEN_STATUSES: IssueStatus[] = ['reported', 'sent', 'acknowledged', 'in_progress', 'reopened'];

export interface NearbyItem {
  id: string;
  title: string;
  categorySlug: string;
  status: IssueStatus;
  distanceM: number;
  meTooCount: number;
  createdAt: Date;
  wardNameEn: string | null;
  wardNameGu: string | null;
  thumbnailUrl: string | null;
}

interface NearbyRow {
  id: string;
  title: string;
  slug: string;
  status: IssueStatus;
  distance_m: number;
  me_too_count: number;
  created_at: Date;
  ward_name_en: string | null;
  ward_name_gu: string | null;
  photo_id: string | null;
}

export async function nearby(lat: number, lng: number, categorySlug: string): Promise<NearbyItem[]> {
  const pt = pointSql(lat, lng);
  const since = new Date(Date.now() - config.DUPLICATE_WINDOW_DAYS * 86_400_000);
  const rows = await prisma.$queryRaw<NearbyRow[]>`
    SELECT i.id::text, i.title, c.slug, i.status, ST_Distance(i.location, ${pt}::geography) AS distance_m,
           i.me_too_count, i.created_at, w.name_en AS ward_name_en, w.name_gu AS ward_name_gu,
           (SELECT ip.photo_id::text FROM issue_photos ip WHERE ip.issue_id = i.id AND ip.kind = 'report'
             ORDER BY ip.position LIMIT 1) AS photo_id
    FROM issues i
    JOIN categories c ON c.id = i.category_id
    LEFT JOIN wards w ON w.id = i.ward_id
    WHERE c.slug = ${categorySlug}
      AND i.status::text IN (${OPEN_STATUSES[0]}, ${OPEN_STATUSES[1]}, ${OPEN_STATUSES[2]}, ${OPEN_STATUSES[3]}, ${OPEN_STATUSES[4]})
      AND i.visibility = 'public'
      AND i.created_at > ${since}
      AND ST_DWithin(i.location, ${pt}::geography, ${config.DUPLICATE_RADIUS_M}::double precision)
    ORDER BY ST_Distance(i.location, ${pt}::geography), i.created_at DESC
    LIMIT 5`;
  return rows.map((r) => ({
    id: r.id, title: r.title, categorySlug: r.slug, status: r.status, distanceM: Math.round(Number(r.distance_m)),
    meTooCount: Number(r.me_too_count), createdAt: r.created_at, wardNameEn: r.ward_name_en, wardNameGu: r.ward_name_gu,
    thumbnailUrl: r.photo_id ? `/api/v1/media/photos/${r.photo_id}?w=320` : null,
  }));
}

/** POST /issues/{id}/me-too (create only): 201 new, 200 repeat. */
export async function addMeToo(userId: string, issueId: string, res?: import('express').Response): Promise<{ created: boolean; meTooCount: number }> {
  const issue = await prisma.issue.findUnique({ where: { id: issueId }, select: { reporterId: true, status: true, visibility: true } });
  if (!issue || issue.visibility !== 'public') throw new AppError('NOT_FOUND');
  if (issue.reporterId === userId) throw new AppError('OWN_ISSUE');
  if (!OPEN_STATUSES.includes(issue.status)) throw new AppError('ISSUE_NOT_OPEN');
  const already = await prisma.meToo.findUnique({ where: { issueId_userId: { issueId, userId } } });
  if (!already) await assertDailyQuota(userId, 'me_too', { res });
  return prisma.$transaction(async (tx) => {
    const inserted = await tx.$executeRaw`
      INSERT INTO me_toos (issue_id, user_id) VALUES (${issueId}::uuid, ${userId}::uuid) ON CONFLICT DO NOTHING`;
    const [r] = await tx.$queryRaw<{ me_too_count: number }[]>`
      UPDATE issues SET me_too_count = (SELECT count(*) FROM me_toos WHERE issue_id = ${issueId}::uuid)
      WHERE id = ${issueId}::uuid RETURNING me_too_count`;
    return { created: inserted > 0, meTooCount: Number(r?.me_too_count ?? 0) };
  });
}

/** POST /issues/{id}/ccrs: reporter links the AMC complaint number; reported → sent. */
export async function linkCcrs(userId: string, issueId: string, rawNumber: string, filedVia: 'web' | 'whatsapp' | 'phone') {
  const ccrsNumber = normalizeCcrs(rawNumber);
  if (ccrsNumber.length < 1 || ccrsNumber.length > 50) {
    throw new AppError('VALIDATION_FAILED', { details: [{ field: 'ccrsNumber', issue: 'Enter the complaint number you got from AMC.' }] });
  }
  const issue = await prisma.issue.findUnique({ where: { id: issueId }, select: { reporterId: true, status: true, ccrsNumber: true, ccrsFiledAt: true } });
  if (!issue) throw new AppError('NOT_FOUND');
  if (issue.reporterId !== userId) throw new AppError('FORBIDDEN');
  if (issue.ccrsNumber) {
    if (issue.ccrsNumber !== ccrsNumber) throw new AppError('CCRS_ALREADY_LINKED');
    return { ccrsNumber, ccrsFiledAt: issue.ccrsFiledAt, status: issue.status };
  }
  const now = new Date();
  return prisma.$transaction(async (tx) => {
    const moveToSent = issue.status === 'reported';
    const updated = await tx.issue.update({
      where: { id: issueId },
      data: { ccrsNumber, ccrsFiledAt: now, ...(moveToSent ? { status: 'sent' as const, statusChangedAt: now } : {}) },
      select: { ccrsNumber: true, ccrsFiledAt: true, status: true },
    });
    await tx.issueEvent.create({ data: { issueId, actorId: userId, actorRole: 'citizen', type: 'ccrs_linked', note: `via:${filedVia}` } });
    if (moveToSent) {
      await tx.issueEvent.create({ data: { issueId, actorId: userId, actorRole: 'citizen', type: 'status_change', fromStatus: 'reported', toStatus: 'sent' } });
    }
    return updated;
  });
}
