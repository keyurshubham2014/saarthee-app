# TASK-08: Complaint Management — List, Detail, Exclusion & Anonymization

| Field | Value |
|---|---|
| Task ID | TASK-08 |
| Status | Not Started |
| Priority | P0 |
| Size | M |
| Depends On | TASK-07 |
| Blocks | TASK-10 |
| Requirement IDs | REQ-F-060, REQ-F-061, REQ-F-062, REQ-F-063, REQ-F-064, REQ-F-065, REQ-F-066, REQ-F-067, REQ-F-068, REQ-F-069, REQ-S-012 |
| Primary Spec Refs | 03-backend-spec.md §2.2, §2.3, §4.5, §4.6, §5.3, §8.3; 02-frontend-spec.md §4.19, §4.20, §2.5, §9.2; 04-database-design.md §3.5, §9.3 |
| Last Updated | 2026-10-03 |

## 1. Objective

The operator can find any complaint through filters and open a full detail view. The detail shows the before/after photos, every fact, the reminder timeline and all verifications. From there the operator can send or revoke reminders, exclude or re-include a complaint, and remove its personal data. Photos stay protected: each one is only reachable by the people allowed to see it. At the end of this task the operator has everything needed to curate pilot data day to day (milestone M3, with TASK-09).

## 2. Scope

### In Scope
- **Admin complaint list filters:** complete and verify every filter on `GET /admin/complaints`: `source`, `categoryId`, `status`, `excluded` (`true`/`false`/`all`, default `false`) and `ccrsDuplicate`. TASK-06 built the endpoint with `due` and cursor paging.
- **All complaints tab** (`/admin/complaints`): filter chips plus a bottom sheet, infinite scroll by `nextCursor`, `StatusChip`, and compact before/after thumbnails.
- **`GET /admin/complaints/{id}`:** returns `ComplaintDetail`. This is the only list/detail surface that carries the phone number.
- **Admin photo endpoints:**
  - `GET /admin/complaints/{id}/photo`: complete it (TASK-06 may have a minimal version), including 410 `PHOTO_DELETED`.
  - `GET /admin/verifications/{id}/photo`: new.
- **Photo access rules (REQ-S-012):** enforced across admin and verify endpoints.
- **Complaint detail screen** (`/admin/complaints/:id`) with:
  - full-width `BeforeAfterCard`;
  - same-image and distance warnings;
  - facts, with the phone number tap-to-copy;
  - reminders timeline with "Revoke";
  - verifications list;
  - bottom action bar.
- **Revoke reminder:** `POST /admin/reminders/{id}/revoke`.
- **Exclusion:** `PATCH /admin/complaints/{id}/exclusion` with the exclude sheet and "Include again". Emits the `record_flagged` event and writes an audit log line.
- **Anonymization:** `POST /admin/complaints/{id}/anonymize` behind a typed-CCRS confirmation dialog. Post-commit file deletion; failures are retried by `photos:cleanup`.
- **"Send reminder"** from the detail action bar, reusing the TASK-06 reminder sheet.

### Out of Scope
- Due list, reminder creation endpoint, reminder sheet and Rates screen: TASK-06 (reused here).
- Verify endpoints and the citizen flow: TASK-07.
- CSV export, invite-code and category management: TASK-09.
- Deletion-request policy and retention period (PRD Q9/Q11): open policy, not code.
- Screenshot blocking on admin screens: deferred (REQ-S-037).

## 3. Prerequisites
- TASK-07 complete. Seed data or a manual run produces complaints in every status, including:
  - filed;
  - reminded;
  - verified fixed and verified not fixed (with repeat answers);
  - excluded;
  - duplicate CCRS;
  - verifications with a same-image photo and with a large distance.
- An admin login works (TASK-05). The Rates tab works (TASK-06).
- `VERIFY_DISTANCE_WARN_M` env var exists. It is empty by default (feature off); set it to e.g. `100` locally to check the highlight.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-07 | Produces verifications (with `distance_from_report_m`, verification photos, `reminder_id`) that the detail view, verification photo endpoint and photo access rules depend on. It also provides the verify endpoints whose token scoping is re-checked here |

