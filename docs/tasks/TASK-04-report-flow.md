# TASK-04: Report Flow — Photo Pipeline, Submission & Draft Safety

| Field | Value |
|---|---|
| Task ID | TASK-04 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | TASK-02, TASK-03 |
| Blocks | TASK-06 |
| Requirement IDs | REQ-F-014, REQ-F-015, REQ-F-016, REQ-F-017, REQ-F-018, REQ-F-019, REQ-F-020, REQ-F-021, REQ-F-022, REQ-F-023, REQ-F-024, REQ-F-025, REQ-F-026, REQ-F-027, REQ-F-028, REQ-F-029, REQ-F-030, REQ-F-031, REQ-F-032, REQ-F-033, REQ-S-010, REQ-S-011, REQ-S-023, REQ-S-031, REQ-S-033, REQ-S-034, REQ-S-035, REQ-O-013 |
| Primary Spec Refs | 03-backend-spec.md §2.2–2.3, §4.1–4.2, §5.3, §6.1, §8; 02-frontend-spec.md §4.4–4.10, §5.2, §6, §8.2, §9.4; 04-database-design.md §3.4–3.5 |
| Last Updated | 2026-10-03 |

## 1. Objective

Deliver the core citizen capability end to end: a citizen records an AMC complaint in six steps — category, AMC hand-off, CCRS number, photo with GPS and time, WhatsApp number with consent, check-your-answers — and the server stores a complete, defensible complaint record. Photos are compressed on the phone, re-encoded and stripped of metadata on the server, and stored behind the storage interface. The draft survives switching to AMC's channels, the OS killing the app, and failed uploads, and retries never create duplicates.

## 2. Scope

### In Scope
- Backend: `GET /categories`; storage interface + local driver; image pipeline; `POST /photos`; `POST /reports` full workflow; idempotency (incl. concurrent duplicates); duplicate-CCRS flag; unknown invite code handling; `report_submitted` event; rate limits for `/photos` and `/reports`; shared phone/CCRS normalization; consent-version and device-clock checks.
- `photos:cleanup` script for orphaned uploads.
- App: `reportDraftProvider` persisted to disk; report steps 1–6 and "Report recorded"; camera-only capture with GPS, accuracy, capture time; on-device compression; background upload with progress/retry; consent with version; check-your-answers with Change links and error summary; offline behaviour; "Your reports on this phone" (P1); Home "Continue your report" replacing the TASK-03 placeholder; camera/location permission strings.

### Out of Scope
- Verification photos and `POST /verify/photos` — TASK-07 (reuses this pipeline).
- Admin views of complaints and photos — TASK-06/08.
- Retrying failed anonymization file deletions in the cleanup script — TASK-08.
- Physical-device and iPhone runs — TASK-10.
- Allowing reports without GPS — open question (PRD Q6); not built.

## 3. Prerequisites

