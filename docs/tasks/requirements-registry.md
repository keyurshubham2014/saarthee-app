# Requirements Registry — Saarthee (Ahmedabad Civic Accountability)

**Last Updated:** 2026-10-03
**Total Requirements:** 182 — **Active:** 177 — **Covered:** 177 — **Uncovered:** 0 — **Deferred:** 5

Active by category: Functional 79 · Data 17 · Non-functional 23 · Security 36 · Operational 22

IDs are sequential per prefix and never reused; REQ-O-022 sits in the Deferred table, so the next operational ID after it is REQ-O-023.

ID prefixes: `REQ-F` functional · `REQ-D` data · `REQ-N` non-functional ·
`REQ-S` security · `REQ-O` operational

Source references use the spec file and section number, e.g. `03 §4.1` = `docs/03-backend-spec.md` section 4.1.
Each row has exactly one primary task. A second task is listed only where it explicitly verifies the requirement system-wide (TASK-10).

## Functional

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-F-001 | Welcome screen with the two-sentence purpose and independence notice on first launch | 02 §4.1 | P0 | TASK-03 |
| REQ-F-002 | A random install ID (UUID) is generated and stored on first launch | 02 §4.1, 03 §2.1 | P0 | TASK-03 |
| REQ-F-003 | Invite code screen: uppercase letters/digits 6–20, validates via API, stores code and group label locally, shows "You're part of {groupLabel}", handles invalid/offline states, emits `invite_code_entered {valid}` | 02 §4.2 | P0 | TASK-03 |
| REQ-F-004 | `POST /invite-codes/validate` returns `{valid, groupLabel}`; case-insensitive lookup; inactive or unknown → 404 `INVITE_CODE_INVALID` | 03 §2.2 | P0 | TASK-03 |
| REQ-F-005 | "I don't have a code" skips to Home with no code stored | 02 §4.2 | P0 | TASK-03 |
| REQ-F-006 | "Change group code" from About re-runs the invite screen | 02 §4.2 | P1 | TASK-03 |
| REQ-F-007 | Home: independence notice, "Record a complaint" (or "Continue your report" when a draft exists), "Answer a follow-up", About link | 02 §4.3, §3.3 | P0 | TASK-03 |
| REQ-F-008 | About screen: about, privacy, independence and the operator login link (admin entry not on Home) | 02 §3.1, §3.2 | P0 | TASK-03 |
| REQ-F-009 | `POST /events` accepts batches of ≤ 50, keeps only allow-listed names and properties, returns 202 `{accepted}` | 03 §2.2, §11 | P0 | TASK-03 |
| REQ-F-010 | App event queue: flush at 20 events, on background, every 60 s; capped at 500 (oldest dropped); drops instead of retrying forever on 429 | 02 §7, 03 §10 | P0 | TASK-03 |
| REQ-F-011 | Global error handler: uncaught errors show "Something went wrong" with "Go home"; never clears the report draft | 02 §9.1 | P0 | TASK-03 |
| REQ-F-012 | API errors converted to a typed app error by backend `code`; messages come from ARB keyed by code; rate-limit messages show the Retry-After wait | 02 §5.3, §9.2 | P0 | TASK-03 |
| REQ-F-013 | Offline banner "You're offline. Your answers are saved." with retry where relevant | 02 §9.2, §4.3 | P0 | TASK-03 |
| REQ-F-014 | `GET /categories` returns active categories in sort order; app caches per session and keeps the last list for offline display | 03 §2.2, 02 §4.4 | P0 | TASK-04 |
| REQ-F-015 | Report step 1 (category): single-select `ChoiceCard`s; a new draft gets a `clientSubmissionId`; emits `report_opened` | 02 §4.4 | P0 | TASK-04 |
| REQ-F-016 | Report step 2 (file with AMC): open CCRS web, AMC WhatsApp, call 155303 (values from config); shows chosen category; emits `ccrs_handoff_clicked {target}` | 02 §4.5 | P0 | TASK-04 |
| REQ-F-017 | Report step 3: CCRS number, required, 1–50 chars after trim, spaces/dashes allowed | 02 §4.6, 03 §4.2 | P0 | TASK-04 |
| REQ-F-018 | Report step 4: camera-only capture with GPS position, accuracy and capture time; location rationale; denied → "Open settings" and step cannot complete; weak GPS (> 50 m) warning with retry/continue | 02 §4.7 | P0 | TASK-04 |
| REQ-F-019 | On-device compression: long edge ≤ 1,600 px, JPEG ~q80; original not kept | 02 §8.2 | P0 | TASK-04 |
| REQ-F-020 | Background photo upload with progress; failure keeps photo and offers "Retry upload"; `PHOTO_UNUSABLE` at submit asks to retake | 02 §4.7 | P0 | TASK-04 |
| REQ-F-021 | `POST /photos` (multipart, `purpose=report`) returns 201 `{photoId}` | 03 §2.2, §2.3 | P0 | TASK-04 |
| REQ-F-022 | Report step 5: phone field with fixed +91 and numeric keypad; consent checkbox with versioned text; "Why we ask" | 02 §4.8 | P0 | TASK-04 |
| REQ-F-023 | Report step 6: check-your-answers summary with "Change" links that return here; server errors shown in an error summary linking to steps | 02 §4.9, §6.2 | P0 | TASK-04 |
| REQ-F-024 | `POST /reports` implements the §4.1 workflow: normalize phone and CCRS number, resolve invite code, check category/photo, single transaction, `report_submitted` event | 03 §4.1 | P0 | TASK-04 |
| REQ-F-025 | Report submission is idempotent: same `clientSubmissionId` returns 200 with the existing complaint (201 first time), including concurrent duplicates | 03 §2.1, §4.1 | P0 | TASK-04 |
| REQ-F-026 | Unknown or inactive invite code at submission stores the report as `unknown` with no code and logs a warning — never rejected | 03 §4.1 | P0 | TASK-04 |
| REQ-F-027 | Duplicate CCRS numbers are flagged (`ccrs_duplicate_flag`), not rejected, and never returned to the citizen | 03 §4.1, 01 §9.1 | P0 | TASK-04 |
| REQ-F-028 | "Report recorded" confirmation screen with next-step copy and "Done" → Home | 02 §4.10 | P0 | TASK-04 |
| REQ-F-029 | Report draft (JSON + compressed photo file) persisted on every change and restored on the same step after the OS kills the app during the CCRS hand-off | 02 §4.5, §5.2, 07 B1 | P0 | TASK-04 |
| REQ-F-030 | The draft is deleted only after the server confirms the save (201/200) | 01 §9.1, 02 §4.9 | P0 | TASK-04 |
| REQ-F-031 | Every report step works offline except photo upload and final submit | 02 §9.4 | P0 | TASK-04 |
| REQ-F-032 | Home "Your reports on this phone" list from local storage only (CCRS number, category, date) | 02 §4.3 | P1 | TASK-04 |
| REQ-F-033 | Orphaned-photo cleanup script deletes files and rows for photos unattached for > `UNATTACHED_PHOTO_TTL_HOURS`; safe to re-run (`photos:cleanup`) | 03 §5.3 | P0 | TASK-04 |
| REQ-F-034 | Create-admin CLI (`admin:create`): prompts for password, never logs it, errors if email exists; reset mode re-hashes and increments `token_version` | 03 §5.3, 06 §2.1 | P0 | TASK-05 |
| REQ-F-035 | `POST /admin/auth/login` returns `{accessToken, expiresAt, admin}`; updates `last_login_at` | 03 §2.2, §3.1 | P0 | TASK-05 |
| REQ-F-036 | `GET /admin/me` returns the current admin | 03 §2.2 | P0 | TASK-05 |
| REQ-F-037 | `POST /admin/auth/logout-all` increments `token_version`, 204 | 03 §2.2, §3.2 | P1 | TASK-05 |
| REQ-F-038 | Operator login screen (from About): email, password with show/hide; stores token + expiry; handles `INVALID_CREDENTIALS`, `ADMIN_DISABLED`, `RATE_LIMITED` | 02 §4.17 | P0 | TASK-05 |
| REQ-F-039 | Admin tab shell: Due, All, Rates, More with a marigold count badge on Due; admin screens allow rotation | 02 §3.3, §2.2 | P0 | TASK-05 |
| REQ-F-040 | 401 (`TOKEN_EXPIRED`/`TOKEN_REVOKED`) on admin calls clears the token, shows "Your session ended…", redirects to login and returns to the original route | 02 §5.3, §9.2 | P0 | TASK-05 |
| REQ-F-041 | More tab: "Log out" (this device) and "Log out everywhere" | 02 §3.1, 07 C7 | P1 | TASK-05 |
| REQ-F-042 | `GET /admin/complaints` returns `ComplaintSummary` items with derived status, cursor paging (`limit` default 50, max 200, `nextCursor`), and the `due` filter | 03 §2.1, §2.2, §2.3 | P0 | TASK-06 |
| REQ-F-043 | "Due" rule: not excluded, not anonymized, no verification, and (no reminder and created > interval ago) or (last reminder > interval ago), using server time and `REMINDER_INTERVAL_DAYS` | 03 §4.3 | P0 | TASK-06 |
| REQ-F-044 | Due tab: item with before thumbnail, CCRS number, category, group label, days since filed/last reminder, reminder count; empty ("Nothing due. Nice."), loading, error, pull-to-refresh | 02 §4.18 | P0 | TASK-06 |
| REQ-F-045 | `POST /admin/complaints/{id}/reminders` creates a reminder and verify token; returns `{reminderId, sentAt, verifyLink, messageText, phoneE164}`; 409 for excluded/anonymized; `reminder_sent` event | 03 §4.4 | P0 | TASK-06 |
| REQ-F-046 | Reminder bottom sheet: message preview, "Open WhatsApp" (click-to-chat with phone + text), "Copy message" fallback | 02 §4.18, 01 §7.3 | P0 | TASK-06 |
| REQ-F-047 | Server-side reminder template (`REMINDER_TEMPLATE_VERSION=v1`, English) containing CCRS number, verify link and the "open the app and tap 'Answer a follow-up'" fallback line | 03 §4.4, 02 §4.18 | P0 | TASK-06 |
| REQ-F-048 | Deep link `saarthee://verify?t=<token>` opens verify entry (https-ready parsing); unparseable link → `/verify/enter-code` and `deep_link_failed {reason}` | 02 §3.1 | P0 | TASK-07 |
| REQ-F-049 | Manual verify code entry accepts the whole pasted link or just the code; records `deep_link_failed` for fallback use | 02 §4.12, 03 §11 | P0 | TASK-07 |
| REQ-F-050 | `GET /verify/complaint` returns `{complaintId, categoryName, ccrsNumber, reportedAt, hasPhoto, previousVerificationCount}` and records `verify_opened` | 03 §2.3, §4.5 | P0 | TASK-07 |
| REQ-F-051 | `GET /verify/complaint/photo` streams the original report photo for the token's complaint | 03 §2.2 | P0 | TASK-07 |
| REQ-F-052 | Verify entry screen: date, category, CCRS number, original photo; "answered before" note; invalid/revoked/offline states | 02 §4.11 | P0 | TASK-07 |
| REQ-F-053 | "Is it fixed?" screen with two `ChoiceCard`s (fixed / not fixed), no "partly" | 02 §4.13 | P0 | TASK-07 |
| REQ-F-054 | Verify photo step (same rules as report photo, original shown for framing) uploading to `POST /verify/photos` | 02 §4.14, 03 §4.5 | P0 | TASK-07 |
| REQ-F-055 | Optional note after "Not fixed" (≤ 1,000 chars with counter, Skip/Continue) | 02 §4.15 | P0 | TASK-07 |
| REQ-F-056 | Verify check-and-send with `BeforeAfterCard`, answer, note preview and Change links; "Thank you" screen | 02 §4.16 | P0 | TASK-07 |
| REQ-F-057 | `POST /verify/submissions`: idempotent by `clientSubmissionId`; one transaction inserts verification with `reminder_id`, attaches photo; records `verify_submitted {result}` | 03 §4.5 | P0 | TASK-07 |
| REQ-F-058 | Repeat verifications are stored as new rows; the latest drives status and H2 | 03 §4.5, 04 A5 | P0 | TASK-07 |
| REQ-F-059 | `distance_from_report_m` computed from report and verification coordinates at insert | 03 §4.5, 04 §3.7 | P1 | TASK-07 |
| REQ-F-060 | All complaints screen with filters (source, category, status, excluded, duplicate) via chips + sheet, infinite scroll by `nextCursor`, `StatusChip` | 02 §4.19, 03 §2.2 | P0 | TASK-08 |
| REQ-F-061 | `GET /admin/complaints/{id}` returns `ComplaintDetail` (complaint, phone, reminders, verifications) | 03 §2.2 | P0 | TASK-08 |
| REQ-F-062 | `GET /admin/complaints/{id}/photo` and `GET /admin/verifications/{id}/photo`; 410 `PHOTO_DELETED` after anonymization | 03 §2.2 | P0 | TASK-08 |
| REQ-F-063 | Complaint detail screen: full-width `BeforeAfterCard`, facts (CCRS + duplicate flag, category, source/group, server and device times, GPS/accuracy, phone tap-to-copy), reminders timeline, verifications list | 02 §4.20 | P0 | TASK-08 |
| REQ-F-064 | "Same image as report" warning (sha256 match) and distance highlight beyond `VERIFY_DISTANCE_WARN_M` (off when unset) | 03 §4.5, 02 §4.20 | P1 | TASK-08 |
| REQ-F-065 | `POST /admin/reminders/{id}/revoke` and the timeline "Revoke" action; revoked links stop working | 03 §2.2, 02 §4.20 | P0 | TASK-08 |
| REQ-F-066 | `PATCH /admin/complaints/{id}/exclusion` (reason required when excluding; re-include clears fields) with exclude sheet / "Include again"; `record_flagged` event | 03 §4.6, 02 §4.20 | P0 | TASK-08 |
| REQ-F-067 | `POST /admin/complaints/{id}/anonymize` with typed-CCRS confirm dialog: null phone, set `anonymized_at`, revoke all tokens (one transaction), then delete photo files and set `deleted_at` | 03 §4.6, 04 §9.3, 02 §4.20 | P0 | TASK-08 |
| REQ-F-068 | Cleanup script also retries failed anonymization file deletions | 03 §5.3 | P1 | TASK-08 |
| REQ-F-069 | "Send reminder" in the complaint detail action bar reuses the reminder sheet | 02 §4.20 | P0 | TASK-08 |
| REQ-F-070 | `GET /admin/rates` returns `{rows:[RateRow], computedAt}` from `pilot_rates_v` | 03 §4.7, §2.3 | P0 | TASK-06 |
| REQ-F-071 | Rates screen: "Trusted sources" card first, per-source rows (complaints, reminded, verified, H1 %, H2 %), exclusion/network note, "Too few answers…" when verified < 10 | 02 §4.21 | P0 | TASK-06 |
| REQ-F-072 | `GET /admin/export?type=complaints\|verifications\|reminders&includePhone=` CSV (phone off by default; derived status columns for complaints); each export logged without contents | 03 §4.6 | P0 | TASK-09 |
| REQ-F-073 | Export screen: type selector, "Include phone numbers" toggle (off, with warning), download and OS share sheet | 02 §4.22 | P0 | TASK-09 |
| REQ-F-074 | Invite code admin API: list with complaint counts, create (code generated if omitted; 409 `INVITE_CODE_TAKEN`), patch label/ward/active; source tag immutable | 03 §2.2 | P0 | TASK-09 |
| REQ-F-075 | Invite codes screen: list, "New code" form, deactivate, "Share" via OS share sheet ("Install the app and enter code {CODE}") | 02 §4.22 | P0 | TASK-09 |
| REQ-F-076 | Category admin API: list including inactive, create, patch (name, ccrsLabel, sortOrder, isActive); 409 on duplicate name | 03 §2.2 | P0 | TASK-09 |
| REQ-F-077 | Categories screen: drag-to-reorder, add, edit, deactivate; "Placeholder list" note | 02 §4.22 | P0 | TASK-09 |
| REQ-F-078 | More tab links to Invite codes, Categories and Export | 02 §3.1, §3.2 | P0 | TASK-09 |
| REQ-F-079 | Optional rates snapshot script prints `pilot_rates_v` to the console | 03 §5.3 | P2 | TASK-06 |