TASK-06 (list endpoint, reminder sheet, Rates), TASK-05 (JWT guard, admin shell) and TASK-04 (storage interface, cleanup script) are required transitively.

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-060 | All complaints screen with filters (source, category, status, excluded, duplicate) via chips + sheet, infinite scroll by `nextCursor`, `StatusChip` | 02 §4.19, 03 §2.2 |
| REQ-F-061 | `GET /admin/complaints/{id}` returns `ComplaintDetail` (complaint, phone, reminders, verifications) | 03 §2.2 |
| REQ-F-062 | `GET /admin/complaints/{id}/photo` and `GET /admin/verifications/{id}/photo`; 410 `PHOTO_DELETED` after anonymization | 03 §2.2 |
| REQ-F-063 | Complaint detail screen: full-width `BeforeAfterCard`, facts (CCRS + duplicate flag, category, source/group, server and device times, GPS/accuracy, phone tap-to-copy), reminders timeline, verifications list | 02 §4.20 |
| REQ-F-064 | "Same image as report" warning (sha256 match) and distance highlight beyond `VERIFY_DISTANCE_WARN_M` (off when unset) | 03 §4.5, 02 §4.20 |
| REQ-F-065 | `POST /admin/reminders/{id}/revoke` and the timeline "Revoke" action; revoked links stop working | 03 §2.2, 02 §4.20 |
| REQ-F-066 | `PATCH /admin/complaints/{id}/exclusion` (reason required when excluding; re-include clears fields) with exclude sheet / "Include again"; `record_flagged` event | 03 §4.6, 02 §4.20 |
| REQ-F-067 | `POST /admin/complaints/{id}/anonymize` with typed-CCRS confirm dialog: null phone, set `anonymized_at`, revoke all tokens (one transaction), then delete photo files and set `deleted_at` | 03 §4.6, 04 §9.3, 02 §4.20 |
| REQ-F-068 | Cleanup script also retries failed anonymization file deletions | 03 §5.3 |
| REQ-F-069 | "Send reminder" in the complaint detail action bar reuses the reminder sheet | 02 §4.20 |
| REQ-S-012 | Photos only streamed through the API: report photo to admin JWT or the same complaint's verify token; verification photos admin-only | 03 §8.3 |

### 5.2 Data Contracts
No schema changes. The tables come from TASK-02.

**`complaints` exclusion columns:**
| Column | Rule |
|---|---|
| `is_excluded` | — |
| `exclusion_reason` | `exclusion_reason` enum: `test`, `invalid`, `duplicate`, `other`. CHECK: required when `is_excluded` is true |
| `exclusion_note` | VARCHAR(500) |
| `excluded_by` | FK → `admin_users`, SET NULL |
| `excluded_at` | — |

- **Exclude** sets all five columns.
- **Re-include** sets `is_excluded=false` and clears the other four.

**`complaints` anonymization columns:**
- `phone_e164` is set to NULL.
- `anonymized_at` is set to the server time.
- Category, source tag, coordinates, timestamps and verification results are **kept** (04 §9.3).

**`reminders`:**
- Revoke sets `revoked_at = now()` on one row.
- Anonymize sets `revoked_at` on every reminder of the complaint where it is still null.

**`photos`:**
- After the anonymization transaction commits, the storage interface deletes each report and verification file of the complaint. Each successful delete sets `deleted_at`.
- A failed delete leaves `deleted_at` null and is logged at `error`.
- Retry selector: `photos` rows with `deleted_at IS NULL` that belong to a complaint with `anonymized_at IS NOT NULL`.

**Same-image check:**
- Computed at read time: verification `photos.sha256` = report `photos.sha256`.
- Uses `idx_photos_sha256`. Nothing is stored.

**Distance highlight:**
- Shown when `verifications.distance_from_report_m > VERIFY_DISTANCE_WARN_M`.
- The threshold is sent to the app only as a boolean per verification, so the app needs no config value.

**Indexes used:**
- `idx_complaints_source_created`, `idx_complaints_category` and `idx_complaints_included_created` for the filters;
- `idx_reminders_complaint_sent` and `idx_verifications_complaint_created` for the detail view.

### 5.3 API Contracts

All endpoints require `Authorization: Bearer <JWT>` (TASK-05 guard) and fall under the admin rate limit of 300 requests per admin per minute.

| Method | Path | Request | Response | Errors |
|---|---|---|---|---|
| GET | /admin/complaints | Query: `source` (source_tag), `categoryId` (UUID), `status` (`filed`\|`reminded`\|`verified_fixed`\|`verified_not_fixed`), `due` (bool), `excluded` (`true`\|`false`\|`all`, default `false`), `ccrsDuplicate` (bool), `cursor`, `limit` (1–200, default 50) | `{items:[ComplaintSummary], nextCursor}` | 400 `VALIDATION_FAILED`, 401 |
| GET | /admin/complaints/{id} | — | `ComplaintDetail` | 401, 404 `NOT_FOUND` |
| GET | /admin/complaints/{id}/photo | — | `image/jpeg` stream | 401, 404, 410 `PHOTO_DELETED` |
| GET | /admin/verifications/{id}/photo | — | `image/jpeg` stream | 401, 404, 410 `PHOTO_DELETED` |
| POST | /admin/reminders/{id}/revoke | — | 200 `{revokedAt}` | 401, 404 |
| PATCH | /admin/complaints/{id}/exclusion | `{isExcluded: bool, reason?: test\|invalid\|duplicate\|other, note?: string ≤ 500}` | `ComplaintSummary` | 400 (`reason` missing when excluding → "Choose a reason."), 401, 404 |
| POST | /admin/complaints/{id}/anonymize | `{confirm: true}` | 200 `{anonymizedAt}` | 400 (confirm missing/false), 401, 404 |

