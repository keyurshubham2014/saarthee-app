#!/usr/bin/env bash
# Creates this worker's test database (and shadow database for the drift gate) in the local compose
# container if absent. Names come from apps/api/.env.test (or TEST_DB_NAME); must contain "_test" / "_shadow".
set -euo pipefail
API="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$API/../.." && pwd)"
[ -f "$API/.env.test" ] || { echo "Missing apps/api/.env.test (copy .env.test.example)." >&2; exit 1; }
url_db() { sed -E 's#^[^=]+=postgres(ql)?://[^/]+/([^?]+).*#\2#'; }
TEST_DB="${TEST_DB_NAME:-$(grep -E '^DATABASE_URL=' "$API/.env.test" | url_db)}"
SHADOW_DB="$(grep -E '^SHADOW_DATABASE_URL=' "$API/.env.test" | url_db || true)"
case "$TEST_DB" in *_test*) ;; *) echo "Refusing: test database name '$TEST_DB' must contain _test." >&2; exit 1;; esac
COMPOSE=(docker compose -f "${COMPOSE_FILE_PATH:-$ROOT/infra/docker-compose.yml}" --env-file "${COMPOSE_ENV_FILE:-$ROOT/infra/.env}")
set -a; # shellcheck disable=SC1090
source "${COMPOSE_ENV_FILE:-$ROOT/infra/.env}"; set +a
for db in "$TEST_DB" ${SHADOW_DB:+"$SHADOW_DB"}; do
  [[ "$db" =~ ^[a-z0-9_]+$ ]] || { echo "Unsafe database name: $db" >&2; exit 1; }
  exists="$("${COMPOSE[@]}" exec -T db psql -U "$POSTGRES_USER" -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname = '$db'")"
  if [ "$exists" = "1" ]; then
    echo "Database $db exists."
  else
    "${COMPOSE[@]}" exec -T db psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE \"$db\"" >/dev/null
    echo "Database $db created."
  fi
done
