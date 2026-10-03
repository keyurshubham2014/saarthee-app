# TASK-07: Verify Flow — Tokens, Deep Links & Verification Submission

| Field | Value |
|---|---|
| Task ID | TASK-07 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | TASK-06 |
| Blocks | TASK-08, TASK-09 |
| Requirement IDs | REQ-F-048, REQ-F-049, REQ-F-050, REQ-F-051, REQ-F-052, REQ-F-053, REQ-F-054, REQ-F-055, REQ-F-056, REQ-F-057, REQ-F-058, REQ-F-059, REQ-S-006, REQ-S-007, REQ-S-008, REQ-S-024, REQ-O-012 |
| Primary Spec Refs | 03-backend-spec.md §3.1, §4.5, §2.2, §2.3; 02-frontend-spec.md §3.1, §4.11–§4.16, §5.1; 05-devops-infrastructure.md §4.6; 04-database-design.md §3.4, §3.6, §3.7 |
| Last Updated | 2026-10-03 |

## 1. Objective

A citizen who receives a reminder can open the verify link (or type the code by hand), see their original complaint, answer "Fixed" or "Not fixed" with a new photo and an optional note, and send it. The verification is stored against the reminder whose token was used. At the end of this task the core loop works on the Android emulator: report → reminder → verify → Rates changes. This is milestone M1, the Stage A "complete" statement in 07 §3.

## 2. Scope

### In Scope
- API: verify-token guard middleware (`src/middleware/verifyToken`), using `src/lib/tokens` hashing from TASK-06.
- API: `GET /verify/complaint`, `GET /verify/complaint/photo`, `POST /verify/photos`, `POST /verify/submissions` in `src/modules/verify`.
- API: `src/lib/geo` haversine distance; `distance_from_report_m` stored on each verification.
- API: server events `verify_opened` and `verify_submitted {result}`.
- API: `/verify/*` rate limit, 60 per IP per hour.
- App: deep-link handling (*candidate* `app_links`) for `saarthee://verify?t=<token>`, with parsing that is ready for https links; `deep_link_failed {reason}` event.
- App: register the `saarthee` URL scheme (Android intent filter, iOS URL type).
- App: `/verify/enter-code` manual entry, accepting the whole link or just the code. This replaces the TASK-03 stub behind Home's "Answer a follow-up".
- App: `verifySessionProvider`, held in memory only.
- App: screens `/verify?t=`, `/verify/answer`, `/verify/photo`, `/verify/note`, `/verify/check`, `/verify/done`, with every state.
- App: the citizen variant of `BeforeAfterCard` on the check screen.
- Documented commands for firing links on the emulator and simulator.

### Out of Scope
- Reminder creation, token generation and the reminder sheet: TASK-06.
- Revoking reminders, the admin detail view, the same-image warning and the distance highlight in admin screens: TASK-08.
- Admin access to verification photos: TASK-08 (REQ-S-012).
- Testing deep links from a real WhatsApp message on physical devices: TASK-10 (REQ-O-015).
- https App Links and Universal Links with association files: deferred (REQ-O-022).

## 3. Prerequisites
- TASK-06 complete:
  - `POST /admin/complaints/{id}/reminders` returns a raw token inside `verifyLink`;
  - `reminders.token_hash` is stored;
  - the Rates tab works.
- TASK-04 complete: the photo pipeline (`src/lib/images`, storage interface), the device-clock rule (REQ-S-034), the coordinate validation, and the app's camera, GPS and compression flow.
- Seed data includes at least one complaint that has a reminder (TASK-02).
- An Android emulator is running the app with `API_BASE_URL=http://10.0.2.2:4000/api/v1` and `DEEP_LINK_SCHEME=saarthee`.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-06 | Produces reminders and raw verify tokens; provides `lib/tokens` (generate, SHA-256 hash), the Rates screen used for the M1 check, and the reminder message containing the link |

TASK-01 to TASK-05 are required transitively (API foundation, schema, design system, photo pipeline, admin auth).

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-048 | Deep link `saarthee://verify?t=<token>` opens verify entry (https-ready parsing); unparseable link → `/verify/enter-code` and `deep_link_failed {reason}` | 02 §3.1 |
| REQ-F-049 | Manual verify code entry accepts the whole pasted link or just the code; records `deep_link_failed` for fallback use | 02 §4.12, 03 §11 |
| REQ-F-050 | `GET /verify/complaint` returns `{complaintId, categoryName, ccrsNumber, reportedAt, hasPhoto, previousVerificationCount}` and records `verify_opened` | 03 §2.3, §4.5 |
| REQ-F-051 | `GET /verify/complaint/photo` streams the original report photo for the token's complaint | 03 §2.2 |
| REQ-F-052 | Verify entry screen: date, category, CCRS number, original photo; "answered before" note; invalid/revoked/offline states | 02 §4.11 |
| REQ-F-053 | "Is it fixed?" screen with two `ChoiceCard`s (fixed / not fixed), no "partly" | 02 §4.13 |
| REQ-F-054 | Verify photo step (same rules as report photo, original shown for framing) uploading to `POST /verify/photos` | 02 §4.14, 03 §4.5 |
| REQ-F-055 | Optional note after "Not fixed" (≤ 1,000 chars with counter, Skip/Continue) | 02 §4.15 |
| REQ-F-056 | Verify check-and-send with `BeforeAfterCard`, answer, note preview and Change links; "Thank you" screen | 02 §4.16 |
| REQ-F-057 | `POST /verify/submissions`: idempotent by `clientSubmissionId`; one transaction inserts verification with `reminder_id`, attaches photo; records `verify_submitted {result}` | 03 §4.5 |
| REQ-F-058 | Repeat verifications are stored as new rows; the latest drives status and H2 | 03 §4.5, 04 A5 |
| REQ-F-059 | `distance_from_report_m` computed from report and verification coordinates at insert | 03 §4.5, 04 §3.7 |
| REQ-S-006 | Verify token travels only in `X-Verify-Token`, never in API URLs or logs; app holds it in memory only, never on disk | 03 §2.1, 02 §3.1, §5.1 |
| REQ-S-007 | Missing/unknown/malformed tokens get the same 401 `VERIFY_TOKEN_INVALID`; revoked/expired/anonymized → 410 `VERIFY_TOKEN_REVOKED` | 03 §3.1, §9.1 |
| REQ-S-008 | Token scope: a verify token reaches only its own complaint; verification photos record `uploaded_for_complaint_id` and cannot be attached to another complaint | 03 §3.3, §4.5 |
| REQ-S-024 | Rate limits: `/verify/*` 60/IP/h (incl. `/verify/photos`) | 03 §10 |
| REQ-O-012 | `saarthee` URL scheme registered (Android intent filter, iOS URL type); link firing documented for emulator/simulator | 05 §4.6 |

