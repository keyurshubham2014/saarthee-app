#!/usr/bin/env bash
# Saarthee v2 demo reset (docs/demo/DEMO-v2.md). DEVELOPMENT ONLY.
#   npm run demo:reset                 # asks for confirmation
#   npm run demo:reset -- --yes        # no prompt
#   npm run demo:reset -- --dry-run    # print every step, change nothing
# Steps: refuse non-dev DATABASE_URL -> drop + recreate that one database -> prisma migrate deploy + db seed
# -> clear Auth Emulator accounts (if running on 9099) -> clear app data, grant permissions, set GPS on emulator-5554
# -> print demo accounts and issues by status. Never prints passwords, OTPs or tokens.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_ENV_FILE="${API_ENV_FILE:-$ROOT/apps/api/.env}"
ADB="${ADB:-/opt/homebrew/share/android-commandlinetools/platform-tools/adb}"
SERIAL="${ANDROID_SERIAL:-emulator-5554}"
APP_ID="in.saarthee.saarthee"
DB_CONTAINER="${DB_CONTAINER:-saarthee-db-1}"
AUTH_EMU="${AUTH_EMU:-127.0.0.1:9099}"
FB_PROJECT="${FIREBASE_PROJECT_ID:-demo-saarthee}"
GEO_LNG="72.5714"; GEO_LAT="23.0225"   # Ward 30 Paldi
AUTH_START="npx -y firebase-tools@15.32.1 emulators:start --only auth --project demo-saarthee"
DRY=0; YES=0
for a in "$@"; do
  case "$a" in
    --dry-run|-n) DRY=1 ;;
    --yes|-y) YES=1 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "demo:reset: unknown option '$a' (use --dry-run, --yes)" >&2; exit 2 ;;
  esac
done

say() { printf '\n==> %s\n' "$*"; }
run() { if [ "$DRY" = 1 ]; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }
die() { echo "demo:reset refused: $*" >&2; exit 1; }
envval() { [ -f "$API_ENV_FILE" ] && grep -E "^$1=" "$API_ENV_FILE" | tail -1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//' || true; }

# --- 1. Guards: only a local development database -------------------------------------------
[ -f "$API_ENV_FILE" ] || die "$API_ENV_FILE not found (copy apps/api/.env.example and fill it in)."
APP_ENV_VALUE="${APP_ENV:-$(envval APP_ENV)}"
DEPLOY_ENV_VALUE="${DEPLOY_ENV:-$(envval DEPLOY_ENV)}"
DB_URL="${DATABASE_URL:-$(envval DATABASE_URL)}"
[ "$APP_ENV_VALUE" = "development" ] || die "APP_ENV is '$APP_ENV_VALUE', must be development."
case "$DEPLOY_ENV_VALUE" in ""|local|development) ;; *) die "DEPLOY_ENV is '$DEPLOY_ENV_VALUE'." ;; esac
re='^postgres(ql)?://([^:@/]+)(:[^@]*)?@([^:/?]+)(:([0-9]+))?/([^?]+)'
[[ "$DB_URL" =~ $re ]] || die "DATABASE_URL is not a postgres URL."
DB_USER="${BASH_REMATCH[2]}"; DB_HOST="${BASH_REMATCH[4]}"; DB_PORT="${BASH_REMATCH[6]:-5432}"; DB_NAME="${BASH_REMATCH[7]}"
case "$DB_HOST" in 127.0.0.1|localhost) ;; *) die "DATABASE_URL host '$DB_HOST' is not local." ;; esac
[[ "$DB_NAME" =~ ^[a-z0-9_]+$ ]] || die "database name '$DB_NAME' has unexpected characters."
case "$DB_NAME" in *prod*|*pilot*|*staging*|postgres|template*) die "database '$DB_NAME' is not a dev database." ;; esac
echo "Target: postgresql://$DB_USER:***@$DB_HOST:$DB_PORT/$DB_NAME (container $DB_CONTAINER)"
[ "$DRY" = 1 ] && echo "DRY RUN: nothing will be changed."

if [ "$DRY" = 0 ] && [ "$YES" = 0 ]; then
  read -r -p "This deletes ALL data in '$DB_NAME' and the app data on $SERIAL. Type RESET to continue: " ans
  [ "$ans" = "RESET" ] || { echo "Aborted."; exit 1; }
fi