- TASK-02: `ccrs_categories` (seeded placeholders), `photos`, `complaints`, `invite_codes`, `events` tables with constraints.
- TASK-03: app shell, router with `/report/*` routes, API client, theme, shared components (`StepScaffold`, `ChoiceCard`, `EvidencePhoto`, `ErrorSummary`, `InlineFieldError`, `OfflineBanner`), event queue, settings (invite code, install ID).
- Env vars set in `apps/api/.env`: `STORAGE_DRIVER=local`, `PHOTO_STORAGE_DIR` (absolute, **outside the repo**), `PHOTO_MAX_UPLOAD_BYTES=5242880`, `PHOTO_MAX_EDGE_PX=2048`, `UNATTACHED_PHOTO_TTL_HOURS=24`, `CONSENT_TEXT_VERSIONS=v1`.
- App dart-defines: `CCRS_WEB_URL`, `CCRS_WHATSAPP_NUMBER`, `AMC_HELPLINE` (05 §2.2; check values before release).
- Emulator with a virtual camera and location set.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-02 | Tables, constraints (unique `client_submission_id`, unique `photo_id`, phone/coord CHECKs) and seeded categories/invite codes |
| TASK-03 | App foundation, router, design system components, API client with typed errors, event queue, stored invite code |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-014 | `GET /categories` returns active categories in sort order; app caches per session and keeps the last list for offline display | 03 §2.2, 02 §4.4 |
| REQ-F-015 | Step 1 (category): single-select `ChoiceCard`s; new draft gets `clientSubmissionId`; emits `report_opened` | 02 §4.4 |
| REQ-F-016 | Step 2: open CCRS web, AMC WhatsApp, call 155303 (config); shows category; emits `ccrs_handoff_clicked {target}` | 02 §4.5 |
| REQ-F-017 | Step 3: CCRS number, required, 1–50 chars after trim, spaces/dashes allowed | 02 §4.6, 03 §4.2 |
| REQ-F-018 | Step 4: camera-only capture with GPS, accuracy, capture time; rationale; denied → "Open settings", cannot complete; weak GPS (> 50 m) warning | 02 §4.7 |
| REQ-F-019 | On-device compression: long edge ≤ 1,600 px, JPEG ~q80; original not kept | 02 §8.2 |
| REQ-F-020 | Background upload with progress; failure keeps photo + "Retry upload"; `PHOTO_UNUSABLE` at submit asks to retake | 02 §4.7 |
| REQ-F-021 | `POST /photos` (multipart, `purpose=report`) returns 201 `{photoId}` | 03 §2.2, §2.3 |
| REQ-F-022 | Step 5: phone with fixed +91 and numeric keypad; consent checkbox with versioned text; "Why we ask" | 02 §4.8 |
| REQ-F-023 | Step 6: check-your-answers with "Change" links returning here; server errors in an error summary linking to steps | 02 §4.9, §6.2 |
| REQ-F-024 | `POST /reports` implements the §4.1 workflow | 03 §4.1 |
| REQ-F-025 | Idempotent: same `clientSubmissionId` → 200 existing (201 first), incl. concurrent duplicates | 03 §2.1, §4.1 |
| REQ-F-026 | Unknown/inactive invite code at submission → `unknown`, no code, warning logged — never rejected | 03 §4.1 |
| REQ-F-027 | Duplicate CCRS numbers flagged, not rejected, never returned to the citizen | 03 §4.1, 01 §9.1 |
| REQ-F-028 | "Report recorded" confirmation with next-step copy and "Done" → Home | 02 §4.10 |
| REQ-F-029 | Draft (JSON + compressed photo) persisted on every change, restored on the same step after the OS kills the app | 02 §4.5, §5.2, 07 B1 |
| REQ-F-030 | Draft deleted only after server confirms (201/200) | 01 §9.1, 02 §4.9 |
| REQ-F-031 | Every step works offline except upload and submit | 02 §9.4 |
| REQ-F-032 | Home "Your reports on this phone" from local storage only | 02 §4.3 |
| REQ-F-033 | Orphaned-photo cleanup script (`photos:cleanup`), safe to re-run | 03 §5.3 |
| REQ-S-010 | Server photo pipeline: size limit before buffering, magic-byte JPEG check, re-encode, metadata stripped, downscale, SHA-256 | 03 §8.2 |
| REQ-S-011 | Storage interface save/open/delete/exists; opaque keys; path containment; delete of missing key succeeds | 03 §6.1 |
| REQ-S-023 | Rate limits: `/photos` 60/IP/h; `/reports` 30/IP/h | 03 §10 |
| REQ-S-031 | Photo files stored outside the repository (`PHOTO_STORAGE_DIR`) | 05 D9, §2.2 |
| REQ-S-033 | `consentGivenAt` required; `consentTextVersion` must be in `CONSENT_TEXT_VERSIONS` | 03 §2.3, §4.2 |
| REQ-S-034 | `deviceCapturedAt` no more than 10 min ahead of server time | 03 §4.2 |
| REQ-S-035 | Shared phone rule (app + API) → E.164; CCRS normalization | 03 §4.2, 02 §6.2 |
| REQ-O-013 | Camera and location permissions with plain-language usage strings | 05 §4.6, 02 §4.7 |

### 5.2 Data Contracts

