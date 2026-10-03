# Coverage Verification Matrix — Saarthee

**Last Updated:** 2026-10-03
**Verified:** 0 / 177 (0%)
**Owner of final sign-off:** TASK-10 (REQ-O-023)

This is the verification layer for the whole plan. It answers one question: **has every feature
and requirement in the spec actually been delivered and checked in the running system?**

## How it works

- One row per **active** requirement in [requirements-registry.md](./requirements-registry.md). Rows are generated
  from the registry: run `python3 docs/tasks/check_coverage.py --sync` after the registry changes.
- **During TASK-01…09:** when a task closes, set each of its rows to `Pass` (or `Fail`) with evidence.
  `python3 docs/tasks/check_coverage.py --task TASK-NN` shows that task's remaining rows.
- **During TASK-10:** re-verify every row end to end on real devices, fix every `Fail`/`Not Verified`
  (status becomes `Fixed` with the commit), and finish with `check_coverage.py` exiting 0.
- **Evidence** is short and reproducible: a manual-check ID from the task's section 8, a curl command,
  an SQL query, a screenshot file name, or a commit hash. Phone numbers are always blurred or made up.

Statuses: `Not Verified` · `Pass` · `Fixed` · `Fail` · `Deferred` (needs who decided and when in Evidence).

## Matrix

