#!/usr/bin/env bash
# Switch the local database container from postgres:17.6 to postgis/postgis:17-3.5 without losing data
# (V2 TASK-01 §6 steps 1–2, AC-1). Development only.
#
#   npm run db:upgrade-postgis                 dump → switch image → compare row counts (auto-restore on mismatch)
#   npm run db:upgrade-postgis -- --restore F  restore path only: down -v, fresh PostGIS volume, pg_restore F, recount
#
# Env overrides: SAARTHEE_BACKUP_DIR (default ~/saarthee-data/backups, outside the repo),
#                COMPOSE_FILE_PATH / COMPOSE_ENV_FILE (default infra/docker-compose.yml + infra/.env of this checkout).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE_PATH="${COMPOSE_FILE_PATH:-$ROOT/infra/docker-compose.yml}"
COMPOSE_ENV_FILE="${COMPOSE_ENV_FILE:-$ROOT/infra/.env}"
BACKUP_DIR="${SAARTHEE_BACKUP_DIR:-$HOME/saarthee-data/backups}"
V1_TABLES=(admin_users invite_codes ccrs_categories photos complaints reminders verifications events _prisma_migrations)

APP_ENV_VALUE="${APP_ENV:-$(grep -E '^APP_ENV=' "$ROOT/apps/api/.env" 2>/dev/null | cut -d= -f2 || true)}"
if [ "$APP_ENV_VALUE" != "development" ]; then
  echo "db:upgrade-postgis refused: APP_ENV is '${APP_ENV_VALUE:-unset}', must be development." >&2; exit 1
fi
[ -f "$COMPOSE_ENV_FILE" ] || { echo "Missing $COMPOSE_ENV_FILE" >&2; exit 1; }
set -a; # shellcheck disable=SC1090
source "$COMPOSE_ENV_FILE"; set +a
COMPOSE=(docker compose -f "$COMPOSE_FILE_PATH" --env-file "$COMPOSE_ENV_FILE")
psql_db() { "${COMPOSE[@]}" exec -T db psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atq "$@"; }

counts() {
  for t in "${V1_TABLES[@]}"; do
    # Table names come from the fixed list above, never from input.
    n="$(psql_db -c "SELECT CASE WHEN to_regclass('public.$t') IS NULL THEN -1 ELSE (SELECT count(*) FROM public.\"$t\") END" 2>/dev/null || echo ERR)"
    echo "$t=$n"
  done
}

restore() {
  local dump="$1"
  [ -s "$dump" ] || { echo "Dump not found or empty: $dump" >&2; exit 1; }
  docker run --rm -i postgis/postgis:17-3.5 pg_restore --list >/dev/null < "$dump" 2>/dev/null \
    || "${COMPOSE[@]}" exec -T db pg_restore --list >/dev/null < "$dump" \
    || { echo "Dump is not readable by pg_restore: $dump — nothing changed." >&2; exit 1; }
  echo "==> Restore path: recreating the volume and restoring $dump"
  "${COMPOSE[@]}" down -v
  "${COMPOSE[@]}" up -d --wait
  "${COMPOSE[@]}" exec -T db pg_restore --no-owner -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$dump"
  local expected="${dump%.dump}.counts"
  counts > "${dump%.dump}.after-restore.counts"
  if [ -f "$expected" ] && diff -q "$expected" "${dump%.dump}.after-restore.counts" >/dev/null; then
    echo "Row counts match after restore: $(tr '\n' ' ' < "$expected")"
  else
    echo "Row counts after restore:"; cat "${dump%.dump}.after-restore.counts"
    [ -f "$expected" ] && { echo "Expected:"; cat "$expected"; exit 1; }
  fi
}

if [ "${1:-}" = "--restore" ]; then
  restore "${2:?usage: --restore <file.dump>}"
  exit 0
fi

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
DUMP="$BACKUP_DIR/saarthee-$TS.dump"
COUNTS="$BACKUP_DIR/saarthee-$TS.counts"

echo "==> 1/3 Dump (current image: $(docker inspect --format '{{.Config.Image}}' "$("${COMPOSE[@]}" ps -q db)" 2>/dev/null || echo 'not running'))"
"${COMPOSE[@]}" up -d --wait --no-recreate db
if ! "${COMPOSE[@]}" exec -T db pg_dump -Fc -U "$POSTGRES_USER" -d "$POSTGRES_DB" > "$DUMP"; then
  rm -f "$DUMP"; echo "pg_dump failed — data untouched, image not switched." >&2; exit 1
fi
[ -s "$DUMP" ] || { rm -f "$DUMP"; echo "Dump is empty — data untouched, image not switched." >&2; exit 1; }
chmod 600 "$DUMP"
counts > "$COUNTS"
echo "Dump written to $DUMP ($(wc -c < "$DUMP" | tr -d ' ') bytes)"

echo "==> 2/3 Switch image (same major version 17, existing volume reused)"
if ! "${COMPOSE[@]}" up -d --wait db; then
  echo "New container did not become healthy."
  restore "$DUMP"
fi
VER="$(psql_db -c "SELECT default_version FROM pg_available_extensions WHERE name = 'postgis'")"
case "$VER" in 3.5.*) echo "PostGIS $VER ready (extension is created by migration 20261004000000_enable_postgis)";;
  *) echo "PostGIS 3.5 not available in the container (got '$VER')." >&2; exit 1;; esac

# postgres:17.6 (Debian trixie, glibc 2.41) and postgis/postgis:17-3.5 (Debian bullseye, glibc 2.31) sort text
# differently; text indexes built under the old collation would be silently wrong. A dump + restore into a
# fresh volume rebuilds every index under the container's collation.
MISMATCH="$(psql_db -c "SELECT datcollversion IS DISTINCT FROM pg_database_collation_actual_version(oid) FROM pg_database WHERE datname = current_database()" 2>/dev/null)"
if [ "$MISMATCH" = "t" ]; then
  echo "Collation version changed with the image (glibc); rebuilding through the restore path."
  restore "$DUMP"
  echo "Done. Next: npm run db:migrate (applies the v2 migrations)."
  exit 0
fi

echo "==> 3/3 Compare row counts"
counts > "$BACKUP_DIR/saarthee-$TS.after.counts"
if diff -q "$COUNTS" "$BACKUP_DIR/saarthee-$TS.after.counts" >/dev/null; then
  echo "Row counts match: $(tr '\n' ' ' < "$COUNTS")"
else
  echo "Row counts differ:"; diff "$COUNTS" "$BACKUP_DIR/saarthee-$TS.after.counts" || true
  echo "Restore command: npm run db:upgrade-postgis -- --restore $DUMP"
  restore "$DUMP"
fi
echo "Done. Next: npm run db:migrate (applies the v2 migrations)."
