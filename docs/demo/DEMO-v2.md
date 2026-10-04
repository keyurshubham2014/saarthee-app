# Saarthee v2 — 7-minute demo script

The demo walks the whole v2 loop on one Android emulator plus the staff web console: a resident picks Gujarati,
reports a broken road with a photo, a moderator acknowledges it on the web and marks it fixed with an after photo,
a neighbour verifies the fix, a two-person Warning alert reaches the ward, the resident messages a corporator,
RSVPs to a drive and exports their data. Everything runs locally against fictional seed data and the Firebase
Auth Emulator — no real phone numbers, SMS or Firebase project.

Screenshots of every step from the integrator's verification runs are in [`v2-evidence/`](./v2-evidence/).
The v1 script ([`DEMO.md`](./DEMO.md)) is superseded.

## 0. Before the audience arrives (≈ 10 min, not timed)

Five terminals, all from the repo root. Prerequisites: Docker Desktop, Node LTS, Flutter, the `emulator-5554` AVD
running, `apps/api/.env` filled in from `.env.example` (`APP_ENV=development`, `FIREBASE_AUTH_MODE=emulator`,
`STAFF_WEB_ORIGINS=http://localhost:8099`, `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD`).

```bash
# T1 — database (PostGIS on 127.0.0.1:5433, container saarthee-db-1)
npm run db:up

# T2 — Firebase Auth Emulator (port 9099; keep this terminal open)
npx -y firebase-tools@15.32.1 emulators:start --only auth --project demo-saarthee

# T3 — reset to the seeded v2 state (asks for RESET; add -- --dry-run to preview, -- --yes to skip the prompt)
npm run demo:reset
#   recreates only the dev database named in apps/api/.env, migrates, seeds, clears Auth Emulator accounts,
#   clears app data on emulator-5554, grants location/camera/notifications, sets GPS to Ward 30 Paldi,
#   prints the demo accounts and an issues-by-status table.

# T4 — API on port 4000 (http://127.0.0.1:4000/api/v1/health → ok)
cd apps/api && npm run dev

# T5 — app (profile build: AOT, fast on the emulator; profile keeps cleartext only for 10.0.2.2/localhost)
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export PATH="/opt/homebrew/share/android-commandlinetools/platform-tools:$PATH"
cd apps/mobile
flutter build apk --profile --target-platform android-arm64 \
  --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1 \
  --dart-define=AUTH_EMULATOR_HOST=10.0.2.2:9099 \
  --dart-define=APP_ENV=development
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-profile.apk
for p in ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION CAMERA POST_NOTIFICATIONS; do
  adb -s emulator-5554 shell pm grant in.saarthee.saarthee android.permission.$p; done
adb -s emulator-5554 emu geo fix 72.5714 23.0225   # Ward 30 Paldi

# T5 (same terminal, after the APK) — staff web console on http://localhost:8099
flutter build web -t lib/main_staff.dart --profile \
  --dart-define=API_BASE_URL=http://localhost:4000/api/v1 \
  --dart-define=AUTH_EMULATOR_HOST=localhost:9099 \
  --dart-define=APP_ENV=development
python3 -m http.server 8099 --directory build/web
```

Browser windows to open before starting (Chrome):

| Window | URL | Signed in as |
|---|---|---|
| A (normal) | http://localhost:8099 | moderator — "Sign in with phone", +91 90000 00025 |
| B (incognito) | http://localhost:8099 | admin — "Admin sign-in with email", `SEED_ADMIN_EMAIL` + password from `apps/api/.env` |
| C (guest profile) | http://localhost:8099 | representative — "Sign in with phone", +91 90000 00027 |

### Demo accounts (all fictional test numbers; phone OTP through the Auth Emulator)

| Role | Sign-in | Notes |
|---|---|---|
| Citizen A | +91 90000 00001 | new account; answers the age question once; the reporter |
| Citizen B | +91 90000 00003 | new account; the neighbour who verifies the fix |
| Follower | +91 90000 00021 | seeded "Sample Citizen Asha" (Gujarati) |
| Moderator | +91 90000 00025 | seeded "Sample Moderator Esha"; staff web + in-app Staff tools |
| Representative | +91 90000 00027 | seeded, verified for Sample Corporator 18-A (Ward 18 Navrangpura) |
| Admin | `SEED_ADMIN_EMAIL` (default `admin@saarthee.local`) | password = `SEED_ADMIN_PASSWORD` in `apps/api/.env` (never shown on screen) |

**Reading an OTP** (type only the 10 digits after +91 in the app; the code is the newest entry for that number):

