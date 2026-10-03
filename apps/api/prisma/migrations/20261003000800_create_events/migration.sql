CREATE TABLE "events" (
    "id" BIGINT GENERATED ALWAYS AS IDENTITY,
    "name" VARCHAR(50) NOT NULL,
    "install_id" UUID,
    "admin_user_id" UUID,
    "complaint_id" UUID,
    "source_tag" "source_tag",
    "properties" JSONB NOT NULL DEFAULT '{}',
    "platform" "platform",
    "app_version" VARCHAR(20),
    "occurred_at" TIMESTAMPTZ(6) NOT NULL,
    "received_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "idx_events_name_received" ON "events"("name", "received_at");

CREATE INDEX "idx_events_complaint" ON "events"("complaint_id");

CREATE INDEX "idx_events_install" ON "events"("install_id");

ALTER TABLE "events" ADD CONSTRAINT "events_admin_user_id_fkey" FOREIGN KEY ("admin_user_id") REFERENCES "admin_users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "events" ADD CONSTRAINT "events_complaint_id_fkey" FOREIGN KEY ("complaint_id") REFERENCES "complaints"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Hand-written: event-name allow-list (04 §3.8). The id column above was changed from Prisma's
-- BIGSERIAL to an identity column by hand because Prisma cannot declare GENERATED ALWAYS AS IDENTITY.
ALTER TABLE "events" ADD CONSTRAINT "ck_events_name" CHECK (name IN ('invite_code_entered','report_opened','ccrs_handoff_clicked','report_submitted','reminder_sent','verify_opened','deep_link_failed','verify_submitted','record_flagged'));
