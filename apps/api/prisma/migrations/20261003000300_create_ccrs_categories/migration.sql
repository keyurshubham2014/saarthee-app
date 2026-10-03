CREATE TABLE "ccrs_categories" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(100) NOT NULL,
    "ccrs_label" VARCHAR(150),
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ccrs_categories_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "idx_ccrs_categories_active_order" ON "ccrs_categories"("is_active", "sort_order");

CREATE UNIQUE INDEX "uq_ccrs_categories_name" ON "ccrs_categories"("name");

-- Hand-written: CHECK constraint (04 §3.3).
ALTER TABLE "ccrs_categories" ADD CONSTRAINT "ck_ccrs_categories_sort_order" CHECK (sort_order >= 0);