Tables from TASK-02 (`docs/04-database-design.md §3.3–3.5`); no new migrations expected.
- `ccrs_categories`: read `id, name` where `is_active` ordered by `sort_order`.
- `photos` insert: `storage_driver='local'`, `storage_key` (`photos/<yyyy>/<mm>/<uuid>.jpg`), `purpose='report'`, `mime_type='image/jpeg'`, `byte_size`, `width_px`, `height_px`, `sha256` (lowercase hex of stored bytes), `uploaded_at`. Set `attached_at` on report submit.
- `complaints` insert: `client_submission_id`, `invite_code_id` (nullable), `source_tag` (copied from code, else `unknown`), `category_id`, `ccrs_number_raw`, `ccrs_number_normalized`, `ccrs_duplicate_flag`, `photo_id`, `latitude`, `longitude`, `gps_accuracy_m`, `device_captured_at`, `phone_e164`, `consent_given_at`, `consent_text_version`, `app_platform`, `app_version`; `created_at` = server receipt (authoritative).
- `events` insert: `report_submitted` with `complaint_id`, `source_tag`.

Local draft (02 §5.2): `clientSubmissionId`, `categoryId`/`categoryName`, `ccrsNumber`, local photo path (app documents folder), `photoId`, `latitude`, `longitude`, `gpsAccuracyM`, `deviceCapturedAt`, `phone`, `consentTextVersion`, `consentGivenAt`, current step. Local "my reports" list: CCRS number, category, date.

### 5.3 API Contracts

| Method | Path | Auth | Request | Response | Errors | Rate limit |
|---|---|---|---|---|---|---|
| GET | `/api/v1/categories` | None | — | `{items:[{id,name}]}` | 429 | 120/IP/min (set in TASK-03) |
| POST | `/api/v1/photos` | None | multipart `photo` (JPEG ≤ 5 MB), `purpose=report` | 201 `{photoId}` | 400, 413 `PHOTO_TOO_LARGE`, 415 `PHOTO_TYPE_UNSUPPORTED`, 422, 429 | 60/IP/h |
| POST | `/api/v1/reports` | None | see below | 201/200 `{complaintId, createdAt}` | 400 `VALIDATION_FAILED`, 404, 409, 422 `CATEGORY_INACTIVE` / `PHOTO_UNUSABLE`, 429 | 30/IP/h |

`POST /reports` request (03 §2.3):

| Field | Required | Validation |
|---|---|---|
| clientSubmissionId | Yes | UUID v4 |
| inviteCode | No | 6–20 letters/digits; case-insensitive |
| categoryId | Yes | exists and active |
| ccrsNumber | Yes | 1–50 chars after trim |
| photoId | Yes | exists, purpose `report`, unattached, uploaded within 24 h |
| latitude / longitude | Yes | −90..90 / −180..180, ≤ 6 decimals |
| gpsAccuracyM | No | ≥ 0 |
| deviceCapturedAt | Yes | ≤ 10 min ahead of server time |
| phone | Yes | Indian mobile → E.164 |
| consentGivenAt | Yes | present |
| consentTextVersion | Yes | in `CONSENT_TEXT_VERSIONS` |
| platform | Yes | `android` / `ios` |
| appVersion | Yes | ≤ 20 chars |

Workflow (03 §4.1): validate + normalize → if `clientSubmissionId` exists return 200 existing → resolve invite code (unknown/inactive → `unknown`, warn log) → category active and photo usable, else 422 → one transaction: duplicate check on `ccrs_number_normalized`, insert complaint, set `photos.attached_at` → record `report_submitted` → 201. Concurrent duplicate: unique violation → re-read → 200. The duplicate flag is **not** in the response.

Validation messages (03 §4.2, returned in `details` and mirrored in ARB):
- Phone: "Enter a valid 10-digit Indian mobile number." — rule: remove spaces, dashes, optional `+91`/`0`/`91` prefix → exactly 10 digits starting 6–9 → `+91XXXXXXXXXX`.
- CCRS: "Enter the complaint number you got from AMC." — normalized = uppercase, spaces and dashes removed.
- Photo: "Your photo upload expired. Please retake the photo."
- Clock: "Your phone's clock looks wrong. Please check the date and time."
- Coordinates: "We couldn't read your location. Please try again."
- Consent: "Please agree to the consent statement to continue."

