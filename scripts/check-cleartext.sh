#!/usr/bin/env bash
# No cleartext HTTP outside debug builds (V2 TASK-13 step 13, REQ-S-013, AC-10). Run in CI.
# Fails when, anywhere in the Android or iOS sources except android/app/src/debug/:
#   - a network security config permits cleartext (cleartextTrafficPermitted="true"),
#   - a manifest sets usesCleartextTraffic, or references a networkSecurityConfig,
#   - iOS Info.plist allows arbitrary loads (NSAllowsArbitraryLoads),
# or when a dart-define env file points at a non-HTTPS API.
set -euo pipefail
cd "$(dirname "$0")/../apps/mobile"
fail=0

hits="$(grep -rIlE 'cleartextTrafficPermitted="true"|usesCleartextTraffic|networkSecurityConfig' \
  android/app/src --include='*.xml' | grep -v '^android/app/src/debug/' || true)"
if [[ -n "$hits" ]]; then
  echo "check-cleartext: cleartext/network-security-config outside src/debug:" >&2
  echo "$hits" >&2
  fail=1
fi

if grep -rIl 'NSAllowsArbitraryLoads' ios --include='*.plist' 2>/dev/null | grep -q .; then
  echo "check-cleartext: NSAllowsArbitraryLoads found in ios/" >&2
  fail=1
fi

for f in env/*.json; do
  [[ -f "$f" ]] || continue
  if grep -E '"API_BASE_URL"[[:space:]]*:[[:space:]]*"' "$f" | grep -vqE '"https://'; then
    echo "check-cleartext: $f API_BASE_URL is not https://" >&2
    fail=1
  fi
done

[[ $fail -eq 0 ]] && echo "check-cleartext: ok (cleartext only in android/app/src/debug)"
exit $fail
