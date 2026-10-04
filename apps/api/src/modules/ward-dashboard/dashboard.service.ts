/**
 * Ward dashboard aggregates (TASK-11 §5.2/§5.3, REQ-F-054). Parameterised SQL over `issues` excluding hidden,
 * rejected and merged rows. Open = reported/sent/acknowledged/in_progress/reopened; age buckets 0–7 / 8–30 /
 * > 30 whole days; overdue = open and sla_due_at < now (50 oldest by sla_due_at); hotspots = open issues on a
 * REP_DASHBOARD_HOTSPOT_CELL_M grid (UTM 43N), cells with ≥ 2, top 30; trend = 12 ISO weeks (IST).
 * Never returns reporter identity, phone, description or photos.
 */
import { config } from '../../config';
import { now as clockNow } from '../../lib/clock';
import { prisma } from '../../lib/db';
import { AppError } from '../../lib/errors';

const OPEN = `('reported','sent','acknowledged','in_progress','reopened')`;
const n = (v: unknown) => Number(v ?? 0);

export async function wardOf(wardId: string) {
  const w = await prisma.ward.findUnique({ where: { id: wardId }, select: { id: true, number: true, nameEn: true, nameGu: true } });
  if (!w) throw new AppError('NOT_FOUND');
  return w;
}

