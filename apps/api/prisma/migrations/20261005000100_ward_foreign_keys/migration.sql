-- V2 TASK-02 §5.2: link issues and users to wards/zones (columns created by TASK-01 as plain uuid).
-- "zone = the ward's zone" is enforced by the services (resolveWard, geo:backfill), not by a CHECK.
CREATE INDEX "idx_issues_zone" ON "issues"("zone_id");
CREATE INDEX "idx_users_home_ward" ON "users"("home_ward_id");

ALTER TABLE "issues" ADD CONSTRAINT "fk_issues_ward" FOREIGN KEY ("ward_id") REFERENCES "wards"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "issues" ADD CONSTRAINT "fk_issues_zone" FOREIGN KEY ("zone_id") REFERENCES "zones"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "users" ADD CONSTRAINT "fk_users_home_ward" FOREIGN KEY ("home_ward_id") REFERENCES "wards"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;
