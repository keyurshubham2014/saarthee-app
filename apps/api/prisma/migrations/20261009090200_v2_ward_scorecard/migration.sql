-- V2 TASK-09 (REQ-D-012, REQ-F-046): public ward scorecard, refreshed hourly by the `scorecard-refresh` job
-- with REFRESH MATERIALIZED VIEW CONCURRENTLY (needs the unique index below).
-- Window: issues created in the last 90 days (SCORECARD_WINDOW_DAYS default), excluding hidden, rejected and
-- merged issues. open_backlog is all-time. Sample sizes are stored so the API can return null below
-- SCORECARD_MIN_SAMPLE (5). Only Saarthee reports are counted, never AMC records.
CREATE MATERIALIZED VIEW "ward_scorecard_mv" AS
WITH base AS (
    SELECT i.id, i.ward_id, i.status, i.status_changed_at, i.created_at
    FROM issues i
    WHERE i.ward_id IS NOT NULL
      AND i.visibility <> 'hidden'
      AND i.status NOT IN ('rejected', 'merged')
),
win AS (
    SELECT b.*,
        (SELECT min(e.created_at) FROM issue_events e WHERE e.issue_id = b.id AND e.to_status = 'acknowledged') AS ack_at,
        (SELECT min(e.created_at) FROM issue_events e WHERE e.issue_id = b.id AND e.to_status = 'marked_fixed') AS fixed_at,
        EXISTS (SELECT 1 FROM issue_events e WHERE e.issue_id = b.id AND e.to_status = 'reopened') AS was_reopened
    FROM base b
    WHERE b.created_at >= now() - interval '90 days'
),
agg AS (
    SELECT ward_id,
        count(*)::int AS issues_reported,
        round((percentile_cont(0.5) WITHIN GROUP (ORDER BY extract(epoch FROM ack_at - created_at) / 86400.0)
            FILTER (WHERE ack_at IS NOT NULL))::numeric, 1) AS median_days_ack,
        count(*) FILTER (WHERE ack_at IS NOT NULL)::int AS ack_sample,
        round((percentile_cont(0.5) WITHIN GROUP (ORDER BY extract(epoch FROM fixed_at - created_at) / 86400.0)
            FILTER (WHERE fixed_at IS NOT NULL))::numeric, 1) AS median_days_fix,
        count(*) FILTER (WHERE fixed_at IS NOT NULL)::int AS fix_sample,
        count(*) FILTER (WHERE status = 'verified')::int AS verified_n,
        count(*) FILTER (WHERE status IN ('verified', 'reopened')
            OR (status = 'marked_fixed' AND status_changed_at < now() - interval '7 days'))::int AS verified_sample,
        count(*) FILTER (WHERE was_reopened AND fixed_at IS NOT NULL)::int AS reopened_n,
        count(*) FILTER (WHERE fixed_at IS NOT NULL)::int AS reopen_sample
    FROM win
    GROUP BY ward_id
),
backlog AS (
    SELECT ward_id, count(*)::int AS open_backlog
    FROM base
    WHERE status IN ('reported', 'sent', 'acknowledged', 'in_progress', 'reopened')
    GROUP BY ward_id
)
SELECT w.id AS ward_id,
    coalesce(a.issues_reported, 0) AS issues_reported,
    a.median_days_ack,
    coalesce(a.ack_sample, 0) AS ack_sample,
    a.median_days_fix,
    coalesce(a.fix_sample, 0) AS fix_sample,
    CASE WHEN coalesce(a.verified_sample, 0) > 0 THEN round(a.verified_n * 100.0 / a.verified_sample, 1) END AS verified_pct,
    coalesce(a.verified_sample, 0) AS verified_sample,
    CASE WHEN coalesce(a.reopen_sample, 0) > 0 THEN round(a.reopened_n * 100.0 / a.reopen_sample, 1) END AS reopen_pct,
    coalesce(a.reopen_sample, 0) AS reopen_sample,
    coalesce(bl.open_backlog, 0) AS open_backlog,
    CASE WHEN w.population IS NOT NULL AND w.population > 0
        THEN round(coalesce(a.issues_reported, 0) * 1000.0 / w.population, 1) END AS reports_per_1000,
    now() AS refreshed_at
FROM wards w
LEFT JOIN agg a ON a.ward_id = w.id
LEFT JOIN backlog bl ON bl.ward_id = w.id;

CREATE UNIQUE INDEX "uq_ward_scorecard_mv_ward" ON "ward_scorecard_mv"("ward_id");