PSQL=(docker exec "$DB_CONTAINER" psql -U "$DB_USER" -v ON_ERROR_STOP=1 -q)
if [ "$DRY" = 0 ]; then
  [ "$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER" 2>/dev/null)" = "true" ] ||
    die "container $DB_CONTAINER is not running — start it with: npm run db:up"
fi

# --- 2. Database: drop + recreate this database only, migrate, seed ------------------------
say "Recreating database $DB_NAME (other databases in the container are untouched)"
run "${PSQL[@]}" -d postgres -c "DROP DATABASE IF EXISTS \"$DB_NAME\" WITH (FORCE)" -c "CREATE DATABASE \"$DB_NAME\""
PHOTO_DIR="$(envval PHOTO_STORAGE_DIR)"
case "$PHOTO_DIR" in
  /*/saarthee-data|/*/saarthee-data/*) say "Clearing seeded/uploaded photos in $PHOTO_DIR/photos"; run rm -rf "${PHOTO_DIR:?}/photos" ;;
  *) say "Photo store '$PHOTO_DIR' left as is (not a saarthee data directory)" ;;
esac
say "Applying migrations and the v2 seed (apps/api: prisma migrate deploy, prisma db seed)"
in_api() { (cd "$ROOT/apps/api" && "$@"); }
run in_api npx prisma migrate deploy
run in_api npx prisma db seed

# --- 3. Firebase Auth Emulator -----------------------------------------------------------
say "Firebase Auth Emulator on $AUTH_EMU"
if curl -s -m 3 -o /dev/null "http://$AUTH_EMU/"; then
  echo "    running — clearing emulator accounts so every test number signs in fresh"
  run curl -s -m 5 -o /dev/null -X DELETE "http://$AUTH_EMU/emulator/v1/projects/$FB_PROJECT/accounts"
else
  echo "    NOT running. Start it in its own terminal (repo root):"
  echo "      $AUTH_START"
fi

# --- 4. Android emulator ----------------------------------------------------------------
say "Android emulator $SERIAL"
if [ -x "$ADB" ] && "$ADB" devices 2>/dev/null | grep -qE "^$SERIAL[[:space:]]+device$"; then
  A=("$ADB" -s "$SERIAL")
  run "${A[@]}" shell pm clear "$APP_ID" || echo "    app not installed — build and install it (DEMO-v2.md §0)"
  for p in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION CAMERA POST_NOTIFICATIONS; do
    run "${A[@]}" shell pm grant "$APP_ID" "android.permission.$p" || echo "    could not grant $p"
  done
  run "${A[@]}" emu geo fix "$GEO_LNG" "$GEO_LAT" || echo "    geo fix failed"
  echo "    GPS set to $GEO_LAT, $GEO_LNG (Ward 30 Paldi)"
else
  echo "    $SERIAL not attached — skipped app data, permissions and GPS"
fi

# --- 5. Demo accounts and seeded state ---------------------------------------------------
say "Demo accounts (phone OTP via the Auth Emulator; numbers are fictional test numbers)"
cat <<EOF
    Role             Sign-in                         Notes
    citizen A        +91 90000 00001                 new account: age screen once, reports in Paldi
    citizen B        +91 90000 00003                 new account: neighbour who verifies the fix
    follower         +91 90000 00021                 seeded "Sample Citizen Asha" (gu)
    moderator        +91 90000 00025                 seeded "Sample Moderator Esha" — staff web + in-app staff
    representative   +91 90000 00027                 seeded, verified for Sample Corporator 18-A (ward 18 Navrangpura)
    admin            $(envval SEED_ADMIN_EMAIL)      email + password from SEED_ADMIN_PASSWORD in apps/api/.env
    OTP codes:  curl -s http://127.0.0.1:9099/emulator/v1/projects/$FB_PROJECT/verificationCodes
EOF
say "Issues by status"
run "${PSQL[@]}" -d "$DB_NAME" -c "SELECT status, count(*) AS issues FROM issues GROUP BY 1 ORDER BY 1"
run "${PSQL[@]}" -d "$DB_NAME" -c "SELECT role, status, count(*) AS users FROM users GROUP BY 1, 2 ORDER BY 1, 2"
echo
[ "$DRY" = 1 ] && echo "Dry run complete — nothing was changed." || echo "Demo reset complete. Restart 'npm run dev' in apps/api if it lost its connection."
