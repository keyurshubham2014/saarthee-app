-- V2 TASK-09 (REQ-D-008): representatives, their areas, assembly constituencies, ward ↔ AC mapping,
-- representative claims (used by TASK-11) and relayed citizen messages.
-- Personal numbers are refused by ck_representatives_public_phone: only an Ahmedabad 079 landline,
-- unless the representative consented through the TASK-11 claim flow (contact_consent_at).

CREATE TYPE "rep_role" AS ENUM ('corporator', 'mla', 'mp');
CREATE TYPE "rep_message_status" AS ENUM ('queued', 'sent', 'failed', 'replied');
CREATE TYPE "rep_claim_status" AS ENUM ('pending', 'approved', 'rejected');

CREATE TABLE "representatives" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name_en" VARCHAR(120) NOT NULL,
    "name_gu" VARCHAR(120) NOT NULL,
    "role" "rep_role" NOT NULL,
    "party_text" VARCHAR(80),
    "term_start" DATE NOT NULL,
    "term_end" DATE,
    "public_phone" VARCHAR(16),
    "public_email" VARCHAR(254),
    "contact_consent_at" TIMESTAMPTZ(6),
    "photo_url" VARCHAR(500),
    "source_url" VARCHAR(500) NOT NULL,
    "last_verified_at" DATE NOT NULL,
    "user_id" UUID,
    "verified_at" TIMESTAMPTZ(6),
    "verified_method" VARCHAR(40),
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "pk_representatives" PRIMARY KEY ("id"),
    CONSTRAINT "ck_representatives_name_en" CHECK (char_length("name_en") BETWEEN 2 AND 120),
    CONSTRAINT "ck_representatives_name_gu" CHECK (char_length("name_gu") BETWEEN 2 AND 120),
    CONSTRAINT "ck_representatives_term" CHECK ("term_end" IS NULL OR "term_end" > "term_start"),
    CONSTRAINT "ck_representatives_public_phone" CHECK ("public_phone" IS NULL OR "public_phone" ~ '^\+9179\d{8}$' OR "contact_consent_at" IS NOT NULL),
    CONSTRAINT "ck_representatives_public_email" CHECK ("public_email" IS NULL OR "public_email" = lower("public_email")),
    CONSTRAINT "ck_representatives_source_url" CHECK ("source_url" ~ '^https://')
);
CREATE UNIQUE INDEX "uq_representatives_user" ON "representatives"("user_id");
CREATE UNIQUE INDEX "uq_representatives_import_key" ON "representatives"("role", lower("name_en"), "term_start");
ALTER TABLE "representatives" ADD CONSTRAINT "fk_representatives_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "assembly_constituencies" (
    "id" SERIAL NOT NULL,
    "number" INTEGER NOT NULL,
    "name_en" VARCHAR(80) NOT NULL,
    "name_gu" VARCHAR(80) NOT NULL,
    "pc_name_en" VARCHAR(80) NOT NULL,
    "pc_name_gu" VARCHAR(80) NOT NULL,
    "source_url" VARCHAR(500) NOT NULL,
    CONSTRAINT "pk_assembly_constituencies" PRIMARY KEY ("id"),
    CONSTRAINT "ck_assembly_constituencies_source_url" CHECK ("source_url" ~ '^https://')
);
CREATE UNIQUE INDEX "uq_assembly_constituencies_number" ON "assembly_constituencies"("number");

