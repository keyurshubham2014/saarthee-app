#!/usr/bin/env bash
# Local backup → restore drill against the `local-db` compose stack (V2 TASK-13, docs/ops/restore-drill.md).
# Uses a throwaway age key, backs up the stack's database with backup.sh, restores into a new database
# `saarthee_restore_drill` with restore.sh, and compares row counts with the source. Exit 0 = counts match.
#   cd infra/deploy && ./drill-local.sh            (needs: docker, age; stack up with --profile local-db)
set -euo pipefail
cd "$(dirname "$0")"
set -a; . ./local.env; set +a

DB_CONTAINER="${COMPOSE_PROJECT_NAME:-saarthee}-db-1"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
age-keygen -o "$work/key.txt" 2>/dev/null
recipient="$(age-keygen -y "$work/key.txt")"
src_url="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:5432/${POSTGRES_DB}"
dst_db="saarthee_restore_drill"
dst_url="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@127.0.0.1:5432/${dst_db}"

counts() {
  docker exec -i -e U="$1" "$DB_CONTAINER" sh -c 'psql -tA -F " " --dbname="$U"' <<'SQL'
SELECT 'migrations', count(*) FROM _prisma_migrations WHERE finished_at IS NOT NULL
UNION ALL SELECT 'users', count(*) FROM users
UNION ALL SELECT 'issues', count(*) FROM issues
UNION ALL SELECT 'photos', count(*) FROM photos
UNION ALL SELECT 'complaints', count(*) FROM complaints
UNION ALL SELECT 'categories', count(*) FROM categories;
SQL
}

echo "== source counts"; counts "$src_url" | tee "$work/src.txt"

echo "== backup"
DEPLOY_ENV=local DATABASE_URL="$src_url" AGE_RECIPIENT="$recipient" BACKUP_DEST_DIR="$work/bucket" \
  PG_EXEC_CONTAINER="$DB_CONTAINER" ./backup.sh
dump="$(find "$work/bucket" -name '*.dump.age' | head -1)"
echo "encrypted object: ${dump#"$work/bucket/"}"
if head -c 5 "$dump" | grep -q PGDMP; then echo "FAIL: dump is not encrypted" >&2; exit 1; fi
if age -d -i /dev/null "$dump" >/dev/null 2>&1; then echo "FAIL: decrypted without the key" >&2; exit 1; fi
echo "not readable without the key: ok"

echo "== restore into fresh database ${dst_db}"
docker exec "$DB_CONTAINER" sh -c "psql -q -U \"\$POSTGRES_USER\" -d postgres -c 'DROP DATABASE IF EXISTS ${dst_db} WITH (FORCE)' -c 'CREATE DATABASE ${dst_db}'"
TARGET_DATABASE_URL="$dst_url" AGE_IDENTITY="$work/key.txt" PG_EXEC_CONTAINER="$DB_CONTAINER" ./restore.sh "$dump"

echo "== restored counts"; counts "$dst_url" | tee "$work/dst.txt"
diff -u "$work/src.txt" "$work/dst.txt" || { echo "DRILL FAIL: row counts differ" >&2; exit 1; }
echo "row counts match"

echo "== temporary API on the restored database"
tmp_api="${COMPOSE_PROJECT_NAME:-saarthee}-restore-api"
docker rm -f "$tmp_api" >/dev/null 2>&1 || true
docker run -d --name "$tmp_api" --network "${COMPOSE_PROJECT_NAME:-saarthee}_internal" --env-file "${API_ENV_FILE}" \
  -e "DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${dst_db}" "${API_IMAGE}" >/dev/null
health="$(docker exec "$tmp_api" node -e "
  const go = (n) => fetch('http://127.0.0.1:3000/api/v1/health').then(async (r) => console.log(r.status, await r.text()))
    .catch(() => (n > 0 ? setTimeout(() => go(n - 1), 1000) : console.log('unreachable')));
  go(20);")"
docker rm -f "$tmp_api" >/dev/null
echo "restored API /health: ${health}"
[[ "$health" == 200* ]] || { echo "DRILL FAIL: restored API unhealthy" >&2; exit 1; }
echo "DRILL PASS: encrypted backup restored, row counts match, API healthy on the restored database"
