-- V2 TASK-02 §5.2: AMC zones and wards (OpenCity ward KML, cross-checked with AMC's ward list).
-- Geometry is planar EPSG:4326 (`geometry`, not `geography`) so ST_Covers / ST_Union / ST_IsValid work on
-- polygons; distances are computed by casting to geography in queries.
CREATE TABLE "zones" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "code" VARCHAR(20) NOT NULL,
    "name_en" VARCHAR(60) NOT NULL,
    "name_gu" VARCHAR(60) NOT NULL,
    "sort_order" SMALLINT NOT NULL DEFAULT 0,
    "geom" geometry(MultiPolygon, 4326),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_zones" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "uq_zones_code" ON "zones"("code");
CREATE INDEX "idx_zones_geom" ON "zones" USING GIST ("geom");

CREATE TABLE "wards" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "number" SMALLINT NOT NULL,
    "name_en" VARCHAR(60) NOT NULL,
    "name_gu" VARCHAR(60) NOT NULL,
    "zone_id" UUID NOT NULL,
    "geom" geometry(MultiPolygon, 4326) NOT NULL,
    "centroid" geometry(Point, 4326) NOT NULL,
    "boundary_version" VARCHAR(60) NOT NULL,
    "office_address_en" VARCHAR(300),
    "office_address_gu" VARCHAR(300),
    "office_phone" VARCHAR(20),
    "population" INTEGER,
    "source_url" VARCHAR(500) NOT NULL,
    "last_verified_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "pk_wards" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "uq_wards_number" ON "wards"("number");
CREATE INDEX "idx_wards_zone" ON "wards"("zone_id");
CREATE INDEX "idx_wards_geom" ON "wards" USING GIST ("geom");

ALTER TABLE "wards" ADD CONSTRAINT "fk_wards_zone" FOREIGN KEY ("zone_id") REFERENCES "zones"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;

-- Hand-written CHECKs.
ALTER TABLE "zones" ADD CONSTRAINT "ck_zones_code" CHECK (code ~ '^[a-z_]{3,20}$');
ALTER TABLE "wards" ADD CONSTRAINT "ck_wards_number" CHECK (number BETWEEN 1 AND 99);
ALTER TABLE "wards" ADD CONSTRAINT "ck_wards_geom_valid" CHECK (ST_IsValid(geom));
-- Public ward-office numbers only (never personal numbers).
ALTER TABLE "wards" ADD CONSTRAINT "ck_wards_phone" CHECK (office_phone IS NULL OR office_phone ~ '^[0-9+ -]{6,20}$');
ALTER TABLE "wards" ADD CONSTRAINT "ck_wards_population" CHECK (population IS NULL OR population >= 0);
