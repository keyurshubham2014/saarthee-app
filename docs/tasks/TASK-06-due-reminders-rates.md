# TASK-06: Due List, WhatsApp Reminders & Rates

| Field | Value |
|---|---|
| Task ID | TASK-06 |
| Status | Not Started |
| Priority | P0 |
| Size | M |
| Depends On | TASK-04, TASK-05 |
| Blocks | TASK-07 |
| Requirement IDs | REQ-F-042, REQ-F-043, REQ-F-044, REQ-F-045, REQ-F-046, REQ-F-047, REQ-F-070, REQ-F-071, REQ-F-079, REQ-S-005, REQ-S-026 |
| Primary Spec Refs | docs/03-backend-spec.md §2.2, §2.3, §4.3, §4.4, §4.7; docs/02-frontend-spec.md §4.18, §4.21; docs/04-database-design.md §3.6, §3.9 |
| Last Updated | 2026-10-03 |

## 1. Objective

The operator opens the Due tab, sees which complaints are due for a WhatsApp reminder, taps "Send reminder", and gets a ready-to-send message containing a fresh, unguessable verify link. They can then open WhatsApp or copy the message. The Rates tab shows H1 and H2 by source, with the trusted total first. After this task the operator side of the loop runs end to end. TASK-07 then lets citizens act on the link.

## 2. Scope

### In Scope
- `GET /admin/complaints` returning `ComplaintSummary` items with derived status from `complaint_status_v`, cursor paging, and the `due` filter. The other query params are parsed and validated now, because that is trivial with the same Zod schema.
- The "due" rule computed at query time with `REMINDER_INTERVAL_DAYS`.
- Minimal `GET /admin/complaints/{id}/photo` (report photo stream, admin JWT) so the Due list can show the "before" thumbnail. See §5.6.
- `POST /admin/complaints/{id}/reminders`: verify-token generation (hash stored), server-side message template v1, the `reminder_sent` event and an audit log line.
- `GET /admin/rates` reading `pilot_rates_v`.
- Optional `rates:snapshot` CLI script (P2).
- App: Due tab (list, states, pull-to-refresh, paging), "Send reminder" bottom sheet (Open WhatsApp / Copy message), Due badge count on the tab shell, and the Rates tab.
- Phone-exposure contract (REQ-S-026 primary): phone appears only in the reminder response, never in list items, events or logs.

### Out of Scope
- UI and verification of the other list filters (source, category, status, excluded, duplicate), the All complaints screen, complaint detail, the verification-photo endpoint, 410 `PHOTO_DELETED` handling and the revoke endpoint → TASK-08 (REQ-F-060…REQ-F-065 stay owned by TASK-08, including REQ-F-062).
- Verify endpoints and screens that consume the token → TASK-07.
- Exclusion/anonymization actions (only their effect on due/409 is checked here) → TASK-08.
- CSV export → TASK-09.
- `pilot_rates_v` / `complaint_status_v` SQL definitions → TASK-02 (consumed here).

## 3. Prerequisites

