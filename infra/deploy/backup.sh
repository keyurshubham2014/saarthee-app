#!/usr/bin/env bash
# Encrypted daily database backup (V2 TASK-13 step 10, REQ-O-006). Runs from the saarthee-backup timer.
#   pg_dump -Fc  →  age (encrypted to the founder's offline public key)  →  R2 backup bucket (rclone)
#   →  Healthchecks ping.  The dump is never written unencrypted to disk.
#
# Config (environment, or /etc/saarthee/backup.env):
#   DEPLOY_ENV            staging | pilot | local
#   DATABASE_URL          source database (read from /etc/saarthee/api.env when unset)
#   AGE_RECIPIENT         age public key (age1…) — the private key never lives on the server
#   BACKUP_REMOTE         rclone destination root, e.g. r2:saarthee-staging-backups   (or)
#   BACKUP_DEST_DIR       local directory instead of rclone (local drills/tests)
#   PG_CLIENT_IMAGE       image with pg_dump 17 (default postgis/postgis:17-3.5)
#   PG_EXEC_CONTAINER     run pg_dump inside this running container instead (local drills)
#   HEALTHCHECKS_URL_BACKUP  optional; /start, success and /fail pings (no data sent)
# Exit: 0 ok; non-zero on any failure (the timer marks the unit failed and Healthchecks alerts).
set -euo pipefail
umask 077

[[ -f /etc/saarthee/backup.env ]] && set -a && . /etc/saarthee/backup.env && set +a
if [[ -z "${DATABASE_URL:-}" && -r /etc/saarthee/api.env ]]; then
  DATABASE_URL="$(grep -E '^DATABASE_URL=' /etc/saarthee/api.env | head -1 | cut -d= -f2-)"
fi
: "${DEPLOY_ENV:?set DEPLOY_ENV}" "${DATABASE_URL:?set DATABASE_URL}" "${AGE_RECIPIENT:?set AGE_RECIPIENT}"
[[ -n "${BACKUP_REMOTE:-}" || -n "${BACKUP_DEST_DIR:-}" ]] || { echo "backup: set BACKUP_REMOTE or BACKUP_DEST_DIR" >&2; exit 2; }
PG_CLIENT_IMAGE="${PG_CLIENT_IMAGE:-postgis/postgis:17-3.5}"
HC="${HEALTHCHECKS_URL_BACKUP:-}"

ping_hc() { [[ -n "$HC" ]] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC$1" || true; }
fail() { echo "backup: FAILED — $1" >&2; ping_hc /fail; exit 1; }
ping_hc /start

ts="$(date -u +%Y%m%dT%H%M%SZ)"
name="saarthee-${DEPLOY_ENV}-${ts}.dump.age"
rel="db/${DEPLOY_ENV}/$(date -u +%Y)/$(date -u +%m)/${name}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

dump() {
  if [[ -n "${PG_EXEC_CONTAINER:-}" ]]; then
    docker exec -i -e DATABASE_URL="$DATABASE_URL" "$PG_EXEC_CONTAINER" \
      sh -c 'pg_dump --format=custom --no-owner --no-privileges --dbname="$DATABASE_URL"'
  else
    docker run --rm -i --network host -e DATABASE_URL="$DATABASE_URL" "$PG_CLIENT_IMAGE" \
      sh -c 'pg_dump --format=custom --no-owner --no-privileges --dbname="$DATABASE_URL"'
  fi
}

started=$(date +%s)
dump | age -r "$AGE_RECIPIENT" -o "$tmp/$name" || fail "pg_dump or encryption"
size=$(wc -c <"$tmp/$name" | tr -d ' ')
[[ "$size" -gt 1024 ]] || fail "dump is suspiciously small (${size} bytes)"

if [[ -n "${BACKUP_REMOTE:-}" ]]; then
  rclone copyto --s3-no-check-bucket "$tmp/$name" "${BACKUP_REMOTE}/${rel}" || fail "upload"
  dest="${BACKUP_REMOTE}/${rel}"
else
  mkdir -p "$(dirname "${BACKUP_DEST_DIR}/${rel}")"
  cp "$tmp/$name" "${BACKUP_DEST_DIR}/${rel}" || fail "copy"
  dest="${BACKUP_DEST_DIR}/${rel}"
fi

echo "backup: ok env=${DEPLOY_ENV} bytes=${size} seconds=$(( $(date +%s) - started )) dest=${dest}"
ping_hc ""
