-- V2 TASK-01 §5.2: issue photos, status history, verifications, me-toos, follows (Spec §5, §6).
CREATE TABLE "issue_photos" (
    "issue_id" UUID NOT NULL,
    "photo_id" UUID NOT NULL,
    "kind" "issue_photo_kind" NOT NULL,
    "position" SMALLINT NOT NULL DEFAULT 0,

    CONSTRAINT "pk_issue_photos" PRIMARY KEY ("issue_id", "photo_id")
);

CREATE UNIQUE INDEX "uq_issue_photos_photo" ON "issue_photos"("photo_id");

CREATE UNIQUE INDEX "uq_issue_photos_position" ON "issue_photos"("issue_id", "kind", "position");

CREATE TABLE "issue_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "issue_id" UUID NOT NULL,
    "actor_id" UUID,
    "actor_role" "actor_role" NOT NULL,
    "type" "issue_event_type" NOT NULL,
    "from_status" "issue_status",
    "to_status" "issue_status",
    "note" VARCHAR(500),
    "photo_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_issue_events" PRIMARY KEY ("id")
);

CREATE INDEX "idx_issue_events_issue_created" ON "issue_events"("issue_id", "created_at");

CREATE INDEX "idx_issue_events_actor" ON "issue_events"("actor_id");

CREATE TABLE "issue_verifications" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "issue_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "answer" "verification_result" NOT NULL,
    "photo_id" UUID,
    "lat" DECIMAL(9,6),
    "lng" DECIMAL(9,6),
    "distance_m" DECIMAL(8,1),
    "created_day" DATE NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_issue_verifications" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "uq_issue_verifications_daily" ON "issue_verifications"("issue_id", "user_id", "created_day");

CREATE INDEX "idx_issue_verifications_user" ON "issue_verifications"("user_id");

CREATE TABLE "me_toos" (
    "issue_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_me_toos" PRIMARY KEY ("issue_id", "user_id")
);

CREATE INDEX "idx_me_toos_user_created" ON "me_toos"("user_id", "created_at" DESC);

CREATE TABLE "follows" (
    "issue_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_follows" PRIMARY KEY ("issue_id", "user_id")
);

CREATE INDEX "idx_follows_user_created" ON "follows"("user_id", "created_at" DESC);

ALTER TABLE "issue_photos" ADD CONSTRAINT "fk_issue_photos_issue" FOREIGN KEY ("issue_id") REFERENCES "issues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "issue_photos" ADD CONSTRAINT "fk_issue_photos_photo" FOREIGN KEY ("photo_id") REFERENCES "photos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "issue_events" ADD CONSTRAINT "fk_issue_events_issue" FOREIGN KEY ("issue_id") REFERENCES "issues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "issue_events" ADD CONSTRAINT "fk_issue_events_actor" FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "issue_events" ADD CONSTRAINT "fk_issue_events_photo" FOREIGN KEY ("photo_id") REFERENCES "photos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "issue_verifications" ADD CONSTRAINT "fk_issue_verifications_issue" FOREIGN KEY ("issue_id") REFERENCES "issues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "issue_verifications" ADD CONSTRAINT "fk_issue_verifications_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "issue_verifications" ADD CONSTRAINT "fk_issue_verifications_photo" FOREIGN KEY ("photo_id") REFERENCES "photos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "me_toos" ADD CONSTRAINT "fk_me_toos_issue" FOREIGN KEY ("issue_id") REFERENCES "issues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "me_toos" ADD CONSTRAINT "fk_me_toos_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "follows" ADD CONSTRAINT "fk_follows_issue" FOREIGN KEY ("issue_id") REFERENCES "issues"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "follows" ADD CONSTRAINT "fk_follows_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Hand-written CHECKs and the append-only rule for issue_events.
-- Report photos use positions 0–2 (max 3 per report); after/verification photos count up from 0.
ALTER TABLE "issue_photos" ADD CONSTRAINT "ck_issue_photos_position" CHECK (position >= 0 AND (kind <> 'report' OR position <= 2));
ALTER TABLE "issue_events" ADD CONSTRAINT "ck_issue_events_status" CHECK (type <> 'status_change' OR to_status IS NOT NULL);
ALTER TABLE "issue_verifications" ADD CONSTRAINT "ck_issue_verifications_coords" CHECK ((lat IS NULL OR lat BETWEEN -90 AND 90) AND (lng IS NULL OR lng BETWEEN -180 AND 180));
ALTER TABLE "issue_verifications" ADD CONSTRAINT "ck_issue_verifications_distance" CHECK (distance_m IS NULL OR distance_m >= 0);

-- Status history is append-only (Spec §5). The only exception is a maintenance write in the same
-- transaction with saarthee.legacy_write = 'on' (withLegacyWrite in src/lib/db), e.g. TASK-04 erasure
-- nulling actor_id. TRUNCATE (test resets) is not a row event and is unaffected.
CREATE FUNCTION issue_events_append_only() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF coalesce(current_setting('saarthee.legacy_write', true), '') = 'on' THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'ISSUE_EVENTS_APPEND_ONLY' USING ERRCODE = 'P0001';
END;
$$;

CREATE TRIGGER trg_issue_events_append_only BEFORE UPDATE OR DELETE ON "issue_events"
  FOR EACH ROW EXECUTE FUNCTION issue_events_append_only();