- TASK-02: `complaints`, `reminders`, `verifications`, `photos`, `events` tables; `complaint_status_v`, `pilot_rates_v` views; dev seed covering every status, with the documented hand-count of expected rates.
- TASK-04: complaints created through the app with stored photos (storage interface, `open` for reading).
- TASK-05: `requireAdmin` guard on `/admin`, admin rate limiter, `auditLog` helper, admin tab shell with a nullable Due-badge provider and placeholder Due/Rates bodies.
- Env vars validated at startup (TASK-01 config): `REMINDER_INTERVAL_DAYS` (default 7), `VERIFY_LINK_BASE` (`saarthee://verify?t=`), `REMINDER_TEMPLATE_VERSION` (`v1`).
- Candidate `url_launcher` and a clipboard API checked on pub.dev; WhatsApp installed on the test emulator/phone where possible.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-04 | Produces complaints and report photos that the Due list shows and reminders target |
| TASK-05 | Provides the admin JWT guard, admin rate limit, audit-log helper and the tab shell this task fills |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-042 | `GET /admin/complaints` returns `ComplaintSummary` items with derived status, cursor paging (`limit` default 50, max 200, `nextCursor`), and the `due` filter | 03 §2.1, §2.2, §2.3 |
| REQ-F-043 | "Due" rule: not excluded, not anonymized, no verification, and (no reminder and created > interval ago) or (last reminder > interval ago), using server time and `REMINDER_INTERVAL_DAYS` | 03 §4.3 |
| REQ-F-044 | Due tab: item with before thumbnail, CCRS number, category, group label, days since filed/last reminder, reminder count; empty ("Nothing due. Nice."), loading, error, pull-to-refresh | 02 §4.18 |
| REQ-F-045 | `POST /admin/complaints/{id}/reminders` creates a reminder and verify token; returns `{reminderId, sentAt, verifyLink, messageText, phoneE164}`; 409 for excluded/anonymized; `reminder_sent` event | 03 §4.4 |
| REQ-F-046 | Reminder bottom sheet: message preview, "Open WhatsApp" (click-to-chat with phone + text), "Copy message" fallback | 02 §4.18, 01 §7.3 |
| REQ-F-047 | Server-side reminder template (`REMINDER_TEMPLATE_VERSION=v1`, English) containing CCRS number, verify link and the "open the app and tap 'Answer a follow-up'" fallback line | 03 §4.4, 02 §4.18 |
| REQ-F-070 | `GET /admin/rates` returns `{rows:[RateRow], computedAt}` from `pilot_rates_v` | 03 §4.7, §2.3 |
| REQ-F-071 | Rates screen: "Trusted sources" card first, per-source rows (complaints, reminded, verified, H1 %, H2 %), exclusion/network note, "Too few answers…" when verified < 10 | 02 §4.21 |
| REQ-F-079 | Optional rates snapshot script prints `pilot_rates_v` to the console | 03 §5.3 |
| REQ-S-005 | Verify tokens: 32 CSPRNG bytes, URL-safe; only SHA-256 hex stored; raw token returned once in the reminder response | 03 §3.2, 04 §2 |
| REQ-S-026 | Phone number exposure: never in logs, events, verify responses or list items; only in complaint detail and reminder response; CSV only with `includePhone=true` | 06 §4.2, 03 §2.3 |

### 5.2 Data Contracts

Read: `complaint_status_v` (one row per complaint: id, source tag, created at, reminder count, last reminder time, verification count, latest result, derived status `filed` → `reminded` → `verified_fixed` / `verified_not_fixed`), joined to `complaints` (ccrs_number_raw, ccrs_duplicate_flag, category_id, invite_code_id, is_excluded, exclusion_reason, anonymized_at, photo_id), `ccrs_categories.name`, `invite_codes.group_label`; `pilot_rates_v` (04 §3.9).

Write `reminders` (04 §3.6): `complaint_id`, `token_hash` (CHAR(64), SHA-256 hex, UNIQUE), `channel='whatsapp_manual'`, `sent_by` (admin ID), `sent_at` (server NOW()), `expires_at=NULL` (no expiry, 04 A7), `revoked_at=NULL`.

Write `events`: `name='reminder_sent'`, `admin_user_id`, `complaint_id`, `source_tag`, `properties='{}'`, `occurred_at=received_at=now`. No phone, token or link in any column.

Due rule (03 §4.3), applied in the API query with the interval passed as a parameter (never string-built SQL):
- `is_excluded = false` AND `anonymized_at IS NULL` AND verification count = 0, AND
- (reminder count = 0 AND `created_at < now() - interval`) OR (`last_reminder_at < now() - interval`).
- No cap on reminders per complaint.

Rate definitions (04 §3.9), owned by the view, displayed unchanged: H1 = complaints with ≥ 1 verification ÷ complaints with ≥ 1 reminder; H2 = complaints whose latest verification is `not_fixed` ÷ complaints with ≥ 1 verification; excluded complaints left out; `trusted` = `rwa` + `activist`; null rate when the denominator is 0.

No migration in this task.

### 5.3 API Contracts

