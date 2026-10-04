#!/usr/bin/env bash
# Restore an encrypted backup into a FRESH database (V2 TASK-13 step 11; drill: docs/ops/backup-restore.md).
#   restore.sh <backup>      <backup> = rclone path (r2:…/db/…dump.age) or a local file
# Config (environment):
#   TARGET_DATABASE_URL   empty database to restore into (refused if it already has tables in public)
#   AGE_IDENTITY          path to the age private key file (founder's offline key; never on the server)
#   PG_CLIENT_IMAGE       image with pg_restore/psql 17 (default postgis/postgis:17-3.5)
#   PG_EXEC_CONTAINER     run the client inside this running container instead (local drills)
# Prints elapsed time and row counts of the main tables so they can be compared with the source.
set -euo pipefail
umask 077

src="${1:?usage: restore.sh <backup.dump.age | rclone path>}"
: "${TARGET_DATABASE_URL:?set TARGET_DATABASE_URL}" "${AGE_IDENTITY:?set AGE_IDENTITY}"
PG_CLIENT_IMAGE="${PG_CLIENT_IMAGE:-postgis/postgis:17-3.5}"
if [[ -r /etc/saarthee/api.env ]] && grep -qF "DATABASE_URL=${TARGET_DATABASE_URL}" /etc/saarthee/api.env; then
  echo "restore: refusing — TARGET_DATABASE_URL is the live database" >&2
  exit 2
fi

pg() { # pg <tool> [args…]  — runs a PostgreSQL client against TARGET_DATABASE_URL, stdin passed through
  local tool="$1"; shift
  if [[ -n "${PG_EXEC_CONTAINER:-}" ]]; then
    docker exec -i -e T="$TARGET_DATABASE_URL" "$PG_EXEC_CONTAINER" sh -c "$tool \"\$@\" --dbname=\"\$T\"" sh "$@"
  else
    docker run --rm -i --network host -e T="$TARGET_DATABASE_URL" "$PG_CLIENT_IMAGE" sh -c "$tool \"\$@\" --dbname=\"\$T\"" sh "$@"
  fi
}

existing="$(pg psql -tAc "SELECT count(*) FROM pg_tables WHERE schemaname='public'")"
[[ "${existing//[[:space:]]/}" == "0" ]] || { echo "restore: refusing — target already has ${existing} tables" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
started=$(date +%s)
if [[ -f "$src" ]]; then cp "$src" "$tmp/b.dump.age"; else rclone copyto "$src" "$tmp/b.dump.age"; fi

# Decrypt straight into pg_restore (the plaintext dump never touches disk).
age -d -i "$AGE_IDENTITY" "$tmp/b.dump.age" | pg pg_restore --no-owner --no-privileges --exit-on-error

echo "restore: ok seconds=$(( $(date +%s) - started ))"
pg psql -tA -F ' ' <<'SQL'
SELECT 'migrations', count(*) FROM _prisma_migrations WHERE finished_at IS NOT NULL
UNION ALL SELECT 'postgis', 1 WHERE postgis_lib_version() IS NOT NULL
UNION ALL SELECT 'users', count(*) FROM users
UNION ALL SELECT 'issues', count(*) FROM issues
UNION ALL SELECT 'photos', count(*) FROM photos
UNION ALL SELECT 'complaints', count(*) FROM complaints
UNION ALL SELECT 'categories', count(*) FROM categories;
SQL