## Data

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-D-001 | All enum types: `source_tag`, `verification_result`, `photo_purpose`, `storage_driver`, `reminder_channel`, `exclusion_reason`, `platform` | 04 §3 | P0 | TASK-02 |
| REQ-D-002 | `admin_users` table with lowercase-unique email, `token_version ≥ 0`, audit columns | 04 §3.1 | P0 | TASK-02 |
| REQ-D-003 | `invite_codes` table: uppercase alnum 6–20 unique code, `source_tag` ≠ `unknown`, indexes | 04 §3.2 | P0 | TASK-02 |
| REQ-D-004 | `ccrs_categories` table with unique name, `sort_order ≥ 0`, `(is_active, sort_order)` index | 04 §3.3 | P0 | TASK-02 |
| REQ-D-005 | `photos` table with unique `storage_key`, sha256 index, partial unattached index, `uploaded_for_complaint_id` required when purpose = verification | 04 §3.4 | P0 | TASK-02 |
| REQ-D-006 | `complaints` table with all columns, CHECK constraints (coords, E.164 phone, exclusion reason rule), unique indexes and partial index | 04 §3.5 | P0 | TASK-02 |
| REQ-D-007 | `reminders` table with unique `token_hash`, `(complaint_id, sent_at DESC)` index | 04 §3.6 | P0 | TASK-02 |
| REQ-D-008 | `verifications` table with unique `client_submission_id` and `photo_id`, note ≤ 1,000, indexes | 04 §3.7 | P0 | TASK-02 |
| REQ-D-009 | `events` table with bigint identity PK and the three indexes | 04 §3.8 | P0 | TASK-02 |
| REQ-D-010 | Foreign keys with the on-delete/on-update rules of §4 (RESTRICT on evidence, SET NULL where listed) | 04 §4 | P0 | TASK-02 |
| REQ-D-011 | `complaint_status_v` view: counts, last reminder, latest result, derived status; due computed with the configured interval at query time | 04 §3.9, 03 §4.3 | P0 | TASK-02 |
| REQ-D-012 | `pilot_rates_v` view: per source + `trusted` (rwa + activist); H1 = verified ÷ reminded; H2 = latest-result `not_fixed` ÷ verified; excluded left out; nulls when denominator is 0 | 04 §3.9, 03 §2.3 | P0 | TASK-02 |
| REQ-D-013 | Migrations follow the §7.3 order and conventions; hand-written SQL (CHECKs, partial indexes, views, identity) commented with why | 04 §7 | P0 | TASK-02 |
| REQ-D-014 | Seed: dev admin from env, one invite code per source tag, placeholder categories, sample set covering every status (filed, reminded, verified fixed/not fixed, excluded, duplicate CCRS) | 04 §8 | P0 | TASK-02 |
| REQ-D-015 | Dev sample seed refuses to run unless `APP_ENV=development` and no real pilot data is present | 04 §8, 05 §2.2 | P0 | TASK-02 |
| REQ-D-016 | Prisma models PascalCase mapped to snake_case; UUID PKs via `gen_random_uuid()` (verify PG version) | 04 §1.2 | P0 | TASK-02 |
| REQ-D-017 | All time columns `TIMESTAMPTZ` (UTC); evidence rows store device time and server receipt time; server time authoritative | 04 §1.2, 01 Decision 9 | P0 | TASK-02 |

