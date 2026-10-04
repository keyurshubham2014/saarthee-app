#!/usr/bin/env bash
# One-command demo reset: fresh database (migrate + seed), fresh photo store, fresh app data on the emulator.
# Development only. Usage: npm run demo:reset
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADB="${ADB:-$(command -v adb || echo /opt/homebrew/share/android-commandlinetools/platform-tools/adb)}"
APP_ID="in.saarthee.saarthee"

echo "==> Resetting database (drop volume, migrate, seed)"
bash "$ROOT/scripts/db-reset.sh" --yes

if "$ADB" get-state >/dev/null 2>&1; then
  echo "==> Clearing app data on the emulator ($APP_ID)"
  "$ADB" shell pm clear "$APP_ID" >/dev/null 2>&1 || echo "    (app not installed yet — install it with the command in docs/demo/DEMO.md)"
  "$ADB" emu geo fix 72.5714 23.0225 >/dev/null 2>&1 || true
else
  echo "==> No emulator/device attached; skipped app data reset"
fi

echo "==> v2 seed after reset (apps/api/prisma/SEED-EXPECTATIONS.md):"
bash "$ROOT/scripts/psql.sh" -c 'SELECT status, count(*) AS issues FROM issues GROUP BY 1 ORDER BY 1'
bash "$ROOT/scripts/psql.sh" -c 'SELECT role, status, count(*) AS users FROM users GROUP BY 1, 2 ORDER BY 1, 2'
bash "$ROOT/scripts/psql.sh" -c 'SELECT count(*) AS categories FROM categories'
echo "Demo reset complete. Admin: admin@saarthee.local / Demo-Admin-2026!"
