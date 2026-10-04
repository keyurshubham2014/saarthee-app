-- CreateTable
CREATE TABLE "services" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "slug" VARCHAR(60) NOT NULL,
    "category" VARCHAR(20) NOT NULL,
    "name_en" VARCHAR(80) NOT NULL,
    "name_gu" VARCHAR(80) NOT NULL,
    "department" VARCHAR(100) NOT NULL,
    "department_gu" VARCHAR(100) NOT NULL,
    "summary_en" VARCHAR(300) NOT NULL,
    "summary_gu" VARCHAR(300) NOT NULL,
    "how_to_en" TEXT NOT NULL,
    "how_to_gu" TEXT NOT NULL,
    "url" VARCHAR(500) NOT NULL,
    "online" BOOLEAN NOT NULL,
    "visit_ward_office" BOOLEAN NOT NULL DEFAULT false,
    "sort_order" INTEGER NOT NULL DEFAULT 100,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "link_ok" BOOLEAN,
    "link_status_code" INTEGER,
    "link_error" VARCHAR(40),
    "last_checked_at" TIMESTAMPTZ(6),
    "verified_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_services" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "initiatives" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "title_en" VARCHAR(100) NOT NULL,
    "title_gu" VARCHAR(100) NOT NULL,
    "description_en" VARCHAR(1000) NOT NULL,
    "description_gu" VARCHAR(1000) NOT NULL,
    "type" VARCHAR(20) NOT NULL,
    "organiser" VARCHAR(20) NOT NULL,
    "organiser_name" VARCHAR(100) NOT NULL,
    "source_url" VARCHAR(500),
    "ward_id" UUID,
    "location_text_en" VARCHAR(200) NOT NULL,
    "location_text_gu" VARCHAR(200) NOT NULL,
    "location" geography(Point, 4326),
    "lat" DECIMAL(9,6),
    "lng" DECIMAL(9,6),
    "starts_at" TIMESTAMPTZ(6) NOT NULL,
    "ends_at" TIMESTAMPTZ(6) NOT NULL,
    "capacity" INTEGER,
    "status" VARCHAR(20) NOT NULL,
    "going_count" INTEGER NOT NULL DEFAULT 0,
    "reminder_sent_at" TIMESTAMPTZ(6),
    "created_by" UUID,
    "updated_by" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_initiatives" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "rsvps" (
    "initiative_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" VARCHAR(20) NOT NULL,
    "attendance_marked_by" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_rsvps" PRIMARY KEY ("initiative_id","user_id")
);

-- CreateTable
CREATE TABLE "service_tips" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "title_en" VARCHAR(80) NOT NULL,
    "title_gu" VARCHAR(80) NOT NULL,
    "body_en" VARCHAR(240) NOT NULL,
    "body_gu" VARCHAR(240) NOT NULL,
    "service_id" UUID,
    "ward_id" UUID,
    "active_from" DATE NOT NULL,
    "active_to" DATE NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_by" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_service_tips" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "idx_services_category_sort" ON "services"("category", "sort_order");

-- CreateIndex
CREATE UNIQUE INDEX "uq_services_slug" ON "services"("slug");

-- CreateIndex
CREATE INDEX "idx_initiatives_status_starts" ON "initiatives"("status", "starts_at");

-- CreateIndex
CREATE INDEX "idx_initiatives_ward_starts" ON "initiatives"("ward_id", "starts_at");

-- CreateIndex
CREATE INDEX "idx_rsvps_user" ON "rsvps"("user_id");

-- CreateIndex
CREATE INDEX "idx_service_tips_window" ON "service_tips"("active_from", "active_to");

-- AddForeignKey
ALTER TABLE "initiatives" ADD CONSTRAINT "fk_initiatives_ward" FOREIGN KEY ("ward_id") REFERENCES "wards"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "initiatives" ADD CONSTRAINT "fk_initiatives_created_by" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "initiatives" ADD CONSTRAINT "fk_initiatives_updated_by" FOREIGN KEY ("updated_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rsvps" ADD CONSTRAINT "fk_rsvps_initiative" FOREIGN KEY ("initiative_id") REFERENCES "initiatives"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rsvps" ADD CONSTRAINT "fk_rsvps_user" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "rsvps" ADD CONSTRAINT "fk_rsvps_marked_by" FOREIGN KEY ("attendance_marked_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_tips" ADD CONSTRAINT "fk_service_tips_service" FOREIGN KEY ("service_id") REFERENCES "services"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_tips" ADD CONSTRAINT "fk_service_tips_ward" FOREIGN KEY ("ward_id") REFERENCES "wards"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_tips" ADD CONSTRAINT "fk_service_tips_created_by" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Hand-written (V2 TASK-12 §5.2): CHECKs and the location trigger (not expressible in schema.prisma).
ALTER TABLE "services" ADD CONSTRAINT "ck_services_slug" CHECK (slug ~ '^[a-z0-9-]{3,60}$');
ALTER TABLE "services" ADD CONSTRAINT "ck_services_category" CHECK (category IN ('tax', 'certificates', 'building', 'health', 'education', 'transport', 'leisure', 'information', 'business'));
ALTER TABLE "services" ADD CONSTRAINT "ck_services_url" CHECK (url ~ '^https://');

ALTER TABLE "initiatives" ADD CONSTRAINT "ck_initiatives_type" CHECK (type IN ('tree_drive', 'cleanup', 'health_camp', 'other'));
ALTER TABLE "initiatives" ADD CONSTRAINT "ck_initiatives_organiser" CHECK (organiser IN ('AMC', 'RWA', 'NGO', 'Saarthee'));
ALTER TABLE "initiatives" ADD CONSTRAINT "ck_initiatives_status" CHECK (status IN ('draft', 'published', 'cancelled', 'completed'));
ALTER TABLE "initiatives" ADD CONSTRAINT "ck_initiatives_time" CHECK (ends_at > starts_at);
ALTER TABLE "initiatives" ADD CONSTRAINT "ck_initiatives_capacity" CHECK (capacity IS NULL OR capacity > 0);
ALTER TABLE "initiatives" ADD CONSTRAINT "ck_initiatives_going" CHECK (going_count >= 0);
ALTER TABLE "initiatives" ADD CONSTRAINT "ck_initiatives_amc_source" CHECK (organiser <> 'AMC' OR source_url IS NOT NULL);
ALTER TABLE "initiatives" ADD CONSTRAINT "ck_initiatives_source_url" CHECK (source_url IS NULL OR source_url ~ '^https://');
ALTER TABLE "initiatives" ADD CONSTRAINT "ck_initiatives_latlng" CHECK ((lat IS NULL) = (lng IS NULL));

ALTER TABLE "rsvps" ADD CONSTRAINT "ck_rsvps_status" CHECK (status IN ('going', 'cancelled', 'attended'));

ALTER TABLE "service_tips" ADD CONSTRAINT "ck_service_tips_window" CHECK (active_to >= active_from);

-- location mirrors lat/lng so the API only writes the two numbers.
CREATE FUNCTION initiatives_set_location() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.lat IS NULL OR NEW.lng IS NULL THEN
    NEW.location := NULL;
  ELSE
    NEW.location := ST_SetSRID(ST_MakePoint(NEW.lng::double precision, NEW.lat::double precision), 4326)::geography;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_initiatives_location BEFORE INSERT OR UPDATE OF lat, lng ON "initiatives"
  FOR EACH ROW EXECUTE FUNCTION initiatives_set_location();

