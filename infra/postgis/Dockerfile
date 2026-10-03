# Native PostGIS for local dev/test (TASK-01). The official postgis/postgis image has no arm64 build,
# and running it under qemu made tests hang on Apple Silicon. Same Postgres 17.6 as v1, plus PostGIS 3
# from the PGDG apt repository that the official postgres image already configures.
FROM postgres:17.6
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-17-postgis-3 postgresql-17-postgis-3-scripts \
 && rm -rf /var/lib/apt/lists/*
