-- V2 TASK-06: v2 verification photos are owned by the citizen (uploaded_by_user_id) instead of naming a v1
-- complaint; v1 rows keep satisfying the original rule.
ALTER TABLE "photos" DROP CONSTRAINT "ck_photos_verification_complaint";
ALTER TABLE "photos" ADD CONSTRAINT "ck_photos_verification_complaint" CHECK (purpose <> 'verification' OR uploaded_for_complaint_id IS NOT NULL OR uploaded_by_user_id IS NOT NULL);