**ComplaintSummary** (03 §2.3; unchanged from TASK-06):

| Group | Fields |
|---|---|
| Core | `id`, `createdAt`, `sourceTag`, `categoryName`, `ccrsNumber`, `groupLabel`, `ccrsDuplicate` |
| Status | `status`, `isDue` |
| Reminders | `reminderCount`, `lastReminderAt` |
| Verifications | `verificationCount`, `latestResult`, `latestVerifiedAt` |
| Exclusion and anonymization | `isExcluded`, `exclusionReason`, `anonymized` |

**No phone number** in list items.

**ComplaintDetail.** Fields follow the sections of 02 §4.20. Exact naming is camelCase, mapped from 04 §3.5–§3.7.
- **Complaint:**
  - all ComplaintSummary fields;
  - `categoryId`, `inviteCodeId`, `ccrsNumberNormalized`;
  - `latitude`, `longitude`, `gpsAccuracyM`;
  - `deviceCapturedAt`, `consentGivenAt`, `consentTextVersion`;
  - `appPlatform`, `appVersion`;
  - `exclusionNote`, `excludedBy` (display name), `excludedAt`, `anonymizedAt`;
  - `phoneE164`: null after anonymization;
  - `hasPhoto`.
- **`reminders[]`:** `id`, `sentAt`, `sentBy` (display name), `channel`, `revokedAt`. **Never** the token or its hash.
- **`verifications[]`:**
  - `id`, `reminderId`, `result`, `createdAt`, `deviceCapturedAt`;
  - `latitude`, `longitude`, `gpsAccuracyM`, `distanceFromReportM`;
  - `distanceWarning` (bool: false when `VERIFY_DISTANCE_WARN_M` is empty);
  - `sameImageAsReport` (bool);
  - `note`, `hasPhoto`, `appPlatform`, `appVersion`.
  - Ordered newest first.

**Photo access rules (REQ-S-012, 03 §8.3):**

| Photo | Admin JWT | Verify token of the same complaint | Verify token of another complaint | No credentials |
|---|---|---|---|---|
| Report photo | ✅ `/admin/complaints/{id}/photo` | ✅ `/verify/complaint/photo` (TASK-07) | ❌ unreachable (complaint comes from the token) | ❌ 401 |
| Verification photo | ✅ `/admin/verifications/{id}/photo` | ❌ no verify endpoint serves it | ❌ | ❌ 401 |

Photos are always streamed through the storage interface `open`. There is no public URL, redirect or file path. A response for a deleted photo (`deleted_at` set) is 410 `PHOTO_DELETED`.

**Server side effects:**

| Action | Event | `info` audit log |
|---|---|---|
| Exclusion change | `record_flagged {isExcluded, reason}` (`complaint_id` column set) | admin ID, complaint ID, action |
| Revoke | none | admin ID, reminder ID |
| Anonymize | none | admin ID, complaint ID. File-delete failures → `error` with photo ID |

**Anonymize workflow** (03 §4.6):
1. Validate `{confirm:true}`.
2. In one transaction: `phone_e164 = NULL`, `anonymized_at = now()`, and revoke all reminders.
3. Commit.
4. For each report and verification photo: storage `delete(key)` (a missing key counts as success), then set `deleted_at`. Failure → `error` log and continue.
5. Return `{anonymizedAt}`.

After anonymization:
- `POST /admin/complaints/{id}/reminders` returns 409 `COMPLAINT_ANONYMIZED` (TASK-06 rule).
- Verify links for the complaint return 410 (TASK-07 guard).

### 5.4 UI Surfaces & States

**`/admin/complaints` (All tab, 02 §4.19):**
- Filter chips: Source, Category, Status, Excluded, Duplicate. Each opens a bottom sheet to set its value; active filters show on their chip.
- List items as in Due: compact `BeforeAfterCard` thumbnails (before only when unanswered), CCRS number, category, group label, plus a `StatusChip` (icon + word).
- Infinite scroll loads the next page from `nextCursor`. Pull to refresh.
- Refetches when the tab regains focus.

| State | What shows |
|---|---|
| Loading | Skeleton rows |
| Empty | "No complaints match these filters" with "Clear filters" |
| Error | Message with Retry |
| Load-more failure | Inline retry row at the list end |
| Unauthorized | 401 → login (TASK-05 behaviour) |