```bash
curl -s http://127.0.0.1:9099/emulator/v1/projects/demo-saarthee/verificationCodes | python3 -m json.tool
```

### `adb` helpers (`scripts/ui.sh`)

```bash
bash scripts/ui.sh dump                      # visible labels with tap centres
bash scripts/ui.sh tap "Submit report"       # tap the first label matching a regex (add a number for the nth)
bash scripts/ui.sh type "9000000001"         # type into the focused field
EVIDENCE_DIR=docs/demo/v2-evidence bash scripts/ui.sh shot my-step   # screenshot
adb -s emulator-5554 emu geo fix 72.5714 23.0225                     # GPS back to Ward 30 Paldi
adb -s emulator-5554 shell monkey -p in.saarthee.saarthee -c android.intent.category.LAUNCHER 1   # open the app
```

Emulator camera: Extended controls → Camera → Back camera = VirtualScene (walk to a textured wall), so photos are not black.

## The 7 minutes

| # | Time | Segment | Who / where |
|---|---|---|---|
| 1 | 0:00–0:40 | Onboarding in Gujarati | phone, visitor |
| 2 | 0:40–1:50 | Report with photo (sign in as citizen A) | phone, citizen A |
| 3 | 1:50–2:30 | Feed, map and "Me too" | phone, citizen A |
| 4 | 2:30–3:10 | Moderator acknowledges on the web console | window A |
| 5 | 3:10–4:00 | Moderator marks fixed with an after photo | phone, moderator |
| 6 | 4:00–4:30 | Representative ward dashboard | window C |
| 7 | 4:30–5:15 | Neighbour verifies the fix | phone, citizen B |
| 8 | 5:15–6:00 | Warning alert with two approvals | windows A + B, phone |
| 9 | 6:00–6:25 | My Ward message relay | phone, citizen B |
| 10 | 6:25–6:45 | Services and drive RSVP | phone, citizen B |
| 11 | 6:45–7:00 | Privacy: export and delete | phone, citizen B |

### 1. Onboarding in Gujarati (0:00–0:40)

1. Open the app (launcher icon or the `monkey` command). **Expect:** "Choose your language / ભાષા પસંદ કરો" with two tiles. → [01-language.png](./v2-evidence/01-language.png)
2. Tap **ગુજરાતી**. The whole app switches to Gujarati. → [02-language-gu.png](./v2-evidence/02-language-gu.png)
3. Intro screen → tap the continue button. → [03-intro-gu.png](./v2-evidence/03-intro-gu.png)
4. Home ward: tap **Use my location** (Gujarati label). **Expect:** "Ward 30 Paldi" suggested from GPS → confirm. → [04-ward-gu.png](./v2-evidence/04-ward-gu.png)
5. **Expect:** Gujarati Home with the green header, the orange "Report a problem" card and the ward alert card. → [05-home-gu.png](./v2-evidence/05-home-gu.png), [10-home-ward-alert.png](./v2-evidence/10-home-ward-alert.png)
6. Say: "Browsing needs no account." Switch language to English from the app bar for the rest of the demo. → [06-home-en.png](./v2-evidence/06-home-en.png)

*Fallback:* GPS not picked up → `adb -s emulator-5554 emu geo fix 72.5714 23.0225` and tap again, or choose Paldi from the ward list.

### 2. Report with photo (0:40–1:50)

1. Tap **Report a problem**. Tap the **Roads** tile. **Expect:** sign-in sheet (an account is needed to report). → [11-report-step1.png](./v2-evidence/11-report-step1.png)
2. Mobile number `9000000001` → send code → read the OTP with the `curl` above → type it → **Verify**. → [12-signin-phone.png](./v2-evidence/12-signin-phone.png), [13-signin-otp.png](./v2-evidence/13-signin-otp.png)
3. **Are you 18 or older?** → **Yes, I am 18 or older**. → [14-signin-age.png](./v2-evidence/14-signin-age.png)
4. Step 2 of 3: **Take photo** (system camera, shutter, ✓). Faces and plates are blurred on the device. → [16-report-step2.png](./v2-evidence/16-report-step2.png), [16c-report-step2-blurring.png](./v2-evidence/16c-report-step2-blurring.png), [16d-report-step2-blurred.png](./v2-evidence/16d-report-step2-blurred.png)
5. Step 3 of 3: location pin in Paldi, optional note → **Submit report**. → [17-report-step3.png](./v2-evidence/17-report-step3.png), [18-report-submitting.png](./v2-evidence/18-report-submitting.png)
6. **Expect:** green circle, drawn check and the reference `SA-XXXXXXXX`. Read it out. → [19-report-submitted.png](./v2-evidence/19-report-submitted.png)