Photo pipeline (03 §8.2): multipart limit `PHOTO_MAX_UPLOAD_BYTES` (reject before buffering) → JPEG magic bytes (ignore filename/content type) → decode + re-encode JPEG (*candidate* sharp), stripping **all** metadata → downscale if long edge > `PHOTO_MAX_EDGE_PX` → SHA-256 of stored bytes → `storage.save` → insert row (unattached).

Storage interface (03 §6.1): `save(bytes) → key`, `open(key) → stream`, `delete(key)` (missing = success), `exists(key)`. Local driver under `PHOTO_STORAGE_DIR`; refuses keys resolving outside it.

### 5.4 UI Surfaces & States

| Route | Content | States |
|---|---|---|
| `/report/category` (Step 1 of 6) | `ChoiceCard` list, "Continue" | loading skeleton cards; error + retry; empty → retry + log; offline → last cached list |
| `/report/file-with-amc` (2/6) | Copy: "First, file your complaint with AMC. They'll give you a complaint number. Come back here when you have it — your answers so far are saved." Buttons "Open AMC complaint website", "Use AMC's WhatsApp", "Call 155303"; chosen category shown; primary "I have my complaint number" | external app fails to open → message |
| `/report/number` (3/6) | Field + help "It's in the SMS or WhatsApp message AMC sent you." | inline error |
| `/report/photo` (4/6) | Rationale "so we can tell it's the same spot later" → permission → "Take photo" (camera only) → preview with Retake / "Use this photo" → upload progress bar | permission denied → explanation + "Open settings", Continue disabled; weak GPS "Location is approximate. Move into the open and try again?" retry/continue; upload failed → "Retry upload"; offline → photo kept, upload later |
| `/report/phone` (5/6) | +91 prefix field, numeric keypad, consent checkbox, "Why we ask" | inline errors |
| `/report/check` (6/6) | Summary: category, complaint number, `EvidencePhoto` thumbnail (time, accuracy), phone — each with "Change"; "Send" | sending (button progress, disabled); server error → `ErrorSummary` with links, focus moved there; offline banner, draft kept |
| `/report/done` | "Recorded. Thank you." / "In about a week, we'll send you a WhatsApp message asking whether it's been fixed. Answering takes less than a minute." "Done" | — |
| Home | "Continue your report" when a draft exists; "Your reports on this phone" list (P1) with empty state | — |

Consent text (draft, version `v1`, needs legal review): "I agree that this app may store my WhatsApp number, my photos, their location and time, and my answers, and may contact me on WhatsApp about this complaint. I can ask for my data to be deleted."

State machine: 02 §6.3 (Category → FileWithAMC ↔ AwayAtAMC → Number → Photo ⇄ Uploading → Phone → Check ⇄ Change targets → Submitting → Done / back to Check on error).

### 5.5 Permissions & Roles

| Action | Citizen (no token) | Admin | Notes |
|---|---|---|---|
| Read categories, upload report photo, submit report | ✅ | ✅ (via app) | Public, rate-limited, schema-validated |
| See duplicate flag | ❌ | ✅ (TASK-06/08) | Never in citizen responses |
| Read stored photo | ❌ | ✅ (TASK-08) | No public URL; no photo read endpoint in this task |

### 5.6 Assumptions

- ASSUMPTION: Step 4 cannot be completed without location — spec says this until PRD Q6 is decided — add a no-GPS path if the founder allows it.
- ASSUMPTION: Weak-GPS threshold 50 m and compression 1,600 px / q80 — 02 D11–D12 starting values — tune after measuring on a low-end phone (TASK-10).
- ASSUMPTION: Upload starts automatically after "Use this photo" and is retried on reconnect while the app is open — "upload in the background" in 02 §4.7 — use a background-task plugin if uploads must survive app kill.
- ASSUMPTION: The CCRS WhatsApp button opens `https://wa.me/<number>` — 02 §4.5 gives no URL format — switch to the verified format (PRD Q8) if different.
- ASSUMPTION: "Your reports on this phone" entries are added on successful submit and never synced — 02 §4.3 says local only.
- ASSUMPTION: `photos:cleanup` deletes the file first, then the row, and logs per-item failures — 03 §5.3 "safe to re-run".

