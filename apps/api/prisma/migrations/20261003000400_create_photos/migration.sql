CREATE TABLE "photos" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "storage_driver" "storage_driver" NOT NULL DEFAULT 'local',
    "storage_key" VARCHAR(255) NOT NULL,
    "purpose" "photo_purpose" NOT NULL,
    "mime_type" VARCHAR(50) NOT NULL,
    "byte_size" INTEGER NOT NULL,
    "width_px" INTEGER,
    "height_px" INTEGER,
    "sha256" CHAR(64) NOT NULL,
    "uploaded_for_complaint_id" UUID,
    "uploaded_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "attached_at" TIMESTAMPTZ(6),
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "photos_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "idx_photos_sha256" ON "photos"("sha256");

CREATE INDEX "idx_photos_uploaded_for_complaint" ON "photos"("uploaded_for_complaint_id");

CREATE UNIQUE INDEX "uq_photos_storage_key" ON "photos"("storage_key");

-- Hand-written: CHECKs and the partial index for the unattached-photo cleanup job (04 §3.4);
-- Prisma cannot express either.
ALTER TABLE "photos" ADD CONSTRAINT "ck_photos_mime" CHECK (mime_type = 'image/jpeg');
ALTER TABLE "photos" ADD CONSTRAINT "ck_photos_size" CHECK (byte_size > 0);
ALTER TABLE "photos" ADD CONSTRAINT "ck_photos_dims" CHECK ((width_px IS NULL OR width_px > 0) AND (height_px IS NULL OR height_px > 0));
ALTER TABLE "photos" ADD CONSTRAINT "ck_photos_sha256" CHECK (sha256 ~ '^[0-9a-f]{64}$');
ALTER TABLE "photos" ADD CONSTRAINT "ck_photos_verification_complaint" CHECK (purpose <> 'verification' OR uploaded_for_complaint_id IS NOT NULL);
CREATE INDEX "idx_photos_unattached" ON "photos"("uploaded_at") WHERE attached_at IS NULL;
