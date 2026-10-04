#!/usr/bin/env bash
# Drift gate (V2 TASK-01 §6 step 4): the migrations folder and schema.prisma must describe the same
# database. Needs SHADOW_DATABASE_URL (an empty, disposable PostGIS database; Prisma resets it).
# Exit 0 = no drift; exit 2 = drift (the SQL Prisma would generate is printed); other = error.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -z "${SHADOW_DATABASE_URL:-}" ] && [ -f .env.test ]; then
  SHADOW_DATABASE_URL="$(grep -E '^SHADOW_DATABASE_URL=' .env.test | cut -d= -f2- || true)"
fi
: "${SHADOW_DATABASE_URL:?SHADOW_DATABASE_URL must point at an empty, disposable database}"
OUT="$(mktemp)"
set +e
npx prisma migrate diff \
  --from-migrations prisma/migrations \
  --to-schema-datamodel "${1:-prisma/schema.prisma}" \
  --shadow-database-url "$SHADOW_DATABASE_URL" \
  --script --exit-code > "$OUT" 2>&1
code=$?
set -e
if [ "$code" -eq 0 ]; then
  echo "Drift gate: schema.prisma matches prisma/migrations."
else
  grep -v -e 'deprecated' -e 'pris.ly' "$OUT" || true
  echo "Drift gate FAILED (exit $code): schema.prisma and prisma/migrations differ." >&2
fi
rm -f "$OUT"
exit "$code"