### 5.2 Data Contracts
No schema changes. This task reads and writes tables created in TASK-02 (04 §3).

- `reminders` (read):
  - `id`, `complaint_id`, `token_hash` (CHAR(64), UNIQUE), `revoked_at`, `expires_at`.
  - Lookup by `uq_reminders_token_hash`.
- `complaints` (read):
  - `id`, `category_id`, `ccrs_number_raw`, `created_at`, `photo_id`, `latitude`, `longitude`, `anonymized_at`.
  - `phone_e164`, `source_tag` and `invite_code_id` are **never** selected into verify responses.
- `photos` (insert and update):
  - On verification upload, insert `purpose='verification'`, `uploaded_for_complaint_id = <token's complaint>`. The DB CHECK requires this column when purpose = verification.
  - On submission, set `attached_at`.
- `verifications` (insert):
  - Required columns: `client_submission_id` (UNIQUE), `complaint_id`, `reminder_id`, `result` (`fixed`|`not_fixed`), `photo_id` (UNIQUE), `latitude`, `longitude` (NUMERIC(9,6)), `device_captured_at`, `app_platform`, `app_version`.
  - Optional: `gps_accuracy_m`, `distance_from_report_m` (NUMERIC(10,2), ≥ 0), `note` (≤ 1,000).
  - `created_at` = server time (authoritative).
- `events` (insert):
  - `verify_opened` with `complaint_id` only.
  - `verify_submitted` with `complaint_id` and `properties = {"result": "<fixed|not_fixed>"}`.
- Repeat answers: always a new `verifications` row. `complaint_status_v` and `pilot_rates_v` already use the latest row per complaint (04 §3.9, A5).

### 5.3 API Contracts

Base path `/api/v1`. The token is sent **only** in the `X-Verify-Token` header. Rate limit: 60 per IP per hour across all `/verify/*`.

| Method | Path | Auth | Request | Response | Errors |
|---|---|---|---|---|---|
| GET | /verify/complaint | Verify token | — | 200 summary (below) | 401 `VERIFY_TOKEN_INVALID`, 410 `VERIFY_TOKEN_REVOKED`, 429 |
| GET | /verify/complaint/photo | Verify token | — | 200 `image/jpeg` stream of the report photo | 401, 404 `NOT_FOUND` (no photo or deleted), 410 |
| POST | /verify/photos | Verify token | multipart `photo` (JPEG ≤ `PHOTO_MAX_UPLOAD_BYTES`) | 201 `{photoId}` | 400, 401, 410, 413 `PHOTO_TOO_LARGE`, 415 `PHOTO_TYPE_UNSUPPORTED`, 422, 429 |
| POST | /verify/submissions | Verify token | JSON (below) | 201 / 200 `{verificationId, createdAt}` | 400 `VALIDATION_FAILED`, 401, 404, 409, 410, 422 `PHOTO_UNUSABLE`, 429 |

**Verify-token guard** (03 §3.1):
1. Read `X-Verify-Token`. If it is missing or empty, return 401 `VERIFY_TOKEN_INVALID`.
2. Compute the SHA-256 hex of the raw value and look up `reminders.token_hash`. If no row matches, return 401 `VERIFY_TOKEN_INVALID`. This is the same body as step 1, so unknown and malformed tokens cannot be told apart.
3. If `revoked_at` is not null, `expires_at` is in the past, or the complaint's `anonymized_at` is not null, return 410 `VERIFY_TOKEN_REVOKED` and log at `warn` ("revoked token presented", reminder ID only).
4. Otherwise attach `{reminderId, complaintId}` to the request.

**GET /verify/complaint — 200**

| Field | Type | Description |
|---|---|---|
| complaintId | UUID | — |
| categoryName | string | — |
| ccrsNumber | string | `ccrs_number_raw` |
| reportedAt | ISO datetime (UTC) | Server receipt time |
| hasPhoto | boolean | False if the report photo was deleted |
| previousVerificationCount | integer | Count of existing verifications for this complaint |

