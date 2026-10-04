-- V2 TASK-01 §5.2: citizens/staff, consents, devices (Spec §6). home_ward_id gets its FK in TASK-02.
CREATE TABLE "users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "phone_e164" VARCHAR(16),
    "firebase_uid" VARCHAR(128),
    "display_name" VARCHAR(60),
    "home_ward_id" UUID,
    "language" "app_language" NOT NULL DEFAULT 'gu',
    "role" "user_role" NOT NULL DEFAULT 'citizen',
    "status" "user_status" NOT NULL DEFAULT 'active',
    "token_version" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMPTZ(6),
    "deleted_at" TIMESTAMPTZ(6),

    CONSTRAINT "pk_users" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "uq_users_phone" ON "users"("phone_e164");

CREATE UNIQUE INDEX "uq_users_firebase_uid" ON "users"("firebase_uid");

CREATE TABLE "consents" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID NOT NULL,
    "purpose" "consent_purpose" NOT NULL,
    "text_version" VARCHAR(20) NOT NULL,
    "granted_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "withdrawn_at" TIMESTAMPTZ(6),

    CONSTRAINT "pk_consents" PRIMARY KEY ("id")
);

CREATE INDEX "idx_consents_user" ON "consents"("user_id");

CREATE TABLE "devices" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" UUID,
    "install_id" UUID NOT NULL,
    "fcm_token" VARCHAR(4096),
    "platform" "platform" NOT NULL,
    "app_version" VARCHAR(20) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_devices" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "uq_devices_install" ON "devices"("install_id");

CREATE UNIQUE INDEX "uq_devices_fcm_token" ON "devices"("fcm_token");

CREATE INDEX "idx_devices_user" ON "devices"("user_id");

ALTER TABLE "consents" ADD CONSTRAINT "fk_consents_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "devices" ADD CONSTRAINT "fk_devices_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Hand-written: CHECKs and partial indexes (not expressible in schema.prisma).
-- Any E.164 number is accepted here; the app restricts sign-in to +91 (TASK-01 §5.6).
ALTER TABLE "users" ADD CONSTRAINT "ck_users_phone" CHECK (phone_e164 IS NULL OR phone_e164 ~ '^\+[1-9][0-9]{7,14}$');
-- A deleted (erased) account keeps no identifiers; every other account has a Firebase identity.
ALTER TABLE "users" ADD CONSTRAINT "ck_users_deleted" CHECK (status <> 'deleted' OR (phone_e164 IS NULL AND firebase_uid IS NULL));
ALTER TABLE "users" ADD CONSTRAINT "ck_users_active_identity" CHECK (status = 'deleted' OR firebase_uid IS NOT NULL);
ALTER TABLE "users" ADD CONSTRAINT "ck_users_token_version" CHECK (token_version >= 0);
CREATE INDEX "idx_users_role" ON "users"("role") WHERE role <> 'citizen';

-- One active (not withdrawn) consent per user and purpose; withdrawing allows a new grant.
CREATE UNIQUE INDEX "uq_consents_active" ON "consents"("user_id", "purpose") WHERE withdrawn_at IS NULL;
ALTER TABLE "consents" ADD CONSTRAINT "ck_consents_order" CHECK (withdrawn_at IS NULL OR withdrawn_at >= granted_at);