All under the TASK-05 `/admin` router (JWT required, 300/admin/min).

| Method | Endpoint | Request | Response | Errors |
|---|---|---|---|---|
| GET | /admin/complaints | Query: `source`, `categoryId`, `status`, `due` (true/false), `excluded` (true/false/all, default false), `ccrsDuplicate`, `cursor`, `limit` (default 50, max 200) | 200 `{items:[ComplaintSummary], nextCursor}` | 400 `VALIDATION_FAILED`, 401 |
| GET | /admin/complaints/{id}/photo | — | 200 `image/jpeg` stream via storage interface | 401, 404 `NOT_FOUND` |
| POST | /admin/complaints/{id}/reminders | — | 201 `{reminderId, sentAt, verifyLink, messageText, phoneE164}` | 401, 404, 409 `COMPLAINT_EXCLUDED`, 409 `COMPLAINT_ANONYMIZED` |
| GET | /admin/rates | — | 200 `{rows:[RateRow], computedAt}` | 401 |

`ComplaintSummary` (03 §2.3). **No phone field.**

| Field | Description |
|---|---|
| id, createdAt, sourceTag, categoryName, ccrsNumber | Core fields (`ccrsNumber` = `ccrs_number_raw`) |
| groupLabel | From invite code, or null |
| ccrsDuplicate | Duplicate flag |
| status | `filed`, `reminded`, `verified_fixed`, `verified_not_fixed` |
| isDue | Due rule above |
| reminderCount, lastReminderAt | — |
| verificationCount, latestResult, latestVerifiedAt | — |
| isExcluded, exclusionReason | — |
| anonymized | boolean |

Paging: sort `createdAt DESC, id DESC` (Due list may sort by oldest-due first; see §5.6); the cursor is an opaque base64 of `(sortKey, id)`. `nextCursor` is null on the last page. An invalid cursor returns 400.

`RateRow` (03 §2.3): `group` (source tag or `trusted`), `complaints`, `reminded`, `verified` (integers, excluded left out), `h1Rate` (number|null), `notFixed` (integer), `h2Rate` (number|null). Order returned: `trusted` first, then `rwa`, `activist`, `social`, `network`, `unknown`.

Reminder workflow (03 §4.4):
1. Load the complaint: 404 if missing, 409 `COMPLAINT_EXCLUDED` if excluded, 409 `COMPLAINT_ANONYMIZED` if anonymized.
2. Raw token = 32 bytes from `crypto.randomBytes`, base64url-encoded. Store `sha256(token)` hex in `reminders.token_hash`.
3. `verifyLink = VERIFY_LINK_BASE + token`.
4. `messageText` from template v1 (English):
   > "Hello! About a week ago you recorded AMC complaint {ccrsNumber} in our app. Has it been fixed? Tap to answer (less than a minute): {verifyLink}. If the link doesn't open, open the app and tap 'Answer a follow-up'. — Saarthee, an independent citizen project (not AMC)."
5. Record the `reminder_sent` event. Call `auditLog(req, 'reminder_created', complaintId)`.
6. Return the 201 body. The raw token exists only in this response and is never stored or logged. Logs must never contain `verifyLink`, `messageText` or `phoneE164`.

The template is selected by `REMINDER_TEMPLATE_VERSION`. An unknown version fails startup config validation.

### 5.4 UI Surfaces & States