**Never returned on any verify endpoint:** phone number, report coordinates, invite code, source tag (03 §2.3). Records a `verify_opened` event on success.

**POST /verify/submissions — request**

| Field | Type | Required | Validation |
|---|---|---|---|
| clientSubmissionId | UUID | Yes | UUID v4 |
| result | string | Yes | `fixed` or `not_fixed` |
| photoId | UUID | Yes | Exists; purpose `verification`; `uploaded_for_complaint_id` = token's complaint; not attached |
| latitude | number | Yes | −90 to 90, ≤ 6 decimals |
| longitude | number | Yes | −180 to 180, ≤ 6 decimals |
| gpsAccuracyM | number | No | ≥ 0 |
| deviceCapturedAt | ISO datetime | Yes | ≤ 10 min ahead of server time (REQ-S-034 rule from TASK-04) |
| note | string | No | ≤ 1,000 characters after trimming |
| platform | string | Yes | `android` or `ios` |
| appVersion | string | Yes | ≤ 20 characters |

**Submission workflow** (03 §4.5):
1. The guard resolves the token.
2. If `clientSubmissionId` exists, return 200 with the existing verification.
3. Validate the photo rules. A failure returns 422 `PHOTO_UNUSABLE` ("Please retake the photo.").
4. In one transaction:
   - insert the verification with `reminder_id` set to the token's reminder;
   - compute `distance_from_report_m` = haversine(report lat/lng, verification lat/lng);
   - set `photos.attached_at`.
5. Record `verify_submitted {result}` and return 201.

If two requests with the same `clientSubmissionId` race, the one that hits the unique-constraint violation re-reads the row and returns 200.

**Validation messages** (03 §4.2):

| Rule | Message |
|---|---|
| Clock more than 10 min ahead | "Your phone's clock looks wrong. Please check the date and time." |
| Coordinates out of range | "We couldn't read your location. Please try again." |
| Note too long | "Your note is too long." |
| Wrong-complaint photo | "Please retake the photo." |
| Anonymized complaint | "This link is no longer active." |

### 5.4 UI Surfaces & States

| Route | Screen | States |
|---|---|---|
| `/verify?t=<token>` | Verify entry (02 §4.11): "Your complaint from {date}", category, AMC complaint number, original photo (`EvidencePhoto`), "Continue". If `previousVerificationCount > 0`: "You've answered before. You can update your answer." | **Loading:** full-screen spinner (the only one allowed, 02 §9.3).<br>**Invalid:** "This link isn't valid." + "Enter a code instead".<br>**Revoked:** "This link is no longer active."<br>**Offline:** `OfflineBanner` + retry.<br>**Rate limited:** wait message from Retry-After.<br>**No photo:** placeholder text instead of image |
| `/verify/enter-code` | Manual entry (02 §4.12): text field accepting a whole pasted link or just the code; "Continue" | **Validation error:** empty or unparseable input → inline error.<br>**In-flight:** disabled button with progress.<br>**Invalid/revoked:** inline messages as above |
| `/verify/answer` | "Is it fixed?" (02 §4.13): `ChoiceCard` "Yes, it's fixed" (✓, `fixed` styling) and "No, it's not fixed" (✕, `notFixed` styling) | **Default:** none selected; "Continue" shows inline error if nothing is selected.<br>**Selected:** colour + icon + text (never colour alone) |
| `/verify/photo` | Photo now (02 §4.14): "Take a photo of the same spot now"; original shown small for framing; camera only; GPS + accuracy + time; compress; upload with progress | Same states as the report photo step from TASK-04:<br>• permission denied → "Open settings";<br>• weak GPS (> 50 m) → retry/continue;<br>• upload failed → "Retry upload";<br>• `PHOTO_UNUSABLE` → retake |
| `/verify/note` | Optional note (02 §4.15), shown only after "Not fixed": multi-line field, max 1,000 with counter, "Skip" and "Continue" | Counter at limit; over-limit input blocked |
| `/verify/check` | Check and send (02 §4.16): `BeforeAfterCard` citizen variant (before = report photo, after = local new photo), answer, note preview, "Change" links to answer/photo/note; "Send" | **Sending:** button disabled with progress.<br>**Server error:** `ErrorSummary` at top linking to the step.<br>**Offline:** banner, answers kept in memory |
| `/verify/done` | "Thank you. Your answer helps show which complaints really get fixed." → Home | Static |

- All copy lives in ARB files.
- Every screen except `/verify/done` uses `StepScaffold` with "Step n of N".
- Screen readers announce the step; photos have descriptions such as "Photo of the problem, taken 3 Oct, 10:42".

**Deep-link parsing** (shared util `parseVerifyInput(String)`):
- Accepts `saarthee://verify?t=X`, `https://<any-host>/verify?t=X` (ready for later App Links), or a bare token.
- Trims whitespace and extracts `t`.
- A bare token must be URL-safe base64 of the expected length; anything else counts as unparseable.
- An unparseable link that opened the app → route to `/verify/enter-code` and track `deep_link_failed {reason: "unparseable"}`.
- Use of the manual-entry fallback → track `deep_link_failed {reason: "manual_entry"}`.
- **The token is never included in event properties.**

