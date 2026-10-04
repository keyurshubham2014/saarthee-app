-- V2 TASK-08: civic alerts, alert wards, subscriptions; additive extension of notifications (TASK-04).
-- Ward and zone ids are UUIDs (TASK-02), so target_zone_id / scope_id are uuid (TASK-08 §5.6).

CREATE TYPE "alert_type" AS ENUM ('water_cut', 'water_timing', 'road_closure', 'heat', 'rain_flood', 'health', 'initiative', 'other');
CREATE TYPE "alert_severity" AS ENUM ('info', 'advisory', 'warning', 'critical');
CREATE TYPE "alert_status" AS ENUM ('draft', 'pending_approval', 'published', 'expired', 'retracted');
CREATE TYPE "alert_origin" AS ENUM ('manual', 'sachet', 'imd');
CREATE TYPE "alert_scope" AS ENUM ('wards', 'zone', 'city');
CREATE TYPE "subscription_scope" AS ENUM ('ward', 'zone', 'city');

CREATE TABLE "alerts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "type" "alert_type" NOT NULL,
    "severity" "alert_severity" NOT NULL,
    "title_en" TEXT NOT NULL DEFAULT '',
    "title_gu" TEXT NOT NULL DEFAULT '',
    "body_en" TEXT NOT NULL DEFAULT '',
    "body_gu" TEXT NOT NULL DEFAULT '',
    "source_name" TEXT NOT NULL,
    "source_url" TEXT NOT NULL,
    "valid_from" TIMESTAMPTZ(6) NOT NULL,
    "valid_to" TIMESTAMPTZ(6) NOT NULL,
    "target_scope" "alert_scope" NOT NULL,
    "target_zone_id" UUID,
    "area" geometry(MultiPolygon, 4326),
    "status" "alert_status" NOT NULL DEFAULT 'draft',
    "origin" "alert_origin" NOT NULL DEFAULT 'manual',
    "origin_ref" TEXT,
    "created_by" UUID,
    "approved_by" UUID[] NOT NULL DEFAULT '{}',
    "submitted_at" TIMESTAMPTZ(6),
    "published_at" TIMESTAMPTZ(6),
    "pushed_at" TIMESTAMPTZ(6),
    "supersedes_id" UUID,
    "retracted_at" TIMESTAMPTZ(6),
    "retracted_by" UUID,
    "retraction_reason" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "pk_alerts" PRIMARY KEY ("id"),
    CONSTRAINT "fk_alerts_zone" FOREIGN KEY ("target_zone_id") REFERENCES "zones"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "fk_alerts_supersedes" FOREIGN KEY ("supersedes_id") REFERENCES "alerts"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT "ck_alerts_titles" CHECK ("status" = 'draft' OR (char_length("title_en") BETWEEN 5 AND 80 AND char_length("title_gu") BETWEEN 5 AND 80)),
    CONSTRAINT "ck_alerts_bodies" CHECK ("status" = 'draft' OR (char_length("body_en") BETWEEN 10 AND 500 AND char_length("body_gu") BETWEEN 10 AND 500)),
    CONSTRAINT "ck_alerts_title_len" CHECK (char_length("title_en") <= 80 AND char_length("title_gu") <= 80),
    CONSTRAINT "ck_alerts_body_len" CHECK (char_length("body_en") <= 500 AND char_length("body_gu") <= 500),
    CONSTRAINT "ck_alerts_source_name" CHECK (char_length(btrim("source_name")) BETWEEN 2 AND 80),
    CONSTRAINT "ck_alerts_source_url" CHECK ("source_url" ~ '^https://' AND char_length("source_url") <= 500),
    CONSTRAINT "ck_alerts_validity" CHECK ("valid_to" > "valid_from"),
    CONSTRAINT "ck_alerts_zone_target" CHECK (("target_scope" = 'zone') = ("target_zone_id" IS NOT NULL)),
    CONSTRAINT "ck_alerts_published_at" CHECK ("status" NOT IN ('published', 'expired') OR "published_at" IS NOT NULL),
    CONSTRAINT "ck_alerts_retracted" CHECK ("status" <> 'retracted' OR "retracted_at" IS NOT NULL),
    CONSTRAINT "ck_alerts_retraction_reason" CHECK ("retraction_reason" IS NULL OR char_length(btrim("retraction_reason")) BETWEEN 5 AND 200),
    CONSTRAINT "ck_alerts_two_person" CHECK (
        "status" NOT IN ('published', 'expired')
        OR cardinality("approved_by") >= CASE WHEN "severity" IN ('warning', 'critical') THEN 2 ELSE 1 END
    ),
    CONSTRAINT "ck_alerts_origin_ref" CHECK (("origin" = 'manual') = ("origin_ref" IS NULL))
);

