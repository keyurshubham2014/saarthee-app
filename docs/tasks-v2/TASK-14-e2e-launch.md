# TASK-14: End-to-End Verification, Accessibility and Pilot Launch

| Field | Value |
|---|---|
| Task ID | TASK-14 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | TASK-07, TASK-08, TASK-11, TASK-12, TASK-13 |
| Blocks | None |
| Requirement IDs | REQ-N-010, REQ-N-013, REQ-O-009, REQ-O-010, REQ-O-011, REQ-O-012 |
| Primary Spec Refs | Spec §2 (D5, D11), §7, §8, §11, §12; DS §5, DS §6, DS §7, DS §8, DS §9; v1 approach `docs/tasks/TASK-10-e2e-verification-gap-closure.md` |
| Last Updated | 2026-10-03 |

## 1. Objective

Prove, with recorded evidence, that the whole of Saarthee v2 works in the running system on an emulator and on a physical low-end Android phone, close every gap found, and launch the pilot in five West-zone wards. At the end of this task:
- the coverage matrix (`docs/tasks-v2/coverage-verification.md`) reports every active requirement (112 at plan time; the registry total at audit time) `Pass`, `Fixed` or `Deferred` with a recorded decision, and `check_coverage.py` exits 0;
- Flutter widget tests cover every core DS §5 component, and an emulator integration test drives report → lifecycle → verify end to end in CI-runnable form;
- the privacy sweep (`scripts/privacy-checks.mjs`, extended for v2) passes: no phone in public responses, clean logs, working export and delete, alerts carrying sources;
- an accessibility audit with TalkBack, 2.0× font, Gujarati and reduced motion passes on report, issue detail, alerts and My Ward;
- every DS §6 motion catalogue moment holds 60 fps with no frame > 16 ms on the reference low-end phone in a profile build, animates only transform/opacity/colour, never flashes more than 3 times per second, and the core loop works with system "Remove animations" on — with timeline summaries and screen recordings in `docs/demo/v2-evidence/motion/` (REQ-N-013);
- the pilot launch checklist for Paldi, Navrangpura, Vasna, Naranpura and Nava Vadaj is complete and signed, and the app is live on the Play closed-testing track;
- v1 documents are marked superseded where v2 differs; a v2 demo script and `npm run demo:reset` exist.

This is milestone **V2-M6 Pilot live** (with TASK-13).

## 2. Scope

### In Scope
- **Coverage audit:** run `python3 docs/tasks-v2/check_coverage.py` and `python3 docs/tasks/validate_tasks.py docs/tasks-v2/`; walk every active requirement against the running system; sweep the Spec §7 endpoint inventory, Spec §8 route inventory, error codes, env vars and seed coverage so nothing the registry missed slips through.
- **Automated tests (REQ-N-010):** Flutter widget tests for the DS §5 component library; one emulator integration test (report → acknowledge → mark fixed → verify); the full API Vitest suite and Flutter tests running in CI.
- **Privacy sweep:** extend `scripts/privacy-checks.mjs` with v2 checks (public responses, logs, `/me/export`, `DELETE /me`, alerts sources, relay phone hiding, staff/ward exports, evidence photo access, EXIF).
- **Accessibility audit (REQ-O-010):** TalkBack, 2.0× font, Gujarati, on report, issue detail, alerts and My Ward (plus sign-in and verify, which sit inside those flows).
- **Motion performance and safety (REQ-N-013, DS §6):** profile-build frame timing of every DS §6 catalogue moment on the reference low-end phone (`flutter drive --profile` with `traceAction`, DevTools timeline for misses), transform/opacity/colour-only check, flash and loop check, full core loop with system "Remove animations" on and with the in-app Animations switch off; evidence in `docs/demo/v2-evidence/motion/`.
- **Device verification (REQ-O-009):** full loop on the Android emulator and on a physical low-end Android phone with the release build from the Play internal track against staging.
- **Pilot launch checklist (REQ-O-011):** verified representative roster for the 5 wards, services links checked, moderators and admins onboarded, alert two-person approval rehearsed, Play closed testing with pilot testers, go/no-go record.
- **Documentation (REQ-O-012):** "Superseded by v2" notices in v1 docs `docs/00…07` and `docs/tasks/00-task-summary.md`, links to `docs/v2/saarthee-v2-spec.md`; spec deviations written back into the v2 spec's decisions table.
- **Gap closure:** fix every `Fail` / `Not Verified` row; placeholder/TODO sweep; S1/S2 bug triage and fixes.
- **Demo:** `docs/demo/DEMO-v2.md` and updated `scripts/demo-reset.sh` (`npm run demo:reset`) for the v2 seed and emulator.

### Out of Scope
- New features not in the registry. A spec item found with no requirement is **added** as a new REQ ID owned by TASK-14 (step 7), not silently built or dropped.
- Production (open) Play release and iOS store release (REQ-O-090, deferred).
- WhatsApp/SMS channels, Hindi, ward polls, CCRS integration (REQ-F-090…094, deferred).
- Deployment infrastructure itself (TASK-13); this task only uses the staging/pilot environments it delivers.
- Legal drafting of DPDP notices; this task records the legal sign-off as a launch gate (summary Open Question 6).

## 3. Prerequisites

- TASK-01…TASK-13 `Complete` on the summary board; their coverage rows should already be `Pass`. This task re-verifies end to end.
- Staging and pilot environments from TASK-13 (HTTPS API, managed PostgreSQL + PostGIS, R2, backups, uptime monitor); Play internal and closed-testing tracks with release signing.
- Firebase project with **test phone numbers** configured (fictional numbers with fixed OTP codes) for automated and demo sign-in; Firebase Auth Emulator available for local runs.
- Devices:
  - Android emulator (API 34+, Pixel profile) with virtual camera and location;
  - a **physical low-end Android phone** — the DS §6 reference device: Android 10, 3 GB RAM (any ≤ 3 GB RAM phone on Android 10+ if that exact spec is unavailable; model, RAM, Android version and renderer (Impeller/Skia) recorded in §13);
  - a low-end AVD (API 29, 3 GB RAM, 2 cores) for early motion pre-checks only;
  - a second phone or emulator for the "neighbour" verifier and push receipt.
- Pilot data inputs: 2026–31 corporator roster for the 5 wards with source URLs (summary Open Question 1), MLA/MP mapping, service links (TASK-12), moderator names (founder).
- Gujarati copy reviewed by a native editor (summary Open Question 5) and legal review of DPDP notices, representative data and election mode (Open Question 6) scheduled before go/no-go.
- `adb` (screen recording via `adb shell screenrecord`, animation settings via `adb shell settings put global …`), Flutter DevTools, and the `integration_test` + `flutter_driver` packages for profile-mode timeline capture.
- Only fictional or team test data in local and staging; pilot production holds real data only after go-live.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-07 | Discovery (feed, map, issue detail, Me too, follow) completes the citizen loop under test; transitively TASK-01…06 |
| TASK-08 | Alerts, approvals and notification inbox are audited (sources, two-person approval, inbox) |
| TASK-11 | Representative claim and dashboard close the operator loop; transitively TASK-09 and TASK-10 |
| TASK-12 | Services directory and initiatives; link checker output feeds the launch checklist |
| TASK-13 | Staging/pilot environments, R2, backups, monitoring, Play tracks and HTTPS-only release builds |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-N-010 | Flutter widget tests for core components and an integration test of report → verify on the emulator | Spec §12 |
| REQ-N-013 | Motion performance and safety: every DS §6 catalogue moment holds 60 fps with no frame > 16 ms on the reference low-end phone (profile build, DevTools timeline evidence); only transform/opacity/colour animated; no element flashes > 3 times per second; reduced-motion run of the core loop passes | DS §6, DS §7 |
| REQ-O-009 | Full v2 end-to-end verification on emulator and a physical low-end Android phone; coverage matrix closed | Spec §12 |
| REQ-O-010 | Accessibility audit (TalkBack, largest font, Gujarati) of report, issue detail, alerts and My Ward | DS §7 |
| REQ-O-011 | Pilot launch checklist: 5 West-zone wards seeded with verified representatives, services and moderators onboarded | Spec D5 |
| REQ-O-012 | v1 spec documents marked superseded where v2 differs; summary links to v2 spec | Spec header |