**Platform registration (REQ-O-012, 05 §4.6):**
- Android: intent filter on the main activity (`VIEW`, categories `DEFAULT` + `BROWSABLE`, `<data android:scheme="saarthee" android:host="verify"/>`).
- iOS: `CFBundleURLTypes` entry with scheme `saarthee`.
- Scheme value comes from `DEEP_LINK_SCHEME`.
- Firing commands (verify on the installed tool versions):
  - Android emulator: `adb shell am start -a android.intent.action.VIEW -d "saarthee://verify?t=<token>"`
  - iOS simulator: `xcrun simctl openurl booted "saarthee://verify?t=<token>"`

### 5.5 Permissions & Roles

| Capability | Admin (JWT) | Citizen with verify token | Citizen (no token) |
|---|---|---|---|
| Read verify summary and report photo | Admin uses admin endpoints (TASK-08) | ✅ only the token's complaint | ❌ 401 |
| Upload verification photo, submit verification | ❌ (not in v1) | ✅ only the token's complaint | ❌ 401 |
| Use a revoked token, or a token for an anonymized complaint | — | ❌ 410 | — |

There is no complaint ID in any verify URL. The complaint comes **only** from the token, so a token cannot be pointed at another complaint.

### 5.6 Assumptions
- ASSUMPTION: a bare manual-entry code is accepted when it is a 43-character URL-safe base64 string (32 bytes, no padding) — this matches 03 §3.2's token format — if TASK-06 encodes tokens differently, update the length check in `parseVerifyInput`.
- ASSUMPTION: verify step count shown is "Step n of 4" (answer, photo, note, check), counting the note step only when "Not fixed" is chosen (it shows "of 3" otherwise) — 02 §1.3 calls it a 4-step flow without defining numbering — a different count only changes ARB strings.
- ASSUMPTION: `GET /verify/complaint/photo` returns 404 `NOT_FOUND` when `hasPhoto` is false (file deleted), matching the endpoint's listed 404 — if 410 is preferred, change the status only.
- ASSUMPTION: `previousVerificationCount` counts all verifications for the complaint, not only those made with this reminder's token — 03 §2.3 says "lets the app say you've already answered" without scope — if per-reminder, change the count query.

- ASSUMPTION (W1 API): The `/verify/*` limiter (60/IP/h, one shared budget) runs **before** the token guard so token probing is rate-limited; `POST /verify/photos` has no separate budget beyond it.
- ASSUMPTION (W1 API): A `clientSubmissionId` already stored for a **different** complaint returns 409 `VALIDATION_FAILED` (`clientSubmissionId` "Already used for another answer.") instead of leaking the other verification.
- ASSUMPTION (W1 API): Distance = haversine with mean Earth radius 6,371,008.8 m, stored to 2 dp.

## 6. Implementation Steps

1. **`src/lib/geo`:** haversine distance in metres between two lat/lng pairs, rounded to 2 decimals. Add a short doc comment with one worked example.
2. **`src/middleware/verifyToken`:** implement the guard as specified in §5.3. Requirements:
   - SHA-256 via `lib/tokens`;
   - identical 401 body for missing, malformed and unknown tokens;
   - 410 for revoked, expired or anonymized;
   - `warn` log with reminder ID on a revoked token.
   Confirm the logger redaction from TASK-01 already strips `X-Verify-Token`.
3. **Rate limiter:** apply 60 per IP per hour to the whole `/verify` router using the TASK-01 limiter factory.
4. **`modules/verify` service, `getSummary(complaintId)`:** select only the allowed fields; `previousVerificationCount` via count; `hasPhoto` = photo exists and `deleted_at` is null. Record `verify_opened` in the same request after a successful read.
5. **`GET /verify/complaint` and `GET /verify/complaint/photo`:** the photo is streamed through the storage interface (`open`) with `Content-Type: image/jpeg`. Never redirect to a file path.
6. **`POST /verify/photos`:** reuse the TASK-04 multipart limit and `lib/images` pipeline (size check, JPEG magic bytes, re-encode, strip metadata, max edge, SHA-256), then the storage `save`. Insert the `photos` row with `purpose='verification'` and `uploaded_for_complaint_id` = guard's complaint ID.
7. **Zod schema for `POST /verify/submissions`:** fields as in §5.3; unknown fields stripped. Reuse the coordinate and device-clock validators from TASK-04 rather than duplicating them.
8. **Submission service:** implement the idempotency check, the photo usability checks (purpose, `uploaded_for_complaint_id` match, unattached), and the transaction (insert verification + distance, attach photo). Catch the unique violation on `client_submission_id`, then re-read and return 200. Record `verify_submitted {result}`.
9. **Manual API pass:** check the token cases and idempotency with curl (M-07-01…M-07-08) before starting the app work.
10. **App platform config:** add the Android intent filter and the iOS `CFBundleURLTypes` for `saarthee`. Add *candidate* `app_links` after checking pub.dev for current version and maintenance.
11. **`core/utils/parseVerifyInput`:** handle scheme, https and bare-token inputs. Route listener in `lib/router`:
    - an incoming link resolves to `/verify` with the token passed in memory (route `extra`), not persisted;
    - an unparseable link goes to `/verify/enter-code` and fires `deep_link_failed`.