export async function wardDashboard(wardId: string) {
  const ward = await wardOf(wardId);
  const at = clockNow();
  const since30 = new Date(at.getTime() - 30 * 86_400_000);

  const [totals] = await prisma.$queryRawUnsafe<Record<string, unknown>[]>(
    `SELECT
       count(*) FILTER (WHERE i.status IN ${OPEN}) AS open,
       count(*) FILTER (WHERE i.status IN ${OPEN} AND i.sla_due_at < $2::timestamptz) AS overdue,
       (SELECT count(DISTINCT e.issue_id) FROM issue_events e JOIN issues j ON j.id = e.issue_id
          WHERE j.ward_id = $1::uuid AND j.visibility <> 'hidden' AND j.status NOT IN ('rejected','merged')
            AND e.to_status = 'marked_fixed' AND e.created_at >= $3::timestamptz) AS marked_fixed_30d,
       (SELECT count(DISTINCT e.issue_id) FROM issue_events e JOIN issues j ON j.id = e.issue_id
          WHERE j.ward_id = $1::uuid AND j.visibility <> 'hidden' AND j.status NOT IN ('rejected','merged')
            AND e.to_status = 'verified' AND e.created_at >= $3::timestamptz) AS verified_30d
     FROM issues i
     WHERE i.ward_id = $1::uuid AND i.visibility <> 'hidden' AND i.status NOT IN ('rejected','merged')`,
    wardId, at, since30,
  );

  const byCategory = await prisma.$queryRawUnsafe<Record<string, unknown>[]>(
    `SELECT c.slug,
       count(*) FILTER (WHERE age <= 7) AS d0_7,
       count(*) FILTER (WHERE age BETWEEN 8 AND 30) AS d8_30,
       count(*) FILTER (WHERE age > 30) AS d31_plus,
       count(*) AS total
     FROM (SELECT i.category_id, floor(extract(epoch FROM ($2::timestamptz - i.created_at)) / 86400)::int AS age
           FROM issues i WHERE i.ward_id = $1::uuid AND i.visibility <> 'hidden' AND i.status IN ${OPEN}) x
     JOIN categories c ON c.id = x.category_id
     GROUP BY c.slug, c.sort_order ORDER BY total DESC, c.sort_order, c.slug`,
    wardId, at,
  );

  const overdue = await prisma.$queryRawUnsafe<Record<string, unknown>[]>(
    `SELECT i.id, i.title, c.slug AS category, i.status::text AS status, i.sla_due_at, i.me_too_count,
       floor(extract(epoch FROM ($2::timestamptz - i.created_at)) / 86400)::int AS age_days
     FROM issues i JOIN categories c ON c.id = i.category_id
     WHERE i.ward_id = $1::uuid AND i.visibility <> 'hidden' AND i.status IN ${OPEN} AND i.sla_due_at < $2::timestamptz
     ORDER BY i.sla_due_at ASC, i.id LIMIT 50`,
    wardId, at,
  );

  const hotspots = await prisma.$queryRawUnsafe<Record<string, unknown>[]>(
    `SELECT ST_Y(ST_Transform(ST_SetSRID(cell, 32643), 4326)) AS lat, ST_X(ST_Transform(ST_SetSRID(cell, 32643), 4326)) AS lng, cnt
     FROM (SELECT ST_SnapToGrid(ST_Transform(i.location::geometry, 32643), $2::float8) AS cell, count(*) AS cnt
           FROM issues i
           WHERE i.ward_id = $1::uuid AND i.visibility <> 'hidden' AND i.status IN ${OPEN} AND i.location IS NOT NULL
           GROUP BY 1) g
     WHERE cnt >= 2 ORDER BY cnt DESC, lat, lng LIMIT 30`,
    wardId, config.REP_DASHBOARD_HOTSPOT_CELL_M,
  );

  const trend = await prisma.$queryRawUnsafe<Record<string, unknown>[]>(
    `WITH weeks AS (
       SELECT generate_series(date_trunc('week', ($2::timestamptz AT TIME ZONE 'Asia/Kolkata')) - interval '11 weeks',
                              date_trunc('week', ($2::timestamptz AT TIME ZONE 'Asia/Kolkata')), interval '1 week') AS wk),
     scoped AS (SELECT id, created_at FROM issues WHERE ward_id = $1::uuid AND visibility <> 'hidden' AND status NOT IN ('rejected','merged')),
     ev AS (SELECT e.issue_id, e.to_status, min(e.created_at) AS at FROM issue_events e JOIN scoped s ON s.id = e.issue_id
            WHERE e.to_status IN ('marked_fixed','verified') GROUP BY e.issue_id, e.to_status)
     SELECT to_char(w.wk, 'YYYY-MM-DD') AS week_start,
       (SELECT count(*) FROM scoped s WHERE date_trunc('week', s.created_at AT TIME ZONE 'Asia/Kolkata') = w.wk) AS reported,
       (SELECT count(*) FROM ev WHERE ev.to_status = 'marked_fixed' AND date_trunc('week', ev.at AT TIME ZONE 'Asia/Kolkata') = w.wk) AS marked_fixed,
       (SELECT count(*) FROM ev WHERE ev.to_status = 'verified' AND date_trunc('week', ev.at AT TIME ZONE 'Asia/Kolkata') = w.wk) AS verified
     FROM weeks w ORDER BY w.wk`,
    wardId, at,
  );

  return {
    ward,
    generatedAt: at.toISOString(),
    totals: { open: n(totals?.open), overdue: n(totals?.overdue), markedFixed30d: n(totals?.marked_fixed_30d), verified30d: n(totals?.verified_30d) },
    byCategory: byCategory.map((r) => ({ slug: String(r.slug), d0_7: n(r.d0_7), d8_30: n(r.d8_30), d31Plus: n(r.d31_plus), total: n(r.total) })),
    overdue: overdue.map((r) => ({
      issueId: String(r.id), title: String(r.title), category: String(r.category), status: String(r.status),
      ageDays: n(r.age_days), slaDueAt: (r.sla_due_at as Date).toISOString(), meTooCount: n(r.me_too_count),
    })),
    hotspots: hotspots.map((r) => ({ lat: Number(n(r.lat).toFixed(5)), lng: Number(n(r.lng).toFixed(5)), count: n(r.cnt) })),
    trend: trend.map((r) => ({ weekStart: String(r.week_start), reported: n(r.reported), markedFixed: n(r.marked_fixed), verified: n(r.verified) })),
  };
}