This task also re-verifies system-wide, without owning them: REQ-S-006 (no reporter identity in public views), REQ-S-004 (export/delete), REQ-S-011 (alert sources), REQ-S-015 (redaction), REQ-S-013 (HTTPS-only release), REQ-N-007 (cold start on a low-end phone), REQ-N-012 (motion tokens and reduced motion, TASK-03).

### 5.2 Data Contracts

No schema change expected. If gap closure needs one, it is a new forward migration. Audit queries (run against local, then staging):

```sql
-- Every issue status represented in the seed (REQ-D-013 re-check)
SELECT status, count(*) FROM issues GROUP BY status ORDER BY 1;

-- Phone-like strings in places that must never hold them
SELECT 'issue_events' t, count(*) FROM issue_events WHERE note ~ '(\+91|\m)[6-9][0-9]{9}\M'
UNION ALL SELECT 'notifications', count(*) FROM notifications WHERE body ~ '(\+91|\m)[6-9][0-9]{9}\M'
UNION ALL SELECT 'events', count(*) FROM events WHERE properties::text ~* 'phone|token|\+91';

-- Alerts published without a source or validity (must be 0)
SELECT id FROM alerts WHERE status = 'published'
  AND (source_name IS NULL OR source_url IS NULL OR valid_to IS NULL);

-- Pilot ward readiness (REQ-O-011)
SELECT w.name_en,
  count(DISTINCT r.id) FILTER (WHERE r.role = 'corporator')                         AS corporators,
  count(DISTINCT r.id) FILTER (WHERE r.source_url IS NULL)                          AS missing_source,
  max(now()::date - r.last_verified_at::date)                                       AS oldest_check_days,
  (SELECT count(*) FROM ward_constituency wc WHERE wc.ward_id = w.id)               AS constituencies
FROM wards w
LEFT JOIN representative_areas ra ON ra.ward_id = w.id
LEFT JOIN representatives r ON r.id = ra.representative_id AND r.term_end >= current_date
WHERE w.name_en IN ('Paldi','Navrangpura','Vasna','Naranpura','Nava Vadaj')
GROUP BY w.id, w.name_en ORDER BY 1;

-- Services shown in the app with a broken link (must be 0 at go-live)
SELECT slug FROM services WHERE link_ok = false;

-- Staff readiness
SELECT role, count(*) FROM users WHERE role IN ('moderator','admin') AND status = 'active' GROUP BY role;
```

New file `docs/v2/pilot-launch-checklist.md` holds the signed checklist (§5.4 table) with dates, owners and evidence links.

### 5.3 API Contracts

**Endpoint inventory sweep (Spec §7).** Every row is exercised against the running API with its happy path and main error, and ticked in §13. Owner = building task.

| # | Group | Endpoints | Key errors to exercise | Owner |
|---|---|---|---|---|
| 1 | Health | `GET /health` | 503 with DB stopped | TASK-01 |
| 2 | Auth & me | `POST /auth/firebase`, `POST /auth/logout`, `GET/PATCH /me`, `GET /me/export`, `DELETE /me`, `POST /me/consents`, `POST /devices` | 401 bad/expired Firebase token, under-18 block, revoked session 401 | TASK-04 |
| 3 | Geo | `GET /wards`, `GET /wards/{id}`, `GET /geo/locate`, `GET /zones` | outside polygons → nearest + `confirm:true`; 400 bad coords | TASK-02 |
| 4 | Categories | `GET /categories` | 429 public read limit | TASK-05 |
| 5 | Issues — write | `POST /photos`, `POST /issues`, `GET /issues/nearby` | 413/415, idempotent 200, 10/day 429 | TASK-05 |
| 6 | Issues — lifecycle | `POST /issues/{id}/status`, `/verifications`, `/escalations`, `/ccrs`, `GET /issues/{id}/events` | disallowed transition 409, verify > 100 m rejected, 20/day 429 | TASK-06 |
| 7 | Discovery | `GET /issues`, `GET /issues/{id}`, `POST/DELETE /me-too`, `POST/DELETE /follow`, `GET /feed`, `GET /map/issues`, `POST /issues/{id}/flags` | bad cursor 400, duplicate me-too idempotent | TASK-07/TASK-10 |
| 8 | Alerts | `GET /alerts`, `GET /alerts/{id}`, `GET/PUT /me/subscriptions`, `GET /me/notifications`, `POST /me/notifications/read` | 404 expired alert detail behaviour, 401 | TASK-08 |
| 9 | Representatives | `GET /wards/{id}/representatives`, `GET /representatives/{id}`, `POST /representatives/{id}/messages`, `POST /representatives/{id}/claims`, `GET /wards/{id}/scorecard` | 5/day relay 429, profanity reject, claim 409 | TASK-09/TASK-11 |
| 10 | Services & initiatives | `GET /services`, `GET /services/{slug}`, `GET /initiatives`, `POST/DELETE /initiatives/{id}/rsvp` | 404 slug, full capacity | TASK-12 |
| 11 | Staff | `/staff/moderation`, `/staff/issues/{id}/*`, `/staff/alerts*`, CRUD `/staff/{representatives,services,initiatives,categories}`, `/staff/rep-claims/*`, `/staff/ward-dashboard*`, `/staff/export`, `/staff/settings/election-mode` | 403 wrong role, 403 `WARD_OUT_OF_SCOPE`, same-approver second approval refused | TASK-08/10/11/12 |

**Error-code sweep.** Every code in `apps/api/src/lib/errors` (v1 codes still in use plus v2 additions from TASK-04…TASK-12) is produced at least once and, where user-facing, shown in the app with its ARB message in English and Gujarati. The list is generated from `ERROR_CODES` at audit time and pasted into §13.

**Privacy-check script contract (`scripts/privacy-checks.mjs`, extended).** Usage: `node scripts/privacy-checks.mjs [baseUrl] [--v1] [--v2]` (default `--v2`; `--v1` keeps the existing 14 checks for the legacy read-only tables). Sign-in uses Firebase Auth Emulator (`FIREBASE_AUTH_EMULATOR_HOST`) locally or Firebase test numbers on staging. Prints `PASS`/`FAIL` per check; exit 1 on any FAIL. v2 checks (ID prefix `P2-`):

| ID | Check |
|---|---|
| P2-01 | Create an issue as test citizen `+91 98765 43210`; `GET /issues`, `/issues/{id}`, `/feed`, `/map/issues`, `/issues/nearby`, `/issues/{id}/events` contain no phone digits, no reporter name, no `reporterId`; reporter shown as "A resident of <ward>" |
| P2-02 | `GET /representatives/{id}` and `/wards/{id}/representatives` expose only `public_phone`/`public_email`; no `user_id`, no claimant data |
| P2-03 | Relay message without phone opt-in: the stored/outgoing relay payload and `/staff/rep-messages` contain no citizen phone; with opt-in it appears only there |
| P2-04 | API log file contains no test phone (any format), no Firebase ID token, no session JWT, no FCM token, no OTP, no relay message body, no comment note |
| P2-05 | `GET /me/export` returns the caller's profile, consents, issues, verifications, messages and follows as JSON, and nothing belonging to another user |
| P2-06 | `DELETE /me` → user `deleted`, issues anonymised (`reporter_id` null / tombstone), the person's photos removed from storage (open → missing), session revoked (401) |
| P2-07 | Every `GET /alerts` item and alert detail has `sourceName`, `sourceUrl`, `validFrom`, `validTo`; published Warning alerts list two different approvers |
| P2-08 | `GET /staff/export` without `includePhone` and `/staff/ward-dashboard/export` contain no phone column or digits; formula cells escaped |
| P2-09 | Rep claim evidence photo: 401 without token, 403 as moderator/representative, 200 as admin with `Cache-Control: no-store` |
| P2-10 | Stored issue photo downloaded via its public URL has no EXIF/GPS/Make/Model |
| P2-11 | Public endpoints return 429 after 120 requests/IP/min; issues 11th/day 429 |
| P2-12 | Responses served over HTTPS on staging; HTTP redirects or refuses (staging run only) |

