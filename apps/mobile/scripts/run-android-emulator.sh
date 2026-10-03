#!/usr/bin/env bash
# Run the app on the Android emulator against the local API (05 §2.2).
# Usage: scripts/run-android-emulator.sh [port]   (default 4000)
set -euo pipefail
PORT="${1:-4000}"
cd "$(dirname "$0")/.."
flutter run -d emulator-5554 \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL="http://10.0.2.2:${PORT}/api/v1"
