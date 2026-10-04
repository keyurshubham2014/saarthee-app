# Firebase setup (Saarthee v2, TASK-04 — REQ-O-003)

Saarthee uses Firebase for two things only: **phone-number sign-in** (Firebase Authentication) and **push
notifications** (Firebase Cloud Messaging, HTTP v1). Nothing Firebase-related is ever committed: the files
below are git-ignored and `scripts/check-secret-files.sh` (CI job `secret-files`) fails if one is tracked.

| File (local only) | Used by | Where it comes from |
|---|---|---|
| `apps/api/secrets/firebase-service-account.json` (or any absolute path outside git) | API (`FIREBASE_AUTH_MODE=google`, `PUSH_DRIVER=fcm`) | Service account key, step 6 |
| `apps/mobile/android/app/google-services.json` | Android build (real Firebase only) | Step 3 |
| `apps/mobile/lib/firebase_options.dart` | App (real Firebase only) | `flutterfire configure`, step 7 |

## 0. Without a Firebase project (default for development)

Everything runs without a real project:

- **API tests** use `FakeFirebaseGateway` and the `memory` push driver — no network.
- **Local API** defaults to `FIREBASE_AUTH_MODE=emulator`, `FIREBASE_PROJECT_ID=demo-saarthee`,
  `PUSH_DRIVER=log` (pushes are written to `notifications`, nothing is sent).
- **Firebase Auth Emulator** (projects named `demo-*` need no Google account):

  ```bash
  # from the repository root (firebase.json: auth on 0.0.0.0:9099, emulator UI off — port 4000 is the API's)
  npx -y firebase-tools@15.32.1 emulators:start --only auth --project demo-saarthee
  # one-shot API check (starts the emulator, runs the check, stops it):
  npx -y firebase-tools@15.32.1 emulators:exec --only auth --project demo-saarthee \
    "npm --prefix apps/api run auth:emulator-check"
  ```

  No Java is needed for the Auth Emulator. It does not send SMS: it prints
  `To verify the phone number +919000000001, use the code NNNNNN.` in its console, and the codes are also at
  `curl -s http://127.0.0.1:9099/emulator/v1/projects/demo-saarthee/verificationCodes`.
- **App against the emulator**: `flutter run --dart-define=AUTH_EMULATOR_HOST=10.0.2.2:9099
  --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1` (Android emulator → host loopback). The app then
  uses the Identity Toolkit REST endpoints of the emulator (`EmulatorAuthGateway`); see TASK-04 §5.6.

Test phone numbers are fictional: `+91 90000 000NN` (e.g. `+919000000001`). Never use a real person's number.

## 1. Create the project (founder)

1. <https://console.firebase.google.com> → *Add project* → name `saarthee-prod` (and later `saarthee-staging`).
   Google Analytics: off. Owner: the founder's Google account; add the developer as *Editor* if needed.
2. Billing: Phone Auth needs the **Blaze** plan for real SMS beyond the free test numbers. Set a budget alert.

## 2. Phone sign-in

1. *Authentication → Sign-in method → Phone* → enable.
2. *Phone numbers for testing*: add two fictional numbers with fixed codes, e.g. `+91 90000 00001` / `123456`
   and `+91 90000 00002` / `654321` (no SMS is sent, no cost).
3. *Settings → SMS region policy* → **Allow** only **India**.
4. Later (TASK-13): App Check with Play Integrity to reduce SMS abuse.

## 3. Android app

1. *Project settings → Your apps → Add app → Android*. Package name = `applicationId` in
   `apps/mobile/android/app/build.gradle.kts` (currently `in.saarthee.saarthee`; keep them identical).
2. SHA fingerprints (needed for phone auth / Play Integrity):
   - debug: `cd apps/mobile/android && ./gradlew signingReport` → copy SHA-1 and SHA-256 of `debug`.
   - release: the upload key **and** the Play App Signing key (Play Console → *App integrity*), TASK-13.
3. Download `google-services.json` → `apps/mobile/android/app/google-services.json` (git-ignored).

## 4. Cloud Messaging

1. *Project settings → Cloud Messaging*: make sure **Firebase Cloud Messaging API (V1)** is enabled
   (the legacy API is not used).
2. Android notification channels are created by the app: `critical_alerts`, `alerts`, `updates`.
3. Topics: `ward_<n>__gu|en`, `zone_<code>__gu|en`, `cat_<slug>__gu|en`, `city_all__gu|en` (D9 + language suffix).

## 5. iOS

Deferred (REQ-O-090). The iOS app stays buildable; APNs key setup is not part of v2.

## 6. Service account for the API

1. Google Cloud console of the same project → *IAM → Service accounts → Create*: `saarthee-api`.
2. Roles: **Firebase Authentication Admin** and **Firebase Cloud Messaging API Admin**. Nothing else.
3. *Keys → Add key → JSON*. Save it **outside git**, e.g. `apps/api/secrets/firebase-service-account.json`
   (`/apps/api/secrets/` is ignored) or `/etc/saarthee/firebase-service-account.json` on the server; `chmod 600`.
4. API environment (`apps/api/.env`):

   ```dotenv
   FIREBASE_AUTH_MODE=google
   FIREBASE_PROJECT_ID=saarthee-prod
   GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/firebase-service-account.json
   PUSH_DRIVER=fcm
   USER_JWT_AUDIENCE=saarthee-app
   USER_JWT_EXPIRES_IN=30d
   CONSENT_TEXT_VERSIONS_V2=v2-1
   GRIEVANCE_EMAIL=<published grievance address>
   ```

   The API refuses to start with `PUSH_DRIVER=fcm` or `FIREBASE_AUTH_MODE=google` and no credentials, and in
   production with anything other than `google`.
5. Rotation: create a new key, deploy it, restart the API, then delete the old key in the console. Rotate at
   least yearly and immediately if a key may have leaked.

## 7. App configuration (real Firebase)

```bash
dart pub global activate flutterfire_cli
cd apps/mobile && flutterfire configure --project=saarthee-prod --platforms=android
```

This writes `lib/firebase_options.dart` (git-ignored; `lib/firebase_options.example.dart` documents the shape).
Real-Firebase delivery in the app is **Deferred — needs Firebase project** (TASK-04 §13): the app ships the
emulator gateway plus the `AuthGateway` interface for the Firebase SDK implementation.

## 8. Manual checks

- `npm run push:test -- --topic ward_12` / `-- --user <userId>` prints the delivery-log row (status, ids).
- `npm run push:flush` sends queued (deferred) notifications; scheduled every 5 minutes in TASK-13.
- `git ls-files | grep -E 'google-services|firebase_options.dart|service-account'` → empty;
  `bash scripts/check-secret-files.sh` → passes.