## 6. Implementation Steps

1. **Shared rules (API).** `src/lib/validation`: phone normalization → E.164, CCRS normalization; unit-free pure functions reused by schemas.
2. **Storage interface.** `src/lib/storage`: interface + local driver with path containment and missing-key-delete success; key generator `photos/<yyyy>/<mm>/<uuid>.jpg`; startup check that `PHOTO_STORAGE_DIR` exists, is writable and is outside the repo.
3. **Image pipeline.** `src/lib/images` (*candidate* sharp — verify version): magic-byte check, decode/re-encode with metadata removal, downscale, dimensions, SHA-256.
4. **`POST /photos`.** `src/modules/photos`: multipart middleware (*candidate* Multer, memory storage with `limits.fileSize`), map oversize → 413, non-JPEG/undecodable → 415, insert row; limiter 60/IP/h.
5. **`GET /categories`.** `src/modules/public`: active ordered list.
6. **`POST /reports` service.** `src/modules/reports`: Zod schema per §5.3, clock and consent checks, idempotency short-circuit, invite resolution (warn log, no code value logged), category/photo checks, Prisma `$transaction` (duplicate flag, insert, attach), catch unique-violation on `client_submission_id` → re-read → 200; record `report_submitted`; limiter 30/IP/h.
7. **Cleanup script.** `scripts/cleanup-photos.ts` + root `photos:cleanup`: select unattached photos older than `UNATTACHED_PHOTO_TTL_HOURS` (uses partial index), delete file then row, log failures, exit non-zero if any failed.
8. **API manual checks** M-04-01…M-04-06 before starting the app side.
9. **App shared validators.** Mirror phone/CCRS rules in `lib/core/utils` (identical test cases as the API).
10. **Draft store.** `features/report/data`: JSON in shared_preferences + photo file in app documents folder (*candidate* path_provider); `reportDraftProvider` with `start`, `setCategory`, `setCcrsNumber`, `setPhoto`, `uploadPhoto`, `setPhone`, `setConsent`, `submit`, `discard`; persist on every change; restore current step on launch/resume.
11. **Categories provider** with session cache and last-list fallback.
12. **Steps 1–3 screens** on `StepScaffold`; `report_opened` on first show for a new draft; step 2 launches external apps (*candidate* url_launcher) after saving the draft, tracks `ccrs_handoff_clicked {target}`.
13. **Permissions.** Android manifest camera + fine location; iOS `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription` in plain language matching 02 §4.7.
14. **Step 4.** Camera-only capture (*candidate* image_picker, `ImageSource.camera`), location with accuracy (*candidate* geolocator), capture time, compression (*candidate* flutter_image_compress), save to draft folder, delete original, preview, background upload with progress + retry, weak-GPS and denied states.
15. **Step 5.** Phone field with fixed +91, numeric keypad, consent checkbox (version `v1` and time stored), "Why we ask".
16. **Step 6 + Done.** Check-your-answers with Change navigation that returns to check; Send → `submit` (same `clientSubmissionId` on retry; 200 = success); on success add to local "my reports", delete draft and photo file, go to `/report/done`; on failure keep draft, show `ErrorSummary` mapped from `details` with step links; `PHOTO_UNUSABLE` → retake path.
17. **Home wiring.** Replace TASK-03 placeholder: "Continue your report" when a draft exists; "Your reports on this phone" list with empty state.
18. **App manual checks** M-04-07…M-04-12; record evidence in the coverage matrix.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Categories
- **Given** seeded categories with one inactive
- **When** step 1 loads (online, then offline after one load)
- **Then** only active categories appear in `sort_order`; offline shows the last list; a load failure shows retry