CREATE TABLE "representative_areas" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "representative_id" UUID NOT NULL,
    "ward_id" UUID,
    "assembly_constituency_id" INTEGER,
    CONSTRAINT "pk_representative_areas" PRIMARY KEY ("id"),
    CONSTRAINT "ck_representative_areas_one" CHECK (num_nonnulls("ward_id", "assembly_constituency_id") = 1)
);
CREATE UNIQUE INDEX "uq_representative_areas_ward" ON "representative_areas"("representative_id", "ward_id");
CREATE UNIQUE INDEX "uq_representative_areas_ac" ON "representative_areas"("representative_id", "assembly_constituency_id");
CREATE INDEX "idx_representative_areas_ward" ON "representative_areas"("ward_id");
CREATE INDEX "idx_representative_areas_ac" ON "representative_areas"("assembly_constituency_id");
ALTER TABLE "representative_areas" ADD CONSTRAINT "fk_representative_areas_rep" FOREIGN KEY ("representative_id") REFERENCES "representatives"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "representative_areas" ADD CONSTRAINT "fk_representative_areas_ward" FOREIGN KEY ("ward_id") REFERENCES "wards"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "representative_areas" ADD CONSTRAINT "fk_representative_areas_ac" FOREIGN KEY ("assembly_constituency_id") REFERENCES "assembly_constituencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "ward_constituency" (
    "ward_id" UUID NOT NULL,
    "assembly_constituency_id" INTEGER NOT NULL,
    "source_url" VARCHAR(500) NOT NULL,
    CONSTRAINT "pk_ward_constituency" PRIMARY KEY ("ward_id", "assembly_constituency_id"),
    CONSTRAINT "ck_ward_constituency_source_url" CHECK ("source_url" ~ '^https://')
);
CREATE INDEX "idx_ward_constituency_ac" ON "ward_constituency"("assembly_constituency_id");
ALTER TABLE "ward_constituency" ADD CONSTRAINT "fk_ward_constituency_ward" FOREIGN KEY ("ward_id") REFERENCES "wards"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ward_constituency" ADD CONSTRAINT "fk_ward_constituency_ac" FOREIGN KEY ("assembly_constituency_id") REFERENCES "assembly_constituencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "rep_claims" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "representative_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "evidence_photo_ids" UUID[] NOT NULL DEFAULT ARRAY[]::UUID[],
    "otp_verified" BOOLEAN NOT NULL DEFAULT false,
    "status" "rep_claim_status" NOT NULL DEFAULT 'pending',
    "reviewer_id" UUID,
    "decided_at" TIMESTAMPTZ(6),
    "note" VARCHAR(500),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "pk_rep_claims" PRIMARY KEY ("id")
);
CREATE INDEX "idx_rep_claims_rep" ON "rep_claims"("representative_id");
CREATE INDEX "idx_rep_claims_user" ON "rep_claims"("user_id");
ALTER TABLE "rep_claims" ADD CONSTRAINT "fk_rep_claims_rep" FOREIGN KEY ("representative_id") REFERENCES "representatives"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "rep_claims" ADD CONSTRAINT "fk_rep_claims_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "rep_claims" ADD CONSTRAINT "fk_rep_claims_reviewer" FOREIGN KEY ("reviewer_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "rep_messages" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "client_message_id" UUID NOT NULL,
    "representative_id" UUID NOT NULL,
    "citizen_id" UUID,
    "issue_id" UUID,
    "subject" VARCHAR(120) NOT NULL,
    "body" VARCHAR(1000) NOT NULL,
    "share_phone" BOOLEAN NOT NULL DEFAULT false,
    "status" "rep_message_status" NOT NULL DEFAULT 'queued',
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "next_attempt_at" TIMESTAMPTZ(6),
    "provider_message_id" VARCHAR(200),
    "sent_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "pk_rep_messages" PRIMARY KEY ("id"),
    CONSTRAINT "ck_rep_messages_subject" CHECK (char_length("subject") BETWEEN 3 AND 120),
    CONSTRAINT "ck_rep_messages_body" CHECK (char_length("body") BETWEEN 10 AND 1000)
);
CREATE UNIQUE INDEX "uq_rep_messages_client_message" ON "rep_messages"("client_message_id");
CREATE INDEX "idx_rep_messages_citizen_rep_created" ON "rep_messages"("citizen_id", "representative_id", "created_at");
CREATE INDEX "idx_rep_messages_status" ON "rep_messages"("status", "next_attempt_at");
ALTER TABLE "rep_messages" ADD CONSTRAINT "fk_rep_messages_rep" FOREIGN KEY ("representative_id") REFERENCES "representatives"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "rep_messages" ADD CONSTRAINT "fk_rep_messages_citizen" FOREIGN KEY ("citizen_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "rep_messages" ADD CONSTRAINT "fk_rep_messages_issue" FOREIGN KEY ("issue_id") REFERENCES "issues"("id") ON DELETE SET NULL ON UPDATE CASCADE;
