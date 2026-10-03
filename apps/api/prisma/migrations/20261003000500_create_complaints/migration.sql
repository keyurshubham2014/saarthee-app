CREATE TABLE "complaints" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "client_submission_id" UUID NOT NULL,
    "invite_code_id" UUID,
    "source_tag" "source_tag" NOT NULL DEFAULT 'unknown',
    "category_id" UUID NOT NULL,
    "ccrs_number_raw" VARCHAR(50) NOT NULL,
    "ccrs_number_normalized" VARCHAR(50) NOT NULL,
    "ccrs_duplicate_flag" BOOLEAN NOT NULL DEFAULT false,
    "photo_id" UUID NOT NULL,
    "latitude" DECIMAL(9,6) NOT NULL,
    "longitude" DECIMAL(9,6) NOT NULL,
    "gps_accuracy_m" DECIMAL(8,2),
    "device_captured_at" TIMESTAMPTZ(6) NOT NULL,
    "phone_e164" VARCHAR(16),
    "consent_given_at" TIMESTAMPTZ(6) NOT NULL,
    "consent_text_version" VARCHAR(20) NOT NULL,
    "app_platform" "platform" NOT NULL,
    "app_version" VARCHAR(20) NOT NULL,
    "ward_code" VARCHAR(50),
    "is_excluded" BOOLEAN NOT NULL DEFAULT false,
    "exclusion_reason" "exclusion_reason",
    "exclusion_note" VARCHAR(500),
    "excluded_by" UUID,
    "excluded_at" TIMESTAMPTZ(6),
    "anonymized_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "complaints_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "idx_complaints_ccrs_norm" ON "complaints"("ccrs_number_normalized");

CREATE INDEX "idx_complaints_source_created" ON "complaints"("source_tag", "created_at");

CREATE INDEX "idx_complaints_category" ON "complaints"("category_id");

CREATE INDEX "idx_complaints_phone" ON "complaints"("phone_e164");

CREATE INDEX "idx_complaints_invite_code" ON "complaints"("invite_code_id");

CREATE UNIQUE INDEX "uq_complaints_client_submission" ON "complaints"("client_submission_id");

CREATE UNIQUE INDEX "uq_complaints_photo" ON "complaints"("photo_id");

ALTER TABLE "photos" ADD CONSTRAINT "photos_uploaded_for_complaint_id_fkey" FOREIGN KEY ("uploaded_for_complaint_id") REFERENCES "complaints"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "complaints" ADD CONSTRAINT "complaints_invite_code_id_fkey" FOREIGN KEY ("invite_code_id") REFERENCES "invite_codes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "complaints" ADD CONSTRAINT "complaints_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "ccrs_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "complaints" ADD CONSTRAINT "complaints_photo_id_fkey" FOREIGN KEY ("photo_id") REFERENCES "photos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "complaints" ADD CONSTRAINT "complaints_excluded_by_fkey" FOREIGN KEY ("excluded_by") REFERENCES "admin_users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Hand-written: CHECKs and the partial index over included complaints (04 §3.5).
-- The photos.uploaded_for_complaint_id FK is added here (above) to resolve the photos <-> complaints cycle.
ALTER TABLE "complaints" ADD CONSTRAINT "ck_complaints_lat" CHECK (latitude BETWEEN -90 AND 90);
ALTER TABLE "complaints" ADD CONSTRAINT "ck_complaints_lng" CHECK (longitude BETWEEN -180 AND 180);
ALTER TABLE "complaints" ADD CONSTRAINT "ck_complaints_accuracy" CHECK (gps_accuracy_m IS NULL OR gps_accuracy_m >= 0);
ALTER TABLE "complaints" ADD CONSTRAINT "ck_complaints_phone" CHECK (phone_e164 IS NULL OR phone_e164 ~ '^\+91[6-9][0-9]{9}$');
ALTER TABLE "complaints" ADD CONSTRAINT "ck_complaints_exclusion" CHECK (NOT is_excluded OR exclusion_reason IS NOT NULL);
ALTER TABLE "complaints" ADD CONSTRAINT "ck_complaints_ccrs_raw" CHECK (length(trim(ccrs_number_raw)) > 0);
CREATE INDEX "idx_complaints_included_created" ON "complaints"("created_at") WHERE is_excluded = false;
