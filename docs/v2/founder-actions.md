# Founder Actions — Saarthee v2

**Created:** 2026-10-04 · **Build:** `v2-demo` / `v2-m6` (ecd5132)

All 14 v2 tasks are In Review and verified on the emulator. The items below need the founder. Each one unblocks
coverage rows that are `Deferred` in [coverage-verification.md](../tasks-v2/coverage-verification.md). When an
item is done, re-run the listed checks, set the rows to `Pass` with evidence, and run:

```
python3 docs/tasks/validate_tasks.py docs/tasks-v2/
python3 docs/tasks-v2/check_coverage.py
```

| # | Action | Status |
|---|---|---|
| 1 | Physical low-end Android phone with USB debugging | Open |
| 2 | Firebase project and service account | Open |
| 3 | Hosting, domain and Play Console | Open |
| 4 | Real 2026–31 corporator roster and IMD/SACHET access | Open |
| 5 | Gujarati and legal review, pilot checklist sign-off | Open |
| 6 | Decision on voice input (REQ-F-019) | Open |

---

## 1. Physical phone with USB debugging

**What to do:** Connect a low-end Android phone (target: Android 10+, ≤ 3 GB RAM) and accept the "Allow USB
debugging" prompt. Phone `RZCT90L8NQN` was seen once but stayed unauthorised.

**Unblocks:**
- REQ-N-004, REQ-O-010: TalkBack pass on report, issue detail, alerts, My Ward.
- REQ-N-007: cold start ≤ 3 s. On the emulator Impeller-GLES adds about 4 s (Skia first frame 2.2 s). Measure with Impeller on and off.
- REQ-N-013: every motion moment ≤ 16 ms per frame (26 traces, profile build).
- REQ-S-007: face and number-plate blur on real photos.
- REQ-F-032: share as a PNG image card.
- REQ-O-009: the physical-phone half of the end-to-end run.

**How to check:**
```
adb devices                                   # phone shows "device", not "unauthorized"
adb shell am start -W -n in.saarthee.saarthee/.MainActivity   # cold start, TotalTime
cd apps/mobile && flutter build apk --profile --target-platform android-arm64 -t integration_test/motion_perf_test.dart
flutter drive --profile --no-dds --use-application-binary build/app/outputs/flutter-apk/app-profile.apk \
  --driver=test_driver/perf_driver.dart -d <serial>
```
Update `docs/demo/v2-evidence/motion/motion-perf-report.md` with the phone's model and results.

## 2. Firebase project and service account

**What to do:** Create the real Firebase project. Add the Android app with SHA-1/SHA-256 fingerprints, enable Phone
Auth, and create a service account for the API. Follow [firebase-setup.md](./firebase-setup.md). Never commit
`google-services.json` or the service-account key. `scripts/check-secret-files.sh` guards this.

**Unblocks:**
- REQ-F-010: real FCM tokens and topic subscription.
- REQ-F-011: real FCM HTTP v1 sends.
- REQ-F-037: alert push to ward, zone and city topics.
- REQ-O-003: fresh-clone run against the real project.

**How to check:** `npm run push:test` from `apps/api`, then confirm the notification arrives on the phone.

## 3. Hosting, domain and Play Console

**What to do:** Choose hosting and a domain for staging and pilot, and give access to the Play Console account.

**Unblocks:**
- P2-12 in `npm run privacy:check`: HTTPS only on staging.
- TASK-13 Deferred rows: deploy, storage, backups, release.
- Play internal and closed testing in the 5 West-zone pilot wards (V2-M6 "pilot live").

**How to check:** `npm run privacy:check` against the staging URL shows 12/12 PASS. Run a backup and restore drill
as described in TASK-13.

## 4. Corporator roster and IMD/SACHET access

**What to do:**
- Compile the real 2026–31 roster for the pilot wards. Use public sources only; record the source and the date
  checked. Use office contacts only, never personal numbers.
- Request IMD/SACHET access for automatic weather alerts.

**Unblocks:**
- REQ-O-011 gate: pilot wards seeded with verified representatives.
- Real My Ward data in place of the clearly fictional samples.
- Automated heat and rain alerts. Until then staff use the manual composer.

## 5. Gujarati and legal review, then pilot checklist sign-off

**What to do:**
- A native Gujarati editor reviews every ARB string marked `"x-review": "pending"` in
  `apps/mobile/lib/core/l10n/app_gu.arb`.
- Legal reviews the privacy notice, the consent text (`v2-1`), the claim declaration and the independence line.
- Sign [pilot-launch-checklist.md](./pilot-launch-checklist.md) (L1–L12).

**Unblocks:** REQ-O-011 and the final move of tasks from In Review to Complete.

## 6. Decision on voice input (REQ-F-019)

**Current state:** Not built in v2. The description is typed only. The `speech_to_text` native plugin could not be
build-checked against AGP 9.1 without a real device.

**Decision needed:** Build it for the pilot, or drop it to a later version.
- **If build:** add the plugin, test Gujarati and English recognition on the phone from item 1, and add the mic button to the report description field.
- **If drop:** mark REQ-F-019 as deferred to v3 in the requirements registry.
