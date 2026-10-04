# Build-time defines (`--dart-define-from-file`)

No secrets here: these values are compiled into the app and visible to anyone with the APK.

| File | Track | API |
|---|---|---|
| `staging.json` | Play internal testing | `https://api-staging.<domain>/api/v1` |
| `pilot.json` | Play closed testing "Pilot – West zone" | `https://api.<domain>/api/v1` |

`saarthee.example` is a placeholder until the founder picks the domain (TASK-13 §5.6) — replace it in both
files before the first Play upload. Release/profile builds refuse any non-HTTPS `API_BASE_URL` and show the
fatal config screen (`lib/core/config/api_url_policy.dart`). Build steps: `docs/ops/release-android.md`.
