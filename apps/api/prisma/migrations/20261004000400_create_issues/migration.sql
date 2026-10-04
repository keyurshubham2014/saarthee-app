-- V2 TASK-01 §5.2: issues (Spec §5, §6). ward_id / zone_id get their FKs in TASK-02.
CREATE TABLE "issues" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "client_submission_id" UUID NOT NULL,
    "reporter_id" UUID,
    "category_id" UUID NOT NULL,
    "title" VARCHAR(120) NOT NULL,
    "description" VARCHAR(1000),
    "lat" DECIMAL(9,6) NOT NULL,
    "lng" DECIMAL(9,6) NOT NULL,
    "location" geography(Point, 4326),
    "gps_accuracy_m" DECIMAL(8,2),
    "ward_id" UUID,
    "zone_id" UUID,
    "address_text" VARCHAR(200),
    "status" "issue_status" NOT NULL DEFAULT 'reported',
    "status_changed_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "sla_due_at" TIMESTAMPTZ(6) NOT NULL,
    "me_too_count" INTEGER NOT NULL DEFAULT 0,
    "follower_count" INTEGER NOT NULL DEFAULT 0,
    "ccrs_number" VARCHAR(50),
    "ccrs_filed_at" TIMESTAMPTZ(6),
    "visibility" "issue_visibility" NOT NULL DEFAULT 'public',
    "is_sensitive" BOOLEAN NOT NULL DEFAULT false,
    "merged_into_id" UUID,
    "legacy_complaint_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_issues" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "uq_issues_client_submission" ON "issues"("client_submission_id");

CREATE UNIQUE INDEX "uq_issues_legacy_complaint" ON "issues"("legacy_complaint_id");

CREATE INDEX "idx_issues_location" ON "issues" USING GIST ("location");

CREATE INDEX "idx_issues_status" ON "issues"("status", "status_changed_at" DESC);

CREATE INDEX "idx_issues_ward_status" ON "issues"("ward_id", "status");

CREATE INDEX "idx_issues_category_created" ON "issues"("category_id", "created_at" DESC);

CREATE INDEX "idx_issues_reporter" ON "issues"("reporter_id");

CREATE INDEX "idx_issues_merged_into" ON "issues"("merged_into_id");

ALTER TABLE "issues" ADD CONSTRAINT "fk_issues_reporter" FOREIGN KEY ("reporter_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "issues" ADD CONSTRAINT "fk_issues_category" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "issues" ADD CONSTRAINT "fk_issues_merged_into" FOREIGN KEY ("merged_into_id") REFERENCES "issues"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "issues" ADD CONSTRAINT "fk_issues_legacy_complaint" FOREIGN KEY ("legacy_complaint_id") REFERENCES "complaints"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Hand-written: CHECKs, the location trigger and the partial SLA index.
ALTER TABLE "issues" ADD CONSTRAINT "ck_issues_coords" CHECK (lat BETWEEN -90 AND 90 AND lng BETWEEN -180 AND 180);
ALTER TABLE "issues" ADD CONSTRAINT "ck_issues_accuracy" CHECK (gps_accuracy_m IS NULL OR gps_accuracy_m >= 0);
ALTER TABLE "issues" ADD CONSTRAINT "ck_issues_counts" CHECK (me_too_count >= 0 AND follower_count >= 0);
-- A merged issue (and only a merged issue) points at its canonical issue, never at itself.
ALTER TABLE "issues" ADD CONSTRAINT "ck_issues_merged" CHECK ((status = 'merged') = (merged_into_id IS NOT NULL) AND merged_into_id IS DISTINCT FROM id);
-- location is always derived from lat/lng by trg_issues_location (callers never write it; Prisma
-- declares it Unsupported and optional). The CHECK runs after the BEFORE trigger.
ALTER TABLE "issues" ADD CONSTRAINT "ck_issues_location" CHECK (location IS NOT NULL);

CREATE FUNCTION issues_set_location() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.location := ST_SetSRID(ST_MakePoint(NEW.lng::double precision, NEW.lat::double precision), 4326)::geography;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_issues_location BEFORE INSERT OR UPDATE OF lat, lng ON "issues"
  FOR EACH ROW EXECUTE FUNCTION issues_set_location();

-- Open issues by SLA due date (overdue sweep, escalation ladder).
CREATE INDEX "idx_issues_sla_open" ON "issues"("sla_due_at")
  WHERE status IN ('reported', 'sent', 'acknowledged', 'in_progress', 'reopened');