12. **`features/verify/data`:** a `VerifyApi` that adds the `X-Verify-Token` header per call. The token is never put in a path or query, and the dio interceptor logging must redact the header in debug.
13. **`verifySessionProvider` (application layer, memory only):** holds token, summary, answer, local photo path, photo ID, GPS/time, note and `clientSubmissionId`. Methods: `openWithToken`, `setAnswer`, `setPhoto`, `uploadPhoto`, `setNote`, `submit`. The provider is disposed on completion or app close, with **no** shared_preferences or secure-storage writes.
14. **Verify entry screen:** loading, invalid, revoked, offline and rate-limited states; the "answered before" note; original photo via an authenticated image fetch using the token header.
15. **`/verify/enter-code`:** wire Home's "Answer a follow-up" card to it, replacing the TASK-03 stub. Track `deep_link_failed {reason:"manual_entry"}` on use.
16. **Answer screen:** two `ChoiceCard`s. "Not fixed" routes through the note step; "Fixed" skips it.
17. **Photo screen:** reuse the TASK-04 camera, GPS and compression components. Show the original thumbnail for framing. Upload to `/verify/photos` with progress and retry.
18. **Note screen:** counter, 1,000 limit, Skip/Continue.
19. **Check screen:** `BeforeAfterCard` citizen variant (TASK-03 component), answer, note preview, Change links that return to check. "Send" calls `submit` and is disabled while sending. Server errors go to `ErrorSummary`. Retries resend the same `clientSubmissionId`.
20. **Done screen** → Home. Clear the verify session.
21. **ARB and accessibility:** add every string to ARB, plus semantics labels (step announcement, photo descriptions, error announcements).
22. **Emulator walk-through:** fire the link with adb and complete the flow, then run the manual checks M-07-09…M-07-16, including the M1 checkpoint (AC-12).

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Valid token returns the summary without personal data
- **Given** a complaint with a reminder whose raw token is T
- **When** `GET /api/v1/verify/complaint` is called with header `X-Verify-Token: T`
- **Then** the response is 200 with exactly `complaintId, categoryName, ccrsNumber, reportedAt, hasPhoto, previousVerificationCount`, contains no phone, coordinates, invite code or source tag, and one `verify_opened` event row exists with that `complaint_id`

**AC-2** — Unknown and malformed tokens are indistinguishable
- **Given** no reminder has the hash of `garbage` or of a well-formed random 43-character token
- **When** `/verify/complaint` is called with each, and once with no header
- **Then** all three return 401 with `error.code = VERIFY_TOKEN_INVALID` and an identical `message`

**AC-3** — Revoked or anonymized tokens are rejected with 410
- **Given** a reminder with `revoked_at` set, and a separate complaint with `anonymized_at` set
- **When** their tokens are used on any `/verify/*` endpoint
- **Then** the response is 410 `VERIFY_TOKEN_REVOKED`, and a `warn` log line names the reminder ID but not the token

**AC-4** — Report photo stream is scoped to the token
- **Given** tokens TA (complaint A) and TB (complaint B)
- **When** `GET /verify/complaint/photo` is called with TA
- **Then** A's report photo bytes are returned as `image/jpeg`; there is no request form that returns B's photo with TA

**AC-5** — Verification photo is bound to the token's complaint
- **Given** a photo uploaded via `POST /verify/photos` with TA
- **When** that `photoId` is submitted in `POST /verify/submissions` with TB
- **Then** the response is 422 `PHOTO_UNUSABLE`, and the `photos` row has `uploaded_for_complaint_id = A`

**AC-6** — Submission is stored atomically with distance and reminder link
- **Given** a valid token, an unattached verification photo for that complaint, and valid evidence fields
- **When** `POST /verify/submissions` is sent
- **Then** the response is 201 `{verificationId, createdAt}`; the row has `reminder_id` = the token's reminder and `distance_from_report_m` = the haversine distance (± 0.5 m); the photo's `attached_at` is set; and a `verify_submitted` event has `properties.result` equal to the answer

**AC-7** — Submission is idempotent
- **Given** a submission already stored with `clientSubmissionId` X
- **When** the same body is resent
- **Then** the response is 200 with the same `verificationId`, and the `verifications` count for the complaint is unchanged

**AC-8** — Repeat answers are new rows and the latest wins
- **Given** a complaint verified "Fixed"
- **When** a later verification with a new `clientSubmissionId` answers "Not fixed"
- **Then** two rows exist, `complaint_status_v` shows `verified_not_fixed`, and the summary's `previousVerificationCount` is 2

**AC-9** — Deep link opens verify entry; a bad link falls back
- **Given** the app is installed on the emulator
- **When** `saarthee://verify?t=<valid>` is fired with adb, and separately `saarthee://verify?x=1`
- **Then** the first opens the verify entry showing the complaint; the second opens `/verify/enter-code` and queues `deep_link_failed {reason:"unparseable"}` with no token in its properties

**AC-10** — Manual code entry works with a link or a bare code
- **Given** the citizen is on `/verify/enter-code` from Home's "Answer a follow-up"
- **When** they paste the whole reminder link, and separately just the token
- **Then** both open the verify entry for that complaint, and `deep_link_failed {reason:"manual_entry"}` is tracked

**AC-11** — Citizen completes the flow with all steps and states
- **Given** a valid verify session
- **When** the citizen chooses "No, it's not fixed", takes a photo, types a 1,000-character note (the counter blocks a 1,001st), and reviews the check screen
- **Then** the check screen shows the `BeforeAfterCard` with both photos, the answer and the note preview. Each "Change" link returns to check. "Send" is disabled while sending and leads to "Thank you". Choosing "Yes, it's fixed" skips the note step