| Surface | States |
|---|---|
| Due tab (`/admin`) | Loading: skeleton list items. Empty: `EmptyState` "Nothing due. Nice.". Error: message with Retry. Unauthorized: TASK-05 401 handling. Pull-to-refresh. Infinite scroll with `nextCursor`. Refresh on tab focus. |
| Due list item | Compact "before" thumbnail (`BeforeAfterCard` compact variant with only the before photo; due items have no verification). Thumbnail placeholder icon while loading or if the photo fails. CCRS number, category, group label (or "No group"), "Filed N days ago" or "Last reminder N days ago", reminder count. "Send reminder" button. |
| Send reminder | Button shows progress and is disabled in flight (double-tap creates one reminder). Success opens the bottom sheet. 409 shows "This complaint is excluded." or "This complaint's personal data was removed." and refreshes the list. Offline shows a banner with retry. |
| Reminder bottom sheet | Message preview (selectable text), recipient shown as +91 98765 43210 format. "Open WhatsApp" uses url_launcher with a click-to-chat URL built from `phoneE164` and URL-encoded `messageText` (format to verify, PRD Q8). If WhatsApp can't open, show a message and keep "Copy message" available. "Copy message" copies to the clipboard and shows a "Copied" snackbar. Closing the sheet refreshes the Due list. |
| Due badge | Count of due complaints on the Due tab icon (`marigold` fill, `ink` text). Hidden when 0. Refreshed with the list. |
| Rates tab (`/admin/rates`) | Loading skeleton cards. Error with Retry. Pull-to-refresh. "Trusted sources" card first, then one row per source: complaints, reminded, verified, H1 %, H2 % ("—" when null). Note under the card: "Excluded complaints aren't counted. Network (friends and family) is shown separately but isn't part of the trusted total." When verified < 10, the row shows "Too few answers to read much into yet". Shows `computedAt` in IST. |

All copy lives in ARB files. Admin screens rotate. Percentages are formatted with no more than one decimal place.

### 5.5 Permissions & Roles

| Action | Admin (JWT) | Citizen with verify token | Citizen (no token) |
|---|---|---|---|
| List complaints / due | ✅ | ❌ 401 | ❌ 401 |
| Report photo via admin endpoint | ✅ | ❌ 401 (uses `/verify/complaint/photo` in TASK-07) | ❌ 401 |
| Create reminder (sees phone once) | ✅ | ❌ 401 | ❌ 401 |
| Rates | ✅ | ❌ 401 | ❌ 401 |

### 5.6 Assumptions

- ASSUMPTION: This task implements `GET /admin/complaints/{id}/photo` minimally (stream the report photo, 404 when missing) so the Due thumbnail is real data. Rationale: it keeps the slice integrated with no placeholder. If wrong: show a placeholder until TASK-08. TASK-08 still owns REQ-F-062 (410 `PHOTO_DELETED`, the verification-photo endpoint, and verification).
- ASSUMPTION: The Due list is ordered oldest-due first (longest wait since filing or since the last reminder). Rationale: 02 §4.18 does not specify an order, and this order serves the operator. If wrong: switch to the default `createdAt DESC`.
- ASSUMPTION: The click-to-chat URL is `https://wa.me/<digits without +>?text=<urlencoded>`. Rationale: 02 §4.18 marks the format "to verify" (PRD Q8). If wrong: change the builder only. Record the verified format and whether pre-fill works in §13.
- ASSUMPTION: The Due badge count comes from the `due=true` query (a first page with `limit=200`, counting items). Rationale: the spec has no count endpoint, and pilot volume is small. If wrong: add a `total` field to the list response.
- ASSUMPTION: The "small sample" threshold (10 verified) applies per row. Rationale: 02 §4.21 says "when verified is under 10". If wrong: apply it to the trusted card only.
- ASSUMPTION: Filter params other than `due` are validated and applied in the query now, but their correctness is verified in TASK-08. If wrong: TASK-08 fixes them in place.

## 6. Implementation Steps

