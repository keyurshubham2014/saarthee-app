#!/usr/bin/env bash
# v1 immutability gate (V2 TASK-01 §6 step 5): the 10 applied v1 migration files must never change.
set -euo pipefail
cd "$(dirname "$0")/../prisma/migrations"
if shasum -a 256 -c V1_CHECKSUMS.sha256 --quiet; then
  echo "v1 migration gate: $(wc -l < V1_CHECKSUMS.sha256 | tr -d ' ') v1 migrations unchanged."
else
  echo "v1 migration gate FAILED: an applied v1 migration was edited. Add a new migration instead." >&2
  exit 1
fi