**AC-12** — M1 loop checkpoint (Stage A complete, 07 §3)
- **Given** on the Android emulator, a complaint recorded in the app (TASK-04) and a reminder sent from the Due tab (TASK-06), with the H2 values noted from the Rates tab
- **When** the verify link from the reminder is fired and the citizen answers "Not fixed" with a photo
- **Then** the Rates tab, after refresh, shows the complaint counted as verified and the H2 numerator and rate for its source (and "trusted" if applicable) changed accordingly

**AC-13** — Token never leaves memory or the header
- **Given** a completed verify session
- **When** the API log output and the app's shared_preferences and secure-storage contents are searched for the raw token
- **Then** there are no matches, and no API request carried the token in a path or query string

**AC-14** — Verify rate limit
- **Given** 60 `/verify/*` requests from one IP within an hour
- **When** a 61st request is made
- **Then** the response is 429 `RATE_LIMITED` with a `Retry-After` header, and the app shows the wait message

**AC-15** — URL scheme registered on both platforms
- **Given** a debug build on the Android emulator and on the iOS simulator
- **When** the documented `adb` / `xcrun simctl openurl` commands are run
- **Then** the app opens on the verify entry on each platform

**AC → Requirement traceability**

| Requirement | ACs |
|---|---|
| REQ-F-048 | AC-9, AC-15 |
| REQ-F-049 | AC-10 |
| REQ-F-050 | AC-1 |
| REQ-F-051 | AC-4 |
| REQ-F-052 | AC-1, AC-3, AC-9 (entry states), AC-11 |
| REQ-F-053 | AC-11 |
| REQ-F-054 | AC-5, AC-11 |
| REQ-F-055 | AC-11 |
| REQ-F-056 | AC-11, AC-12 |
| REQ-F-057 | AC-6, AC-7 |
| REQ-F-058 | AC-8, AC-12 |
| REQ-F-059 | AC-6 |
| REQ-S-006 | AC-13 |
| REQ-S-007 | AC-2, AC-3 |
| REQ-S-008 | AC-4, AC-5 |
| REQ-S-024 | AC-14 |
| REQ-O-012 | AC-15 |

### 7.2 Non-Functional Checklist

- [ ] All four verify endpoints validate input with Zod. Validation failures return 400 `VALIDATION_FAILED` with field `details`; business-rule failures return 409/410/422 as listed.
- [ ] Error bodies follow `{error:{code,message,details?,requestId}}` with no stack traces or SQL.
- [ ] Logs for verify requests contain the route template (`/verify/complaint`), status and duration; no token, note, coordinates or phone.
- [ ] Event properties for `verify_opened`, `verify_submitted` and `deep_link_failed` contain only allow-listed fields (`result`, `reason`).
- [ ] Verify entry has loading, invalid, revoked, offline and rate-limited states, each reachable on the emulator.
- [ ] Photo step reuses the TASK-04 permission-denied, weak-GPS, upload-failed and retake states.
- [ ] "Send" and "Continue" buttons are disabled while in flight, so a double tap creates one verification.
- [ ] Answer `ChoiceCard`s show icon + word + colour; readable in grayscale.
- [ ] TalkBack announces "Step n of N", photo descriptions and error messages on the verify screens.
- [ ] Verify screens work at 320 px width and at the largest system text size without clipping.
- [ ] No hard-coded colours or strings: tokens from the theme, copy from ARB.
- [ ] `VERIFY_LINK_BASE` / `DEEP_LINK_SCHEME` come from config; no scheme literal outside platform manifests and config.

## 8. Validation & Testing

