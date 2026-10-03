#!/usr/bin/env bash
# Run the app on the iOS simulator against the local API (05 §2.2).
set -euo pipefail
PORT="${1:-4000}"
cd "$(dirname "$0")/.."
flutter run -d booted \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL="http://localhost:${PORT}/api/v1"
