CREATE TABLE "admin_users" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "email" VARCHAR(255) NOT NULL,
    "password_hash" VARCHAR(255) NOT NULL,
    "display_name" VARCHAR(100) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "token_version" INTEGER NOT NULL DEFAULT 0,
    "last_login_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "admin_users_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "uq_admin_users_email" ON "admin_users"("email");

-- Hand-written: CHECK constraints are not expressible in the Prisma schema (04 §3.1).
ALTER TABLE "admin_users" ADD CONSTRAINT "ck_admin_users_email_lower" CHECK (email = lower(email));
ALTER TABLE "admin_users" ADD CONSTRAINT "ck_admin_users_token_version" CHECK (token_version >= 0);
