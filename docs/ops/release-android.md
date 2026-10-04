# Android release

V2 TASK-13 steps 13–15, REQ-S-013, REQ-O-008. App id `in.saarthee.saarthee`; version from `pubspec.yaml`
(`2.0.0+<build number>`; raise the build number for every upload, or pass `--build-number`).

## HTTPS-only builds (done)

- Cleartext is allowed only in `android/app/src/debug/` (10.0.2.2, localhost). The profile exception was
  removed; `scripts/check-cleartext.sh` (CI `ops` job) fails on any cleartext config outside `src/debug/`,
  on `NSAllowsArbitraryLoads` in iOS, and on non-`https` `API_BASE_URL` in `apps/mobile/env/*.json`.
- At startup `apiBaseUrlIsAllowed(API_BASE_URL, buildMode)` (`lib/core/config/api_url_policy.dart`) must pass,
  otherwise the app shows only "This build is misconfigured. Please install the latest version from Play."
  (`configErrorBody`) and makes no request. Debug may use `http://10.0.2.2|localhost` (and a LAN IP passed as
  `DEV_CLEARTEXT_HOST` by `scripts/run-lan-phone.sh`). Unit-tested in `test/core/config_test.dart` (F-13-01).

## Upload key (once) — Deferred: needs the founder's vault and Play Console account

```bash
mkdir -p ~/saarthee-keys && cd ~/saarthee-keys
keytool -genkeypair -v -keystore saarthee-upload.jks -storetype PKCS12 -alias saarthee-upload \
  -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Saarthee, O=Saarthee, L=Ahmedabad, C=IN"
keytool -list -v -keystore saarthee-upload.jks -alias saarthee-upload   # note SHA-1 and SHA-256
```

Back up the `.jks` and both passwords in the founder's vault immediately. Then create
`apps/mobile/android/key.properties` (git-ignored; template `key.properties.example`) — or export
`SAARTHEE_UPLOAD_STORE_FILE`, `…_STORE_PASSWORD`, `…_KEY_ALIAS`, `…_KEY_PASSWORD`. Never commit either and
never paste passwords into CI logs. Lost upload key: Play Console → App integrity → "Request upload key
reset" with a new key's certificate (Play App Signing keeps the real signing key safe).

## Build (integrator / build lead machine)

```bash
cd apps/mobile
flutter build appbundle --release --dart-define-from-file=env/staging.json --build-number <n>   # internal
flutter build appbundle --release --dart-define-from-file=env/pilot.json   --build-number <n+1> # closed
```

- Without `key.properties` the release build stops at `preReleaseBuild` with "Release signing is not
  configured…" (AC-11). Local emulator builds only: add `-Psaarthee.allowDebugSigning=true` (Play rejects it).
- Verify: `bundletool build-apks --bundle build/app/outputs/bundle/release/app-release.aab --output /tmp/s.apks --mode universal`,
  unzip, then `apksigner verify --print-certs universal.apk` → upload certificate SHA-256 from above.
- `apkanalyzer manifest print` on the profile and release APKs: no `networkSecurityConfig`, no
  `usesCleartextTraffic="true"`, `debuggable` absent/false (M-13-08). Record AAB size here: ___ MB.
- Replace `saarthee.example` in `env/*.json` with the real domain before the first upload.

## Play Console — Deferred: needs the founder's Play Console developer account

1. Create app "Saarthee — Amdavad civic issues", default language English (India), app, free.
2. App integrity → enrol in **Play App Signing**; upload the first AAB to **Internal testing** (testers: team
   list). Copy the **app-signing** and **upload** certificate SHA-1/SHA-256 to TASK-04 (Firebase Android app).
3. Store listing (en-IN and gu): title `Saarthee — Amdavad civic issues`; the first line of both descriptions:
   - en: "Saarthee is an independent app. It is not made by or affiliated with the Amdavad Municipal Corporation."
   - gu: "સારથી એક સ્વતંત્ર ઍપ છે. તે અમદાવાદ મ્યુનિસિપલ કોર્પોરેશન દ્વારા બનાવવામાં આવી નથી કે તેની સાથે જોડાયેલી નથી."
   Icon/feature graphic from `docs/brand/`; screenshots from staging with fictional data only; no AMC logo or marks (D1).
4. Policy: privacy policy URL `https://<domain>/privacy/`; account deletion URL `https://<domain>/delete-account/`
   (Cloudflare Pages project from `infra/site/`, build command none, output dir `infra/site`; run
   `node scripts/check-site.mjs --release` first — it fails while the draft banner or the grievance-email
   placeholder remain). Content rating questionnaire; target audience **18+**; ads **none**; app access:
   reviewer instructions with a Firebase **test** phone number + fixed OTP (TASK-04), never a real number.
5. **Data safety** — enter exactly this (source: TASK-13 §5.4 and Spec §11; any change in data use must update
   this table, the form, and `infra/site/privacy/` together):

| Data type | Collected | Shared | Purpose | Optional |
|---|---|---|---|---|
| Phone number | Yes | No | Account management, fraud prevention | No |
| Name | Yes | No | App functionality | Yes |
| Precise location | Yes | No | App functionality | Yes |
| Photos | Yes | No | App functionality | Yes |
| Other in-app messages | Yes | Yes (representative, user-initiated) | App functionality | Yes |
| Other user-generated content | Yes | No | App functionality | Yes |
| App interactions | Yes | No | Analytics | No |
| Device or other IDs | Yes | No | App functionality | No |
| Crash logs / diagnostics | No | — | — | — |

   Plus: encrypted in transit — Yes; users can request deletion — Yes; no ads; target audience 18+.
6. **Closed testing** track "Pilot – West zone" (pilot build), testers = a Google Group; share the opt-in link.
7. Screenshot every submitted page into `docs/ops/play/` (M-13-10).

## Status

| Item | State |
|---|---|
| Cleartext removal, HTTPS guard, CI check | Done (F-13-01 passing) |
| Signing config (key.properties / env, fails without) | Done — not executed: Gradle builds belong to the integrator |
| Upload key, Play App Signing, tracks, listing, Data safety | **Deferred — needs the founder's Play Console account and vault** |
| Privacy + deletion pages | Built (`infra/site/`); **Deferred — needs domain + Cloudflare Pages, grievance email, legal and native Gujarati review (Open Question 6)** |
