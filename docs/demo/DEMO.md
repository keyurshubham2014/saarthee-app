# Saarthee — 5-minute demo script

> **Superseded by Saarthee v2** where they differ — see `docs/v2/saarthee-v2-spec.md` and `docs/tasks-v2/00-task-summary.md`.
>
> The v2 demo script is [`DEMO-v2.md`](./DEMO-v2.md) (`npm run demo:reset`).


The demo shows the whole accountability loop on an Android emulator. A citizen records a complaint. The
operator sends a WhatsApp reminder a week later. The citizen answers "Not fixed" with a photo, and the H2
rate on the Rates screen changes.

## 0. Start everything (fresh terminal, ~2 minutes)

```bash
cd ~/Documents/Projects/LDRP-ITR
export PATH="$PATH:/opt/homebrew/share/android-commandlinetools/platform-tools:/opt/homebrew/share/android-commandlinetools/emulator"

# 1. Emulator (skip if already running)
emulator -avd leadpilot_pixel9 -no-snapshot-save -no-audio &
adb wait-for-device

# 2. Database + API
npm run db:up
npm run api:dev            # leave running (port 4000); in a second terminal:

# 3. Known seeded state (fresh DB, seed, app data cleared, GPS set to Ahmedabad)
npm run demo:reset

# 4. Build + install the app (profile build: AOT-compiled, much faster than debug on the emulator)
cd apps/mobile
flutter build apk --profile --target-platform android-arm64 \
  --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1 --dart-define=APP_ENV=development
adb install -r build/app/outputs/flutter-apk/app-profile.apk
adb shell pm grant in.saarthee.saarthee android.permission.CAMERA
adb shell pm grant in.saarthee.saarthee android.permission.ACCESS_FINE_LOCATION
adb emu geo fix 72.5714 23.0225
adb shell monkey -p in.saarthee.saarthee -c android.intent.category.LAUNCHER 1
# (debug alternative: flutter run -d emulator-5554 --dart-define=... — slow cold start, ~15 s)
```

Before the audience arrives: open the emulator, make sure **Settings → Location** is on, and open the
app once so it is warm.

Check: `curl -s localhost:4000/api/v1/health` → `{"status":"ok","db":"ok"}`.

## Seeded logins and codes

| What | Value |
|---|---|
| Operator login | `admin@saarthee.local` / `Demo-Admin-2026!` |
| Invite codes | `RWATEST01` (RWA), `ACTTEST01` (activist), `SOCTEST01` (social), `NETTEST01` (network) |
| Seeded complaints | 11 (see `apps/api/prisma/SEED-EXPECTATIONS.md`); due list starts with 3 |
| Emulator GPS | `adb emu geo fix 72.5714 23.0225` (Ahmedabad) — run before any photo step |

## 1. Citizen: first launch and invite code (0:00–0:45)

1. App opens on **Welcome** ("Check that complaints to AMC really get fixed."). Tap **Continue**.
2. **Invite code**: type `RWATEST01`, tap **Continue** → "You're part of Test RWA — Navrangpura" → Home.

## 2. Citizen: record a complaint (0:45–2:15)

1. Home → **Record a complaint**.
2. Step 1 — choose **Pothole or damaged road**.
3. Step 2 — CCRS hand-off: tap the AMC option (leaves the app), come back — the draft is still there.
4. Step 3 — enter the CCRS number, e.g. `AMC-DEMO-0001`.
5. Step 4 — **Take photo** → shutter → **Done** (emulator camera scene) → scroll down → **Use this photo**
   (if it says "Location is approximate", tap **Continue anyway**) → "Photo uploaded" → **Continue**.
6. Step 5 — WhatsApp number `98765 43210` (invented test number) + consent.
7. Step 6 — check the summary → **Send**. "Your complaint is recorded" screen.

## 3. Operator: reminder (2:15–3:15)

1. Home → **About** → **Operator login** → log in with the seeded operator account.
2. **Due** tab — the new complaint is not due yet (filed today); the seeded due items are. For the demo, pick
   the seeded RWA complaint `AMC-2026-0001` (filed 10 days ago).
3. **Send reminder** → the sheet shows the message text and the `saarthee://verify?t=…` link, with
   **Open WhatsApp** and **Copy message**. Tap **Copy message** (no WhatsApp on the emulator).

## 4. Citizen: answer the follow-up via the deep link (3:15–4:30)

Fire the link with adb (paste the token from the sheet / clipboard):

```bash
adb shell am start -a android.intent.action.VIEW \
  -d "saarthee://verify?t=<TOKEN>" in.saarthee.saarthee
```

1. The verify summary opens (no phone, coordinates or source shown).
2. Choose **Not fixed** → take a photo → add a note ("Still broken") → **Send**.
3. Alternative path: Home → **Answer a follow-up** → paste the link or code.

## 5. Operator: Rates moved (4:30–5:00)

Open the **Rates** tab. Expected change from the seed (see SEED-EXPECTATIONS "Demo delta"):

| Group | H1 before → after | H2 before → after |
|---|---|---|
| RWA | 66.7% → 75.0% | 50.0% → **66.7%** |
| Trusted (RWA + activist) | 60.0% → 66.7% | 66.7% → **75.0%** |

## Reset between runs

```bash
npm run demo:reset
```

## Evidence of the verified run

`docs/demo/evidence/` holds screenshots of every step (01 first launch … 10 Rates after), taken on the emulator
on 2026-10-03, plus the extra flows (invalid code, skip, change code, enter-code, exclusion, admin screens, session
ended, offline banner). Privacy checks: `node scripts/privacy-checks.mjs` (14/14 pass).

## Known limitations

- iOS not demoed: Xcode is not fully installed on the demo machine (`flutter doctor`). iPhone and real WhatsApp
  deep-link tests are deferred — need a physical device.
- No GitHub remote was created (outward-facing action left to the founder); CI workflow exists but has not run.
- PostgreSQL is published on host port **5433** (5432 is used by another project on this machine).
- Debug builds cold-start slowly on this loaded emulator (~15 s) and can trigger "isn't responding" when the camera
  hands back; use the profile build above. Performance on a real low-end phone is unmeasured (Deferred).
- If Android kills the app while the camera is open, the un-accepted photo is lost (image_picker
  `retrieveLostData()` not handled); the draft itself survives — just retake.
- "Use this photo" sits below the fold under the pinned Continue button — scroll down after taking a photo.
- No WhatsApp on the emulator: use **Copy message** and fire the link with `adb` (above). Real WhatsApp tappability,
  iPhone, TalkBack/VoiceOver and the low-end-phone checklist are Deferred — need physical devices.
- Fonts: system font at the spec's sizes (Anek/Noto not bundled — licence check pending).
- Invite-code "Share" copies the text to the clipboard (no share sheet package added).
