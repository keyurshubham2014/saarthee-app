-- V2 TASK-01 §5.2: v2 issue categories (Spec §4). Table only; rows come from the dev seed fixture
-- and TASK-05's reference data.
CREATE TABLE "categories" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "slug" VARCHAR(32) NOT NULL,
    "name_en" VARCHAR(60) NOT NULL,
    "name_gu" VARCHAR(60) NOT NULL,
    "icon" VARCHAR(64) NOT NULL,
    "colour_token" VARCHAR(40) NOT NULL,
    "sla_days" SMALLINT NOT NULL,
    "sensitive" BOOLEAN NOT NULL DEFAULT false,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_categories" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "uq_categories_slug" ON "categories"("slug");

CREATE INDEX "idx_categories_active_order" ON "categories"("is_active", "sort_order");

-- Hand-written CHECKs.
ALTER TABLE "categories" ADD CONSTRAINT "ck_categories_slug" CHECK (slug ~ '^[a-z][a-z_]{1,31}$');
ALTER TABLE "categories" ADD CONSTRAINT "ck_categories_sla" CHECK (sla_days BETWEEN 1 AND 365);