**`/admin/complaints/:id` (detail, 02 §4.20).** Sections, in order:
1. `BeforeAfterCard`, full width:
   - **before:** the admin report photo;
   - **after:** the latest verification photo;
   - **status stamp:** colour + icon + word.
   - Warning lines appear beneath: "Same image as report", and "Taken {n} m from the report location" when `distanceWarning`.
2. Facts:
   - CCRS number (with a "Duplicate" tag when flagged);
   - category, source tag and group label;
   - filed (server time, IST) and captured (device time, IST);
   - GPS with accuracy;
   - phone shown as `+91 98765 43210`, tap to copy (snackbar "Copied").
   - After anonymization, the phone row reads "Removed" and the photos show the "This photo was deleted." placeholder.
3. Reminders timeline: sent at, sent by, and a "Revoke" button on each active reminder (confirmation dialog). Revoked reminders show "Revoked {time}".
4. Verifications list: result `StatusChip`, time, photo thumbnail (tap to view full), note, distance.

Bottom action bar:
- "Send reminder": opens the TASK-06 reminder sheet; hidden or disabled with an explanation when the complaint is excluded or anonymized.
- "Exclude": opens a sheet with a reason radio list and a note field (≤ 500, with counter). If the complaint is already excluded, "Include again" (with confirmation) replaces it.
- Overflow → "Remove personal data": opens a confirmation dialog where the operator types the CCRS number. The confirm button stays disabled until the text matches the CCRS number exactly (trimmed). The dialog explains what is removed and what is kept.

| State | What shows |
|---|---|
| Loading | Skeleton |
| Error | Retry |
| 404 | "Complaint not found" + Back |
| Action in flight | Button progress; controls disabled |
| Success | Snackbar ("Excluded", "Included again", "Reminder revoked", "Personal data removed"), then a provider refresh |
| Failure | Error message keyed by backend code (ARB) |
| 401 | Login redirect, returning to this route |

The complaint lists and Rates are refreshed after exclusion or anonymization (no optimistic updates, 02 §5.3).

### 5.5 Permissions & Roles

| Action | Admin (JWT) | Citizen (token or none) | Unauthenticated result |
|---|---|---|---|
| List/filter complaints, read detail (incl. phone) | ✅ | ❌ | 401 |
| Read report or verification photo via admin endpoints | ✅ | ❌ | 401 |
| Revoke reminder | ✅ | ❌ | 401 |
| Exclude / include | ✅ | ❌ | 401 |
| Anonymize | ✅ | ❌ | 401 |

There is only one admin role, with no finer-grained permissions (03 §3.3). Every mutating endpoint is authorized server-side by the JWT guard. UI hiding is UX only.

### 5.6 Assumptions
- ASSUMPTION: `ComplaintDetail` field names are as listed in §5.3 — 03 §2.2 names the type without a field table, so fields are taken from 02 §4.20 sections and 04 §3.5–§3.7 columns — if the founder wants fewer fields, trim the response and screen together.
- ASSUMPTION: the distance threshold is evaluated server-side and returned as `distanceWarning` — keeps config on the server (`VERIFY_DISTANCE_WARN_M`) — if the app should evaluate it, expose the threshold in the response instead.
- ASSUMPTION: revoking an already-revoked reminder returns 200 with the original `revokedAt` (idempotent) — spec lists only 401/404 — if 409 is preferred, add a code.
- ASSUMPTION: anonymizing an already-anonymized complaint returns 200 with the original `anonymizedAt` and re-attempts any undeleted files — spec lists no conflict code — if 409 `COMPLAINT_ANONYMIZED` is preferred, change the status.
- ASSUMPTION: excluding an anonymized complaint is still allowed — exclusion affects rates only, not personal data — if not, return 409 `COMPLAINT_ANONYMIZED`.
- ASSUMPTION: the photo-retry selector is "photos linked to an anonymized complaint with `deleted_at IS NULL`" (report via `complaints.photo_id`, verification via `verifications.photo_id`) — no separate failure table exists in 04 — if one is wanted, add it in a new migration.

## 6. Implementation Steps

1. **Filter query.** Extend the `admin-complaints` service filter builder from TASK-06:
   - `source`, `categoryId`, `status` (from `complaint_status_v`), `ccrsDuplicate`, `excluded` (`true`/`false`/`all`, default `false`);
   - combined with `due` and the cursor;
   - parameterized SQL / Prisma only.
   Validate the query with Zod. An invalid enum value returns 400.
2. **`getDetail(id)`.** Load the complaint, its category, invite-code group label, reminders (newest first, with sender display name) and verifications (newest first). Compute:
   - `sameImageAsReport` via sha256 comparison;
   - `distanceWarning` from `VERIFY_DISTANCE_WARN_M` (add it to the config schema if TASK-01 did not; an empty value means off).
   Never select `token_hash`.