**AC-2** — Draft start and hand-off events
- **Given** no draft
- **When** a category is selected and an AMC button is tapped
- **Then** a draft with a new UUID `clientSubmissionId` is saved before leaving the app, and `report_opened` and `ccrs_handoff_clicked {target}` are queued

**AC-3** — Draft survives app kill
- **Given** a draft at step 2
- **When** the app is force-stopped and reopened
- **Then** it reopens on step 2 with category intact; Home shows "Continue your report"

**AC-4** — CCRS number validation
- **Given** step 3
- **When** Continue is tapped with an empty or whitespace field, or > 50 chars
- **Then** "Enter the complaint number you got from AMC." appears inline; spaces and dashes are accepted

**AC-5** — Photo capture with evidence
- **Given** location permission granted
- **When** a photo is taken
- **Then** only the camera opens (no gallery), GPS + accuracy + capture time are recorded, the compressed JPEG has long edge ≤ 1,600 px, the original file is gone, and upload shows progress and stores `photoId` in the draft

**AC-6** — Photo step failure paths
- **Given** location denied / accuracy worse than 50 m / upload failing
- **When** the citizen is on step 4
- **Then** respectively: explanation + "Open settings" and Continue disabled; "Location is approximate…" with retry/continue; photo kept with "Retry upload"

**AC-7** — Server photo pipeline
- **Given** a JPEG with EXIF GPS, a 6 MB file, and a PNG renamed `.jpg`
- **When** each is posted to `/photos`
- **Then** the JPEG returns 201 and the stored file has no EXIF/GPS and long edge ≤ 2,048, under `PHOTO_STORAGE_DIR` outside the repo, with sha256 matching the file; the 6 MB file → 413 `PHOTO_TOO_LARGE`; the PNG → 415 `PHOTO_TYPE_UNSUPPORTED`

**AC-8** — Phone and consent
- **Given** step 5
- **When** "12345" or "5876543210" is entered, or consent is unticked
- **Then** "Enter a valid 10-digit Indian mobile number." / consent message appear; "098765 43210" is accepted and sent normalized as `+919876543210`

**AC-9** — Successful submission
- **Given** a complete draft with a valid invite code
- **When** Send is tapped on the check screen
- **Then** 201 `{complaintId, createdAt}`; DB row has `source_tag` from the code, normalized phone, `created_at` server time, photo `attached_at` set; a `report_submitted` event exists; draft deleted; `/report/done` shows; the report appears in "Your reports on this phone"

**AC-10** — Idempotency
- **Given** a stored report
- **When** the same body is posted again, and when two identical new bodies are posted concurrently
- **Then** the repeat returns 200 with the same `complaintId`; the concurrent pair yields one 201 and one 200; exactly one complaint row exists

**AC-11** — Unknown code and duplicate CCRS
- **Given** an inactive invite code and a CCRS number already stored (different spacing/case)
- **When** a report is submitted
- **Then** it is stored with `source_tag=unknown`, `invite_code_id` null, a `warn` log without the code value, and `ccrs_duplicate_flag=true`; the response contains no duplicate field

**AC-12** — Business-rule rejections keep the draft
- **Given** a draft whose photo is > 24 h old or already attached, inactive category, `deviceCapturedAt` 15 min ahead, or consent version `v9`
- **When** Send is tapped
- **Then** 422 `PHOTO_UNUSABLE` / 422 `CATEGORY_INACTIVE` / 400 with the clock or consent message; the app shows an error summary linking to the step (retake for photo), and the draft is kept

**AC-13** — Offline behaviour
- **Given** airplane mode from step 1
- **When** the citizen completes steps 1–5 and taps Send
- **Then** every step works except upload/submit, which show the offline banner; after reconnecting, upload and Send succeed with no duplicate

**AC-14** — Rate limits
- **Given** one IP
- **When** it sends 61 photo uploads or 31 report submissions within an hour
- **Then** the extra request returns 429 `RATE_LIMITED` with `Retry-After`

**AC-15** — Orphan cleanup
- **Given** an unattached photo older than 24 h and an attached one
- **When** `npm run photos:cleanup` runs twice
- **Then** only the orphan's file and row are removed; the second run succeeds with nothing to do

