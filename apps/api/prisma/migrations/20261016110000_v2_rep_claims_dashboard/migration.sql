-- V2 TASK-11 (REQ-F-053…056): representative claim review fields, per-term verification, reply tracking for
-- relayed messages, private claim evidence photos and the representative ward scope view.

-- Claim lifecycle beyond TASK-09's pending/approved/rejected.
ALTER TYPE "rep_claim_status" ADD VALUE IF NOT EXISTS 'expired';
ALTER TYPE "rep_claim_status" ADD VALUE IF NOT EXISTS 'revoked';
ALTER TYPE "rep_claim_status" ADD VALUE IF NOT EXISTS 'withdrawn';

-- Evidence photos for claims: private, admin-only, never attached to an issue.
ALTER TYPE "photo_purpose" ADD VALUE IF NOT EXISTS 'rep_evidence';

ALTER TABLE "rep_claims"
  ADD COLUMN "phone_match" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "claimant_note" VARCHAR(500),
  ADD COLUMN "reject_reason" VARCHAR(300),
  ADD COLUMN "verified_method" VARCHAR(30),
  ADD COLUMN "term_end" DATE;
-- One pending claim per (representative, user); the API maps a violation to CLAIM_ALREADY_PENDING.
CREATE UNIQUE INDEX "rep_claims_one_pending" ON "rep_claims"("representative_id", "user_id") WHERE "status" = 'pending';
CREATE INDEX "idx_rep_claims_status_created" ON "rep_claims"("status", "created_at");

ALTER TABLE "representatives" ADD CONSTRAINT "representatives_verified_method_chk"
  CHECK ("verified_method" IS NULL OR "verified_method" IN ('certificate_of_election', 'official_gazette', 'in_person', 'official_email'));

ALTER TABLE "rep_messages"
  ADD COLUMN "reply_token" CHAR(32),
  ADD COLUMN "replied_at" TIMESTAMPTZ(6),
  ADD COLUMN "reply_channel" VARCHAR(10),
  ADD COLUMN "reply_body" VARCHAR(2000),
  ADD COLUMN "read_by_rep_at" TIMESTAMPTZ(6),
  ADD CONSTRAINT "ck_rep_messages_reply_channel" CHECK ("reply_channel" IS NULL OR "reply_channel" IN ('email', 'in_app'));
CREATE UNIQUE INDEX "uq_rep_messages_reply_token" ON "rep_messages"("reply_token");
CREATE INDEX "idx_rep_messages_rep_created" ON "rep_messages"("representative_id", "created_at");

-- Wards a signed-in representative may act on: verified, active, in term (term_end today still counts).
-- Corporators through representative_areas.ward_id; MLA/MP through their constituency's ward_constituency rows.
CREATE VIEW "rep_scope_wards_v" AS
SELECT DISTINCT r."user_id", r."id" AS "representative_id", w."ward_id"
FROM "representatives" r
JOIN "representative_areas" a ON a."representative_id" = r."id"
JOIN LATERAL (
  SELECT a."ward_id" WHERE a."ward_id" IS NOT NULL
  UNION
  SELECT wc."ward_id" FROM "ward_constituency" wc WHERE wc."assembly_constituency_id" = a."assembly_constituency_id"
) w ON true
WHERE r."user_id" IS NOT NULL
  AND r."verified_at" IS NOT NULL
  AND r."is_active"
  AND (r."term_end" IS NULL OR r."term_end" >= (now() AT TIME ZONE 'Asia/Kolkata')::date);
