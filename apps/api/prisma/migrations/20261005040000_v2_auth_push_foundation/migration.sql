-- V2 TASK-04 §5.2: citizen auth columns, device language/topics, consent lookup index and the
-- notifications delivery log (created here; TASK-08 extends it — Open Question 7).
-- TASK-01 already created users.token_version, users.deleted_at, nullable phone/uid, ck_users_deleted,
-- uq_devices_install and idx_devices_user; those parts are no-ops here (recorded in TASK-04 §13).

ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "age_confirmed_at" TIMESTAMPTZ(6);

ALTER TABLE "devices" ADD COLUMN IF NOT EXISTS "language" "app_language" NOT NULL DEFAULT 'gu';
ALTER TABLE "devices" ADD COLUMN IF NOT EXISTS "topics" TEXT[] DEFAULT ARRAY[]::TEXT[];

CREATE INDEX IF NOT EXISTS "idx_consents_user_purpose" ON "consents"("user_id", "purpose");

CREATE TABLE "notifications" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID,
    "device_id" UUID,
    "topic" VARCHAR(60),
    "kind" TEXT NOT NULL,
    "ref_id" TEXT,
    "route" TEXT,
    "channel" VARCHAR(20) NOT NULL DEFAULT 'updates',
    "title_en" VARCHAR(120) NOT NULL,
    "title_gu" VARCHAR(120) NOT NULL,
    "body_en" VARCHAR(400) NOT NULL,
    "body_gu" VARCHAR(400) NOT NULL,
    "status" TEXT NOT NULL,
    "send_after" TIMESTAMPTZ(6),
    "sent_at" TIMESTAMPTZ(6),
    "provider_message_ids" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "error_code" TEXT,
    "read_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_notifications" PRIMARY KEY ("id")
);

CREATE INDEX "idx_notifications_user_created" ON "notifications"("user_id", "created_at" DESC);

CREATE INDEX "idx_notifications_kind_ref" ON "notifications"("kind", "ref_id");

ALTER TABLE "notifications" ADD CONSTRAINT "fk_notifications_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "notifications" ADD CONSTRAINT "fk_notifications_device" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Hand-written: CHECKs and the partial queue index (not expressible in schema.prisma).
-- Prisma lists are NOT NULL-less; enforce it here.
ALTER TABLE "devices" ALTER COLUMN "topics" SET NOT NULL;
ALTER TABLE "notifications" ALTER COLUMN "provider_message_ids" SET NOT NULL;
ALTER TABLE "notifications" ADD CONSTRAINT "ck_notifications_kind" CHECK (kind IN ('alert', 'issue_update', 'initiative', 'system'));
ALTER TABLE "notifications" ADD CONSTRAINT "ck_notifications_status" CHECK (status IN ('queued', 'sent', 'partial', 'failed', 'no_device'));
ALTER TABLE "notifications" ADD CONSTRAINT "ck_notifications_channel" CHECK (channel IN ('critical_alerts', 'alerts', 'updates'));
ALTER TABLE "notifications" ADD CONSTRAINT "ck_notifications_topic" CHECK (topic IS NULL OR topic ~ '^[a-z0-9_]{1,60}$');
CREATE INDEX "idx_notifications_queued" ON "notifications"("status", "send_after") WHERE status = 'queued';