## Non-Functional

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-N-001 | Material 3 theme built from the indigo-and-marigold design tokens; no hard-coded colours in screens | 02 §2.1 | P0 | TASK-03 |
| REQ-N-002 | Typography scale; Anek (or Noto fallback) fonts bundled after licence/coverage check, only used weights | 02 §2.1, §8.2 | P0 | TASK-03 |
| REQ-N-003 | Spacing (4-pt), radii hierarchy, no card shadows, Material Symbols Rounded with labels, motion respects reduce-motion | 02 §2.1 | P1 | TASK-03 |
| REQ-N-004 | Layouts work 320–480 px; > 480 centered at max 560; citizen flows portrait-locked, admin rotates | 02 §2.2 | P0 | TASK-03 |
| REQ-N-005 | Touch targets ≥ 48×48; primary buttons full-width ≥ 56 tall, pinned above keyboard | 02 §2.3, §3.3 | P0 | TASK-03 |
| REQ-N-006 | Every screen works at the largest system text size; no fixed-height text containers | 02 §2.3 | P0 | TASK-03 |
| REQ-N-007 | Screen-reader semantics: labels on all controls, photo descriptions, "Step n of N" announced, errors announced | 02 §2.3 | P0 | TASK-03 |
| REQ-N-008 | Never colour alone: statuses, errors and selections always carry icon and/or text | 02 §2.1, §2.3 | P0 | TASK-03 |
| REQ-N-009 | Focus order follows visual order; focus moves to the error summary on failed submit | 02 §2.3 | P0 | TASK-03 |
| REQ-N-010 | All user-facing strings in ARB files with code generation (English v1); layouts tolerate ~40% longer text | 02 §2.4 | P0 | TASK-03 |
| REQ-N-011 | Dates/times shown in IST in device-locale format; phone shown as +91 98765 43210 | 02 §2.4 | P0 | TASK-03 |
| REQ-N-012 | HTTP timeouts: 15 s JSON, 60 s photo uploads | 02 §5.3 | P1 | TASK-03 |
| REQ-N-013 | `StepScaffold` "one decision per screen" layout with Back and "Step n of N" | 02 §2.0, §3.3 | P0 | TASK-03 |
| REQ-N-014 | Form validation on "Continue", then live re-validation; inline errors in `notFixed` colour with icon; shared validators | 02 §6 | P0 | TASK-03 |
| REQ-N-015 | Loading patterns: skeletons for lists/category step, progress in buttons (disabled while sending), upload progress bar, no full-screen spinner except verify entry | 02 §9.3 | P0 | TASK-03 |
| REQ-N-016 | Static checks pass with zero errors: TypeScript strict + ESLint; `dart analyze` with `flutter_lints`; `dart format` | 06 §7.2, 07 §7.1 | P0 | TASK-01 |
| REQ-N-017 | Performance targets checked by hand on a low-end Android phone (cold start ≤ 3 s, tap response < 100 ms, compression ≤ 2 s, 200–600 KB photos) | 02 §8.1, 06 §11 | P1 | TASK-10 |
| REQ-N-018 | Accessibility audit: TalkBack and VoiceOver run-through of report and verify, largest font, statuses readable in grayscale | 06 §10.1, 07 D6 | P1 | TASK-10 |
| REQ-N-019 | Optional Vitest safety-net tests in §8.1 order (rates, idempotency, verify access, redaction, CSV, due boundary) | 06 §8.1 | P2 | TASK-10 |
| REQ-N-020 | Shared component set: `StepScaffold`, `PrimaryButton`, `SecondaryButton`, `ChoiceCard`, `EvidencePhoto`, `StatusChip`, `ErrorSummary`, `InlineFieldError`, `IndependenceNotice`, `EmptyState`, `OfflineBanner` | 02 §1.3 | P0 | TASK-03 |
| REQ-N-021 | `BeforeAfterCard` signature component (full, compact thumbnail pair, citizen check variant) with status stamp; correct at 320 wide | 02 §2.5 | P0 | TASK-03 |
| REQ-N-022 | Flutter feature folders split `data` / `application` / `presentation`; screens never call the API directly | 02 §1.2 | P0 | TASK-03 |
| REQ-N-023 | Backend layering: handlers parse/shape; services hold business rules; only services and storage touch Prisma or the file system | 03 §1.2 | P0 | TASK-01 |

