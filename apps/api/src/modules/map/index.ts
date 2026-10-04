/**
 * GET /map/issues (V2 TASK-07 §5.3, REQ-F-029, REQ-N-008): server grid clusters below MAP_CLUSTER_MAX_ZOOM,
 * points (≤ MAP_POINTS_MAX) at or above it; too many points → clusters. The app clusters points again.
 */
import { Prisma } from '@prisma/client';
import { Router } from 'express';
import { config } from '../../config';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';
import { rateLimit } from '../../middleware/rateLimit';
import { optionalUser } from '../../middleware/requireUser';
import { validate } from '../../middleware/validate';
import { baseWhere } from '../issues/list.service';
import { mapQuery, type MapQuery } from '../issues/list.schemas';

const OPEN = Prisma.sql`i.status::text IN ('reported', 'sent', 'acknowledged', 'in_progress', 'reopened')`;

/** ≈ 64 px cells: 360 / 2^zoom / 4 degrees. */
export const cellDeg = (zoom: number) => 360 / 2 ** zoom / 4;

async function clusters(where: Prisma.Sql, zoom: number, now: Date) {
  const cell = cellDeg(zoom);
  const rows = await prisma.$queryRaw<{ lat: number; lng: number; count: bigint; top: string; overdue: boolean }[]>`
    SELECT ST_Y(ST_Centroid(ST_Collect(g))) AS lat, ST_X(ST_Centroid(ST_Collect(g))) AS lng, count(*) AS count,
           mode() WITHIN GROUP (ORDER BY slug) AS top, bool_or(overdue) AS overdue
    FROM (
      SELECT ST_SnapToGrid(i.location::geometry, ${cell}::float8) AS cellg, i.location::geometry AS g, c.slug,
             (${OPEN} AND i.sla_due_at < ${now}) AS overdue
      FROM issues i JOIN categories c ON c.id = i.category_id
      WHERE ${where}
    ) s
    GROUP BY cellg`;
  return {
    mode: 'clusters' as const,
    cellDeg: cell,
    items: rows.map((r) => ({ lat: Number(r.lat), lng: Number(r.lng), count: Number(r.count), topCategory: r.top, hasOverdue: r.overdue })),
  };
}

export async function mapIssues(q: MapQuery, userId: string | undefined) {
  if (q.mine && !userId) throw new AppError('AUTH_REQUIRED');
  const now = clockNow();
  const where = Prisma.join(baseWhere({ category: q.category, status: q.status, bbox: q.bbox, mine: q.mine }, userId, now), ' AND ');
  if (q.zoom < config.MAP_CLUSTER_MAX_ZOOM) return clusters(where, q.zoom, now);
  const max = config.MAP_POINTS_MAX;
  const rows = await prisma.$queryRaw<{ id: string; lat: number; lng: number; slug: string; status: string; overdue: boolean }[]>`
    SELECT i.id::text AS id, i.lat::float8 AS lat, i.lng::float8 AS lng, c.slug, i.status::text AS status,
           (${OPEN} AND i.sla_due_at < ${now}) AS overdue
    FROM issues i JOIN categories c ON c.id = i.category_id
    WHERE ${where}
    ORDER BY i.created_at DESC
    LIMIT ${max + 1}`;
  if (rows.length > max) return { ...(await clusters(where, q.zoom, now)), truncated: true };
  return {
    mode: 'points' as const,
    items: rows.map((r) => ({ id: r.id, lat: Number(r.lat), lng: Number(r.lng), categorySlug: r.slug, status: r.status, isOverdue: r.overdue })),
    truncated: false,
  };
}

export const mapRouter = Router();
const limiter = rateLimit({ windowMs: 60_000, max: 120 });

mapRouter.get('/map/issues', limiter, optionalUser, validate({ query: mapQuery }), async (req, res) => {
  res.json(await mapIssues(res.locals.query as MapQuery, req.user?.id));
});