| Level | What to test | ACs proven |
|---|---|---|
| Static | `npm run typecheck` and ESLint in `apps/api`; `dart format --set-exit-if-changed .` and `dart analyze` in `apps/mobile`: zero errors | All (precondition) |
| API manual | **M-07-01** `curl -i -H "X-Verify-Token: $T" $API/verify/complaint` → 200 with the 6 fields only; then `SELECT name, complaint_id FROM events ORDER BY id DESC LIMIT 1;` → `verify_opened` | AC-1 |
| API manual | **M-07-02** Same call with `X-Verify-Token: garbage`, with a random 43-character token, and with no header → three identical 401 bodies (compare with `diff` after removing `requestId`) | AC-2 |
| API manual | **M-07-03** `UPDATE reminders SET revoked_at=now() WHERE id=…;` then call → 410; check the API log for a `warn` line with the reminder ID and no token. Repeat on a complaint with `anonymized_at` set | AC-3 |
| API manual | **M-07-04** `curl -H "X-Verify-Token: $TA" $API/verify/complaint/photo -o a.jpg` → valid JPEG equal to A's stored file (compare SHA-256 with `photos.sha256`) | AC-4 |
| API manual | **M-07-05** `curl -F photo=@x.jpg -H "X-Verify-Token: $TA" $API/verify/photos` → 201; submit that photoId with `$TB` → 422 `PHOTO_UNUSABLE`; `SELECT uploaded_for_complaint_id FROM photos WHERE id=…` = A | AC-5 |
| API manual | **M-07-06** Valid submission → 201. Check the row: `reminder_id`, `distance_from_report_m` (compare with a hand haversine), `photos.attached_at`, and the `verify_submitted` event properties | AC-6 |
| API manual | **M-07-07** Resend the identical body → 200, same ID; `SELECT count(*) FROM verifications WHERE complaint_id=…` unchanged | AC-7 |
| DB manual | **M-07-08** Submit "fixed" then "not_fixed" (new IDs); `SELECT status FROM complaint_status_v WHERE complaint_id=…` → `verified_not_fixed`; summary shows `previousVerificationCount=2` | AC-8 |
| API manual | **M-07-09** Loop 61 requests to `/verify/complaint` → the 61st returns 429 with `Retry-After` | AC-14 |
| App manual | **M-07-10** `adb shell am start -a android.intent.action.VIEW -d "saarthee://verify?t=$T"` → verify entry; `-d "saarthee://verify?x=1"` → enter-code screen; queued event has `reason`, no token | AC-9, AC-15 |
| App manual | **M-07-11** `xcrun simctl openurl booted "saarthee://verify?t=$T"` on the iOS simulator → verify entry (commands to verify on installed tooling) | AC-15 |
| App manual | **M-07-12** Home → "Answer a follow-up" → paste the whole link → entry; repeat with the bare token → entry | AC-10 |
| App manual | **M-07-13** Full flow "Not fixed" + photo + note at 1,000 chars + Change links + Send (double tap) → Thank you; one row in DB. Repeat with "Fixed" (no note step). Airplane mode on the check screen → offline banner, answers kept; reconnect and send | AC-11 |
| App manual | **M-07-14** Entry states: revoked token → "no longer active"; invalid → "isn't valid" + "Enter a code instead"; offline → retry | AC-3, AC-9 |
| App manual | **M-07-15** M1 checkpoint: record a complaint in the app, make it due (seed or set `created_at` back 8 days in SQL), send the reminder from the Due tab, copy the link, fire it with adb, answer "Not fixed" with a photo, then Rates → H2 changed for the source and trusted row | AC-12 |
| App manual | **M-07-16** After M-07-13: `grep -r "$T" <api log>` → none; `adb shell run-as <pkg> cat shared_prefs/*.xml \| grep "$T"` → none; secure storage holds only the admin JWT key | AC-13 |
| Optional automated | Vitest + Supertest "verify access" (06 §8.1 #3): valid token works; unknown/revoked/anonymized rejected; token cannot reach another complaint's photo. Only if time allows (scheduled in TASK-10, REQ-N-019) | AC-2, AC-3, AC-4, AC-5 |

### Verification log (W1, API only — 2026-10-03, `saarthee_w1` DB, `API=http://localhost:4001/api/v1`, `V="X-Verify-Token: <token from TASK-06 reminder for C1>"`)

| Check | Command | Observed |
|---|---|---|
| Static | `cd apps/api && npx tsc --noEmit && npx eslint .` | clean |
| Summary | `curl -s $API/verify/complaint -H "$V"` | 200 `{complaintId, categoryName:"Garbage and cleanliness", ccrsNumber:"AMC-2026-0001", reportedAt, hasPhoto:true, previousVerificationCount:0}` — no phone/coords/invite/source; `verify_opened` event `{}` |
| Invalid tokens | no header; 43-char unknown token; token in `?t=` query only | 401 `VERIFY_TOKEN_INVALID` (identical bodies); query token ignored → 401 |
| Report photo | `curl -s $API/verify/complaint/photo -H "$V"` | 200 `image/jpeg` |
| Verify photo | `curl -s -F photo=@exif.jpg $API/verify/photos -H "$V"` | 201 `{photoId}`; row `purpose verification`, `uploaded_for_complaint_id` = C1 |
| Submit | `curl -s -X POST $API/verify/submissions -H 'Content-Type: application/json' -H "$V" -d '{"clientSubmissionId":"b1111111-…","result":"not_fixed","photoId":"<id>","latitude":23.0230,"longitude":72.5720,"gpsAccuracyM":12,"deviceCapturedAt":"2026-10-03T14:05:00+05:30","note":"  Still broken  ","platform":"android","appVersion":"0.1.0"}'` | 201 `{verificationId, createdAt}`; row `not_fixed`, note trimmed `Still broken`, `distance_from_report_m 97.89`, `reminder_id` set; `verify_submitted {"result":"not_fixed"}` |
| Idempotent | same body again | 200, same `verificationId` |
| Photo rules | attached photo with a new id; a `report`-purpose photo | 422 `PHOTO_UNUSABLE` "Please retake the photo." (both) |
| Note length | 1,001-char note | 400 `details:[{field:"note",issue:"Your note is too long."}]` |
| H1/H2 demo delta | `curl -s $API/admin/rates -H "$H"` after C1 reminded + verified not_fixed | rwa reminded 4 / verified 3 / h1 0.75 / not_fixed 2 / **h2 0.6667**; trusted 6 / 4 / h1 0.6667 / not_fixed 3 / **h2 0.75** — exactly the SEED-EXPECTATIONS demo delta |
| Revoked → 410 | `curl -s -X POST $API/admin/reminders/<id>/revoke -H "$H"` then summary | 200 `{revokedAt}`; then 410 `VERIFY_TOKEN_REVOKED` "This link is no longer active."; `warn` "revoked token presented" with reminderId only |
| Log redaction | `grep -c -E "<token>\|Still broken" api.log` | 0 |

## 9. Deliverables
- `src/middleware/verifyToken`, `src/lib/geo`, and `src/modules/verify` (routes, handlers, service, Zod schemas) with the four endpoints.
- Server events `verify_opened` and `verify_submitted`.
- `/verify/*` rate limiter applied.
- Android intent filter and iOS URL type for `saarthee`.
- *Candidate* `app_links` integrated after verification.
- `parseVerifyInput` util and deep-link router handling with the `deep_link_failed` event.
- `features/verify/` data, application and presentation layers: `verifySessionProvider` and six screens plus `/verify/enter-code`.
- ARB strings for every verify screen and error.
- A short note in `apps/mobile/README.md` with the adb and simctl link-firing commands.
- Manual check results M-07-01…M-07-16 recorded in the progress log and the coverage matrix.

## 10. Files Expected to Change

Prediction only. Exact paths depend on the patterns established in TASK-01 to TASK-06.

| Path | Change |
|---|---|
| `apps/api/src/middleware/verifyToken.*` | New |
| `apps/api/src/lib/geo/` | New |
| `apps/api/src/modules/verify/` | New |
| `apps/api/src/app.*` (router mount, rate limiter) | Modified |
| `apps/api/src/lib/images/`, `apps/api/src/lib/storage/` | Modified only if reuse needs a small extension (purpose parameter) |
| `apps/mobile/android/app/src/main/AndroidManifest.xml` | Modified (intent filter) |
| `apps/mobile/ios/Runner/Info.plist` | Modified (URL type) |
| `apps/mobile/lib/router/` | Modified (verify routes, deep-link listener) |
| `apps/mobile/lib/core/utils/` | Modified (`parseVerifyInput`) |
| `apps/mobile/lib/features/verify/` | New |
| `apps/mobile/lib/features/home/` | Modified (wire "Answer a follow-up") |
| `apps/mobile/lib/core/l10n/*.arb` | Modified |
| `apps/mobile/pubspec.yaml` | Modified (`app_links` candidate) |
| `apps/mobile/README.md` | Modified (link-firing commands) |

## 11. Related Documentation
- `docs/03-backend-spec.md §3.1`: verify-token "authentication" and identical responses for unknown tokens.
- `docs/03-backend-spec.md §3.2`: verify token format (32 bytes, URL-safe, SHA-256 stored, no expiry).
- `docs/03-backend-spec.md §2.2, §2.3`: verify endpoint table and request/response schemas.
- `docs/03-backend-spec.md §4.5`: verify workflow, repeat answers, same-image and distance rules.
- `docs/03-backend-spec.md §8`: photo pipeline reused for verification uploads.
- `docs/03-backend-spec.md §10`: `/verify/*` rate limit.
- `docs/04-database-design.md §3.4, §3.6, §3.7`: photos, reminders, verifications columns and constraints.
- `docs/04-database-design.md §3.9`: latest verification drives status and H2 (A5).
- `docs/02-frontend-spec.md §3.1`: verify routes, token in memory, deep-link behaviour.
- `docs/02-frontend-spec.md §4.11–§4.16`: verify screens and copy.
- `docs/02-frontend-spec.md §2.5`: `BeforeAfterCard` citizen variant.
- `docs/02-frontend-spec.md §5.1–§5.2`: `verifySessionProvider` is memory-only.
- `docs/05-devops-infrastructure.md §4.6`: scheme registration and firing links without WhatsApp.
- `docs/01-project-overview.md §7.1, Decision 7`: local-mode deep-link limits; token-based access.
- `docs/07-implementation-roadmap.md §3`: A6/A11 steps and the Stage A "complete when" statement.

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Custom-scheme links not tappable in WhatsApp (01 A14) | Citizens can't open the link locally | Manual code entry (AC-10); real WhatsApp check deferred to TASK-10 (REQ-O-015) |
| Token leaks into logs via a dio debug interceptor or an error report | Privacy, and token reuse | Redact `X-Verify-Token` in app and API logging; AC-13 grep check |
| Timing difference between "unknown" and "revoked" lookups lets tokens be probed | Low (256-bit tokens) | Identical 401 body; hash lookup only; rate limit |
| Two submissions race with the same `clientSubmissionId` | Duplicate rows or 500 | Unique constraint + catch → re-read → 200 |
| Photo reused across complaints | False evidence | `uploaded_for_complaint_id` check (AC-5); same-image warning in TASK-08 |
| `app_links` package API changes | Build breaks | Verify the current version on pub.dev before adding; keep parsing in our own util |
| Haversine precision vs NUMERIC(10,2) | Off by centimetres | Round to 2 decimals before insert |
| App killed mid-verify loses answers (memory only by design) | Citizen re-enters answers | Accepted per 02 §9.4; flow is short |

## 13. Progress Status

**Current status:** Not Started
**Progress:** 0%

| Date | Progress | Commit |
|---|---|---|
| 2026-10-03 | W1: backend done — verify-token guard (`X-Verify-Token` header only, SHA-256 lookup, 401/410), `GET /verify/complaint`, `GET /verify/complaint/photo`, `POST /verify/photos`, `POST /verify/submissions` (idempotent, haversine distance, `verify_submitted {result}`), 60/IP/h limiter on `/verify/*`. No new libraries. Curl-verified incl. H1/H2 demo delta (§8 W1 log). | TASK-07: API (w1-api) |

## 14. Completion Checklist

- [ ] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [ ] Static checks pass and every AC verified by the manual checks in §8 (no automated tests in v1 — 06 §7.1)
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-07` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `TASK-07: …`
- [ ] Validator passes
