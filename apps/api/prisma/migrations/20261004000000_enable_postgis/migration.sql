-- V2 TASK-01 (Spec D10): PostGIS for ward polygons and issue locations. Requires the
-- postgis/postgis:17-3.5 image (infra/docker-compose.yml); see scripts/db-upgrade-postgis.sh.
CREATE EXTENSION IF NOT EXISTS postgis;
