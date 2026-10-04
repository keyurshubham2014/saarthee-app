-- V2 TASK-06 §5.2: issue lifecycle (timestamps, optimistic lock, CCRS closed), idempotent events with meta,
-- verification idempotency + accuracy, after photos, escalation contacts.

ALTER TYPE "issue_event_type" ADD VALUE IF NOT EXISTS 'ccrs_closed';
ALTER TYPE "issue_event_type" ADD VALUE IF NOT EXISTS 'verification';
ALTER TYPE "issue_event_type" ADD VALUE IF NOT EXISTS 'system';
ALTER TYPE "photo_purpose" ADD VALUE IF NOT EXISTS 'after';

ALTER TABLE "issues" ADD COLUMN "marked_fixed_at" TIMESTAMPTZ(6);
ALTER TABLE "issues" ADD COLUMN "verified_at" TIMESTAMPTZ(6);
ALTER TABLE "issues" ADD COLUMN "reopened_count" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "issues" ADD COLUMN "overdue_notified_at" TIMESTAMPTZ(6);
ALTER TABLE "issues" ADD COLUMN "ccrs_closed_at" TIMESTAMPTZ(6);
ALTER TABLE "issues" ADD COLUMN "ccrs_reminder_sent_at" TIMESTAMPTZ(6);
ALTER TABLE "issues" ADD COLUMN "status_version" INTEGER NOT NULL DEFAULT 0;
CREATE INDEX "idx_issues_status_sla" ON "issues"("status", "sla_due_at");
-- Hand-written partial index for the ccrs-reopen-reminder job.
CREATE INDEX "idx_issues_ccrs_closed_pending" ON "issues"("ccrs_closed_at") WHERE "ccrs_reminder_sent_at" IS NULL;

ALTER TABLE "issue_events" ADD COLUMN "client_action_id" UUID;
ALTER TABLE "issue_events" ADD COLUMN "meta" JSONB;
CREATE UNIQUE INDEX "uq_issue_events_client_action" ON "issue_events"("client_action_id");

ALTER TABLE "issue_verifications" ADD COLUMN "gps_accuracy_m" DECIMAL(8,2);
ALTER TABLE "issue_verifications" ADD COLUMN "client_submission_id" UUID;
CREATE UNIQUE INDEX "uq_issue_verifications_client_submission" ON "issue_verifications"("client_submission_id");

CREATE TABLE "escalation_contacts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "level" VARCHAR(30) NOT NULL,
    "zone_id" UUID,
    "title_en" VARCHAR(160) NOT NULL,
    "title_gu" VARCHAR(200) NOT NULL,
    "email" VARCHAR(254),
    "phone" VARCHAR(20),
    "source_url" VARCHAR(500) NOT NULL,
    "last_verified_at" DATE NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_escalation_contacts" PRIMARY KEY ("id"),
    CONSTRAINT "ck_escalation_contacts_level" CHECK ("level" IN ('zone_office', 'deputy_commissioner', 'commissioner'))
);
CREATE UNIQUE INDEX "uq_escalation_contacts_level_zone" ON "escalation_contacts"("level", "zone_id");
-- Hand-written: one city-wide row per level (NULL zone_id is not covered by the unique index above).
CREATE UNIQUE INDEX "uq_escalation_contacts_level_citywide" ON "escalation_contacts"("level") WHERE "zone_id" IS NULL;
ALTER TABLE "escalation_contacts" ADD CONSTRAINT "fk_escalation_contacts_zone" FOREIGN KEY ("zone_id")
  REFERENCES "zones"("id") ON DELETE CASCADE ON UPDATE CASCADE;