| Req ID | Requirement | Owner | Status | Evidence | Verified On |
|---|---|---|---|---|---|
| REQ-F-001 | Welcome screen with the two-sentence purpose and independence notice on first launch | TASK-03 | Not Verified | — | — |
| REQ-F-002 | A random install ID (UUID) is generated and stored on first launch | TASK-03 | Not Verified | — | — |
| REQ-F-003 | Invite code screen: uppercase letters/digits 6–20, validates via API, stores code and group label locally, ... | TASK-03 | Not Verified | — | — |
| REQ-F-004 | `POST /invite-codes/validate` returns `{valid, groupLabel}`; case-insensitive lookup; inactive or unknown →... | TASK-03 | Not Verified | — | — |
| REQ-F-005 | "I don't have a code" skips to Home with no code stored | TASK-03 | Not Verified | — | — |
| REQ-F-006 | "Change group code" from About re-runs the invite screen | TASK-03 | Not Verified | — | — |
| REQ-F-007 | Home: independence notice, "Record a complaint" (or "Continue your report" when a draft exists), "Answer a ... | TASK-03 | Not Verified | — | — |
| REQ-F-008 | About screen: about, privacy, independence and the operator login link (admin entry not on Home) | TASK-03 | Not Verified | — | — |
| REQ-F-009 | `POST /events` accepts batches of ≤ 50, keeps only allow-listed names and properties, returns 202 `{accepted}` | TASK-03 | Not Verified | — | — |
| REQ-F-010 | App event queue: flush at 20 events, on background, every 60 s; capped at 500 (oldest dropped); drops inste... | TASK-03 | Not Verified | — | — |
| REQ-F-011 | Global error handler: uncaught errors show "Something went wrong" with "Go home"; never clears the report d... | TASK-03 | Not Verified | — | — |
| REQ-F-012 | API errors converted to a typed app error by backend `code`; messages come from ARB keyed by code; rate-lim... | TASK-03 | Not Verified | — | — |
| REQ-F-013 | Offline banner "You're offline. Your answers are saved." with retry where relevant | TASK-03 | Not Verified | — | — |
| REQ-F-014 | `GET /categories` returns active categories in sort order; app caches per session and keeps the last list f... | TASK-04 | Not Verified | — | — |
| REQ-F-015 | Report step 1 (category): single-select `ChoiceCard`s; a new draft gets a `clientSubmissionId`; emits `repo... | TASK-04 | Not Verified | — | — |
| REQ-F-016 | Report step 2 (file with AMC): open CCRS web, AMC WhatsApp, call 155303 (values from config); shows chosen ... | TASK-04 | Not Verified | — | — |
| REQ-F-017 | Report step 3: CCRS number, required, 1–50 chars after trim, spaces/dashes allowed | TASK-04 | Not Verified | — | — |
| REQ-F-018 | Report step 4: camera-only capture with GPS position, accuracy and capture time; location rationale; denied... | TASK-04 | Not Verified | — | — |
| REQ-F-019 | On-device compression: long edge ≤ 1,600 px, JPEG ~q80; original not kept | TASK-04 | Not Verified | — | — |
| REQ-F-020 | Background photo upload with progress; failure keeps photo and offers "Retry upload"; `PHOTO_UNUSABLE` at s... | TASK-04 | Not Verified | — | — |
| REQ-F-021 | `POST /photos` (multipart, `purpose=report`) returns 201 `{photoId}` | TASK-04 | Not Verified | — | — |
| REQ-F-022 | Report step 5: phone field with fixed +91 and numeric keypad; consent checkbox with versioned text; "Why we... | TASK-04 | Not Verified | — | — |
| REQ-F-023 | Report step 6: check-your-answers summary with "Change" links that return here; server errors shown in an e... | TASK-04 | Not Verified | — | — |
| REQ-F-024 | `POST /reports` implements the §4.1 workflow: normalize phone and CCRS number, resolve invite code, check c... | TASK-04 | Not Verified | — | — |
| REQ-F-025 | Report submission is idempotent: same `clientSubmissionId` returns 200 with the existing complaint (201 fir... | TASK-04 | Not Verified | — | — |
| REQ-F-026 | Unknown or inactive invite code at submission stores the report as `unknown` with no code and logs a warnin... | TASK-04 | Not Verified | — | — |
| REQ-F-027 | Duplicate CCRS numbers are flagged (`ccrs_duplicate_flag`), not rejected, and never returned to the citizen | TASK-04 | Not Verified | — | — |
| REQ-F-028 | "Report recorded" confirmation screen with next-step copy and "Done" → Home | TASK-04 | Not Verified | — | — |
| REQ-F-029 | Report draft (JSON + compressed photo file) persisted on every change and restored on the same step after t... | TASK-04 | Not Verified | — | — |
| REQ-F-030 | The draft is deleted only after the server confirms the save (201/200) | TASK-04 | Not Verified | — | — |
| REQ-F-031 | Every report step works offline except photo upload and final submit | TASK-04 | Not Verified | — | — |
| REQ-F-032 | Home "Your reports on this phone" list from local storage only (CCRS number, category, date) | TASK-04 | Not Verified | — | — |
| REQ-F-033 | Orphaned-photo cleanup script deletes files and rows for photos unattached for > `UNATTACHED_PHOTO_TTL_HOUR... | TASK-04 | Not Verified | — | — |
| REQ-F-034 | Create-admin CLI (`admin:create`): prompts for password, never logs it, errors if email exists; reset mode ... | TASK-05 | Not Verified | — | — |
| REQ-F-035 | `POST /admin/auth/login` returns `{accessToken, expiresAt, admin}`; updates `last_login_at` | TASK-05 | Not Verified | — | — |
| REQ-F-036 | `GET /admin/me` returns the current admin | TASK-05 | Not Verified | — | — |
| REQ-F-037 | `POST /admin/auth/logout-all` increments `token_version`, 204 | TASK-05 | Not Verified | — | — |
| REQ-F-038 | Operator login screen (from About): email, password with show/hide; stores token + expiry; handles `INVALID... | TASK-05 | Not Verified | — | — |
| REQ-F-039 | Admin tab shell: Due, All, Rates, More with a marigold count badge on Due; admin screens allow rotation | TASK-05 | Not Verified | — | — |
| REQ-F-040 | 401 (`TOKEN_EXPIRED`/`TOKEN_REVOKED`) on admin calls clears the token, shows "Your session ended…", redirec... | TASK-05 | Not Verified | — | — |
| REQ-F-041 | More tab: "Log out" (this device) and "Log out everywhere" | TASK-05 | Not Verified | — | — |
| REQ-F-042 | `GET /admin/complaints` returns `ComplaintSummary` items with derived status, cursor paging (`limit` defaul... | TASK-06 | Not Verified | — | — |
| REQ-F-043 | "Due" rule: not excluded, not anonymized, no verification, and (no reminder and created > interval ago) or ... | TASK-06 | Not Verified | — | — |
| REQ-F-044 | Due tab: item with before thumbnail, CCRS number, category, group label, days since filed/last reminder, re... | TASK-06 | Not Verified | — | — |
| REQ-F-045 | `POST /admin/complaints/{id}/reminders` creates a reminder and verify token; returns `{reminderId, sentAt, ... | TASK-06 | Not Verified | — | — |
| REQ-F-046 | Reminder bottom sheet: message preview, "Open WhatsApp" (click-to-chat with phone + text), "Copy message" f... | TASK-06 | Not Verified | — | — |
| REQ-F-047 | Server-side reminder template (`REMINDER_TEMPLATE_VERSION=v1`, English) containing CCRS number, verify link... | TASK-06 | Not Verified | — | — |
| REQ-F-048 | Deep link `saarthee://verify?t=<token>` opens verify entry (https-ready parsing); unparseable link → `/veri... | TASK-07 | Not Verified | — | — |
| REQ-F-049 | Manual verify code entry accepts the whole pasted link or just the code; records `deep_link_failed` for fal... | TASK-07 | Not Verified | — | — |
| REQ-F-050 | `GET /verify/complaint` returns `{complaintId, categoryName, ccrsNumber, reportedAt, hasPhoto, previousVeri... | TASK-07 | Not Verified | — | — |
| REQ-F-051 | `GET /verify/complaint/photo` streams the original report photo for the token's complaint | TASK-07 | Not Verified | — | — |
| REQ-F-052 | Verify entry screen: date, category, CCRS number, original photo; "answered before" note; invalid/revoked/o... | TASK-07 | Not Verified | — | — |
| REQ-F-053 | "Is it fixed?" screen with two `ChoiceCard`s (fixed / not fixed), no "partly" | TASK-07 | Not Verified | — | — |
| REQ-F-054 | Verify photo step (same rules as report photo, original shown for framing) uploading to `POST /verify/photos` | TASK-07 | Not Verified | — | — |
| REQ-F-055 | Optional note after "Not fixed" (≤ 1,000 chars with counter, Skip/Continue) | TASK-07 | Not Verified | — | — |
| REQ-F-056 | Verify check-and-send with `BeforeAfterCard`, answer, note preview and Change links; "Thank you" screen | TASK-07 | Not Verified | — | — |
| REQ-F-057 | `POST /verify/submissions`: idempotent by `clientSubmissionId`; one transaction inserts verification with `... | TASK-07 | Not Verified | — | — |
| REQ-F-058 | Repeat verifications are stored as new rows; the latest drives status and H2 | TASK-07 | Not Verified | — | — |
| REQ-F-059 | `distance_from_report_m` computed from report and verification coordinates at insert | TASK-07 | Not Verified | — | — |
| REQ-F-060 | All complaints screen with filters (source, category, status, excluded, duplicate) via chips + sheet, infin... | TASK-08 | Not Verified | — | — |
| REQ-F-061 | `GET /admin/complaints/{id}` returns `ComplaintDetail` (complaint, phone, reminders, verifications) | TASK-08 | Not Verified | — | — |
| REQ-F-062 | `GET /admin/complaints/{id}/photo` and `GET /admin/verifications/{id}/photo`; 410 `PHOTO_DELETED` after ano... | TASK-08 | Not Verified | — | — |
| REQ-F-063 | Complaint detail screen: full-width `BeforeAfterCard`, facts (CCRS + duplicate flag, category, source/group... | TASK-08 | Not Verified | — | — |
| REQ-F-064 | "Same image as report" warning (sha256 match) and distance highlight beyond `VERIFY_DISTANCE_WARN_M` (off w... | TASK-08 | Not Verified | — | — |
| REQ-F-065 | `POST /admin/reminders/{id}/revoke` and the timeline "Revoke" action; revoked links stop working | TASK-08 | Not Verified | — | — |
| REQ-F-066 | `PATCH /admin/complaints/{id}/exclusion` (reason required when excluding; re-include clears fields) with ex... | TASK-08 | Not Verified | — | — |
| REQ-F-067 | `POST /admin/complaints/{id}/anonymize` with typed-CCRS confirm dialog: null phone, set `anonymized_at`, re... | TASK-08 | Not Verified | — | — |
| REQ-F-068 | Cleanup script also retries failed anonymization file deletions | TASK-08 | Not Verified | — | — |
| REQ-F-069 | "Send reminder" in the complaint detail action bar reuses the reminder sheet | TASK-08 | Not Verified | — | — |
| REQ-F-070 | `GET /admin/rates` returns `{rows:[RateRow], computedAt}` from `pilot_rates_v` | TASK-06 | Not Verified | — | — |
| REQ-F-071 | Rates screen: "Trusted sources" card first, per-source rows (complaints, reminded, verified, H1 %, H2 %), e... | TASK-06 | Not Verified | — | — |
| REQ-F-072 | `GET /admin/export?type=complaints\ | TASK-09 | Not Verified | — | — |
| REQ-F-073 | Export screen: type selector, "Include phone numbers" toggle (off, with warning), download and OS share sheet | TASK-09 | Not Verified | — | — |
| REQ-F-074 | Invite code admin API: list with complaint counts, create (code generated if omitted; 409 `INVITE_CODE_TAKE... | TASK-09 | Not Verified | — | — |
| REQ-F-075 | Invite codes screen: list, "New code" form, deactivate, "Share" via OS share sheet ("Install the app and en... | TASK-09 | Not Verified | — | — |
| REQ-F-076 | Category admin API: list including inactive, create, patch (name, ccrsLabel, sortOrder, isActive); 409 on d... | TASK-09 | Not Verified | — | — |
| REQ-F-077 | Categories screen: drag-to-reorder, add, edit, deactivate; "Placeholder list" note | TASK-09 | Not Verified | — | — |
| REQ-F-078 | More tab links to Invite codes, Categories and Export | TASK-09 | Not Verified | — | — |
| REQ-F-079 | Optional rates snapshot script prints `pilot_rates_v` to the console | TASK-06 | Not Verified | — | — |
| REQ-D-001 | All enum types: `source_tag`, `verification_result`, `photo_purpose`, `storage_driver`, `reminder_channel`,... | TASK-02 | Not Verified | — | — |
| REQ-D-002 | `admin_users` table with lowercase-unique email, `token_version ≥ 0`, audit columns | TASK-02 | Not Verified | — | — |
| REQ-D-003 | `invite_codes` table: uppercase alnum 6–20 unique code, `source_tag` ≠ `unknown`, indexes | TASK-02 | Not Verified | — | — |
| REQ-D-004 | `ccrs_categories` table with unique name, `sort_order ≥ 0`, `(is_active, sort_order)` index | TASK-02 | Not Verified | — | — |
| REQ-D-005 | `photos` table with unique `storage_key`, sha256 index, partial unattached index, `uploaded_for_complaint_i... | TASK-02 | Not Verified | — | — |
| REQ-D-006 | `complaints` table with all columns, CHECK constraints (coords, E.164 phone, exclusion reason rule), unique... | TASK-02 | Not Verified | — | — |
| REQ-D-007 | `reminders` table with unique `token_hash`, `(complaint_id, sent_at DESC)` index | TASK-02 | Not Verified | — | — |
| REQ-D-008 | `verifications` table with unique `client_submission_id` and `photo_id`, note ≤ 1,000, indexes | TASK-02 | Not Verified | — | — |
| REQ-D-009 | `events` table with bigint identity PK and the three indexes | TASK-02 | Not Verified | — | — |
| REQ-D-010 | Foreign keys with the on-delete/on-update rules of §4 (RESTRICT on evidence, SET NULL where listed) | TASK-02 | Not Verified | — | — |
| REQ-D-011 | `complaint_status_v` view: counts, last reminder, latest result, derived status; due computed with the conf... | TASK-02 | Not Verified | — | — |
| REQ-D-012 | `pilot_rates_v` view: per source + `trusted` (rwa + activist); H1 = verified ÷ reminded; H2 = latest-result... | TASK-02 | Not Verified | — | — |
| REQ-D-013 | Migrations follow the §7.3 order and conventions; hand-written SQL (CHECKs, partial indexes, views, identit... | TASK-02 | Not Verified | — | — |
| REQ-D-014 | Seed: dev admin from env, one invite code per source tag, placeholder categories, sample set covering every... | TASK-02 | Not Verified | — | — |
| REQ-D-015 | Dev sample seed refuses to run unless `APP_ENV=development` and no real pilot data is present | TASK-02 | Not Verified | — | — |
| REQ-D-016 | Prisma models PascalCase mapped to snake_case; UUID PKs via `gen_random_uuid()` (verify PG version) | TASK-02 | Not Verified | — | — |
| REQ-D-017 | All time columns `TIMESTAMPTZ` (UTC); evidence rows store device time and server receipt time; server time ... | TASK-02 | Not Verified | — | — |
| REQ-N-001 | Material 3 theme built from the indigo-and-marigold design tokens; no hard-coded colours in screens | TASK-03 | Not Verified | — | — |
| REQ-N-002 | Typography scale; Anek (or Noto fallback) fonts bundled after licence/coverage check, only used weights | TASK-03 | Not Verified | — | — |
| REQ-N-003 | Spacing (4-pt), radii hierarchy, no card shadows, Material Symbols Rounded with labels, motion respects red... | TASK-03 | Not Verified | — | — |
| REQ-N-004 | Layouts work 320–480 px; > 480 centered at max 560; citizen flows portrait-locked, admin rotates | TASK-03 | Not Verified | — | — |
| REQ-N-005 | Touch targets ≥ 48×48; primary buttons full-width ≥ 56 tall, pinned above keyboard | TASK-03 | Not Verified | — | — |
| REQ-N-006 | Every screen works at the largest system text size; no fixed-height text containers | TASK-03 | Not Verified | — | — |
| REQ-N-007 | Screen-reader semantics: labels on all controls, photo descriptions, "Step n of N" announced, errors announced | TASK-03 | Not Verified | — | — |
| REQ-N-008 | Never colour alone: statuses, errors and selections always carry icon and/or text | TASK-03 | Not Verified | — | — |
| REQ-N-009 | Focus order follows visual order; focus moves to the error summary on failed submit | TASK-03 | Not Verified | — | — |
| REQ-N-010 | All user-facing strings in ARB files with code generation (English v1); layouts tolerate ~40% longer text | TASK-03 | Not Verified | — | — |
| REQ-N-011 | Dates/times shown in IST in device-locale format; phone shown as +91 98765 43210 | TASK-03 | Not Verified | — | — |
| REQ-N-012 | HTTP timeouts: 15 s JSON, 60 s photo uploads | TASK-03 | Not Verified | — | — |
| REQ-N-013 | `StepScaffold` "one decision per screen" layout with Back and "Step n of N" | TASK-03 | Not Verified | — | — |
| REQ-N-014 | Form validation on "Continue", then live re-validation; inline errors in `notFixed` colour with icon; share... | TASK-03 | Not Verified | — | — |
| REQ-N-015 | Loading patterns: skeletons for lists/category step, progress in buttons (disabled while sending), upload p... | TASK-03 | Not Verified | — | — |
| REQ-N-016 | Static checks pass with zero errors: TypeScript strict + ESLint; `dart analyze` with `flutter_lints`; `dart... | TASK-01 | Not Verified | — | — |
| REQ-N-017 | Performance targets checked by hand on a low-end Android phone (cold start ≤ 3 s, tap response < 100 ms, co... | TASK-10 | Not Verified | — | — |
| REQ-N-018 | Accessibility audit: TalkBack and VoiceOver run-through of report and verify, largest font, statuses readab... | TASK-10 | Not Verified | — | — |
| REQ-N-019 | Optional Vitest safety-net tests in §8.1 order (rates, idempotency, verify access, redaction, CSV, due boun... | TASK-10 | Not Verified | — | — |
| REQ-N-020 | Shared component set: `StepScaffold`, `PrimaryButton`, `SecondaryButton`, `ChoiceCard`, `EvidencePhoto`, `S... | TASK-03 | Not Verified | — | — |
| REQ-N-021 | `BeforeAfterCard` signature component (full, compact thumbnail pair, citizen check variant) with status sta... | TASK-03 | Not Verified | — | — |
| REQ-N-022 | Flutter feature folders split `data` / `application` / `presentation`; screens never call the API directly | TASK-03 | Not Verified | — | — |
| REQ-N-023 | Backend layering: handlers parse/shape; services hold business rules; only services and storage touch Prism... | TASK-01 | Not Verified | — | — |
| REQ-S-001 | Admin passwords: Argon2id (bcrypt cost 12 fallback), ≥ 12 chars, reject the 10,000 most common passwords | TASK-05 | Not Verified | — | — |
| REQ-S-002 | Admin JWT HS256 (`JWT_SECRET` ≥ 32 bytes), claims `sub`,`tv`,`iat`,`exp`,`iss`,`aud`, 8 h expiry, no refres... | TASK-05 | Not Verified | — | — |
| REQ-S-003 | Login uses constant-time hash check and the same `INVALID_CREDENTIALS` for unknown email and wrong password... | TASK-05 | Not Verified | — | — |
| REQ-S-004 | Login rate limit 5 per IP + email per 15 min → 429 with Retry-After; no account lockout | TASK-05 | Not Verified | — | — |
| REQ-S-005 | Verify tokens: 32 CSPRNG bytes, URL-safe; only SHA-256 hex stored; raw token returned once in the reminder ... | TASK-06 | Not Verified | — | — |
| REQ-S-006 | Verify token travels only in `X-Verify-Token`, never in API URLs or logs; app holds it in memory only, neve... | TASK-07 | Not Verified | — | — |
| REQ-S-007 | Missing/unknown/malformed tokens get the same 401 `VERIFY_TOKEN_INVALID`; revoked/expired/anonymized → 410 ... | TASK-07 | Not Verified | — | — |
| REQ-S-008 | Token scope: a verify token reaches only its own complaint; verification photos record `uploaded_for_compla... | TASK-07 | Not Verified | — | — |
| REQ-S-009 | Every admin endpoint requires a valid admin JWT (authorization matrix §3.3) | TASK-05 | Not Verified | — | — |
| REQ-S-010 | Server photo pipeline: multipart size limit before buffering, JPEG magic-byte check, decode + re-encode, al... | TASK-04 | Not Verified | — | — |
| REQ-S-011 | Storage interface (save/open/delete/exists) with local driver; opaque server keys `photos/<yyyy>/<mm>/<uuid... | TASK-04 | Not Verified | — | — |
| REQ-S-012 | Photos only streamed through the API: report photo to admin JWT or the same complaint's verify token; verif... | TASK-08 | Not Verified | — | — |
| REQ-S-013 | Logger redaction: `Authorization`, `X-Verify-Token`, `password`, `phone`, `phoneE164`, `note` removed; bodi... | TASK-01 | Not Verified | — | — |
| REQ-S-014 | Event properties never contain phone numbers, tokens, invite codes, coordinates or notes; unknown names/pro... | TASK-03 | Not Verified | — | — |
| REQ-S-015 | Every request schema-validated (Zod candidate) before business logic; unknown fields stripped/rejected; onl... | TASK-01 | Not Verified | — | — |
| REQ-S-016 | JSON body limit 64 KB | TASK-01 | Not Verified | — | — |
| REQ-S-017 | CSV export escapes values beginning with `=`, `+`, `-`, `@` | TASK-09 | Not Verified | — | — |
| REQ-S-018 | Error responses never include stack traces, SQL, file paths or internal IDs (except request ID) | TASK-01 | Not Verified | — | — |
| REQ-S-019 | Security headers (helmet candidate): nosniff, frame deny, no referrer, CSP `default-src 'none'` | TASK-01 | Not Verified | — | — |
| REQ-S-020 | CORS disabled by default; `CORS_ORIGINS` may enable a local tool | TASK-01 | Not Verified | — | — |
| REQ-S-021 | Rate-limit middleware (in-memory, per IP or admin, 429 `RATE_LIMITED` + Retry-After, `warn` log) available ... | TASK-01 | Not Verified | — | — |
| REQ-S-022 | Rate limits: `/invite-codes/validate` 30/IP/h; `/events` 120/IP/min; `/health` + `/categories` 120/IP/min | TASK-03 | Not Verified | — | — |
| REQ-S-023 | Rate limits: `/photos` 60/IP/h; `/reports` 30/IP/h | TASK-04 | Not Verified | — | — |
| REQ-S-024 | Rate limits: `/verify/*` 60/IP/h (incl. `/verify/photos`) | TASK-07 | Not Verified | — | — |
| REQ-S-025 | Rate limit: admin endpoints 300/admin/min | TASK-05 | Not Verified | — | — |
| REQ-S-026 | Phone number exposure: never in logs, events, verify responses or list items; only in complaint detail and ... | TASK-06 | Not Verified | — | — |
| REQ-S-027 | Admin actions (reminder, exclusion, anonymization, export, category/invite-code change, logout-all) logged ... | TASK-05 | Not Verified | — | — |
| REQ-S-028 | Plain-HTTP exception only for the dev machine and only in Android debug / iOS Debug builds; absent from rel... | TASK-03 | Not Verified | — | — |
| REQ-S-029 | Admin JWT stored in platform secure storage (Keystore/Keychain) | TASK-05 | Not Verified | — | — |
| REQ-S-030 | Secrets only in git-ignored `.env`; committed `.env.example` files; secrets generated with CSPRNG; app ship... | TASK-01 | Not Verified | — | — |
| REQ-S-031 | Photo files stored outside the repository (`PHOTO_STORAGE_DIR`) | TASK-04 | Not Verified | — | — |
| REQ-S-032 | PostgreSQL bound to 127.0.0.1 only; API bound to `API_HOST` for LAN phones | TASK-01 | Not Verified | — | — |
| REQ-S-033 | Consent: `consentGivenAt` required and `consentTextVersion` must be in `CONSENT_TEXT_VERSIONS` | TASK-04 | Not Verified | — | — |
| REQ-S-034 | `deviceCapturedAt` no more than 10 min ahead of server time (reports and verifications) | TASK-04 | Not Verified | — | — |
| REQ-S-035 | Shared phone rule (app + API): strip spaces/dashes/+91/0/91 → 10 digits starting 6–9 → E.164; CCRS normaliz... | TASK-04 | Not Verified | — | — |
| REQ-S-036 | Dependency audit before shared builds: `npm audit --audit-level=high`, `flutter pub outdated`; Dependabot a... | TASK-10 | Not Verified | — | — |
| REQ-O-001 | Repo layout `apps/api`, `apps/mobile`, `infra`, `docs`; `.gitignore` | TASK-01 | Not Verified | — | — |
| REQ-O-002 | `infra/docker-compose.yml`: one `db` service, pinned postgres major, `127.0.0.1:5432`, volume `pgdata`, `pg... | TASK-01 | Not Verified | — | — |
| REQ-O-003 | API validates all env vars of 05 §2.2 at startup and exits with a clear message when missing/invalid | TASK-01 | Not Verified | — | — |
| REQ-O-004 | Root scripts `db:up`, `db:down`, `api:dev` | TASK-01 | Not Verified | — | — |
| REQ-O-005 | Root scripts `db:migrate`, `db:seed`, and `db:reset` (refuses unless `APP_ENV=development`, asks for confir... | TASK-02 | Not Verified | — | — |
| REQ-O-006 | `GET /health` returns `{status, db}`; 503 `SERVICE_UNAVAILABLE` when the database is unreachable | TASK-01 | Not Verified | — | — |
| REQ-O-007 | Structured JSON logger (levels used per §9.2); request ID accepted from header or generated, returned in a ... | TASK-01 | Not Verified | — | — |
| REQ-O-008 | Uniform error response `{error:{code,message,details?,requestId}}` and the full error-code table | TASK-01 | Not Verified | — | — |
| REQ-O-009 | GitHub Actions: path-filtered API job (install, `prisma generate`, `tsc --noEmit`, ESLint) and mobile job (... | TASK-01 | Not Verified | — | — |
| REQ-O-010 | Optional weekly `npm audit --audit-level=high` workflow (notification only) | TASK-01 | Not Verified | — | — |
| REQ-O-011 | Flutter build config via `--dart-define` (`APP_ENV`, `API_BASE_URL`, `DEEP_LINK_SCHEME`, `CCRS_WEB_URL`, `C... | TASK-03 | Not Verified | — | — |
| REQ-O-012 | `saarthee` URL scheme registered (Android intent filter, iOS URL type); link firing documented for emulator... | TASK-07 | Not Verified | — | — |
| REQ-O-013 | Camera and location permissions declared with plain-language usage strings (Android manifest, iOS Info.plist) | TASK-04 | Not Verified | — | — |
| REQ-O-014 | Full loop works on a physical low-end Android phone (LAN `API_BASE_URL`) and on iOS simulator + iPhone | TASK-10 | Not Verified | — | — |
| REQ-O-015 | Deep link tested from a real WhatsApp message; if not tappable, manual code entry confirmed; result recorded | TASK-10 | Not Verified | — | — |
| REQ-O-016 | Manual release checklist (06 §12.3) passes on both phones; S1/S2 bugs fixed | TASK-10 | Not Verified | — | — |
| REQ-O-017 | Optional rotating local log file kept ≤ 14 days | TASK-01 | Not Verified | — | — |
| REQ-O-018 | Express app built separately from the server entry point that listens | TASK-01 | Not Verified | — | — |
| REQ-O-019 | `pg_dump` before risky migrations documented (backups outside the project, never committed) | TASK-02 | Not Verified | — | — |
| REQ-O-020 | Deviations from the spec recorded in the affected document's Decisions & Assumptions table | TASK-10 | Not Verified | — | — |
| REQ-O-021 | Git repository initialised, pushed to GitHub, spec docs in `docs/`, no `.env` committed | TASK-01 | Not Verified | — | — |
| REQ-O-023 | Feature-coverage verification layer: every active requirement in this registry is verified against the runn... | TASK-10 | Not Verified | — | — |
