-- V2 TASK-10: moderation flags, moderation stamps on issues, moderation event types (REQ-D-011).
-- app_settings already exists (TASK-09, 20261009090100) — not re-created here. issues.merged_into_id and
-- ck_issues_merged (merged <=> merged_into_id set, never self) already exist (TASK-01).

CREATE TYPE "flag_target" AS ENUM ('issue', 'issue_event');
CREATE TYPE "flag_reason" AS ENUM ('spam', 'abusive', 'private_info', 'not_civic', 'wrong_location', 'duplicate', 'other');
CREATE TYPE "flag_status" AS ENUM ('open', 'actioned', 'dismissed');

ALTER TYPE "issue_event_type" ADD VALUE IF NOT EXISTS 'recategorised';
ALTER TYPE "issue_event_type" ADD VALUE IF NOT EXISTS 'ward_changed';
ALTER TYPE "issue_event_type" ADD VALUE IF NOT EXISTS 'hidden';
ALTER TYPE "issue_event_type" ADD VALUE IF NOT EXISTS 'unhidden';
ALTER TYPE "issue_event_type" ADD VALUE IF NOT EXISTS 'reviewed';

ALTER TABLE "issues" ADD COLUMN "moderated_at" TIMESTAMPTZ(6);
ALTER TABLE "issues" ADD COLUMN "moderated_by" UUID;

CREATE TABLE "moderation_flags" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "target_type" "flag_target" NOT NULL,
    "target_id" UUID NOT NULL,
    "issue_id" UUID NOT NULL,
    "reporter_id" UUID NOT NULL,
    "reason" "flag_reason" NOT NULL,
    "note" VARCHAR(200),
    "status" "flag_status" NOT NULL DEFAULT 'open',
    "handled_by" UUID,
    "handled_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "pk_moderation_flags" PRIMARY KEY ("id"),
    CONSTRAINT "ck_moderation_flags_handled" CHECK ("status" = 'open' OR ("handled_by" IS NOT NULL AND "handled_at" IS NOT NULL))
);

ALTER TABLE "moderation_flags" ADD CONSTRAINT "fk_moderation_flags_issue" FOREIGN KEY ("issue_id") REFERENCES "issues"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "moderation_flags" ADD CONSTRAINT "fk_moderation_flags_reporter" FOREIGN KEY ("reporter_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- One open flag per person per target.
CREATE UNIQUE INDEX "uq_moderation_flags_open" ON "moderation_flags"("reporter_id", "target_type", "target_id") WHERE "status" = 'open';
CREATE INDEX "idx_moderation_flags_status_created" ON "moderation_flags"("status", "created_at");
CREATE INDEX "idx_moderation_flags_issue_status" ON "moderation_flags"("issue_id", "status");
CREATE INDEX "idx_moderation_flags_reporter_created" ON "moderation_flags"("reporter_id", "created_at");
-- Sensitive / out-of-area queues filter on moderated_at IS NULL.
CREATE INDEX "idx_issues_unmoderated" ON "issues"("created_at") WHERE "moderated_at" IS NULL;

-- Hidden comments: issue_events is append-only, so a moderator's comment hide is recorded beside it.
-- Public timelines (TASK-07) exclude events listed here; staff still see them.
CREATE TABLE "issue_event_hides" (
    "event_id" UUID NOT NULL,
    "issue_id" UUID NOT NULL,
    "hidden_by" UUID NOT NULL,
    "hidden_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "pk_issue_event_hides" PRIMARY KEY ("event_id")
);
ALTER TABLE "issue_event_hides" ADD CONSTRAINT "fk_issue_event_hides_event" FOREIGN KEY ("event_id") REFERENCES "issue_events"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "issue_event_hides" ADD CONSTRAINT "fk_issue_event_hides_issue" FOREIGN KEY ("issue_id") REFERENCES "issues"("id") ON DELETE CASCADE ON UPDATE CASCADE;
CREATE INDEX "idx_issue_event_hides_issue" ON "issue_event_hides"("issue_id");
