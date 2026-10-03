-- Hand-written: views are raw SQL (04 §3.9). The "due" interval is NOT in the view; the API applies
-- REMINDER_INTERVAL_DAYS as a query parameter to due_reference_at (03 §4.3).
CREATE VIEW complaint_status_v AS
WITH r AS (
  SELECT complaint_id, COUNT(*)::int AS reminder_count, MAX(sent_at) AS last_reminder_at
  FROM reminders GROUP BY complaint_id
), vc AS (
  SELECT complaint_id, COUNT(*)::int AS verification_count FROM verifications GROUP BY complaint_id
), vl AS (
  SELECT DISTINCT ON (complaint_id) complaint_id, result AS latest_result, created_at AS latest_verified_at
  FROM verifications ORDER BY complaint_id, created_at DESC, id DESC
)
SELECT c.id AS complaint_id, c.source_tag, c.category_id, c.invite_code_id, c.created_at, c.is_excluded,
       c.anonymized_at, c.ccrs_duplicate_flag,
       COALESCE(r.reminder_count, 0) AS reminder_count, r.last_reminder_at,
       COALESCE(vc.verification_count, 0) AS verification_count, vl.latest_result, vl.latest_verified_at,
       CASE WHEN vl.latest_result = 'fixed' THEN 'verified_fixed'
            WHEN vl.latest_result = 'not_fixed' THEN 'verified_not_fixed'
            WHEN COALESCE(r.reminder_count, 0) > 0 THEN 'reminded'
            ELSE 'filed' END AS status,
       COALESCE(r.last_reminder_at, c.created_at) AS due_reference_at
FROM complaints c
LEFT JOIN r ON r.complaint_id = c.id
LEFT JOIN vc ON vc.complaint_id = c.id
LEFT JOIN vl ON vl.complaint_id = c.id;

-- H1 = verified / reminded; H2 = complaints whose LATEST verification is not_fixed / verified (04 A5).
-- Excluded complaints are left out. One row per source tag (zero rows kept) plus 'trusted' = rwa + activist.
CREATE VIEW pilot_rates_v AS
WITH per AS (
  SELECT s.source_tag::text AS grp,
         s.source_tag IN ('rwa','activist') AS trusted,
         COUNT(*)::int AS complaints,
         COUNT(*) FILTER (WHERE s.reminder_count > 0)::int AS reminded,
         COUNT(*) FILTER (WHERE s.verification_count > 0)::int AS verified,
         COALESCE(SUM(s.verification_count), 0)::int AS verifications,
         COUNT(*) FILTER (WHERE s.latest_result = 'not_fixed')::int AS not_fixed
  FROM complaint_status_v s WHERE NOT s.is_excluded GROUP BY s.source_tag
), tags AS (
  SELECT unnest(enum_range(NULL::source_tag))::text AS grp
), rows AS (
  SELECT t.grp, COALESCE(p.complaints,0) AS complaints, COALESCE(p.reminded,0) AS reminded,
         COALESCE(p.verified,0) AS verified, COALESCE(p.verifications,0) AS verifications,
         COALESCE(p.not_fixed,0) AS not_fixed
  FROM tags t LEFT JOIN per p ON p.grp = t.grp
  UNION ALL
  SELECT 'trusted', COALESCE(SUM(complaints),0)::int, COALESCE(SUM(reminded),0)::int, COALESCE(SUM(verified),0)::int,
         COALESCE(SUM(verifications),0)::int, COALESCE(SUM(not_fixed),0)::int
  FROM per WHERE trusted
)
SELECT grp AS "group", complaints, reminded, verified,
       CASE WHEN reminded = 0 THEN NULL ELSE ROUND(verified::numeric / reminded, 4) END AS h1_rate,
       verifications, not_fixed,
       CASE WHEN verified = 0 THEN NULL ELSE ROUND(not_fixed::numeric / verified, 4) END AS h2_rate
FROM rows;