## Security

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-S-001 | Admin passwords: Argon2id (bcrypt cost 12 fallback), ≥ 12 chars, reject the 10,000 most common passwords | 06 §2.1 | P0 | TASK-05 |
| REQ-S-002 | Admin JWT HS256 (`JWT_SECRET` ≥ 32 bytes), claims `sub`,`tv`,`iat`,`exp`,`iss`,`aud`, 8 h expiry, no refresh; signature, expiry, issuer, audience, `token_version` and `is_active` checked on every request | 03 §3.2, 06 §2.2 | P0 | TASK-05 |
| REQ-S-003 | Login uses constant-time hash check and the same `INVALID_CREDENTIALS` for unknown email and wrong password; disabled → 403 `ADMIN_DISABLED`; bad logins logged with hashed email | 03 §3.1, §9.2 | P0 | TASK-05 |
| REQ-S-004 | Login rate limit 5 per IP + email per 15 min → 429 with Retry-After; no account lockout | 03 §10, 06 §2.1 | P0 | TASK-05 |
| REQ-S-005 | Verify tokens: 32 CSPRNG bytes, URL-safe; only SHA-256 hex stored; raw token returned once in the reminder response | 03 §3.2, 04 §2 | P0 | TASK-06 |
| REQ-S-006 | Verify token travels only in `X-Verify-Token`, never in API URLs or logs; app holds it in memory only, never on disk | 03 §2.1, 02 §3.1, §5.1 | P0 | TASK-07 |
| REQ-S-007 | Missing/unknown/malformed tokens get the same 401 `VERIFY_TOKEN_INVALID`; revoked/expired/anonymized → 410 `VERIFY_TOKEN_REVOKED` | 03 §3.1, §9.1 | P0 | TASK-07 |
| REQ-S-008 | Token scope: a verify token reaches only its own complaint; verification photos record `uploaded_for_complaint_id` and cannot be attached to another complaint | 03 §3.3, §4.5 | P0 | TASK-07 |
| REQ-S-009 | Every admin endpoint requires a valid admin JWT (authorization matrix §3.3) | 03 §3.3 | P0 | TASK-05 |
| REQ-S-010 | Server photo pipeline: multipart size limit before buffering, JPEG magic-byte check, decode + re-encode, all metadata stripped, downscale to `PHOTO_MAX_EDGE_PX`, SHA-256 of stored bytes | 03 §8.2 | P0 | TASK-04 |
| REQ-S-011 | Storage interface (save/open/delete/exists) with local driver; opaque server keys `photos/<yyyy>/<mm>/<uuid>.jpg`; refuses keys resolving outside `PHOTO_STORAGE_DIR`; delete of missing key succeeds | 03 §6.1 | P0 | TASK-04 |
| REQ-S-012 | Photos only streamed through the API: report photo to admin JWT or the same complaint's verify token; verification photos admin-only | 03 §8.3 | P0 | TASK-08 |
| REQ-S-013 | Logger redaction: `Authorization`, `X-Verify-Token`, `password`, `phone`, `phoneE164`, `note` removed; bodies never logged; routes logged by template | 03 §9.2 | P0 | TASK-01 |
| REQ-S-014 | Event properties never contain phone numbers, tokens, invite codes, coordinates or notes; unknown names/properties ignored | 03 §11, 04 §3.8 | P0 | TASK-03 |
| REQ-S-015 | Every request schema-validated (Zod candidate) before business logic; unknown fields stripped/rejected; only parameterized SQL | 06 §3.1 | P0 | TASK-01 |
| REQ-S-016 | JSON body limit 64 KB | 06 §3.1 | P0 | TASK-01 |
| REQ-S-017 | CSV export escapes values beginning with `=`, `+`, `-`, `@` | 06 §3.1 | P0 | TASK-09 |
| REQ-S-018 | Error responses never include stack traces, SQL, file paths or internal IDs (except request ID) | 06 §3.1 | P0 | TASK-01 |
| REQ-S-019 | Security headers (helmet candidate): nosniff, frame deny, no referrer, CSP `default-src 'none'` | 06 §3.4 | P0 | TASK-01 |
| REQ-S-020 | CORS disabled by default; `CORS_ORIGINS` may enable a local tool | 06 §3.2 | P0 | TASK-01 |
| REQ-S-021 | Rate-limit middleware (in-memory, per IP or admin, 429 `RATE_LIMITED` + Retry-After, `warn` log) available to all modules | 03 §10 | P0 | TASK-01 |
| REQ-S-022 | Rate limits: `/invite-codes/validate` 30/IP/h; `/events` 120/IP/min; `/health` + `/categories` 120/IP/min | 03 §10 | P0 | TASK-03 |
| REQ-S-023 | Rate limits: `/photos` 60/IP/h; `/reports` 30/IP/h | 03 §10 | P0 | TASK-04 |
| REQ-S-024 | Rate limits: `/verify/*` 60/IP/h (incl. `/verify/photos`) | 03 §10 | P0 | TASK-07 |
| REQ-S-025 | Rate limit: admin endpoints 300/admin/min | 03 §10 | P0 | TASK-05 |
| REQ-S-026 | Phone number exposure: never in logs, events, verify responses or list items; only in complaint detail and reminder response; CSV only with `includePhone=true` | 06 §4.2, 03 §2.3 | P0 | TASK-06 (primary), TASK-10 (verification) |
| REQ-S-027 | Admin actions (reminder, exclusion, anonymization, export, category/invite-code change, logout-all) logged at `info` with admin ID and target ID | 03 §9.2, 06 T11 | P0 | TASK-05 (primary), TASK-10 (verification) |
| REQ-S-028 | Plain-HTTP exception only for the dev machine and only in Android debug / iOS Debug builds; absent from release builds | 05 §4.6, 06 §4.1 | P0 | TASK-03 |
| REQ-S-029 | Admin JWT stored in platform secure storage (Keystore/Keychain) | 06 §2.2, 02 §5.2 | P0 | TASK-05 |
| REQ-S-030 | Secrets only in git-ignored `.env`; committed `.env.example` files; secrets generated with CSPRNG; app ships no secrets | 06 §5.2, 05 §2.3 | P0 | TASK-01 |
| REQ-S-031 | Photo files stored outside the repository (`PHOTO_STORAGE_DIR`) | 05 D9, 05 §2.2 | P0 | TASK-04 |
| REQ-S-032 | PostgreSQL bound to 127.0.0.1 only; API bound to `API_HOST` for LAN phones | 05 §3.2, D8 | P0 | TASK-01 |
| REQ-S-033 | Consent: `consentGivenAt` required and `consentTextVersion` must be in `CONSENT_TEXT_VERSIONS` | 03 §2.3, §4.2 | P0 | TASK-04 |
| REQ-S-034 | `deviceCapturedAt` no more than 10 min ahead of server time (reports and verifications) | 03 §4.2 | P0 | TASK-04 |
| REQ-S-035 | Shared phone rule (app + API): strip spaces/dashes/+91/0/91 → 10 digits starting 6–9 → E.164; CCRS normalization (uppercase, no spaces/dashes) | 03 §4.2, 02 §6.2 | P0 | TASK-04 |
| REQ-S-036 | Dependency audit before shared builds: `npm audit --audit-level=high`, `flutter pub outdated`; Dependabot alerts on | 06 §5.3 | P1 | TASK-10 |

