#!/usr/bin/env bash
# Deploy one release on a staging/pilot host (V2 TASK-13 step 7; runbook docs/ops/deploy.md).
#   deploy.sh <tag>          e.g. deploy.sh 3b4276e   (images built and pushed by .github/workflows/deploy.yml)
# Steps: pull → prisma migrate deploy (one-off container) → up -d → poll /health for 60 s → on failure roll
# back to the previous tag (migrations are forward-only and must stay backward compatible; see deploy.md).
# Config (environment or /etc/saarthee/deploy.env):
#   IMAGE_REPO      ghcr.io/<owner>/saarthee-api      CADDY_REPO  ghcr.io/<owner>/saarthee-caddy
#   SITE_ADDRESS    api-staging.<domain> | api.<domain>
#   STACK_DIR       directory holding compose.yml (default: this script's directory)
#   HEALTH_URL      default https://$SITE_ADDRESS/api/v1/health resolved to 127.0.0.1 (origin cert → -k)
#   COMPOSE_ARGS    extra `docker compose` arguments (local rehearsal: "--env-file local.env --profile local-db")
#   SKIP_PULL=1     use local images (local rehearsal only)
set -euo pipefail
tag="${1:?usage: deploy.sh <image tag>}"
[[ "$tag" =~ ^[A-Za-z0-9._-]{1,64}$ ]] || { echo "deploy: bad tag" >&2; exit 2; }
[[ -f /etc/saarthee/deploy.env ]] && set -a && . /etc/saarthee/deploy.env && set +a
: "${IMAGE_REPO:?set IMAGE_REPO}" "${CADDY_REPO:?set CADDY_REPO}" "${SITE_ADDRESS:?set SITE_ADDRESS}"
STACK_DIR="${STACK_DIR:-$(cd "$(dirname "$0")" && pwd)}"
STATE_DIR="${STATE_DIR:-/var/lib/saarthee}"
mkdir -p "$STATE_DIR"
prev="$(cat "$STATE_DIR/current-release" 2>/dev/null || true)"

# shellcheck disable=SC2086 # COMPOSE_ARGS is a word list on purpose
compose() { # compose <tag> <args…>
  local t="$1"; shift
  API_IMAGE="$IMAGE_REPO:$t" CADDY_IMAGE="$CADDY_REPO:$t" SITE_ADDRESS="$SITE_ADDRESS" \
    docker compose -f "$STACK_DIR/compose.yml" ${COMPOSE_ARGS:-} "$@"
}

healthy() {
  local _
  for _ in $(seq 1 30); do
    if curl -fsS -k -m 2 --resolve "${SITE_ADDRESS}:443:127.0.0.1" "${HEALTH_URL:-https://${SITE_ADDRESS}/api/v1/health}" 2>/dev/null \
      | grep -q '"status":"ok"'; then
      return 0
    fi
    sleep 2
  done
  return 1
}

echo "deploy: ${prev:-<none>} → ${tag}"
[[ "${SKIP_PULL:-0}" == 1 ]] || compose "$tag" pull api caddy
compose "$tag" run --rm --no-deps api npx prisma migrate deploy
compose "$tag" up -d --no-build --remove-orphans api caddy

if healthy; then
  echo "$tag" >"$STATE_DIR/current-release"
  [[ -n "$prev" ]] && echo "$prev" >"$STATE_DIR/previous-release"
  docker image prune -f --filter "until=168h" >/dev/null || true
  echo "deploy: ok ${tag}"
  exit 0
fi

echo "deploy: /health failed after 60 s" >&2
if [[ -n "$prev" ]]; then
  echo "deploy: rolling back to ${prev}" >&2
  compose "$prev" up -d --no-build api caddy
  if healthy; then echo "deploy: rolled back to ${prev}" >&2; else echo "deploy: ROLLBACK UNHEALTHY — page the build lead" >&2; fi
fi
exit 1