1. Add `REMINDER_INTERVAL_DAYS`, `VERIFY_LINK_BASE` and `REMINDER_TEMPLATE_VERSION` to the config schema if TASK-01 did not; reject unknown template versions at startup.
2. `src/lib/pagination`: cursor encode/decode (opaque base64url of sort key + id); invalid cursor → `VALIDATION_FAILED`.
3. `src/modules/admin-complaints` service `listComplaints(filters, cursor, limit)`: parameterized query over `complaint_status_v` joined to complaints/categories/invite codes. Due rule from §5.2 with the interval as a bound parameter. Map rows to `ComplaintSummary` through an explicit allow-list mapper with no phone field.
4. Zod schema for the query params (§5.3); handler returns `{items, nextCursor}`.
5. `GET /admin/complaints/{id}/photo`: look up `photo_id → storage_key`, stream via the storage interface `open` with `Content-Type: image/jpeg`; 404 when missing.
6. `src/lib/tokens`: `generateVerifyToken()` (32 bytes, base64url) and `hashVerifyToken(raw)` (SHA-256 hex). Reused by TASK-07 for lookup.
7. `src/modules/reminders` service `createReminder(adminId, complaintId)` per the §5.3 workflow: 404/409 checks, insert reminder with the hash, render template v1, insert the `reminder_sent` event, `auditLog('reminder_created', complaintId)`. Handler returns 201.
8. `src/modules/rates`: `GET /admin/rates` reads `pilot_rates_v` via Prisma's parameterized raw query, orders rows (trusted first), adds `computedAt`.
9. `scripts/rates-snapshot.*` + root script `rates:snapshot` (P2): prints the view as a console table.
10. Mount the routes under the `/admin` router (guard and limiter inherited).
11. Manual API verification of M-06-01…M-06-08 (§8), including log and event greps.
12. App `features/admin/data`: `AdminComplaintsRepository.list(filter, cursor)`, `photoUrl/bytes(id)` with the auth header, `RemindersRepository.create(id)`, `RatesRepository.get()`.
13. App `application`: `adminComplaintsProvider` family (filter `due=true` here) with `loadMore`/`refresh`; `dueCountProvider` feeding the TASK-05 badge slot; `ratesProvider` with `refresh`; a send-reminder action that refreshes the list and badge after success.
14. Due tab UI: replace the TASK-05 placeholder with the list, item widget (compact before thumbnail via authenticated image load), skeleton/empty/error states, pull-to-refresh and infinite scroll.
15. Reminder bottom sheet: preview, phone display format, "Open WhatsApp" (click-to-chat builder in `core/utils`, `canLaunchUrl` check, error fallback), and "Copy message" with a snackbar.
16. Rates tab UI: trusted card, source rows, null-safe percentages, note text, small-sample text, `computedAt` in IST, loading/error/pull-to-refresh.
17. Add all strings to ARB; run `tsc --noEmit`, ESLint, `dart analyze` and `dart format`.
18. Manual app verification M-06-09…M-06-13 on the emulator (and WhatsApp on a phone if available). Record the verified click-to-chat format in §13. Update the coverage matrix and task docs.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Complaint list with paging and summary shape
- **Given** the dev seed (every status present) and an admin token
- **When** `GET /admin/complaints?limit=2` is called, then repeated with each returned `nextCursor`
- **Then** each page has ≤ 2 `ComplaintSummary` items with all §5.3 fields, no item repeats or goes missing across pages, the last page has `nextCursor: null`, `limit=500` returns 400, and a garbage cursor returns 400

**AC-2** — Due rule boundaries
- **Given** `REMINDER_INTERVAL_DAYS=7` and complaints that are: created 8 days ago with no reminder; created 6 days ago; last reminded 8 days ago; last reminded 2 days ago; verified; excluded; anonymized
- **When** `GET /admin/complaints?due=true` is called
- **Then** only "created 8 days ago" and "last reminded 8 days ago" are returned with `isDue=true`, and changing the interval to 1 (restart) adds the 2-day and 6-day ones

**AC-3** — Due tab shows the list
- **Given** due complaints exist
- **When** the operator opens the Due tab
- **Then** skeletons show while loading, then items show the before thumbnail, CCRS number, category, group label, "Filed/Last reminder N days ago" and reminder count; the Due badge shows the due count; pull-to-refresh reloads; scrolling past 50 items loads the next page

**AC-4** — Due tab empty and error states
- **Given** no complaint is due, and separately the API is stopped
- **When** the Due tab loads
- **Then** it shows "Nothing due. Nice." with no badge, and with the API down it shows an error with Retry that recovers once the API is back