3. **Photo streaming helper.** One shared function `streamPhoto(photo)`:
   - missing → 404;
   - `deleted_at` set → 410 `PHOTO_DELETED`;
   - otherwise storage `open` → pipe with `Content-Type: image/jpeg`.
   Use it in `/admin/complaints/{id}/photo` (completing TASK-06's version) and the new `/admin/verifications/{id}/photo`.
4. **Access audit.** Confirm no verify route serves verification photos and the verify photo route derives the complaint only from the token (REQ-S-012). Add a comment at the router listing the matrix in §5.3.
5. **Revoke.** `POST /admin/reminders/{id}/revoke`: 404 if missing; set `revoked_at` if null; audit log.
6. **Exclusion.** `PATCH /admin/complaints/{id}/exclusion`:
   - Zod (`reason` required when `isExcluded`; note ≤ 500);
   - set or clear the five columns;
   - record the `record_flagged {isExcluded, reason}` event;
   - audit log;
   - return `ComplaintSummary`.
7. **Anonymize service.** Transaction (null phone, `anonymized_at`, revoke all reminders), then post-commit file deletes via storage `delete`, setting `deleted_at`. Log failures at `error` with photo IDs; audit log on success.
8. **Cleanup script.** Extend `scripts/photos-cleanup` (TASK-04) with a second pass that retries undeleted photos of anonymized complaints. It must stay safe to re-run and print a count per pass.
9. **API checks.** Run the manual API checks M-08-01…M-08-09 with curl before the app work.
10. **App data layer.** `features/admin/data`: `getComplaints(filter, cursor)`, `getDetail(id)`, `revokeReminder`, `setExclusion`, `anonymize`. Build photo URLs with the bearer header, using an image provider that sends `Authorization`.
11. **List provider.** `adminComplaintsProvider` (family by filter) with `loadMore` and `refresh`, plus an immutable filter model.
12. **All complaints screen.** Filter chips and bottom sheets (categories from `GET /categories` or the admin categories list, if TASK-09 already exists — otherwise the public list), list items with `StatusChip`, infinite scroll, and every state in §5.4.
13. **Detail provider.** `complaintDetailProvider` (family by ID) with `sendReminder`, `revokeReminder`, `setExclusion` and `anonymize`. After each action, refresh the detail, the lists and `ratesProvider`.
14. **Detail screen.** Sections and warnings, phone tap-to-copy (`Clipboard`), the deleted-photo placeholder, and the bottom action bar.
15. **Dialogs and sheets:**
    - exclude sheet (reason radio + note counter);
    - "Include again" confirmation;
    - revoke confirmation;
    - "Remove personal data" dialog with typed-CCRS matching. All destructive actions are confirmed.
16. **Reuse the reminder sheet.** Wire "Send reminder" to the TASK-06 sheet (shared widget, no copy). Show the 409 codes `COMPLAINT_EXCLUDED` and `COMPLAINT_ANONYMIZED` as ARB messages.
17. **Strings and semantics.** Add every string to ARB. Add semantics labels on warnings, chips, the photo pair and dialog fields. Allow admin screen rotation.
18. **Emulator walk-through.** Run M-08-10…M-08-16, including the revoked-link and anonymized-link checks in the citizen verify flow.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Filters return exactly the matching complaints
- **Given** seed data covering every source, status, an excluded complaint and a duplicate-CCRS complaint
- **When** `GET /admin/complaints` is called with each of `source=rwa`, `categoryId=<id>`, `status=verified_not_fixed`, `ccrsDuplicate=true`, `excluded=true`, `excluded=all`, and with no `excluded` parameter
- **Then** each response contains only matching items (checked against an SQL count); without `excluded` no excluded complaint appears; with `excluded=all` both appear; `status=bogus` returns 400 `VALIDATION_FAILED`

**AC-2** — All complaints tab filters and scrolls
- **Given** more complaints than one page (set `limit=5` in dev or seed more)
- **When** the operator applies filters via chips/sheet and scrolls to the end
- **Then** the list shows matching items with `StatusChip`s (icon + word) and loads further pages via `nextCursor` without duplicates; an impossible filter combination shows the empty state with "Clear filters"

**AC-3** — Detail returns all data; the phone appears only here
- **Given** a verified complaint with two reminders (one revoked) and two verifications
- **When** `GET /admin/complaints/{id}` is called
- **Then** the response includes `phoneE164`, both reminders with `revokedAt` where set (no token or hash), and both verifications newest first with distance and flags; the corresponding `ComplaintSummary` in the list has no phone field

**AC-4** — Detail screen shows every section
- **Given** the same complaint
- **When** the operator opens it from the All or Due tab
- **Then** the screen shows:
  - the full-width before/after card with the latest verification photo and status stamp;
  - facts with the duplicate tag (if flagged), IST times and GPS accuracy;
  - the phone formatted `+91 …` that copies on tap;
  - the reminder timeline;
  - the verifications list.

**AC-5** — Same-image and distance warnings
- **Given** a verification whose photo sha256 equals the report photo's, and another with `distance_from_report_m = 500`
- **When** the detail is viewed with `VERIFY_DISTANCE_WARN_M=100`, and again with it empty
- **Then** "Same image as report" shows for the first; the distance warning shows for the second only when the threshold is set

**AC-6** — Photo access is restricted per the matrix
- **Given** complaint A with a report and verification photo, an admin JWT, and verify tokens TA and TB
- **When** the photos are requested with each credential
- **Then**:
  - the admin gets both A photos (200 `image/jpeg`);
  - TA gets only A's report photo via `/verify/complaint/photo`;
  - TB cannot obtain any A photo;
  - no verify endpoint returns a verification photo;
  - requests without credentials get 401.

**AC-7** — Revoked reminder link stops working
- **Given** a reminder with an active link
- **When** the operator taps "Revoke" in the timeline and confirms
- **Then** the API returns `{revokedAt}`; the timeline shows "Revoked"; opening that link in the citizen app shows "This link is no longer active." (API 410); other reminders' links for the complaint still work

**AC-8** — Exclude and re-include change the rates
- **Given** a verified "not fixed" complaint from `rwa`, with the Rates values noted
- **When** the operator excludes it with reason `test` and a note, then later taps "Include again"
- **Then**:
  - after excluding, the five exclusion columns are set, a `record_flagged {isExcluded:true, reason:"test"}` event exists, the complaint disappears from the default list, the Due tab and the rates (the trusted and rwa rows drop accordingly), and an `info` log names the admin and complaint IDs;
  - after re-including, all columns clear and the rates return to their original values;
  - excluding without a reason returns 400 "Choose a reason."

**AC-9** — Anonymize removes personal data and keeps results
- **Given** a complaint with a phone, a report photo, two verification photos and an active reminder link
- **When** the operator chooses "Remove personal data", types the CCRS number (the button is disabled until it matches) and confirms
- **Then**:
  - `phone_e164` is null and `anonymized_at` is set;
  - every reminder has `revoked_at`;
  - all three files are gone from `PHOTO_STORAGE_DIR` and have `deleted_at`;
  - category, source, coordinates, timestamps and results remain;
  - admin photo endpoints return 410 `PHOTO_DELETED`;
  - the old verify link returns 410 in the app;
  - "Send reminder" returns 409 `COMPLAINT_ANONYMIZED`;
  - rates still count the complaint (anonymization doesn't exclude it).

**AC-10** — Failed file deletions are retried by the cleanup script
- **Given** an anonymization where one file delete failed (simulate by making the file read-only or its folder unwritable), leaving `deleted_at` null and an `error` log
- **When** the cause is removed and `npm run photos:cleanup` is run twice
- **Then** the first run deletes the file and sets `deleted_at`, reporting 1 retried; the second run reports 0 and succeeds

**AC-11** — Send reminder from the detail screen
- **Given** an included, non-anonymized complaint open in detail
- **When** the operator taps "Send reminder"
- **Then** the same reminder sheet as the Due tab opens with the message preview, "Open WhatsApp" and "Copy message", and the timeline shows the new reminder after the sheet closes; for an excluded complaint the action is unavailable, with the explanation "This complaint is excluded."

**AC → Requirement traceability**

| Requirement | ACs |
|---|---|
| REQ-F-060 | AC-1, AC-2 |
| REQ-F-061 | AC-3 |
| REQ-F-062 | AC-6, AC-9 |
| REQ-F-063 | AC-4 |
| REQ-F-064 | AC-5 |
| REQ-F-065 | AC-7 |
| REQ-F-066 | AC-8 |
| REQ-F-067 | AC-9 |
| REQ-F-068 | AC-10 |
| REQ-F-069 | AC-11 |
| REQ-S-012 | AC-6 |

### 7.2 Non-Functional Checklist

- [ ] All new endpoints validate params/body with Zod and return the standard error shape; enum or UUID errors return 400 with field `details`.
- [ ] Every endpoint in this task returns 401 without a JWT (checked with curl for all seven).
- [ ] List query uses parameterized filters only; one query per page (no N+1 when computing status, group label or thumbnails).
- [ ] Detail never contains `token_hash` or raw tokens; list items never contain the phone (grep the JSON).
- [ ] Audit `info` logs exist for revoke, exclusion and anonymization, with admin ID and target ID and no phone or note text.
- [ ] File-deletion failures log at `error` with the photo ID only.
- [ ] Anonymization DB changes happen in one transaction; a forced failure mid-transaction leaves the phone intact.
- [ ] All complaints list has loading, empty (with "Clear filters"), error, load-more-error and unauthorized states, each reachable.
- [ ] Detail has loading, error, 404, deleted-photo placeholder and in-flight states; buttons disable during actions (double tap → one request).
- [ ] Destructive actions (revoke, exclude, include again, remove personal data) all confirm; "Remove personal data" requires an exact typed CCRS number.
- [ ] Statuses and warnings use icon + text, not colour alone; `StatusChip` is readable in grayscale.
- [ ] Admin screens work in portrait and landscape, at 320 px width and at the largest text size.
- [ ] All strings in ARB; colours from theme tokens; `VERIFY_DISTANCE_WARN_M` from config, not hard-coded.

## 8. Validation & Testing

| Level | What to test | ACs proven |
|---|---|---|
| Static | `apps/api`: typecheck + ESLint; `apps/mobile`: `dart format --set-exit-if-changed .` + `dart analyze`: zero errors | All (precondition) |
| API manual | **M-08-01** For each filter in AC-1: `curl -H "Authorization: Bearer $JWT" "$API/admin/complaints?source=rwa&limit=200"` and compare item count with `SELECT count(*) FROM complaints WHERE source_tag='rwa' AND NOT is_excluded;`. Also `?status=bogus` → 400 | AC-1 |
| API manual | **M-08-02** `curl $API/admin/complaints/$ID` → contains `phoneE164`, reminders without `tokenHash`, verifications newest first; `curl $API/admin/complaints \| grep -c phone` → 0 | AC-3 |
| API manual | **M-08-03** Photo matrix: admin JWT on both admin photo endpoints → 200 `image/jpeg`; no auth → 401; `X-Verify-Token: $TA` on `/verify/complaint/photo` → A's report photo; `$TB` → B's photo only (compare sha256); confirm no verify route exists for verification photos (route list) | AC-6 |
| API manual | **M-08-04** Set the `VERIFY_DISTANCE_WARN_M=100` env var, restart, and get detail → `distanceWarning:true` for the 500 m verification; unset it → false; the same-image fixture shows `sameImageAsReport:true` | AC-5 |
| API manual | **M-08-05** `curl -X POST $API/admin/reminders/$RID/revoke` → `{revokedAt}`; `curl -H "X-Verify-Token: $T" $API/verify/complaint` → 410; another reminder's token → 200 | AC-7 |
| API manual | **M-08-06** `PATCH …/exclusion {"isExcluded":true}` → 400 "Choose a reason."; with `reason:"test", note` → 200; check the five columns, the `record_flagged` event and `GET /admin/rates` before/after; then `{"isExcluded":false}` → columns cleared, rates restored | AC-8 |
| DB manual | **M-08-07** Anonymize: `POST …/anonymize {"confirm":true}` → 200; `SELECT phone_e164, anonymized_at FROM complaints WHERE id=…`; `SELECT revoked_at FROM reminders WHERE complaint_id=…`; `SELECT deleted_at FROM photos WHERE …`; `ls $PHOTO_STORAGE_DIR/...` shows the files gone; admin photo → 410; old verify token → 410; `POST …/reminders` → 409 `COMPLAINT_ANONYMIZED`; `{}` body → 400 | AC-9 |
| DB manual | **M-08-08** Force one delete failure (`chmod 500` on the photo's folder), anonymize, check the `error` log and the null `deleted_at`; `chmod 700`, run `npm run photos:cleanup` twice → counts 1 then 0 | AC-10 |
| API manual | **M-08-09** All seven endpoints without `Authorization` → 401 | AC-6 (authz), §7.2 |
| App manual | **M-08-10** All tab: each chip filter; scroll past one page; impossible combination → empty state; airplane mode → error + retry | AC-2 |
| App manual | **M-08-11** Open detail: all sections, IST times, phone copy (paste elsewhere), duplicate tag, warnings with the env set | AC-4, AC-5 |
| App manual | **M-08-12** Revoke a reminder in the timeline → "Revoked"; fire that link on the emulator (adb, TASK-07 command) → "This link is no longer active." | AC-7 |
| App manual | **M-08-13** Exclude with reason and note → snackbar; complaint gone from the All (default) and Due tabs; Rates changed; "Include again" → restored | AC-8 |
| App manual | **M-08-14** "Remove personal data": the button stays disabled with a wrong CCRS number; correct → success; detail shows "Removed" and deleted-photo placeholders; old link rejected in the citizen flow | AC-9 |
| App manual | **M-08-15** "Send reminder" from detail → shared sheet; for an excluded complaint the action is unavailable with the explanation | AC-11 |
| App manual | **M-08-16** Rotate on detail and list; largest font; TalkBack on chips, warnings and the dialog | §7.2 |
| Optional automated | Not applicable — 06 §8.1 lists no test for this area; exclusion-in-rates is covered by optional test #1 scheduled in TASK-10 | — |

## 9. Deliverables
- Completed filtering on `GET /admin/complaints`.
- New endpoints:
  - `GET /admin/complaints/{id}`;
  - `GET /admin/verifications/{id}/photo`;
  - `POST /admin/reminders/{id}/revoke`;
  - `PATCH /admin/complaints/{id}/exclusion`;
  - `POST /admin/complaints/{id}/anonymize`.
- A completed `GET /admin/complaints/{id}/photo` and a shared photo streaming helper.
- `record_flagged` event and audit logging for revoke, exclusion and anonymization.
- `photos:cleanup` extended with the anonymization-retry pass.
- App:
  - All complaints tab with filters and paging;
  - complaint detail screen;
  - exclude sheet, include-again, revoke and remove-personal-data dialogs;
  - detail-screen reminder action.
- ARB strings.
- Manual check results M-08-01…M-08-16 recorded in the progress log and the coverage matrix.

## 10. Files Expected to Change

Prediction only. Exact paths follow the patterns from TASK-01 to TASK-07.

| Path | Change |
|---|---|
| `apps/api/src/modules/admin-complaints/` | Modified (filters, detail, exclusion, photo endpoints) |
| `apps/api/src/modules/reminders/` | Modified (revoke) |
| `apps/api/src/modules/anonymize/` | New |
| `apps/api/src/lib/storage/` or a shared photo-stream helper | Modified |
| `apps/api/src/config/` | Modified (`VERIFY_DISTANCE_WARN_M` if not yet present) |
| `apps/api/scripts/photos-cleanup.*` | Modified (retry pass) |
| `apps/mobile/lib/features/admin/data/` | Modified |
| `apps/mobile/lib/features/admin/application/` | Modified (list family, detail family) |
| `apps/mobile/lib/features/admin/presentation/complaints/` | New (All tab, filter sheets) |
| `apps/mobile/lib/features/admin/presentation/detail/` | New (detail, dialogs, sheets) |
| `apps/mobile/lib/router/` | Modified (`/admin/complaints/:id`) |
| `apps/mobile/lib/core/l10n/*.arb` | Modified |

## 11. Related Documentation
- `docs/03-backend-spec.md §2.2`: admin complaint, reminder, exclusion, anonymize and photo endpoint table.
- `docs/03-backend-spec.md §2.3`: `ComplaintSummary` shape; phone only in detail and reminder response.
- `docs/03-backend-spec.md §4.5`: same-image check and distance flag.
- `docs/03-backend-spec.md §4.6`: exclusion, anonymization (transaction then file deletion), audit logging.
- `docs/03-backend-spec.md §5.3`: cleanup script, including retry of failed deletions.
- `docs/03-backend-spec.md §8.3`: photo access rules.
- `docs/03-backend-spec.md §9.1`: `PHOTO_DELETED`, `COMPLAINT_EXCLUDED` and `COMPLAINT_ANONYMIZED` codes.
- `docs/04-database-design.md §3.5`: exclusion and anonymization columns and CHECK.
- `docs/04-database-design.md §3.9`: excluded complaints left out of rates.
- `docs/04-database-design.md §9.3`: anonymization procedure: what is removed and what is kept.
- `docs/02-frontend-spec.md §4.19, §4.20`: All complaints and detail screens.
- `docs/02-frontend-spec.md §2.5`: `BeforeAfterCard` full and compact.
- `docs/02-frontend-spec.md §9.2`: destructive-action confirmation and typed CCRS number.
- `docs/06-security-testing.md §4.2, §4.3`: personal-data exposure and the deletion process.

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Photo file deleted but DB transaction rolled back (or vice versa) | Data inconsistency | DB first, files after commit; failures logged and retried by cleanup (AC-10) |
| Anonymization removes evidence the founder later wants | Irreversible | Typed-CCRS confirmation; dialog lists what is removed; policy for use is open (PRD Q9) |
| Admin image loading leaks the JWT into image cache logs | Credential exposure | Use an image provider that sets the header; never put the JWT in a URL query |
| Status filter via view is slow with joins | Slow list | Pilot volume is tiny; indexes from 04 §5; single query per page |
| Filter state and cursor mismatch after a filter change | Duplicate or missing items | Reset the cursor whenever the filter changes; providers keyed by filter |
| Phone visible on an unlocked admin phone | Privacy | JWT 8 h expiry, screen-lock operating rule (06 §2.3); screenshot blocking deferred (REQ-S-037) |
| `ComplaintDetail` fields assumed (§5.6) | Rework if trimmed | Keep the mapping in one serializer |

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
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-08` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `TASK-08: …`
- [ ] Validator passes
