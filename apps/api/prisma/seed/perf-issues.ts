/**
 * Performance seed (V2 TASK-07 §5.2, REQ-N-008/011). NOT part of the default seed: `npm run seed:perf`
 * (development DB) or `seedPerfIssues()` from the perf test. Defaults: 5,000 issues across every imported
 * ward (2,000 inside `dense` bbox), all non-merged statuses, 4 events per issue (20,000), 30,000 me-toos
 * and 15,000 follows from 1,000 fictional users (no phone numbers). Bulk SQL; ~seconds.
 */
import type { PrismaClient } from '@prisma/client';

export interface PerfSeedOptions {
  issues?: number;
  dense?: number;
  /** minLng, minLat, maxLng, maxLat; default Paldi–Vasna. */
  denseBbox?: [number, number, number, number];
  users?: number;
  meToosPerIssue?: number;
  followsPerIssue?: number;
}

export const PALDI_VASNA_BBOX: [number, number, number, number] = [72.548, 22.99, 72.575, 23.02];

export async function seedPerfIssues(prisma: PrismaClient, o: PerfSeedOptions = {}) {
  const issues = o.issues ?? 5000;
  const dense = o.dense ?? 2000;
  const [x0, y0, x1, y1] = o.denseBbox ?? PALDI_VASNA_BBOX;
  const users = o.users ?? 1000;
  const meToos = o.meToosPerIssue ?? 6;
  const follows = o.followsPerIssue ?? 3;
  const tag = `perf${Date.now().toString(36)}`;

  await prisma.$executeRawUnsafe(
    `INSERT INTO users (firebase_uid, display_name, language)
     SELECT '${tag}-' || n, 'Perf resident ' || n, 'gu' FROM generate_series(1, $1::int) n`,
    users,
  );
  // Wards in a stable order; issue n goes to ward (n mod #wards), dense ones get points inside the bbox.
  await prisma.$executeRawUnsafe(
    `WITH w AS (SELECT id, zone_id, ST_Y(centroid) AS lat, ST_X(centroid) AS lng, row_number() OVER (ORDER BY number) - 1 AS k,
                       count(*) OVER () AS total FROM wards),
          u AS (SELECT id, row_number() OVER (ORDER BY id) - 1 AS k FROM users WHERE firebase_uid LIKE '${tag}-%'),
          c AS (SELECT id, slug, sla_days, row_number() OVER (ORDER BY sort_order, slug) - 1 AS k, count(*) OVER () AS total
                FROM categories WHERE is_active),
          s AS (SELECT n, (ARRAY['reported','sent','acknowledged','in_progress','marked_fixed','verified','reopened','reported','in_progress','rejected'])[1 + n % 10] AS st
                FROM generate_series(0, $1::int - 1) n)
     INSERT INTO issues (client_submission_id, reporter_id, category_id, title, lat, lng, ward_id, zone_id, status, sla_due_at,
                         created_at, status_changed_at, marked_fixed_at, visibility)
     SELECT gen_random_uuid(), u.id, c.id, 'Perf issue ' || s.n,
            CASE WHEN s.n < $2::int THEN $3::float8 + random() * ($5::float8 - $3::float8) ELSE w.lat + (random() - 0.5) * 0.01 END,
            CASE WHEN s.n < $2::int THEN $4::float8 + random() * ($6::float8 - $4::float8) ELSE w.lng + (random() - 0.5) * 0.01 END,
            w.id, w.zone_id, s.st::issue_status,
            now() - (s.n % 120) * interval '1 day' + c.sla_days * interval '1 day',
            now() - (s.n % 120) * interval '1 day' - (s.n % 1440) * interval '1 minute',
            now() - (s.n % 60) * interval '1 day',
            CASE WHEN s.st IN ('marked_fixed', 'verified') THEN now() - (s.n % 20) * interval '1 day' END,
            CASE WHEN s.n % 97 = 0 THEN 'hidden'::issue_visibility ELSE 'public'::issue_visibility END
     FROM s
     JOIN w ON w.k = s.n % w.total
     JOIN u ON u.k = s.n % $7::int
     JOIN c ON c.k = (s.n / 7) % c.total`,
    issues, dense, y0, x0, y1, x1, users,
  );
  await prisma.$executeRawUnsafe(
    `INSERT INTO issue_events (issue_id, actor_role, type, from_status, to_status, created_at)
     SELECT i.id, 'system', 'status_change', NULL, (ARRAY['reported','sent','acknowledged','in_progress'])[g]::issue_status,
            i.created_at + g * interval '1 hour'
     FROM issues i CROSS JOIN generate_series(1, 4) g WHERE i.title LIKE 'Perf issue %'`,
  );
  const pairs = (per: number, table: string) =>
    prisma.$executeRawUnsafe(
      `WITH i AS (SELECT id, row_number() OVER (ORDER BY id) AS k FROM issues WHERE title LIKE 'Perf issue %'),
            u AS (SELECT id, row_number() OVER (ORDER BY id) - 1 AS k FROM users WHERE firebase_uid LIKE '${tag}-%')
       INSERT INTO ${table} (issue_id, user_id)
       SELECT i.id, u.id FROM i CROSS JOIN generate_series(0, $1::int - 1) g
       JOIN u ON u.k = (i.k * 37 + g * 101 + ${table === 'follows' ? 13 : 0}) % $2::int
       ON CONFLICT DO NOTHING`,
      per, users,
    );
  await pairs(meToos, 'me_toos');
  await pairs(follows, 'follows');
  await prisma.$executeRawUnsafe(
    `UPDATE issues i SET me_too_count = (SELECT count(*) FROM me_toos m WHERE m.issue_id = i.id),
                         follower_count = (SELECT count(*) FROM follows f WHERE f.issue_id = i.id)
     WHERE i.title LIKE 'Perf issue %'`,
  );
  await prisma.$executeRawUnsafe('ANALYZE issues');
  await prisma.$executeRawUnsafe('ANALYZE issue_events');
  return { issues, dense, users };
}