**AC-5** — Create a reminder
- **Given** a due complaint
- **When** `POST /admin/complaints/{id}/reminders` is called
- **Then** the response is 201 with `reminderId`, `sentAt`, `verifyLink` starting with `saarthee://verify?t=`, `messageText` matching template v1 with the complaint's CCRS number and the link plus the "Answer a follow-up" line, and `phoneE164`; a `reminders` row has `token_hash = sha256(token)`, `sent_by` = admin, `channel='whatsapp_manual'`; a `reminder_sent` event exists; an `info` audit line `reminder_created` names the admin and complaint

**AC-6** — Token is unguessable and never stored raw
- **Given** two reminders for the same complaint
- **When** their responses and the DB are inspected
- **Then** the two tokens differ, each decodes to 32 bytes (43 base64url chars), neither raw token appears in any DB column or log line, and only 64-char lowercase hex hashes are stored

**AC-7** — Reminders refused for excluded or anonymized complaints
- **Given** a complaint with `is_excluded=true`, and another with `anonymized_at` set
- **When** a reminder is requested for each
- **Then** they return 409 `COMPLAINT_EXCLUDED` and 409 `COMPLAINT_ANONYMIZED` respectively, and no reminder row or event is written

**AC-8** — Send reminder from the app
- **Given** the Due tab
- **When** the operator taps "Send reminder" (double-tapping quickly)
- **Then** exactly one reminder is created, the bottom sheet shows the message preview and the recipient as "+91 98765 43210"-style text, "Open WhatsApp" opens WhatsApp chat to that number with the text pre-filled (or shows an error if WhatsApp is missing), "Copy message" copies the full text with a "Copied" confirmation, and closing the sheet refreshes the list (the item leaves Due)

**AC-9** — Phone exposure contract
- **Given** reminders were just created via API and app
- **When** the list JSON, the `events` rows and the API log output are inspected for the test phone number (both `+91…` and 10-digit forms)
- **Then** the number appears only in the reminder responses: no `phone`/`phoneE164` field in any `ComplaintSummary`, no match in `events.properties` or any events column, and no match in the logs

**AC-10** — Rates endpoint matches the seed hand count
- **Given** the TASK-02 seed and its documented expected rate table
- **When** `GET /admin/rates` is called
- **Then** rows come back with `trusted` first, and for every row `complaints`, `reminded`, `verified`, `notFixed`, `h1Rate` and `h2Rate` equal the documented expectations; groups with zero reminded or verified have null rates; excluded seed complaints are not counted

**AC-11** — Rates screen
- **Given** the seed data
- **When** the operator opens the Rates tab
- **Then** the "Trusted sources" card appears first, then one row per source with complaints, reminded, verified, H1 % and H2 % ("—" for null), the exclusion/network note is shown, rows with verified < 10 show "Too few answers to read much into yet", and loading/error/pull-to-refresh behave like the Due tab

**AC-12** — Rates snapshot script (P2)
- **Given** the seeded database
- **When** `npm run rates:snapshot` is run
- **Then** it prints the same numbers as `GET /admin/rates` and exits 0

**AC-13** — Admin-only access
- **Given** no token
- **When** calling `GET /admin/complaints`, `GET /admin/complaints/{id}/photo`, `POST /admin/complaints/{id}/reminders` and `GET /admin/rates`
- **Then** each returns 401 and no reminder is created

| AC | Requirements |
|---|---|
| AC-1 | REQ-F-042 |
| AC-2 | REQ-F-043 |
| AC-3, AC-4 | REQ-F-044 |
| AC-5 | REQ-F-045, REQ-F-047 |
| AC-6 | REQ-S-005 |
| AC-7 | REQ-F-045 |
| AC-8 | REQ-F-046 |
| AC-9 | REQ-S-026 |
| AC-10 | REQ-F-070 |
| AC-11 | REQ-F-071 |
| AC-12 | REQ-F-079 |
| AC-13 | REQ-F-042, REQ-F-045, REQ-F-070 |

### 7.2 Non-Functional Checklist

