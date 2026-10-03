CREATE TABLE "invite_codes" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" VARCHAR(20) NOT NULL,
    "source_tag" "source_tag" NOT NULL,
    "group_label" VARCHAR(120) NOT NULL,
    "ward_hint" VARCHAR(50),
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_by" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "invite_codes_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "idx_invite_codes_source_tag" ON "invite_codes"("source_tag");

CREATE INDEX "idx_invite_codes_created_by" ON "invite_codes"("created_by");

CREATE UNIQUE INDEX "uq_invite_codes_code" ON "invite_codes"("code");

ALTER TABLE "invite_codes" ADD CONSTRAINT "invite_codes_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "admin_users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Hand-written: CHECK constraints (04 §3.2).
ALTER TABLE "invite_codes" ADD CONSTRAINT "ck_invite_codes_code" CHECK (code ~ '^[A-Z0-9]{6,20}$');
ALTER TABLE "invite_codes" ADD CONSTRAINT "ck_invite_codes_source_tag" CHECK (source_tag <> 'unknown');