**AC-16** — Storage containment
- **Given** the local driver
- **When** asked to open or save a key like `../../etc/passwd`, or to delete a missing key
- **Then** the traversal is refused with an error and the missing-key delete succeeds

**AC-17** — Permission strings
- **Given** a fresh install
- **When** the camera and location prompts appear (Android and iOS simulator)
- **Then** plain-language usage text is shown, matching 02 §4.7

| AC | Requirements |
|---|---|
| AC-1 | REQ-F-014 |
| AC-2 | REQ-F-015, REQ-F-016 |
| AC-3 | REQ-F-029 |
| AC-4 | REQ-F-017, REQ-S-035 |
| AC-5 | REQ-F-018, REQ-F-019, REQ-F-020 |
| AC-6 | REQ-F-018, REQ-F-020 |
| AC-7 | REQ-F-021, REQ-S-010, REQ-S-031 |
| AC-8 | REQ-F-022, REQ-S-035, REQ-S-033 |
| AC-9 | REQ-F-023, REQ-F-024, REQ-F-028, REQ-F-030, REQ-F-032 |
| AC-10 | REQ-F-025 |
| AC-11 | REQ-F-026, REQ-F-027 |
| AC-12 | REQ-F-020, REQ-F-023, REQ-F-030, REQ-S-033, REQ-S-034 |
| AC-13 | REQ-F-031 |
| AC-14 | REQ-S-023 |
| AC-15 | REQ-F-033 |
| AC-16 | REQ-S-011 |
| AC-17 | REQ-O-013 |

### 7.2 Non-Functional Checklist

- [ ] Every report screen has loading, error, offline and in-flight states; Send and upload buttons disabled while in flight
- [ ] Step progress "Step n of 6" announced; inline errors announced; focus moves to `ErrorSummary` on failed submit
- [ ] All copy (incl. consent `v1` and all §4.2 messages) in ARB, keyed by error code where server-originated
- [ ] Screens usable at 320 px and largest text; primary button stays above the keyboard on steps 3 and 5
- [ ] Request bodies never logged; `phone` redacted; warn log for unknown code omits the code value
- [ ] `PHOTO_STORAGE_DIR` outside the repo verified at startup; no photo files in `git status`
- [ ] Report insert, duplicate check and photo attach happen in one transaction (rollback verified by forcing a failure)
- [ ] Phone and CCRS normalization give identical results in app and API for the same inputs (table of cases checked)
- [ ] Report screens import providers only — no API client in `presentation/`
- [ ] No hard-coded URLs/numbers: CCRS web, WhatsApp and helpline come from dart-defines
- [ ] Compression completes ≤ 2 s on the emulator (re-measured on a low-end phone in TASK-10)

## 8. Validation & Testing

| Level | What to test | ACs |
|---|---|---|
| Static | API `typecheck` + `lint`; mobile `dart format` check + `dart analyze`; CI green | all |
| API manual M-04-01 | `curl $API/categories` → active only, ordered; deactivate one via SQL and repeat | AC-1 |
| API manual M-04-02 | `curl -F photo=@exif.jpg -F purpose=report $API/photos` → 201; inspect stored file with `exiftool` (no GPS/device tags), check dimensions and `sha256sum` vs DB; 6 MB file → 413; PNG renamed → 415 | AC-7 |
| API manual M-04-03 | POST `/reports` valid body → 201; repeat → 200 same id; two parallel `curl &` with a new id → one 201 + one 200; `SELECT count(*) FROM complaints WHERE client_submission_id=…` = 1 | AC-9, AC-10 |
| API manual M-04-04 | Inactive invite code + duplicate CCRS (`"ab-12 3"` vs `"AB123"`) → stored `unknown`, flag true, response has no flag; check log line | AC-11 |
| API manual M-04-05 | Old/attached photo, inactive category, clock +15 min, consent `v9`, phone `5876543210` → expected 422/400 with messages | AC-12, AC-8 |
| API manual M-04-06 | 61 photo / 31 report requests → 429 + `Retry-After`; storage traversal key via a scratch script → refused; delete missing key → ok | AC-14, AC-16 |
| DB manual M-04-07 | Insert an orphan photo row + file aged 25 h (`uploaded_at = now() - interval '25 hours'`), run `photos:cleanup` twice | AC-15 |
| App manual M-04-08 | Full happy path on the emulator with a valid code → done screen; verify DB row, event, "Your reports on this phone" | AC-2, AC-5, AC-8, AC-9 |
| App manual M-04-09 | Kill the app (`adb shell am force-stop`) at step 2 → reopen → step 2 intact; Home shows "Continue your report" | AC-3 |
| App manual M-04-10 | Deny location; set emulator accuracy poor; stop API during upload → Retry upload | AC-6 |
| App manual M-04-11 | Airplane mode through steps 1–5, Send, reconnect, Send → one complaint | AC-13 |
| App manual M-04-12 | Empty/long CCRS number; invalid phone; consent unticked; check-screen Change links return to check; forced server 422 shows error summary with focus | AC-4, AC-8, AC-12 |
| App manual M-04-13 | Fresh install permission prompts on Android emulator and iOS simulator | AC-17 |
| Optional automated | 06 §8.1 #2 — Vitest + Supertest: same `clientSubmissionId` twice → one complaint, 201 then 200 (optional, may be added in TASK-10) | AC-10 |