- [ ] Query params validated with Zod; invalid `limit`, `status`, `source`, `excluded` or cursor → 400 `VALIDATION_FAILED` with `details`
- [ ] Interval and filters passed as bound parameters; no string-built SQL in the list or rates queries
- [ ] List query does not run one query per item (single query or fixed small number regardless of page size)
- [ ] `ComplaintSummary` produced by an explicit field mapper; serializer can never emit `phone_e164`
- [ ] Logs after reminder creation contain no token, `verifyLink`, `messageText` or phone (grep check)
- [ ] `VERIFY_LINK_BASE`, `REMINDER_INTERVAL_DAYS` and the template version come from config; no hard-coded link base in code or app
- [ ] Due and Rates tabs: loading, empty, error and session-ended states reachable; Send reminder disabled while in flight
- [ ] Status and badge not colour-only (count text); percentages readable at largest font and 320 px width; rotation works
- [ ] All strings (incl. note and small-sample copy) in ARB; times in IST
- [ ] Reuses TASK-05 guard/audit helper and TASK-03 widgets (`EmptyState`, `OfflineBanner`, `BeforeAfterCard` compact)

## 8. Validation & Testing

| Level | What to test | ACs proven |
|---|---|---|
| Static | `tsc --noEmit`, ESLint, `dart analyze`, `dart format --set-exit-if-changed` clean | — |
| API manual | **M-06-01** `curl -H "Authorization: Bearer $T" "$API/admin/complaints?limit=2"`, follow `nextCursor` to null; collect IDs → no duplicates, total = `SELECT count(*) FROM complaints WHERE NOT is_excluded`; `limit=500` and `cursor=zzz` → 400 | AC-1 |
| DB + API manual | **M-06-02** set up the seven boundary complaints with `UPDATE complaints SET created_at = now() - interval '8 days'` etc. (and reminders' `sent_at`); `?due=true` → expected two; restart with `REMINDER_INTERVAL_DAYS=1` → four | AC-2 |
| API + DB manual | **M-06-03** `curl -XPOST -H "Authorization: Bearer $T" $API/admin/complaints/$ID/reminders` → 201 body check; `SELECT token_hash, sent_by, channel FROM reminders WHERE id=…`; compare `printf %s "$TOKEN" \| shasum -a 256`; `SELECT name, admin_user_id FROM events ORDER BY id DESC LIMIT 1`; audit line in log | AC-5 |
| API + DB manual | **M-06-04** two reminders → tokens differ, length 43; `SELECT * FROM reminders` and `grep -r "$TOKEN"` over the log file and a `pg_dump --data-only` → no match | AC-6 |
| API manual | **M-06-05** reminder for excluded and anonymized seed complaints → 409 codes; `SELECT count(*) FROM reminders WHERE complaint_id IN (…)` unchanged | AC-7 |
| Privacy manual | **M-06-06** after M-06-03/04: `grep -E "98765|\+9198765" <api log>` → none; list JSON `jq '.items[] \| keys'` has no phone key; `SELECT * FROM events WHERE properties::text ~ '98765'` → 0 rows | AC-9 |
| API manual | **M-06-07** `GET /admin/rates` vs the TASK-02 expected-rates table (trusted, rwa, activist, social, network, unknown); `npm run rates:snapshot` prints the same | AC-10, AC-12 |
| API manual | **M-06-08** the four endpoints with no token → 401; reminder count unchanged | AC-13 |
| App manual | **M-06-09** Due tab: skeleton, items, badge count = API due count, pull-to-refresh, scroll paging (seed > 50 due rows, or temporarily `limit=5` in dev) | AC-3 |
| App manual | **M-06-10** reset seed so nothing is due → empty copy, no badge; stop API → error + Retry; start API → Retry recovers | AC-4 |
| App manual | **M-06-11** Send reminder with a fast double tap → one new row (SQL); sheet preview; Open WhatsApp on a device with WhatsApp (record URL format and whether pre-fill worked); emulator without WhatsApp → error + Copy works; paste shows the full text; close → list refreshes | AC-8 |
| App manual | **M-06-12** Rates tab: trusted first, numbers = M-06-07, "—" for nulls, note, small-sample copy, error/pull-to-refresh, 320 px + largest font | AC-11 |
| Optional automated | 06 §8.1 #1 rate calculation against a fixed dataset; #6 due calculation around the interval boundary (Vitest, optional, scheduled in TASK-10 REQ-N-019) | AC-2, AC-10 |

## 9. Deliverables

- `GET /admin/complaints` (summary, paging, due + parsed filters), minimal `GET /admin/complaints/{id}/photo`, `POST /admin/complaints/{id}/reminders`, `GET /admin/rates`.
- Verify-token generate/hash helpers in `src/lib/tokens`; pagination helper; reminder template v1.
- `rates:snapshot` script (P2).
- Flutter Due tab, reminder bottom sheet with WhatsApp/copy, Due badge count, Rates tab; repositories and providers.
- ARB strings; config additions in `.env.example`.
- §13 note of the verified WhatsApp click-to-chat format (PRD Q8 input).

## 10. Files Expected to Change

Prediction, not a constraint.

| Path | Change |
|---|---|
| `apps/api/src/modules/admin-complaints/` | New |
| `apps/api/src/modules/reminders/` (incl. `templates/v1`) | New |
| `apps/api/src/modules/rates/` | New |
| `apps/api/src/lib/pagination/`, `apps/api/src/lib/tokens/` (verify-token helpers) | New / Modified |
| `apps/api/src/app.*` (admin router mounts), `apps/api/src/config/` | Modified |
| `apps/api/scripts/rates-snapshot.*`, root `package.json`, `apps/api/.env.example` | New / Modified |
| `apps/mobile/lib/features/admin/data/` (complaints, reminders, rates repositories) | New |
| `apps/mobile/lib/features/admin/application/` (list, due count, rates providers) | New |
| `apps/mobile/lib/features/admin/presentation/` (Due tab, reminder sheet, Rates tab) | New / Modified (placeholders replaced) |
| `apps/mobile/lib/core/utils/` (click-to-chat builder, phone display) | Modified |
| `apps/mobile/lib/core/l10n/*.arb`, `apps/mobile/pubspec.yaml` (`url_launcher` candidate) | Modified |

## 11. Related Documentation

- `docs/03-backend-spec.md §2.1`: pagination and conventions. `§2.2`: admin complaint, reminder and rates endpoints. `§2.3`: `ComplaintSummary`, reminder response, `RateRow`.
- `docs/03-backend-spec.md §4.3`: due rule. `§4.4`: reminder workflow. `§4.7`: rates.
- `docs/03-backend-spec.md §3.2`: verify-token generation. `§9.2`: logging/redaction and admin action logs. `§11`: `reminder_sent` event.
- `docs/04-database-design.md §3.6`: reminders table. `§3.9`: views and H1/H2 definitions. `§2`: one token per reminder.
- `docs/02-frontend-spec.md §4.18`: Due tab, sheet and template. `§4.21`: Rates. `§2.5`: before/after card. `§5.2–§5.3`: providers and refresh rules.
- `docs/06-security-testing.md §4.2`: phone exposure rules. `§12.3`: rates hand count and log search checks.
- `docs/01-project-overview.md` Decision 6: a manual reminder counts as sent when tapped.

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| WhatsApp click-to-chat ignores pre-filled text or the custom-scheme link is not tappable | Operator workflow slower; H1 drop | "Copy message" fallback always present; record findings; TASK-10 tests a real WhatsApp message |
| Reminder counts as sent even if the operator never sends it (Decision 6) | Inflates the H1 denominator | Accepted in spec; operator guidance; visible reminder count |
| Due rule computed differently in view vs API | Wrong Due list | Due logic lives in one service query with the interval parameter; M-06-02 boundary check |
| Phone leaks via a generic serializer or error log | Privacy breach (S1) | Explicit mapper; logger redaction from TASK-01; M-06-06 grep |
| Seed expected-rate table missing or wrong in TASK-02 | AC-10 cannot be proven | Recompute by hand from the seed SQL; fix the TASK-02 doc if wrong |

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
- [ ] Assumptions documented and, where possible, confirmed (incl. verified WhatsApp click-to-chat format)
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-06` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `TASK-06: …`
- [ ] Validator passes