## Operational

| Req ID | Requirement | Source | Priority | Covered By |
|---|---|---|---|---|
| REQ-O-001 | Repo layout `apps/api`, `apps/mobile`, `infra`, `docs`; `.gitignore` | 05 D4, 07 A1 | P0 | TASK-01 |
| REQ-O-002 | `infra/docker-compose.yml`: one `db` service, pinned postgres major, `127.0.0.1:5432`, volume `pgdata`, `pg_isready` health check, `unless-stopped`, creds from `infra/.env` | 05 §3.2, §3.3 | P0 | TASK-01 |
| REQ-O-003 | API validates all env vars of 05 §2.2 at startup and exits with a clear message when missing/invalid | 05 §2.2, 03 §1.2 | P0 | TASK-01 |
| REQ-O-004 | Root scripts `db:up`, `db:down`, `api:dev` | 05 §3.3 | P0 | TASK-01 |
| REQ-O-005 | Root scripts `db:migrate`, `db:seed`, and `db:reset` (refuses unless `APP_ENV=development`, asks for confirmation) | 05 §3.3 | P0 | TASK-02 |
| REQ-O-006 | `GET /health` returns `{status, db}`; 503 `SERVICE_UNAVAILABLE` when the database is unreachable | 03 §2.2, §9.1 | P0 | TASK-01 |
| REQ-O-007 | Structured JSON logger (levels used per §9.2); request ID accepted from header or generated, returned in a header and in `error.requestId`; one info line per request | 03 §9.2 | P0 | TASK-01 |
| REQ-O-008 | Uniform error response `{error:{code,message,details?,requestId}}` and the full error-code table | 03 §2.1, §9.1 | P0 | TASK-01 |
| REQ-O-009 | GitHub Actions: path-filtered API job (install, `prisma generate`, `tsc --noEmit`, ESLint) and mobile job (`flutter pub get`, `dart format` check, `dart analyze`) | 05 §4.1, §4.2 | P0 | TASK-01 |
| REQ-O-010 | Optional weekly `npm audit --audit-level=high` workflow (notification only) | 05 §4.2 | P2 | TASK-01 |
| REQ-O-011 | Flutter build config via `--dart-define` (`APP_ENV`, `API_BASE_URL`, `DEEP_LINK_SCHEME`, `CCRS_WEB_URL`, `CCRS_WHATSAPP_NUMBER`, `AMC_HELPLINE`) plus committed run configurations per target | 05 §2.2, 01 §9.3 | P0 | TASK-03 |
| REQ-O-012 | `saarthee` URL scheme registered (Android intent filter, iOS URL type); link firing documented for emulator/simulator | 05 §4.6 | P0 | TASK-07 |
| REQ-O-013 | Camera and location permissions declared with plain-language usage strings (Android manifest, iOS Info.plist) | 05 §4.6, 02 §4.7 | P0 | TASK-04 |
| REQ-O-014 | Full loop works on a physical low-end Android phone (LAN `API_BASE_URL`) and on iOS simulator + iPhone | 05 §4.5–4.6, 07 E1–E2 | P0 | TASK-10 |
| REQ-O-015 | Deep link tested from a real WhatsApp message; if not tappable, manual code entry confirmed; result recorded | 01 A14, 07 E3 | P0 | TASK-10 |
| REQ-O-016 | Manual release checklist (06 §12.3) passes on both phones; S1/S2 bugs fixed | 06 §12, 07 E5 | P0 | TASK-10 |
| REQ-O-017 | Optional rotating local log file kept ≤ 14 days | 05 §6.1, 06 §4.3 | P2 | TASK-01 |
| REQ-O-018 | Express app built separately from the server entry point that listens | 03 §1.2 | P0 | TASK-01 |
| REQ-O-019 | `pg_dump` before risky migrations documented (backups outside the project, never committed) | 05 §8, 04 §9.1 | P2 | TASK-02 |
| REQ-O-020 | Deviations from the spec recorded in the affected document's Decisions & Assumptions table | 07 §7.2 | P1 | TASK-10 |
| REQ-O-021 | Git repository initialised, pushed to GitHub, spec docs in `docs/`, no `.env` committed | 07 §2.2, A1 | P0 | TASK-01 |
| REQ-O-023 | Feature-coverage verification layer: every active requirement in this registry is verified against the running system and recorded (Pass / Fixed / Deferred-with-decision) in `docs/tasks/coverage-verification.md`; `check_coverage.py` reports 0 unverified | 07 §7.3, 06 §12 | P0 | TASK-10 |

## Deferred / Out of Scope

| Req ID | Requirement | Source | Reason | Decided by |
|---|---|---|---|---|
| REQ-O-022 | Deployment: hosting, managed PostgreSQL, HTTPS, App/Universal Links, Cloudflare storage, secret rotation, store listings | 05 §9, 07 Stage F | Spec defers deployment ("not planned yet"); local-only v1 | Spec 01 §5.2 / 05 §9 (founder, 2026-10-03) |
| REQ-N-024 | Gujarati and Hindi interface text | 01 §5.2, 02 §2.4 | Out of scope for v1; ARB readiness covered by REQ-N-010 | Spec 01 §5.2 (founder, 2026-10-03) |
| REQ-N-025 | Release build obfuscation and split debug info | 02 §8.2 | Release builds belong to deployment / store release (out of scope) | Spec 01 §5.2 (founder, 2026-10-03) |
| REQ-S-037 | Block screenshots on Android admin screens showing phone numbers | 06 §2.3 | Marked P2 in spec | Spec 06 §2.3 |
| REQ-S-038 | Field-level encryption of `phone_e164` | 06 §4.1 | Marked P2 option in spec | Spec 06 §4.1 |
