#!/usr/bin/env bash
# Drops the local database volume, recreates, migrates and seeds. Development only.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_ENV_VALUE="${APP_ENV:-$(grep -E '^APP_ENV=' "$ROOT/apps/api/.env" | cut -d= -f2)}"
if [ "$APP_ENV_VALUE" != "development" ]; then
  echo "db:reset refused: APP_ENV is '$APP_ENV_VALUE', must be development." >&2; exit 1
fi
if [ "${1:-}" != "--yes" ]; then
  read -r -p "This deletes ALL local data. Type RESET to continue: " ans
  [ "$ans" = "RESET" ] || { echo "Aborted."; exit 1; }
fi
COMPOSE=(docker compose -f "$ROOT/infra/docker-compose.yml" --env-file "$ROOT/infra/.env")
"${COMPOSE[@]}" down -v
"${COMPOSE[@]}" up -d --wait
PHOTO_DIR="$(grep -E '^PHOTO_STORAGE_DIR=' "$ROOT/apps/api/.env" | cut -d= -f2)"
case "$PHOTO_DIR" in /*/saarthee*) rm -rf "${PHOTO_DIR:?}/photos" ;; esac
cd "$ROOT/apps/api"
npx prisma migrate deploy
npx prisma db seed