*Fallback:* black camera frame → set VirtualScene (§0) or proceed with the black photo (it still uploads). A duplicate card ("Add me too") may appear near a seeded Paldi issue — tap **Add me too** to show duplicate handling, then report again a little further away (`emu geo fix 72.5690 23.0205`). OTP rejected → newest code from the `curl` list; codes are per request.

### 3. Feed, map and "Me too" (1:50–2:30)

1. **Home** → scroll the ward feed; pull down to refresh (chevron). → [40-home-feed.png](./v2-evidence/40-home-feed.png), [41-home-near-you.png](./v2-evidence/41-home-near-you.png), [46-pull-refresh-chevron.png](./v2-evidence/46-pull-refresh-chevron.png)
2. **Map** tab → pins drop over Paldi; tap a cluster, then a pin → preview sheet. → [42-map.png](./v2-evidence/42-map.png)
3. Open a **seeded** Paldi issue (not your own) → **Me too**. **Expect:** spring, count rolls up, "Following" on. → [43-issue-detail.png](./v2-evidence/43-issue-detail.png), [44-issue-metoo-following.png](./v2-evidence/44-issue-metoo-following.png)

*Fallback:* map tiles blank (no internet) → pins and the preview sheet still work; show the list on Home instead.

### 4. Moderator acknowledges on the web console (2:30–3:10)

1. Window A (moderator). **Expect:** staff dashboard with counts. → [web/staff-dashboard-moderator.jpg](./v2-evidence/web/staff-dashboard-moderator.jpg), [web/staff-login-branded.jpg](./v2-evidence/web/staff-login-branded.jpg)
2. **Moderation** → open the new `SA-…` report (newest in Paldi) → **Looks fine** → **Acknowledge**. → [32-staff-moderation-flagged.png](./v2-evidence/32-staff-moderation-flagged.png), [33-staff-acknowledged.png](./v2-evidence/33-staff-acknowledged.png)
3. Back on the phone, open the issue: the status chip cross-fades to **Acknowledged**; the bell shows an update.

*Fallback:* CORS error in the browser console → `STAFF_WEB_ORIGINS=http://localhost:8099` in `apps/api/.env`, restart the API. Web login fails → do the same in-app: Me → **Staff tools** (step 5 account).

### 5. Moderator marks fixed with an after photo (3:10–4:00)

1. Phone: **Me** → **Sign out** → **Sign in** with `9000000025` (moderator). → [30-account-staff.png](./v2-evidence/30-account-staff.png)
2. **Staff tools** → the `SA-…` issue → **Mark as fixed** → **Take photo** (after photo) → confirm. → [31-staff-home.png](./v2-evidence/31-staff-home.png), [34-staff-fixed-sheet.png](./v2-evidence/34-staff-fixed-sheet.png), [35-staff-marked-fixed.png](./v2-evidence/35-staff-marked-fixed.png)
3. **Expect:** timeline grows a "Fixed" step with the after photo; followers get an update. → [36-follower-inbox-ack-fixed.png](./v2-evidence/36-follower-inbox-ack-fixed.png)

*Fallback:* use window A → issue → **Mark as fixed** without a photo (note only), and say the after photo is taken on a phone.

### 6. Representative ward dashboard (4:00–4:30)

1. Window C (representative +91 90000 00027). `/staff` opens the **Ward dashboard** for Ward 18 Navrangpura: stat tiles count up, category bars grow, overdue list. → [50-rep-ward-dashboard.png](./v2-evidence/50-rep-ward-dashboard.png), motion [rep-dashboard-first-view.mp4](./v2-evidence/motion/rep-dashboard-first-view.mp4)
2. Point out: representatives can acknowledge and mark fixed in their own wards only; they cannot verify, reject, merge or hide.

*Fallback:* "No access" → the account is not verified; re-run `npm run demo:reset` (seeds the verified claim).

### 7. Neighbour verifies the fix (4:30–5:15)

1. Phone: **Me** → **Sign out** → **Sign in** with `9000000003` (citizen B) → age question → Yes.
2. **Map** or Home feed → the `SA-…` issue (now "Fixed") → **Is it fixed?** → **Yes, it's fixed**.
3. **Take photo** (you are within 100 m: the emulator GPS is still at the report point) → **Send**. **Expect:** the button becomes a progress bar, a toast with a drawn check, and the chip changes **Fixed → Verified**.

*Fallback:* `LOCATION_TOO_FAR` → `adb -s emulator-5554 emu geo fix 72.5714 23.0225` (the report point) and send again. To show reopening instead: sign in as citizen A and answer **Still not fixed** → chip "Reopened".

