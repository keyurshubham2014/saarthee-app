#!/usr/bin/env bash
# Run on a physical phone on the same Wi-Fi. Pass the dev machine's LAN IP
# (and add it to android/app/src/debug/res/xml/network_security_config.xml).
# Usage: scripts/run-lan-phone.sh 192.168.1.20 [port]
set -euo pipefail
LAN_IP="${1:?LAN IP of the dev machine required}"
PORT="${2:-4000}"
cd "$(dirname "$0")/.."
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL="http://${LAN_IP}:${PORT}/api/v1"
