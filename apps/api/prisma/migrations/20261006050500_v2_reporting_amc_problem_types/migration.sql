-- V2 TASK-05 §5.2: AMC CCRS problem types (created here), photo ownership + blur flag, issue quota index.
-- issues GIST(location) and (category_id, created_at DESC) already exist (TASK-01).

CREATE TABLE "amc_problem_types" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "category_id" UUID NOT NULL,
    "source_key" CHAR(40) NOT NULL,
    "ccrs_row" INTEGER,
    "dept_en" VARCHAR(80) NOT NULL,
    "dept_gu" VARCHAR(120) NOT NULL,
    "problem_category_en" VARCHAR(160) NOT NULL,
    "problem_en" VARCHAR(300) NOT NULL,
    "problem_gu" VARCHAR(300) NOT NULL,
    "is_primary" BOOLEAN NOT NULL DEFAULT false,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "fetched_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_amc_problem_types" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "uq_amc_problem_types_source_key" ON "amc_problem_types"("source_key");
CREATE INDEX "idx_amc_problem_types_category" ON "amc_problem_types"("category_id", "is_active");

ALTER TABLE "amc_problem_types" ADD CONSTRAINT "fk_amc_problem_types_category" FOREIGN KEY ("category_id")
  REFERENCES "categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "photos" ADD COLUMN "uploaded_by_user_id" UUID;
ALTER TABLE "photos" ADD COLUMN "blur_applied" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "photos" ADD CONSTRAINT "fk_photos_uploaded_by_user" FOREIGN KEY ("uploaded_by_user_id")
  REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
CREATE INDEX "idx_photos_uploader_uploaded" ON "photos"("uploaded_by_user_id", "uploaded_at");

CREATE INDEX "idx_issues_reporter_created" ON "issues"("reporter_id", "created_at" DESC);

-- Hand-written (not expressible in schema.prisma): one primary problem per category.
CREATE UNIQUE INDEX "uq_amc_problem_types_primary" ON "amc_problem_types"("category_id") WHERE "is_primary";
