-- V2 TASK-07 §5.2: discovery read indexes (feed, lists, map). follows/me_toos (user_id, created_at DESC)
-- and issues (status, sla_due_at) already exist (TASK-01/05/06).

-- Ward lists and the feed's nearby section; keyset (created_at DESC, id) paging.
CREATE INDEX "idx_issues_ward_status_created" ON "issues"("ward_id", "status", "created_at" DESC, "id");
-- City-wide newest-first lists.
CREATE INDEX "idx_issues_created_id" ON "issues"("created_at" DESC, "id" DESC);
-- Hand-written partial index: "most affected" sort over public issues.
CREATE INDEX "idx_issues_me_too_public" ON "issues"("me_too_count" DESC, "id") WHERE "visibility" = 'public';
-- Hand-written expression index: bbox (&& ST_MakeEnvelope) and ST_SnapToGrid clustering on geometry.
CREATE INDEX "idx_issues_location_geom" ON "issues" USING GIST (("location"::geometry));