### 5.4 UI Surfaces & States

**Route inventory sweep (Spec §8).** Each route is reached on the emulator and on the physical phone and shows its default, loading, empty, error, offline and unauthorised states where applicable:

| Citizen | Staff (web + in-app) |
|---|---|
| `/onboarding/language`, `/onboarding/intro`, `/onboarding/ward`, `/sign-in`, `/sign-in/otp` | `/staff` dashboard, moderation queue, issue tools |
| `/` Home, `/map`, `/report/what`, `/report/photo`, `/report/details`, `/report/done` | alerts list, composer, approvals |
| `/issues/:id` (+ verify, escalate, link CCRS sheets) | representatives, claims (`/staff/claims`, `/staff/claims/:id`) |
| `/alerts`, `/alerts/:id`, `/alerts/settings` | services, initiatives, categories, users & roles |
| `/ward`, `/ward/:id`, `/representatives/:id`, `/representatives/:id/message`, `/representatives/:id/claim` | election mode, exports |
| `/services`, `/services/:slug`, `/initiatives`, `/initiatives/:id` | representative: `/staff/ward`, `/staff/ward/issues`, `/staff/messages` |
| `/me`, `/me/reports`, `/me/following`, `/me/settings`, `/me/privacy`, `/me/messages` | |

**Accessibility audit matrix (REQ-O-010, DS §7).** Run on the physical phone; record Pass/Fail per cell with a screenshot (in `docs/demo/v2-evidence/a11y/`) or note in `docs/v2/a11y-audit-v2.md`:

| Screen | TalkBack: labels, order, announcements | 2.0× font: no clipping/overlap | Gujarati: full translation, no clipping, Indic line height | 48 dp, contrast, icon + word |
|---|---|---|---|---|
| Report step 1–3 + done | "Step n of 3" read; category tiles labelled; photo described ("Photo of the problem, taken …"); error summary gets focus | | | |
| Issue detail (+ verify sheet) | status read as word; timeline order; Me too / Follow state announced | | | |
| Alerts inbox + detail | severity word + icon read; source line read; validity read | | | |
| My Ward + representative profile | corporator rows read name, role, ward; "Message" labelled; verified badge read | | | |
| Sign-in (phone, OTP, age) | OTP field and errors announced | | | |

Each screen is also run with system "Remove animations" on: every change is instant or a ≤ 100 ms cross-fade, the same text appears, and state changes are still announced (DS §6, DS §7). Gujarati renders in Baloo Bhai 2 / Mukta Vaani without clipped matras.

**Motion performance matrix (REQ-N-013, DS §6).** Each DS §6 catalogue moment is triggered by `integration_test/motion_perf_test.dart` inside `binding.traceAction(..., reportKey: '<moment>')`, 3 runs each (first run after cold start + 2 warm), in a profile build on the reference phone. Pass = in every run `worst_frame_build_time_millis` ≤ 16 and `worst_frame_rasterizer_time_millis` ≤ 16 and `missed_frame_build_budget_count` = `missed_frame_rasterizer_budget_count` = 0; no layout pass during the motion except its first frame (exempt: report progress bar, timeline step expand); no flash > 3/s. Results in `docs/demo/v2-evidence/motion/motion-perf-report.md` (moment, device, run, worst build ms, worst raster ms, missed frames, layout-free, flash check, recording link):

| # | Moment (DS §6) | Trigger in the perf test | Owner |
|---|---|---|---|
| MO-01 | App launch | Cold start to first screen | TASK-03 |
| MO-02 | Onboarding shared axis + language tile spring | Language → intro → ward | TASK-03 |
| MO-03 | Tab switch fade-through + nav pill | Home → Map → Alerts → My Ward → Home | TASK-03 |
| MO-04 | Push navigation + sheet `springIn` | Open `/me/settings`, back; open ward picker | TASK-03 |
| MO-05 | Press scale | Press-hold-release on primary button and issue card | TASK-03 |
| MO-06 | Skeleton shimmer → content | Feed load with 1 s delayed fixture | TASK-03 |
| MO-07 | Home first load stagger | Fresh Home build | TASK-07 |
| MO-08 | Report card spring + first-launch ring | First launch Home | TASK-07 |
| MO-09 | Report step 1 tile pop + selection | Open Report, select a tile | TASK-05 |
| MO-10 | Between report steps + progress bar | Step 1 → 2 → 3 → back | TASK-05 |
| MO-11 | Photo fly-in + pin drop | Capture fixture photo | TASK-05 |
| MO-12 | Duplicate card slide + "Added ✓" morph | Report near a seeded issue, "Add me too" | TASK-05 |
| MO-13 | Report submitted (circle, drawn check, number) | Submit | TASK-05 |
| MO-14 | Status change chip cross-fade + timeline expand | Push a status update while detail is open | TASK-06 |
| MO-15 | Verify fix (button → progress → toast check, chip Fixed → Verified) | "Yes, fixed" flow | TASK-06 |
| MO-16 | Feed card → detail `Hero` + stagger | Tap a feed card | TASK-07 |
| MO-17 | "Me too" spring + rolling count | Tap Me too | TASK-07 |
| MO-18 | Pull to refresh indicator | Fling down on feed | TASK-07 |
| MO-19 | Map pins drop, cluster zoom, preview sheet | Open Map, tap cluster, tap pin | TASK-07 |
| MO-20 | New alert banner (+ critical single pulse) | Inject alert while open | TASK-08 |
| MO-21 | Inbox swipe to read + badge roll | Swipe a notification | TASK-08 |
| MO-22 | My Ward rows stagger + "Message sent" toast | Open My Ward, send message (fake relay) | TASK-09 |
| MO-23 | Scorecard / dashboard count-up + bars | Open scorecard; open ward dashboard | TASK-09, TASK-11 |
| MO-24 | Initiative RSVP morph + attendee roll | Tap "Going" | TASK-12 |
| MO-25 | Staff console fades | Navigate staff routes on Flutter web (Chrome performance panel) and in-app staff screens on the phone | TASK-10 |

**Pilot launch checklist (REQ-O-011)** — copied into `docs/v2/pilot-launch-checklist.md`, each item with owner, date and evidence:

| # | Gate | Pass condition |
|---|---|---|
| L1 | Ward data | Paldi, Navrangpura, Vasna, Naranpura, Nava Vadaj boundaries checked against AMC ward list (TASK-02); `GET /geo/locate` correct at 3 known points per ward |
| L2 | Representatives verified | Each of the 5 wards has its 4 current corporators, MLA and MP, each with `source_url`, `last_verified_at` within 30 days, checked against two independent sources; no personal numbers (REQ-S-012) |
| L3 | Representative outreach | Claim invitation sent to the 20 corporators' office emails; claims received are reviewed (badge is not a launch gate) |
| L4 | Services | TASK-12 link check run within 7 days; 0 broken links among services shown; independence line on every service page |
| L5 | Moderators | ≥ 2 moderators and ≥ 2 admins active with OTP accounts; moderation guide read; rota for 07:00–22:00 covering every day of the first 2 weeks; emergency contact list |
| L6 | Alert rehearsal | Warning alert drafted, first approval by moderator, second by a different admin, published to a test ward topic, retracted; Critical bypasses quiet hours on a test device |
| L7 | Notifications | Push received on the physical phone for ward alert, issue update and RSVP reminder |
| L8 | Environment | TASK-13 restore drill recorded; uptime monitor green 7 days; error alerting without PII; R2 versioning on |
| L9 | Release | Release build from Play **closed testing** track installed by ≥ 10 pilot testers from the 5 wards; Data safety form matches Spec §11; no cleartext exception (REQ-S-013) |
| L10 | Language & legal | Gujarati copy review done; legal sign-off on DPDP notices, representative data and election mode; grievance contact live in `/me/privacy` |
| L11 | Content | Election mode off (or on, if an election is notified) with banner verified; seed/demo data absent from pilot DB |
| L12 | Go/no-go | Founder signs the checklist; date recorded in summary Change Log |

