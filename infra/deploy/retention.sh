#!/usr/bin/env bash
# Daily retention run on the host (V2 TASK-13 §5.2). Runs `retention:run` inside the running API container
# (same image, same api.env) and pings Healthchecks. When the TASK-06 job runner (src/jobs) schedules
# retention in-process, disable the saarthee-retention timer (docs/ops/monitoring.md).
#   retention.sh [--dry-run] [--rule <name>]
set -euo pipefail
[[ -f /etc/saarthee/backup.env ]] && set -a && . /etc/saarthee/backup.env && set +a
HC="${HEALTHCHECKS_URL_RETENTION:-}"
ping_hc() { [[ -n "$HC" ]] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC$1" || true; }
STACK_DIR="${STACK_DIR:-$(cd "$(dirname "$0")" && pwd)}"

ping_hc /start
if docker compose -f "$STACK_DIR/compose.yml" exec -T api node dist/scripts/retention.js "$@"; then
  ping_hc ""
else
  ping_hc /fail
  exit 1
fi