### 8. Warning alert with two approvals (5:15–6:00)

1. Window A (moderator) → **Alerts** → **New alert**: type Water cut, severity **Warning** ("Warning and Critical need two approvers"), target Ward 30 Paldi, title and body in **both** Gujarati and English, validity today → **Send for approval** → **Approve** (first approval).
2. Window B (admin, a different person) → **Alerts** → the pending alert → **Approve** → **Publish now**. Show "Approved by … (moderator)" and "(admin)".
3. Phone: the in-app banner slides in; **Alerts** tab lists the Warning with severity icon + word, source line and validity; the bell's inbox has it. → [24-alerts-tab.png](./v2-evidence/24-alerts-tab.png), [25-alerts-warning.png](./v2-evidence/25-alerts-warning.png), [26-inbox.png](./v2-evidence/26-inbox.png)
4. Say: on the pilot this is also an FCM push; locally the push is recorded in the `notifications` table:
   `docker exec saarthee-db-1 psql -U saarthee -d saarthee -c "SELECT kind, status, channel, created_at FROM notifications ORDER BY created_at DESC LIMIT 5"`

*Fallback:* no time to compose → use the seeded pending Warning "Waterlogging likely in low areas": admin **Approve** → **Publish now**. Moderator cannot give the second approval — that refusal is itself worth showing.

### 9. My Ward message relay (6:00–6:25)

1. **My Ward** tab → Ward 30 Paldi: four corporators, MLA, MP, each with source and "last verified" date. → [20-myward.png](./v2-evidence/20-myward.png)
2. Open a corporator → **Message** → write a short note → **Send message**. **Expect:** "Message sent" toast with a drawn check. → [21-message-form.png](./v2-evidence/21-message-form.png), [22-message-filled.png](./v2-evidence/22-message-filled.png), [23-message-sent-toast.png](./v2-evidence/23-message-sent-toast.png)
3. Say: the citizen's phone is never shared; the relay email goes out from Saarthee (locally the email driver writes a file).

*Fallback:* the 4th Paldi seat has no official email, so its **Message** is disabled by design — pick another corporator.

### 10. Services and drive RSVP (6:25–6:45)

1. Home → **Drives and services** → **AMC services** → open one service: steps, official link, "Saarthee is independent" line.
2. **Drives and events** → "Tree planting on the canal road (sample)" → **I'm going**. **Expect:** button morphs, attendee count rolls. → [27-initiative.png](./v2-evidence/27-initiative.png), [28-rsvp-going.png](./v2-evidence/28-rsvp-going.png), motion [initiative-rsvp.mp4](./v2-evidence/motion/initiative-rsvp.mp4)

*Fallback:* RSVP error → check the API terminal; show the seeded initiative list instead.

### 11. Privacy: export and delete (6:45–7:00)

1. **Me** → **Privacy and your data** → **Download my data**: JSON export with the phone masked.
2. **Delete my account** → **Delete account**. **Expect:** signed out; citizen B's verification stays on the issue's timeline as "A resident of Paldi", with no link to the deleted account.

*Fallback:* skip the delete if you want to repeat steps; `npm run demo:reset -- --yes` restores everything in ≈ 1 minute.

## After the demo

```bash
npm run demo:reset -- --yes      # back to the seeded state (DB, Auth Emulator accounts, app data, GPS)
```

Evidence: emulator screenshots `v2-evidence/*.png`, web console `v2-evidence/web/`, brand `v2-evidence/brand/`,
motion clips `v2-evidence/motion/*.mp4` (app launch, home first load, pull to refresh, inbox swipe, initiative RSVP,
Me too spring, representative dashboard first view).

## Known limitations (local demo)

- **Push** is recorded in `notifications` (`PUSH_DRIVER=memory|log`), not delivered by FCM: the app has no Firebase project yet (TASK-04 Deferred — needs a real Firebase project and `google-services.json`).
- **OTP** comes from the Auth Emulator; no SMS is sent. Any +91 test number works.
- **Representative relay** and claim replies use the local email driver; SES and inbound reply tracking need the founder's domain and credentials.
- **Data** is fictional ("Sample …" names, `079 0000 NNNN` office numbers). The real corporator roster with sources is a launch gate (pilot checklist L2).
- **Gujarati** copy is drafted and awaits native review (`x-review: pending`).
- **Map tiles** need internet; the share image and the representative hotspot map layer are Deferred.
- Motion performance and accessibility on a physical low-end phone are not covered by this demo (TASK-14 Phase D/E2).