## 9. Deliverables

- API modules `public` (categories), `photos`, `reports`; libs `storage`, `images`, validation rules.
- `photos:cleanup` script and root script entry.
- App report feature: data (draft store, API), application (providers), presentation (6 steps + done); Home updates.
- Android/iOS permission declarations.
- Coverage matrix evidence for 28 requirements.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/api/src/lib/{storage,images,validation}/` | New |
| `apps/api/src/modules/{public,photos,reports}/` | New / Modified |
| `apps/api/scripts/cleanup-photos.ts`, root `package.json` scripts | New / Modified |
| `apps/api/src/config/` (storage env checks) | Modified |
| `apps/mobile/lib/features/report/{data,application,presentation}/` | New |
| `apps/mobile/lib/features/home/` | Modified |
| `apps/mobile/lib/core/utils/` (phone/CCRS rules), `lib/core/l10n/app_en.arb` | Modified |
| `apps/mobile/android/app/src/main/AndroidManifest.xml`, `apps/mobile/ios/Runner/Info.plist` | Modified |
| `apps/mobile/pubspec.yaml` | Modified |

## 11. Related Documentation

- `docs/03-backend-spec.md §2.2–2.3` — endpoint table and `POST /reports` schema
- `docs/03-backend-spec.md §4.1–4.2` — report workflow and validation messages
- `docs/03-backend-spec.md §5.3, §6.1, §8` — cleanup script, storage interface, file pipeline
- `docs/04-database-design.md §3.4–3.5, §1.2` — photos and complaints columns, idempotency and time rules
- `docs/02-frontend-spec.md §4.4–4.10` — step screens and copy
- `docs/02-frontend-spec.md §5.2, §6.3, §8.2, §9.4` — draft provider, state machine, compression, offline
- `docs/05-devops-infrastructure.md §2.2, §4.6` — env vars, permissions

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| OS kills the app while away at CCRS and the draft is lost | Lost reports, lower G1 | Persist on every change; test with force-stop (M-04-09) |
| sharp native build issues on the dev machine | Pipeline blocked | Verify install early (step 3); keep pipeline behind `lib/images` |
| Phone rule rejects real numbers (03 D12 "to verify") | Valid citizens blocked | Check against current numbering; same rule both sides |
| Emulator camera/GPS differ from real phones | False confidence | Re-run on low-end Android in TASK-10 |
| Concurrent submit race not handled | Duplicate complaints skew H1 | Unique constraint + re-read path; M-04-03 parallel check |

## 13. Progress Status

**Current status:** Not Started

**Progress:** 0%

| Date | Progress | Commit |
|---|---|---|

## 14. Completion Checklist

- [ ] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [ ] Static checks pass and every AC verified by the manual checks in §8 (no automated tests in v1 — 06 §7.1)
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-04` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `TASK-04: …`
- [ ] Validator passes
