#!/usr/bin/env bash
# psql inside the db container (no local psql needed).
set -a; source "$(dirname "$0")/../infra/.env"; set +a
exec docker compose -f "$(dirname "$0")/../infra/docker-compose.yml" --env-file "$(dirname "$0")/../infra/.env" exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"
