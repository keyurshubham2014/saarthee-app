#!/usr/bin/env bash
# TASK-04 (AC-15, S-04-01): fails when Firebase config files, service-account keys or .env files are tracked.
# Run from anywhere inside the repository: bash scripts/check-secret-files.sh
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
pattern='(^|/)(google-services\.json|GoogleService-Info\.plist|firebase_options\.dart|[^/]*service-account[^/]*\.json|\.env|\.env\.test)$|^apps/api/secrets/'
tracked="$(git ls-files | grep -E "$pattern" || true)"
if [ -n "$tracked" ]; then
  echo "Secret-file check FAILED. These files must not be in git:" >&2
  echo "$tracked" >&2
  exit 1
fi
echo "Secret-file check: no Firebase config, service-account or .env files tracked."