CREATE UNIQUE INDEX "uq_alerts_origin_ref" ON "alerts"("origin", "origin_ref");
CREATE UNIQUE INDEX "uq_alerts_supersedes" ON "alerts"("supersedes_id");
CREATE INDEX "idx_alerts_status_valid_to" ON "alerts"("status", "valid_to");
CREATE INDEX "idx_alerts_published_at" ON "alerts"("published_at" DESC);
CREATE INDEX "idx_alerts_area" ON "alerts" USING GIST ("area");

CREATE TABLE "alert_wards" (
    "alert_id" UUID NOT NULL,
    "ward_id" UUID NOT NULL,
    CONSTRAINT "pk_alert_wards" PRIMARY KEY ("alert_id", "ward_id"),
    CONSTRAINT "fk_alert_wards_alert" FOREIGN KEY ("alert_id") REFERENCES "alerts"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "fk_alert_wards_ward" FOREIGN KEY ("ward_id") REFERENCES "wards"("id") ON DELETE RESTRICT ON UPDATE CASCADE
);
CREATE INDEX "idx_alert_wards_ward" ON "alert_wards"("ward_id");

CREATE TABLE "subscriptions" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID,
    "device_id" UUID,
    "scope" "subscription_scope" NOT NULL,
    "scope_id" UUID,
    "category" TEXT,
    "channel" TEXT NOT NULL DEFAULT 'push',
    "muted_types" "alert_type"[] NOT NULL DEFAULT '{}',
    "critical_only" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "pk_subscriptions" PRIMARY KEY ("id"),
    CONSTRAINT "fk_subscriptions_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "fk_subscriptions_device" FOREIGN KEY ("device_id") REFERENCES "devices"("id") ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT "ck_subscriptions_owner" CHECK (num_nonnulls("user_id", "device_id") = 1),
    CONSTRAINT "ck_subscriptions_scope_id" CHECK (("scope" = 'city') = ("scope_id" IS NULL)),
    CONSTRAINT "ck_subscriptions_channel" CHECK ("channel" = 'push')
);
CREATE UNIQUE INDEX "uq_subscriptions_user" ON "subscriptions"("user_id", "scope", "scope_id") NULLS NOT DISTINCT WHERE "user_id" IS NOT NULL;
CREATE UNIQUE INDEX "uq_subscriptions_device" ON "subscriptions"("device_id", "scope", "scope_id") NULLS NOT DISTINCT WHERE "device_id" IS NOT NULL;

-- Device-level home ward for visitors' alert matching (set by PUT /devices/{installId}/subscriptions).
ALTER TABLE "devices" ADD COLUMN "home_ward_id" UUID;
ALTER TABLE "devices" ADD CONSTRAINT "fk_devices_home_ward" FOREIGN KEY ("home_ward_id") REFERENCES "wards"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- notifications (TASK-04) — additive only.
ALTER TABLE "notifications" ADD COLUMN "target_device_ids" UUID[] NOT NULL DEFAULT '{}';
CREATE INDEX "idx_notifications_unread" ON "notifications"("user_id") WHERE "read_at" IS NULL AND "user_id" IS NOT NULL;
CREATE UNIQUE INDEX "uq_notifications_user_alert" ON "notifications"("user_id", "ref_id") WHERE "kind" = 'alert' AND "user_id" IS NOT NULL;
