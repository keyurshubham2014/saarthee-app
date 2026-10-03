CREATE TABLE "verifications" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "client_submission_id" UUID NOT NULL,
    "complaint_id" UUID NOT NULL,
    "reminder_id" UUID,
    "result" "verification_result" NOT NULL,
    "photo_id" UUID NOT NULL,
    "latitude" DECIMAL(9,6) NOT NULL,
    "longitude" DECIMAL(9,6) NOT NULL,
    "gps_accuracy_m" DECIMAL(8,2),
    "device_captured_at" TIMESTAMPTZ(6) NOT NULL,
    "distance_from_report_m" DECIMAL(10,2),
    "note" VARCHAR(1000),
    "app_platform" "platform" NOT NULL,
    "app_version" VARCHAR(20) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "verifications_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "idx_verifications_complaint_created" ON "verifications"("complaint_id", "created_at" DESC);

CREATE INDEX "idx_verifications_reminder" ON "verifications"("reminder_id");

CREATE UNIQUE INDEX "uq_verifications_client_submission" ON "verifications"("client_submission_id");

CREATE UNIQUE INDEX "uq_verifications_photo" ON "verifications"("photo_id");

ALTER TABLE "verifications" ADD CONSTRAINT "verifications_complaint_id_fkey" FOREIGN KEY ("complaint_id") REFERENCES "complaints"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "verifications" ADD CONSTRAINT "verifications_reminder_id_fkey" FOREIGN KEY ("reminder_id") REFERENCES "reminders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "verifications" ADD CONSTRAINT "verifications_photo_id_fkey" FOREIGN KEY ("photo_id") REFERENCES "photos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Hand-written: CHECKs (04 §3.7).
ALTER TABLE "verifications" ADD CONSTRAINT "ck_verifications_lat" CHECK (latitude BETWEEN -90 AND 90);
ALTER TABLE "verifications" ADD CONSTRAINT "ck_verifications_lng" CHECK (longitude BETWEEN -180 AND 180);
ALTER TABLE "verifications" ADD CONSTRAINT "ck_verifications_accuracy" CHECK (gps_accuracy_m IS NULL OR gps_accuracy_m >= 0);
ALTER TABLE "verifications" ADD CONSTRAINT "ck_verifications_distance" CHECK (distance_from_report_m IS NULL OR distance_from_report_m >= 0);