### 5.5 Permissions & Roles

Re-verify the authorisation matrix end to end with one account per role (visitor, citizen, second citizen, moderator, admin, representative):
- visitor can browse feed, map, issue, alerts, services, ward directory, and is sent to sign-in for report, Me too, follow, verify, message, RSVP (Spec D6);
- citizen cannot reach any `/staff/*` endpoint (403) or screen (unauthorised state);
- moderator cannot give the second approval of a Warning/Critical alert, decide rep claims or change roles;
- representative is limited to own wards and never verifies/rejects/merges/hides (TASK-11);
- every staff action produces one audit line with actor, role and target and no bodies (REQ-S-010);
- deleted and suspended users are refused with 401/403.

### 5.6 Assumptions

- ASSUMPTION: "Verified representatives seeded" (REQ-O-011) means the roster entries are verified against official sources (two independent sources, `last_verified_at` within 30 days), not that corporators have completed the TASK-11 claim. Claims depend on the representatives and cannot gate launch. If wrong: add "≥ 1 claimed corporator per ward" as gate L3.
- ASSUMPTION: The integration test drives the app with provider overrides for camera capture and GPS (fixture JPEG, fixed coordinates inside Navrangpura) because emulator cameras cannot be scripted reliably; the real camera path is covered by the manual device run M-14-08. Sign-in uses a Firebase test phone number against the Firebase Auth Emulator.
- ASSUMPTION: Staff steps inside the integration test (acknowledge, mark fixed) are performed through the API with a seeded moderator token from a test helper, not through the staff UI; staff UI is covered by widget tests and the manual route sweep.
- ASSUMPTION: The physical-device run uses the release build from the Play internal track against **staging**; pilot production is touched only for the go-live smoke test (L9) with team accounts.
- ASSUMPTION: Widget tests assert semantics, layout at 1.0×/2.0× text scale in `en` and `gu`, and states; no golden-image tests (fragile across font rendering). If wrong: add goldens for the status chip and issue card only.
- ASSUMPTION: "Superseded" marking is a banner at the top of each v1 doc plus per-section notes only where v2 contradicts it; v1 docs are not rewritten. v1 task files stay as history.
- ASSUMPTION: Any requirement that cannot be verified (e.g. IMD access never granted, inbound email provider not chosen for REQ-F-056) is set to `Deferred` only with the founder's name and date in the matrix; never `Pass`.
- ASSUMPTION: The REQ-N-013 gate is the **physical** reference phone (profile build, release-equivalent AOT); the low-end AVD is used only for early pre-checks because emulator GPU timings are not representative. If the exact Android 10 / 3 GB model is unavailable, the closest ≤ 3 GB RAM phone on Android 10+ is used and its spec recorded.
- ASSUMPTION: "No frame > 16 ms" is judged per catalogue moment over 3 runs (first after cold start + 2 warm), using the `TimelineSummary` worst build and raster times; the first run counts, so shader-compilation jank on first occurrence is a failure to fix (simpler effect, warm-up), not to excuse.
- ASSUMPTION: "Only transform/opacity/colour animated" is verified by (a) the perf test counting layout timeline events during each moment's frames after the first (exempt: report progress bar and timeline step expand, both clipped, DS §6) and (b) a code sweep for layout-animating widgets; DevTools "Track layouts" is used to investigate any hit.
- ASSUMPTION: The flash rule (≤ 3 flashes/s) is checked by inventorying every repeating animation (`repeat(` sweep: only the skeleton shimmer at 1.2 s per sweep and the refresh chevron while a refresh is in flight may loop; DS §6 treats both as waiting indicators) and by frame-stepping the recordings of MO-08 (first-launch ring) and MO-20 (critical pulse); no automated photosensitivity analyser is required.
- ASSUMPTION: The staff console moment (MO-25) on Flutter web is timed with the Chrome DevTools Performance panel on a typical staff laptop, not on the phone; staff in-app screens are timed on the phone like the rest.
- ASSUMPTION: S1 = data loss, personal data exposed, wrong ward/representative shown, wrong or unsourced alert published, crash in report/verify/alerts; S2 = a P0 flow blocked or unusable with TalkBack. S3 and below are logged in the summary's Open Questions with the build version.
- ASSUMPTION (W-T14D, 2026-10-04): The demo script is 7 minutes (GOAL-V2-PROMPT) rather than step 24's 10, and the emulator GPS is Ward 30 Paldi (72.5714, 23.0225) rather than a Navrangpura point — the founder's demo brief names Paldi and the seeded representative (ward 18) is shown on the web dashboard instead.
- ASSUMPTION (W-T14D): `demo:reset` drops and recreates only the database named in `apps/api/.env` (`DROP DATABASE … WITH (FORCE)` via `docker exec`), then `prisma migrate deploy`, `prisma db seed`, `legacy:migrate`; it no longer drops the Docker volume (that erased every worker's database). `prisma migrate reset` is avoided because the Prisma CLI refuses it non-interactively (TASK-01 §5.6). It refuses unless `APP_ENV=development`, the host is 127.0.0.1/localhost and the name has no prod/pilot/staging.
- ASSUMPTION (W-T14D): `demo:reset` clears Auth Emulator accounts when the emulator is running (seeded staff are re-linked by phone at sign-in, `auth.service.ts`), so citizen A/B always see the age question once.
- ASSUMPTION (W-T14D): Moderator "mark fixed with after photo" is shown in-app (Staff tools) because the after photo needs the phone camera; acknowledge is on the web console. Me too is done by citizen A on a seeded issue to avoid an extra account switch.
- ASSUMPTION (W-T14D): Build deviations from TASK-01…13 §5.6 are recorded as v2 spec decisions D13–D43 (one row each, material ones only); §13 logs were not mined row by row.

## 6. Implementation Steps

**Phase A — Coverage audit**

1. **Baselines.** Run `python3 docs/tasks/validate_tasks.py docs/tasks-v2/` and `python3 docs/tasks-v2/check_coverage.py`; paste outputs into §13. Every row not `Pass` is a work item.
2. **Clean stack.** `npm run db:reset` (v2 seed) → `npm run api:dev` → Firebase Auth Emulator → debug app on the emulator; `GET /health` ok; seed status query (§5.2) covers every issue status.
3. **Registry walk.** Category order REQ-F → REQ-D → REQ-N → REQ-S → REQ-O (counts from the registry header at audit time). For each row perform the owning task's §8 check (cite its ID) and set `Pass`/`Fail` with evidence and date. Use `check_coverage.py --task TASK-NN` per task.
4. **Route sweep.** Reach every route in §5.4 with its states, on emulator and (in Phase E) on the physical phone; staff routes on Flutter web too.
5. **Contract sweeps.** All 11 endpoint groups in §5.3 with key errors; the error-code sweep; every API env var validated at startup and listed in `.env.example` (remove one → clear failure); every dart-define set in each run configuration.
6. **Role sweep.** §5.5 matrix with one account per role.
7. **Registry gaps.** Spec item without a REQ → add a new sequential REQ ID to `requirements-registry.md` with `Covered By: TASK-14`, add to this file's Requirement IDs and §5.1, run `check_coverage.py --sync`, re-run the validator.

**Phase B — Automated tests (REQ-N-010)**

8. **Widget tests** in `apps/mobile/test/widgets/` for: app bar (language switch, bell badge), bottom navigation (5 tabs, labels, selected state), primary button (progress, disabled), inputs (label, optional suffix, error text), error summary (focus), filter/status chips (icon + word for all 7 statuses), list row, issue card (overdue tag, Me too count), status timeline (hollow future steps, after photo), alert card (4 severities, source line, validity), banners (offline, election, independence), empty/loading/error states, representative row (no phone unless published, verified badge), step header ("Step n of 3"), Home header + `sunrise` Report card, category badge (tinted rounded square, 14 slugs), toast (`primaryDark`, drawn check, announced), and the TASK-03 motion widgets (`Pressable`, `StaggeredColumn`, `MotionCheck`, `CountUp`, `RollingCount`) in reduced mode. Each test runs in `en` and `gu` at text scale 1.0 and 2.0, once with `disableAnimations: true`, and asserts no overflow, correct semantics labels and identical text with and without motion.
9. **Integration test** `apps/mobile/integration_test/report_to_verify_test.dart`: sign in with Firebase test number (citizen A) → report `roads` with fixture photo at a Navrangpura point → done → issue detail shows "Reported" → helper acknowledges and marks fixed with moderator token → app receives refresh, timeline shows Fixed → citizen B signs in, opens the issue, "Is it fixed?" → Yes → photo within 100 m → Send → status chip "Verified". Second scenario: "Still not fixed" by reporter → "Reopened". Run with `flutter test integration_test -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1 --dart-define=APP_ENV=test`.
10. **CI.** Ensure the workflow runs API Vitest (all suites from TASK-01…13), `flutter test` (widget), and documents the integration test command (emulator job optional; run locally and record output in §13).

**Phase C — Privacy and security sweep**

11. **Extend `scripts/privacy-checks.mjs`** with P2-01…P2-12 (§5.3), keeping v1 checks behind `--v1`. Add an npm alias `privacy:check` in the root `package.json`. Run locally (all) and on staging (P2-01…12 with test numbers). Record output.
12. **SQL audits** from §5.2 (phone-like strings, unsourced alerts) → 0 rows.
13. **Dependencies.** `npm audit --audit-level=high` (api), `flutter pub outdated` (mobile), Dependabot alerts on. Fix or accept-with-note each high/critical.

**Phase D — Accessibility audit (REQ-O-010)**

14. On the physical phone, run the §5.4 accessibility matrix with TalkBack on, then font size at maximum / display size largest (≈ 2.0×), then app language Gujarati, then grayscale, then system Remove animations on (instant or ≤ 100 ms cross-fade changes, same content). Fix failures in shared components first (TASK-03 set) and re-run widget tests. Record `docs/v2/a11y-audit-v2.md`.

**Phase E — Device verification (REQ-O-009)**

15. **Emulator full loop.** Onboarding (Gujarati) → home ward by GPS → sign in → report with duplicate suggestion → Me too from second account → moderator acknowledge (web console) → representative mark fixed (TASK-11) → neighbour verify → alert published with two approvals → push received → My Ward message relay → services → RSVP → export + delete account. Screenshots to `docs/demo/v2-evidence/e2e/emulator/`.
16. **Physical low-end phone.** Install the release build from the Play internal track (staging API). Same loop as step 15 with the real camera, real GPS, real push; screenshots to `docs/demo/v2-evidence/e2e/device/`. Measure cold start (≤ 3 s, REQ-N-007) and report taps after photo (≤ 4) with screen recording; note RAM and install size. Kill the app during camera hand-off → draft restored.

**Phase E2 — Motion performance and safety (REQ-N-013, DS §6)**

17. **Perf harness.** Add `apps/mobile/integration_test/motion_perf_test.dart` (one `binding.traceAction(() async {…}, reportKey: 'MO-nn')` per §5.4 motion matrix row, fixtures and provider overrides as in step 9, `debugProfileLayoutsEnabled = true` to emit layout events) and `apps/mobile/test_driver/perf_driver.dart` (`integrationDriver(responseDataCallback:)` writing `TimelineSummary.summarize(...).writeTimelineToFile('MO-nn', destinationDirectory: 'build/motion', pretty: true)` and failing a moment whose summary exceeds 16 ms worst build/raster, has missed-budget frames, or has a non-exempt layout event after its first frame). Run on the reference phone: `flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/motion_perf_test.dart -d <phone-serial> --dart-define=APP_ENV=test --dart-define=API_BASE_URL=<staging>/api/v1`, three times. Copy `build/motion/*.timeline_summary.json` to `docs/demo/v2-evidence/motion/perf/`; open any failing moment's `*.timeline.json` in DevTools (Performance → timeline), save a screenshot to `docs/demo/v2-evidence/motion/perf/devtools/`, fix in the owning component (TASK-03 widget first), re-run. Record the device, renderer and per-moment numbers in `docs/demo/v2-evidence/motion/motion-perf-report.md`.
18. **Safety sweeps.** (a) Layout-animation sweep: `rg -n "AnimatedContainer|AnimatedSize|AnimatedPadding|AnimatedAlign|SizeTransition|AnimatedPositioned" apps/mobile/lib` — every hit justified as exempt (progress bar, timeline step) or replaced with transform/opacity. (b) Loop sweep: `rg -n "\.repeat\(|repeat: true|onPlay: .*repeat" apps/mobile/lib` — only the skeleton shimmer and the in-flight refresh chevron; each period ≥ 1 s. (c) Token sweep: `rg -n "Duration\(|Cubic\(|Curves\." apps/mobile/lib/features --glob '!**/dev/**'` returns nothing (TASK-03 guard T-03-22 still green). (d) Frame-step the MO-08 and MO-20 recordings: no element changes brightness more than 3 times in any 1 s window.
19. **Recordings and reduced-motion loop.** For every MO row record a short clip on the reference phone: `adb shell screenrecord --time-limit 10 --bit-rate 6000000 /sdcard/MO-nn-full.mp4` while triggering it, then `adb pull /sdcard/MO-nn-full.mp4 docs/demo/v2-evidence/motion/recordings/`. Then turn on system Remove animations (Settings → Accessibility → Remove animations, or `adb shell settings put global animator_duration_scale 0`, `transition_animation_scale 0`, `window_animation_scale 0`), run the full step 15 loop and I-14-03, and record `MO-nn-reduced.mp4` for MO-01, MO-03, MO-04, MO-10, MO-13, MO-15, MO-16, MO-23; repeat the loop once with system animations on and the in-app Settings → Animations switch off. Restore the scales to 1 afterwards. Evidence contains only test data; blur any number.

**Phase F — Gap closure**

20. **Fix every `Fail` / `Not Verified` row.** Small gaps: fix, commit `V2-TASK-14: fix <REQ-ID> …`, set row `Fixed` with hash. Whole-feature gaps: reopen the owning task (`In Progress`, reason in the summary Change Log), complete it, return.
21. **Placeholder/TODO sweep.** Each remaining hit needs a written justification in §13:
    - `rg -n "TODO|FIXME|XXX|stub|mock|fake|placeholder|lorem|tbd" apps/ --glob '!**/*.lock' --glob '!**/test/**' --glob '!**/integration_test/**'`
    - `rg -n "Color\(0x|Colors\." apps/mobile/lib --glob '!**/theme/**'` (no colours outside tokens)
    - `rg -n "Text\(\s*['\"]" apps/mobile/lib` (no string literals in widgets)
    - `rg -n "console\.log" apps/api/src`
    - `rg -n "AMC logo|amc_logo|#9E6B22|1E3C72" apps/` (no AMC marks, DS §1)
    - Neem design sweep (DS v2.2): `rg -n "Icons\." apps/mobile/lib --glob '!**/theme/**'` (Material Symbols Rounded only, via `SaartheeIcons`); `rg -n "_outlined|Outlined\b" apps/mobile/lib --glob '!**/theme/**'` (no Outlined icon set); `rg -n "fontFamily: *'Noto" apps/mobile/lib` (Noto only as `fontFamilyFallback`; primary families `BalooBhai2` / `MuktaVaani`); `rg -in "civic ?blue|indigo|marigold|secondaryContainer" apps/mobile/lib` (no superseded tokens); `rg -n "sunrise" apps/mobile/lib/features` reviewed — report actions only
    - Check `app_gu.arb` has every key in `app_en.arb` (script count equal; no English values left in `gu` except brand names).
22. **Bug triage.** S1/S2 per §5.6 fixed and re-verified before go/no-go; S3 logged with build version.

**Phase G — Documentation, demo and launch**

23. **v1 superseded (REQ-O-012).** Add at the top of `docs/00-master-index.md`, `docs/01…07-*.md`, `docs/tasks/00-task-summary.md` and `docs/demo/DEMO.md`: "> **Superseded by Saarthee v2** where they differ — see `docs/v2/saarthee-v2-spec.md` and `docs/tasks-v2/00-task-summary.md`." Add per-section notes where v2 contradicts (e.g. invite codes, H1/H2 rates, WhatsApp verify tokens, no-tests decision, indigo/marigold tokens). Link the v2 spec from `docs/00-master-index.md` and `README.md`. Write deviations found in TASK-01…14 (from each §5.6 and §13) into the v2 spec's Decisions table.
24. **Demo.** Rewrite `scripts/demo-reset.sh` for v2: v2 `db:reset --yes`, clear app data, set emulator GPS to a Navrangpura point, ensure Firebase Auth Emulator test numbers, print demo accounts (citizen A/B test numbers + OTP code, moderator, admin, representative) and an issues-by-status table. Write `docs/demo/DEMO-v2.md`: 10-minute script — onboarding in Gujarati, report with photo (≤ 4 taps), duplicate "Me too", map, moderator acknowledge on web console, representative dashboard and mark fixed, neighbour verify, Warning alert with two approvals arriving as push, My Ward relay, services and drive RSVP, privacy export/delete; each step with expected screen and fallback.
25. **Pilot launch (REQ-O-011).** Work through L1–L12 in `docs/v2/pilot-launch-checklist.md`; seed the pilot roster via TASK-09's CSV import with sources; onboard moderators; promote the build to closed testing; hold go/no-go with the founder.
26. **Close-out.** `check_coverage.py` exits 0; `coverage-verification.md` header shows N / N for the registry's active total; all task files `Complete`; summary 14/14, V2-M6 reached, Change Log row; validator 0 errors; commit `V2-TASK-14: e2e verification and pilot launch`, tag the verified build (e.g. `mobile-v2.0.0+N`).

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Widget tests cover the component library
- **Given** the DS §5 component list in step 8
- **When** `flutter test test/widgets` runs in CI
- **Then** every listed component has at least one test, each passes in `en` and `gu` at text scale 1.0 and 2.0 with no overflow, and status/severity tests assert icon + word for every value

**AC-2** — Integration test report → verify on the emulator
- **Given** the local stack with the Firebase Auth Emulator and the emulator running
- **When** `flutter test integration_test/report_to_verify_test.dart` runs
- **Then** both scenarios pass: citizen A reports, the issue is acknowledged and marked fixed, citizen B verifies within 100 m and the chip reads "Verified"; the reporter's "Still not fixed" yields "Reopened"; exactly one issue and the expected `issue_events` rows exist

**AC-3** — Coverage matrix closed
- **Given** TASK-01…13 complete and a clean reset
- **When** `python3 docs/tasks-v2/check_coverage.py` runs at the end of this task
- **Then** it exits 0: every active requirement is `Pass`, `Fixed`, or `Deferred` with decision-maker and date; no `Fail`, no `Not Verified`; every row has evidence

**AC-4** — Inventories complete
- **Given** the §5.3 endpoint groups, error codes, env vars and the §5.4 routes
- **When** each is exercised against the running system
- **Then** every item behaves per spec, and any spec item found without a requirement has been added as a new REQ ID, verified and counted in AC-3

**AC-5** — Full loop on emulator and physical low-end phone
- **Given** the debug build on the emulator and the Play-internal release build on the low-end phone against staging
- **When** the step 15/16 loop is run
- **Then** every step succeeds on both, push notifications arrive on the phone, the draft survives an app kill during camera hand-off, cold start is ≤ 3 s on the phone (or a measured miss is logged as S3 with a fix plan), and the release build has no cleartext exception

**AC-6** — Privacy sweep passes
- **Given** `node scripts/privacy-checks.mjs` with the v2 checks
- **When** it runs locally and on staging
- **Then** P2-01…P2-12 all print PASS (staging-only checks marked), the §5.2 SQL audits return 0 rows, and no public response contains a phone number or reporter identity

**AC-7** — Accessibility audit passes
- **Given** the physical phone with TalkBack, largest font (≈ 2.0×), Gujarati and grayscale
- **When** report, issue detail (with verify), alerts and My Ward (with representative profile) are used end to end
- **Then** every control is announced with a label in the current language, focus order equals visual order, "Step n of 3" and errors are announced, focus moves to the error summary on failed submit, no text clips at 2.0× in either language, statuses and severities are distinguishable without colour, every target is ≥ 48 dp, and with system Remove animations on every change is instant or a ≤ 100 ms cross-fade with the same content; results are recorded in `docs/v2/a11y-audit-v2.md`

**AC-8** — Pilot wards ready and launched
- **Given** the pilot launch checklist L1–L12
- **When** the go/no-go review is held
- **Then** each of Paldi, Navrangpura, Vasna, Naranpura and Nava Vadaj has 4 current corporators plus MLA and MP with sources and recent checks (readiness SQL), services have 0 broken links, ≥ 2 moderators and ≥ 2 admins are active and on the rota, the two-person alert rehearsal is recorded, ≥ 10 pilot testers have installed from Play closed testing, legal and Gujarati reviews are signed, and the founder's sign-off date is in the summary Change Log

**AC-9** — v1 docs superseded
- **Given** the v1 documents `docs/00…07`, `docs/tasks/00-task-summary.md` and `docs/demo/DEMO.md`
- **When** they are opened
- **Then** each starts with the "Superseded by Saarthee v2" notice linking `docs/v2/saarthee-v2-spec.md`, contradicted sections carry a note, `docs/00-master-index.md` and `README.md` link the v2 spec and task summary, and spec deviations from all v2 tasks are in the v2 spec's Decisions table

**AC-10** — No placeholders, no open S1/S2
- **Given** the codebase after gap closure
- **When** the step 21 sweeps run and the bug list is reviewed
- **Then** there are zero unjustified hits (TODO/placeholder, colour literals, widget string literals, `console.log`, AMC marks), `app_gu.arb` has every key, every list screen loads real API data, and there are no open S1/S2 bugs

**AC-11** — Demo reproducible
- **Given** a fresh clone with Docker, the emulator and the Firebase Auth Emulator
- **When** `npm run demo:reset` runs and `docs/demo/DEMO-v2.md` is followed
- **Then** the reset completes without manual steps, prints demo accounts and the issues-by-status table, and every demo step shows the expected screen

**AC-12** — Motion holds the frame budget on the reference phone
- **Given** a profile build on the reference low-end phone (Android 10, 3 GB RAM) and `motion_perf_test.dart` covering MO-01…MO-25 (MO-25 web part in Chrome)
- **When** `flutter drive --profile` runs each moment three times (first after cold start)
- **Then** every moment's timeline summary shows worst frame build ≤ 16 ms, worst raster ≤ 16 ms and zero missed-budget frames in all runs; the summaries are in `docs/demo/v2-evidence/motion/perf/`, any investigated miss has a DevTools screenshot and a fix commit, and `motion-perf-report.md` lists device, renderer and numbers for every moment

**AC-13** — Motion is safe
- **Given** the step 18 sweeps, the perf-test layout counts and the recordings in `docs/demo/v2-evidence/motion/recordings/`
- **When** they are reviewed
- **Then** only transform, opacity and colour are animated (layout during a motion only for the exempt progress bar and timeline step), only the skeleton shimmer and an in-flight refresh indicator loop, no element flashes more than 3 times in any second, no `Duration(`/`Cubic(`/`Curves.` literal exists under `lib/features/**`, and no Lottie or Rive asset ships

**AC-14** — Core loop with reduced motion
- **Given** the reference phone with system Remove animations on (and, in a second run, system animations on with the in-app Animations switch off)
- **When** the step 15 loop and I-14-03 are run
- **Then** every step succeeds with the same content as with motion on, every motion is an instant change or a ≤ 100 ms cross-fade, TalkBack still announces state changes, and `MO-nn-reduced.mp4` recordings are saved

**AC → Requirement**

| AC | Requirements |
|---|---|
| AC-1, AC-2 | REQ-N-010 |
| AC-12, AC-13, AC-14 | REQ-N-013 |
| AC-3, AC-4, AC-5, AC-6, AC-10, AC-11 | REQ-O-009 |
| AC-7 | REQ-O-010 |
| AC-8 | REQ-O-011 |
| AC-9 | REQ-O-012 |

### 7.2 Non-Functional Checklist

**Builds and static checks**
- [ ] API typecheck, lint and all Vitest suites pass; `dart format` check, `dart analyze` and `flutter test` pass; CI green on `main`
- [ ] `npm audit --audit-level=high` clean or each finding accepted with a note; `flutter pub outdated` recorded
- [ ] Release APK/AAB merged manifest has no cleartext exception and no debug flags

**Core flows**
- [ ] P0 flows pass on emulator and physical phone: onboarding, sign-in, report, Me too/follow, lifecycle, verify/reopen, alerts, My Ward relay, staff moderation, alert approvals
- [ ] P1 flows pass: escalation, CCRS link + reminder, scorecard, claims and dashboard, services link check, initiatives RSVP + reminder
- [ ] Retry after a network drop creates one issue; draft survives app kill

**Privacy and safety**
- [ ] `privacy-checks.mjs` v2 all PASS locally and on staging
- [ ] No reporter phone or name in any public view; relay hides phone unless opted in
- [ ] Every published alert shows source, validity and "Relayed by Saarthee"; independence line on About, alerts, services and hand-offs
- [ ] Export and delete verified with a test account on staging
- [ ] Audit log: one line per staff action, no bodies

**Motion (REQ-N-013)**
- [ ] MO-01…MO-25 pass the 16 ms budget on the reference phone in a profile build (3 runs each); `motion-perf-report.md` complete
- [ ] Only transform/opacity/colour animated; loops limited to skeleton and in-flight refresh; no flashing > 3/s
- [ ] Core loop passes with system Remove animations on and with the in-app Animations switch off
- [ ] Motion evidence (`perf/`, `recordings/`, report) in `docs/demo/v2-evidence/motion/` with test data only

**Accessibility and language**
- [ ] §5.4 accessibility matrix all Pass on the physical phone
- [ ] Gujarati: every key translated and reviewed; no clipping at 2.0×

**Task-specific**
- [ ] Every route in §5.4 shows its states; staff routes checked on Flutter web
- [ ] Every fix committed with a `V2-TASK-14:` message and referenced by hash in the matrix
- [ ] Evidence contains only fictional/test data; screenshots blur any number

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-14-01 | `npm run typecheck && npm run lint` (api); `dart format --set-exit-if-changed . && dart analyze` (mobile) | AC-10 |
| API automated | T-14-01 | Full Vitest + Supertest suite (`npm test` in `apps/api`) green in CI, including permissions and rate-limit suites from TASK-01…13 | AC-3, AC-4 |
| API automated | T-14-02 | `node scripts/privacy-checks.mjs` → P2-01…P2-12 PASS (local) | AC-6 |
| API automated | T-14-03 | `node scripts/privacy-checks.mjs https://<staging>/api/v1` → PASS incl. P2-12 | AC-6 |
| Flutter widget | W-14-01 | `flutter test test/widgets` — all DS §5 components (Neem), `en`/`gu`, 1.0×/2.0×, `disableAnimations` on/off, semantics | AC-1 |
| Flutter integration | I-14-01 | `flutter test integration_test/report_to_verify_test.dart -d emulator-5554` — verified scenario | AC-2 |
| Flutter integration | I-14-02 | Same file — reopened scenario | AC-2 |
| Flutter integration | I-14-03 | Same file, both scenarios, on the reference phone with `animator_duration_scale 0` (system Remove animations): navigation asserted after `pump(100 ms)` instead of `pumpAndSettle` for each transition | AC-14 |
| Flutter perf | P-14-01 | `flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/motion_perf_test.dart -d <phone>` ×3 — MO-01…MO-24 within 16 ms build/raster, 0 missed frames, no non-exempt layout | AC-12, AC-13 |
| Web perf | P-14-02 | MO-25 staff console fades in Chrome DevTools Performance (Flutter web profile build): no frame > 16 ms | AC-12 |
| Code sweep | M-14-14 | Step 18 safety sweeps (layout-animating widgets, loops, token literals) and frame-stepping MO-08/MO-20 recordings | AC-13 |
| Device manual | M-14-15 | Step 19: recordings `MO-nn-full.mp4` for every moment, reduced loop with system setting and with in-app switch, `MO-nn-reduced.mp4` | AC-13, AC-14 |
| Verification layer | M-14-01 | `python3 docs/tasks-v2/check_coverage.py` → exit 0, output in §13 | AC-3 |
| Verification layer | M-14-02 | `python3 docs/tasks/validate_tasks.py docs/tasks-v2/` → 0 errors | AC-9 |
| API manual | M-14-03 | Endpoint group sweep (§5.3 rows 1–11) with curl/HTTP file; error-code sweep list pasted | AC-4 |
| App manual | M-14-04 | Route sweep (§5.4) on emulator and Flutter web, states ticked | AC-4 |
| DB manual | M-14-05 | §5.2 audit queries → expected results | AC-6, AC-8 |
| Config manual | M-14-06 | Remove each required env var → clear startup failure; `.env.example` complete; dart-defines per run config | AC-4 |
| Device manual | M-14-07 | Emulator full loop (step 15) with screenshots in `docs/demo/v2-evidence/e2e/emulator/` | AC-5 |
| Device manual | M-14-08 | Physical low-end phone full loop (step 16), cold start and tap counts recorded; screenshots in `docs/demo/v2-evidence/e2e/device/` | AC-5 |
| Accessibility manual | M-14-09 | §5.4 accessibility matrix on the physical phone → `docs/v2/a11y-audit-v2.md` | AC-7 |
| Code sweep | M-14-10 | Step 21 `rg` commands and ARB key parity → zero unjustified hits | AC-10 |
| Launch manual | M-14-11 | L1–L12 in `docs/v2/pilot-launch-checklist.md` signed; readiness SQL output attached | AC-8 |
| Docs manual | M-14-12 | v1 docs banners and section notes; README and master index links; v2 Decisions table updated | AC-9 |
| Demo manual | M-14-13 | Fresh clone → `npm run demo:reset` → walk `DEMO-v2.md` start to end | AC-11 |

Bug notes: build version, device and OS, steps, expected, actual, severity (§5.6), screenshot with numbers blurred.

## 9. Deliverables

- `docs/tasks-v2/coverage-verification.md` at 100% with evidence on every row; `check_coverage.py` exit 0.
- `apps/mobile/test/widgets/*_test.dart` (component suite) and `apps/mobile/integration_test/report_to_verify_test.dart`; `integration_test` dev dependency; CI updated.
- Extended `scripts/privacy-checks.mjs` (v2 checks, `--v1` legacy) and root `privacy:check` script.
- `docs/v2/a11y-audit-v2.md` and `docs/v2/pilot-launch-checklist.md` (signed).
- `apps/mobile/integration_test/motion_perf_test.dart`, `apps/mobile/test_driver/perf_driver.dart`; `docs/demo/v2-evidence/motion/` with `perf/*.timeline_summary.json`, `perf/devtools/` screenshots, `recordings/MO-nn-{full,reduced}.mp4` and `motion-perf-report.md` (REQ-N-013).
- Screenshot evidence in `docs/demo/v2-evidence/{e2e/emulator,e2e/device,a11y}/`.
- Updated `scripts/demo-reset.sh` and new `docs/demo/DEMO-v2.md`.
- Superseded notices in v1 docs; links from `README.md` and `docs/00-master-index.md`; v2 spec Decisions table updated.
- All gap fixes committed (`V2-TASK-14: …`) with hashes in the matrix; tagged verified build; app on Play closed testing for the 5 pilot wards.

## 10. Files Expected to Change

Prediction only — exact fixes depend on what the audit finds.

| Path | Change |
|---|---|
| `apps/api/src/**`, `apps/mobile/lib/**` | Modified (gap, accessibility and translation fixes) |
| `apps/mobile/test/widgets/*_test.dart`, `apps/mobile/test/helpers/` | New |
| `apps/mobile/integration_test/report_to_verify_test.dart`, `apps/mobile/integration_test/helpers/` | New |
| `apps/mobile/integration_test/motion_perf_test.dart`, `apps/mobile/test_driver/perf_driver.dart` | New |
| `apps/mobile/pubspec.yaml` (`integration_test`, `flutter_driver` dev dependencies) | Modified |
| `docs/demo/v2-evidence/motion/**`, `docs/demo/v2-evidence/{e2e,a11y}/**` | New (timeline summaries, recordings, screenshots, report) |
| `apps/mobile/lib/core/l10n/app_gu.arb`, `app_en.arb` | Modified |
| `.github/workflows/*` | Modified (flutter test, API tests) |
| `scripts/privacy-checks.mjs`, `scripts/demo-reset.sh`, root `package.json` | Modified |
| `docs/demo/DEMO-v2.md`, `docs/v2/a11y-audit-v2.md`, `docs/v2/pilot-launch-checklist.md` | New |
| `docs/00-master-index.md`, `docs/01…07-*.md`, `docs/tasks/00-task-summary.md`, `docs/demo/DEMO.md`, `README.md` | Modified (superseded notices, links) |
| `docs/v2/saarthee-v2-spec.md` (Decisions table) | Modified |
| `docs/tasks-v2/coverage-verification.md`, `requirements-registry.md`, `00-task-summary.md`, all `TASK-*.md` | Modified |

## 11. Related Documentation

- `docs/v2/saarthee-v2-spec.md` Spec §2 (D5 pilot wards, D11 v1 retirement), §7 (endpoint inventory, rate limits), §8 (route inventory), §11 (privacy, safety, neutrality), §12 (operations, verification posture).
- `docs/v2/design-system.md` v2.2 ("Neem") DS §5 (component list for widget tests), DS §6 (motion catalogue, performance and accessibility rules), DS §7 (accessibility), DS §8 (key flows and the ≤ 4-tap target), DS §9 (screen inventory).
- `docs/tasks/TASK-10-e2e-verification-gap-closure.md` — v1 approach this task mirrors (phases, sweeps, close-out).
- `docs/tasks-v2/00-task-summary.md` — Decisions & Open Questions 1, 5, 6 (roster, Gujarati review, legal review).
- `docs/tasks-v2/TASK-03-design-system-shell.md` — `SaartheeMotion`, motion widgets, reduced motion, guard test T-03-22.
- `docs/tasks-v2/TASK-13-*.md` — environments, Play tracks, backups, monitoring used here.
- `scripts/privacy-checks.mjs` — v1 checks being extended.

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| 2026–31 corporator roster incomplete or unverifiable | My Ward wrong at launch; trust damage | Start roster compilation at TASK-09; two-source rule; launch a ward only when L2 passes for it (partial launch allowed by founder decision) |
| Low-end phone misses cold-start or memory targets | Poor first impression | Measure early in Phase E; profile build; defer heavy packages; log S3 with plan if within 1 s |
| Motion misses 16 ms on the low-end phone (shimmer, fade-through over heavy tabs, map pins, first-run shader jank) | REQ-N-013 fails; app feels slow | Pre-check on low-end AVD early; fix in the shared TASK-03 widget first; simplify the effect (fewer animated items, `RepaintBoundary`, no blur/shadow animation); reduced scheme is never used to pass the gate |
| Integration test flaky on CI emulators | False failures | Run locally as the gate; provider overrides for camera/GPS; retries only for setup, never assertions |
| Gujarati review or legal sign-off late | Launch slips | Schedule both at TASK-14 start; L10 is an explicit gate |
| Wrong alert published during pilot | Serious trust damage | Two-person approval rehearsal (L6), retract path tested, moderator rota |
| Gaps larger than expected | Overrun or silent absorption | New REQ IDs; reopen owning task for whole-feature gaps; record in Change Log |
| Evidence contains personal data | Privacy breach in docs | Test numbers only; blur screenshots; never paste tokens (use `<token>`) |
| Pilot DB contains demo data | Fake issues visible to residents | L11 gate; `demo:reset` refuses non-local `DATABASE_URL` |

## 13. Progress Status

**Current status:** Not Started

**Progress:** 0%

| Date | Progress | Commit |
|---|---|---|
| 2026-10-04 | W-T14D step 23: v1 docs 00–07, v1 task summary and DEMO.md carry the superseded banner + per-section v2 notes (invite codes, H1/H2, WhatsApp verify tokens, no-tests, indigo/marigold); v2 spec linked from master index + README; spec decisions D13–D43 | f0b5fff, 4d6262b |
| 2026-10-04 | W-T14D step 24: `scripts/demo-reset.sh` v2 (`--dry-run`, guards, Auth Emulator, emulator perms + GPS, accounts + issues-by-status), `docs/demo/DEMO-v2.md` 7-minute script | 710f57c, 5847109 |
| 2026-10-04 | W-T14D step 25: `docs/v2/pilot-launch-checklist.md` L1–L12 (L1/L4/L6/L8 Partial with evidence; founder items Deferred with exact actions) | e465354 |

## 14. Completion Checklist

- [ ] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [ ] Static checks pass and every AC verified by the checks in §8
- [ ] Automated tests added and passing
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified on every route
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed
- [ ] No open S1/S2 bugs
- [ ] Motion performance matrix MO-01…MO-25 all Pass on the reference phone; `docs/demo/v2-evidence/motion/motion-perf-report.md` complete with timeline summaries and recordings
- [ ] Motion safety sweeps clean (transform/opacity/colour only, loops limited, no flashing > 3/s) and reduced-motion core loop (system setting and in-app switch) passed
- [ ] Neem design sweep clean (no `Icons.*`/Outlined icons, Noto only as fallback, no Civic Blue/v1 tokens, `sunrise` on report actions only)
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-14` shows 0 unverified)
- [ ] `check_coverage.py` (all tasks) exits 0 — verification layer at 100%
- [ ] Pilot launch checklist signed by the founder
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated (14/14, V2-M6 reached)
- [ ] Committed as `V2-TASK-14: …`
- [ ] Validator passes
