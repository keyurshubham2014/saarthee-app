# TASK-09: CSV Export & Reference Data Management

| Field | Value |
|---|---|
| Task ID | TASK-09 |
| Status | Not Started |
| Priority | P1 |
| Size | M |
| Depends On | TASK-07 |
| Blocks | TASK-10 |
| Requirement IDs | REQ-F-072, REQ-F-073, REQ-F-074, REQ-F-075, REQ-F-076, REQ-F-077, REQ-F-078, REQ-S-017 |
| Primary Spec Refs | 03-backend-spec.md §2.2, 03-backend-spec.md §4.6, 02-frontend-spec.md §4.22, 06-security-testing.md §3.1 |
| Last Updated | 2026-10-03 |

## 1. Objective

The pilot operator can run the pilot's reference data and get data out of the app without touching SQL. At the end of this task the admin can:
- export complaints, verifications or reminders as a spreadsheet-safe CSV, with phone numbers left out unless they ask for them, and share the file from the phone;
- create, share, relabel and deactivate invite codes;
- add, edit, reorder and deactivate CCRS categories.

All of these are reached from the admin **More** tab.

## 2. Scope

### In Scope
- `GET /admin/export` for `type=complaints|verifications|reminders`, with `includePhone` defaulting to false and CSV formula-injection escaping. Each export is logged with the admin ID, type and `includePhone`, never its contents.
- Admin Export screen: type selector, an "Include phone numbers" toggle (off by default) with a warning, download, and the OS share sheet.
- Invite code admin API:
  - `GET /admin/invite-codes` with complaint counts;
  - `POST /admin/invite-codes`, which generates a code when none is given;
  - `PATCH /admin/invite-codes/{id}` for group label, ward hint and active flag. The source tag cannot be changed.
- Invite Codes screen: list, "New code" form, deactivate/activate, and "Share" through the OS share sheet.
- Category admin API: `GET /admin/categories` (including inactive), `POST`, and `PATCH` (name, ccrsLabel, sortOrder, isActive), with 409 on a duplicate name.
- Categories screen: drag-to-reorder (persisted as `sortOrder` patches), add, edit, deactivate/activate, and the "Placeholder list" note.
- More tab links to Invite codes, Categories and Export. The Log out entries already exist from TASK-05.
- Every change to invite codes or categories, and every export, is audit-logged at `info` with the admin ID and target ID.
- These behaviours are checked end to end in this task:
  - a deactivated category disappears from citizen `GET /categories`, but historical complaints keep their link;
  - a deactivated invite code returns `INVITE_CODE_INVALID` from validate, and reports submitted with it become `unknown` (the rule from TASK-04).

### Out of Scope
- Rates screen and `GET /admin/rates` belong to TASK-06.
- Complaint list, detail, exclusion and anonymization belong to TASK-08.
- Citizen `GET /categories` and `POST /invite-codes/validate` already exist (TASK-03, TASK-04). This task only verifies how they react to admin changes.
- Install links in the invite share message are deployment work (REQ-O-022, deferred).
- Deleting invite codes or categories. The spec offers only deactivation, and the RESTRICT foreign keys in 04 §4 block deletion.

## 3. Prerequisites

- TASK-07 is complete. Seed data and loop-created data now contain complaints, reminders and verifications in every state, so all three export types have rows.
- An admin can log in (TASK-05), and the More tab shell exists.
- Candidate library to verify on pub.dev before adding: `share_plus` (02 §1.1). It shares the CSV and the invite message. If CSV writing needs a library on the API side, check its maintenance first. Hand-written escaping is acceptable and keeps the escaping rule visible.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-07 | Verifications and reminders must exist for meaningful exports. Also brings in, transitively: the admin JWT guard, audit logging and the More tab (TASK-05); `complaint_status_v` and the derived status fields (TASK-02/06); the citizen category and invite flows whose behaviour this task changes (TASK-03/04) |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-072 | `GET /admin/export?type=complaints\|verifications\|reminders&includePhone=` returns a CSV. Phone numbers are off by default, complaints include derived status columns, and each export is logged without its contents | 03 §4.6 |
| REQ-F-073 | Export screen: type selector, "Include phone numbers" toggle (off, with warning), download and OS share sheet | 02 §4.22 |
| REQ-F-074 | Invite code admin API: list with complaint counts; create (code generated if omitted; 409 `INVITE_CODE_TAKEN`); patch label/ward/active. The source tag is immutable | 03 §2.2 |
| REQ-F-075 | Invite codes screen: list, "New code" form, deactivate, and "Share" via the OS share sheet ("Install the app and enter code {CODE}") | 02 §4.22 |
| REQ-F-076 | Category admin API: list including inactive, create, patch (name, ccrsLabel, sortOrder, isActive); 409 on a duplicate name | 03 §2.2 |
| REQ-F-077 | Categories screen: drag-to-reorder, add, edit, deactivate; "Placeholder list" note | 02 §4.22 |
| REQ-F-078 | More tab links to Invite codes, Categories and Export | 02 §3.1, §3.2 |
| REQ-S-017 | CSV export escapes values beginning with `=`, `+`, `-`, `@` | 06 §3.1 |

### 5.2 Data Contracts

No migration in this task. The tables come from TASK-02 (`docs/04-database-design.md §3`).

- `invite_codes` (04 §3.2):
  - `code` is VARCHAR(20), UNIQUE, uppercase letters and digits only, 6–20 characters, with case-insensitive lookup;
  - `source_tag` cannot be `unknown`;
  - other columns: `group_label` (VARCHAR 120, required), `ward_hint` (VARCHAR 50, nullable), `is_active`, `created_by` (FK admin, nullable), `created_at`, `updated_at`.
- `ccrs_categories` (04 §3.3):
  - `name` is VARCHAR(100), UNIQUE;
  - `ccrs_label` is VARCHAR(150), nullable;
  - `sort_order` is an INTEGER ≥ 0;
  - other columns: `is_active`, `created_at`, `updated_at`.
- Complaint counts per invite code come from `COUNT(complaints.id) GROUP BY invite_code_id`. A single aggregate query, not N+1.
- Export sources:
  - **complaints:** the `complaints` columns (04 §3.5) joined with category name, invite code group label and the derived fields from `complaint_status_v` (status, reminder count, last reminder time, verification count, latest result). `phone_e164` is included only when `includePhone=true`.
  - **verifications:** `verifications` columns (04 §3.7).
  - **reminders:** `reminders` columns (04 §3.6). `token_hash` is **never** exported (ASSUMPTION below).
  - Times are exported in UTC ISO 8601 (03 §2.1).

### 5.3 API Contracts

All routes are under `/api/v1` and require `Authorization: Bearer <JWT>` (admin guard from TASK-05). Errors use the standard shape `{error:{code,message,details?,requestId}}` (03 §2.1). The admin rate limit is 300 per admin per minute (TASK-05).

| Method | Endpoint | Request | Response | Error Codes |
|---|---|---|---|---|
| GET | /admin/export | Query: `type=complaints\|verifications\|reminders` (required), `includePhone=true\|false` (default false) | `200 text/csv`, `Content-Disposition: attachment; filename="saarthee-<type>-<yyyymmdd-hhmm>.csv"` | 400 `VALIDATION_FAILED`, 401 |
| GET | /admin/invite-codes | — | `{items:[InviteCode & {complaintCount}]}` | 401 |
| POST | /admin/invite-codes | `{code?, sourceTag, groupLabel, wardHint?}` | 201 `InviteCode` | 400, 401, 409 `INVITE_CODE_TAKEN` |
| PATCH | /admin/invite-codes/{id} | `{groupLabel?, wardHint?, isActive?}` | `InviteCode` | 400, 401, 404 |
| GET | /admin/categories | — | `{items:[Category]}` (including inactive, ordered by `sortOrder`, then name) | 401 |
| POST | /admin/categories | `{name, ccrsLabel?, sortOrder}` | 201 `Category` | 400, 401, 409 |
| PATCH | /admin/categories/{id} | `{name?, ccrsLabel?, sortOrder?, isActive?}` | `Category` | 400, 401, 404, 409 |

`InviteCode` is `{id, code, sourceTag, groupLabel, wardHint, isActive, createdAt}`. `Category` is `{id, name, ccrsLabel, sortOrder, isActive}`.

Validation rules (03 §4.2):
- Invite code: letters and digits only, 6–20 characters, unique ignoring case. The message is "That code is invalid or already in use." Codes are stored uppercase.
- `sourceTag` must be one of `rwa`, `activist`, `social`, `network`. `unknown` is rejected with 400.
- Category `name` is 1–100 characters after trimming. `sortOrder` is an integer ≥ 0.

Escaping (06 §3.1): any cell whose value begins with `=`, `+`, `-` or `@` is prefixed with a single quote `'`. All cells are then quoted RFC-4180 style: wrap in double quotes and double any embedded quotes. Embedded commas and newlines therefore cannot break columns.

### 5.4 UI Surfaces & States

| Screen (route) | Components | States |
|---|---|---|
| More tab (`/admin/more`) | List tiles: Invite codes, Categories, Export; existing Log out / Log out everywhere (TASK-05) | Default |
| Invite codes (`/admin/invite-codes`) | List: group label, `StatusChip`-style source tag, active state (icon + word), complaint count; "New code" FAB/button → form sheet (source tag picker, group label, optional ward hint, optional custom code); per-row "Deactivate"/"Activate", "Share" | Loading (skeleton rows); empty (`EmptyState` "No invite codes yet" + "New code"); error (retry); form field errors inline (`INVITE_CODE_TAKEN` on the code field); submitting (button progress, disabled); success snackbar; 401 → login (TASK-05 handler) |
| Categories (`/admin/categories`) | Placeholder note banner ("Placeholder list — replace with AMC's real categories"); reorderable list with drag handles (accessible "Move up/Move down" actions too); add/edit sheet (name, CCRS label, sort order); deactivate/activate toggle | Loading; empty; error; reorder saving (list disabled while patches are in flight; on failure revert the order + error); inline 409 duplicate-name error; success feedback |
| Export (`/admin/export`) | Type selector (`ChoiceCard`s: Complaints / Verifications / Reminders); "Include phone numbers" switch, off by default, warning "Only turn this on if you need to contact people. Don't share this file." shown when on; "Export" primary button | Default; downloading (button progress, disabled); error (message + retry); success → OS share sheet opens with the file |

All strings go in ARB files. Labels and touch targets follow the TASK-03 design system. Admin screens allow rotation (02 §2.2).

### 5.5 Permissions & Roles

| Action | Admin (JWT) | Citizen |
|---|---|---|
| Export CSV (with or without phone) | ✅ | ❌ 401 |
| List/create/patch invite codes | ✅ | ❌ 401 |
| List/create/patch categories (incl. inactive) | ✅ | ❌ 401 |

Each mutation and export writes an `info` audit log line: action, adminId, targetId (or export type + includePhone). No CSV contents, phone numbers or group-label free text appear in that line (03 §9.2).

### 5.6 Assumptions

- ASSUMPTION: A `PATCH /admin/invite-codes/{id}` body containing `sourceTag` is rejected with 400 `VALIDATION_FAILED` (`details: [{field:"sourceTag", issue:"cannot be changed; create a new code"}]`), not silently ignored. Rationale: 03 §2.2 says the source tag "cannot be changed", and a loud rejection keeps the attribution history unambiguous. If wrong, the strict schema becomes a strip-unknown schema.
- ASSUMPTION: A generated code is 8 uppercase characters from a CSPRNG over an alphabet without ambiguous characters (no 0/O/1/I). It is regenerated on collision. The spec only says "generated if left out". If wrong, adjust the length or alphabet.
- ASSUMPTION: The reminders export never includes `token_hash`, and no export includes `password_hash`. Hashes have no analysis value, and leaving them out follows minimisation (06 §4.2). If wrong, add the column.
- ASSUMPTION: Reordering sends one `PATCH sortOrder` per moved category, renumbered in steps of 10. There is no bulk-reorder endpoint in 03 §2.2. If wrong, add a bulk endpoint as a recorded deviation.
- ASSUMPTION: The `includePhone=true` export also prints the admin's phone-export warning in the log at `info`, with no phone numbers in it. If wrong, there is only one log line.

## 6. Implementation Steps

1. **Escaping utility (API).** Add `src/lib/csv`: a `toCsv(rows, columns)` that applies the 06 §3.1 formula escape (`=`, `+`, `-`, `@` → prefix `'`) and RFC-4180 quoting. Check the date, null and number formatting rules.
2. **Export service (`src/modules/export`).** One query per type:
   - complaints: join `complaint_status_v`, `ccrs_categories` and `invite_codes`;
   - verifications;
   - reminders.

   Define column lists as constants. Add `phone_e164` to the complaints columns only when `includePhone` is true. Read with Prisma parameterized queries (`$queryRaw` tagged template for the view join).
3. **Export route.** Add `GET /admin/export` with a Zod query schema: `type` enum required; `includePhone` boolean parsed from the string, default false. Stream `text/csv` with a `Content-Disposition` filename. Log at `info` `{action:"export", adminId, type, includePhone, rowCount}`, with no contents.
4. **Invite-code service (`src/modules/invite-codes`).**
   - List with complaint counts from one aggregate query.
   - Create: normalise the code to uppercase; validate the regex `^[A-Z0-9]{6,20}$`; reject `sourceTag=unknown`; generate a code if it is absent; on a unique violation (case-insensitive check before insert, plus a catch on P2002) return 409 `INVITE_CODE_TAKEN`. Set `created_by` to the admin.
   - Patch label, ward and active. Reject `sourceTag` (§5.6). Return 404 for an unknown id.
5. **Invite-code routes.** Strict Zod schemas. Audit log on create and patch (`invite_code.created`, `invite_code.updated` with the changed field names, not their values).
6. **Category service and routes (`src/modules/categories-admin`).**
   - List all categories ordered by `sortOrder`, then name.
   - Create and patch with name trim and length checks, plus `sortOrder ≥ 0`.
   - Duplicate name → 409. Use a `CONFLICT`-family code from the 03 §9.1 table: no specific code is listed there, so return HTTP 409 with `VALIDATION_FAILED`-style details on `name` and record the choice in the Progress log.
   - Audit-log every change.
7. **Confirm the citizen side reacts correctly. No changes are expected.** Confirm `GET /categories` filters `is_active = true` (TASK-04), `POST /invite-codes/validate` rejects inactive codes (TASK-03), and `POST /reports` stores an inactive code as `unknown` (TASK-04). Fix only if broken, and note it in the Progress log.
8. **App data layer.** Add `features/admin/data` repositories for export, invite codes and categories, using the shared API client (TASK-03). The export download writes the response bytes to a temporary file (path_provider candidate) named from `Content-Disposition`.
9. **Providers.** Add `inviteCodesProvider` and `adminCategoriesProvider` (create, update, refresh after each mutation, no optimistic updates — 02 §5.3), and an export notifier (idle → downloading → shared/error).
10. **More tab.** Add the three list tiles linking to `/admin/invite-codes`, `/admin/categories` and `/admin/export`. Register the routes behind the admin guard.
11. **Invite codes screen.** List, new-code sheet with field validation mirroring the server, deactivate/activate, and the Share action. Share uses share_plus with the ARB message "Install the app and enter code {CODE}". Implement all states from §5.4.
12. **Categories screen.**
    - Placeholder note banner.
    - Reorderable list. On drop, compute the new `sortOrder` values (steps of 10) and PATCH the changed rows sequentially with the list disabled. On any failure, revert and show an error.
    - Add/edit sheet and active toggle.
    - Accessible move actions for screen readers.
13. **Export screen.**
    - Type `ChoiceCard`s.
    - Phone toggle, off by default; the warning is visible when it is on.
    - "Export": download → open the OS share sheet with the CSV file.
    - Handle errors with retry.
    - Delete the temp file after sharing where the platform allows it.
14. **Strings and accessibility.** All copy goes into ARB files. Labels on toggles, drag handles and share buttons. Check at 320 px width and the largest text size.
15. **Static checks.** `tsc --noEmit`, ESLint, `dart analyze` and `dart format` are clean.
16. **Manual verification.** Run checks M-09-01…M-09-12 (§8). Record evidence in `coverage-verification.md` for the 8 requirements.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Complaints export leaves out phones by default
- **Given** at least one complaint with a phone number, and an admin JWT
- **When** the admin calls `GET /admin/export?type=complaints`
- **Then** the response is `200 text/csv` with a download filename, one row per complaint, and derived status columns (status, reminderCount, verificationCount, latestResult)
- **And** no phone column or phone value appears anywhere in the file

**AC-2** — Phone included only on explicit opt-in
- **Given** the same data
- **When** the admin calls `GET /admin/export?type=complaints&includePhone=true`
- **Then** the CSV contains a phone column with E.164 values
- **And** the API log has one `info` line with adminId, type and `includePhone:true`, and no CSV contents or phone numbers

**AC-3** — All three export types work and validate input
- **Given** an admin JWT
- **When** the admin requests `type=verifications`, `type=reminders`, and then `type=bogus`
- **Then** the first two return CSVs with one row per record (reminders without `token_hash`)
- **And** `type=bogus` returns 400 `VALIDATION_FAILED`, and a request without a JWT returns 401

**AC-4** — Formula injection is neutralised
- **Given** a verification note `=HYPERLINK("http://x")` and a CCRS number `+123`
- **When** the admin exports verifications and complaints and opens the files in Excel or Google Sheets
- **Then** both values show as literal text prefixed with `'`, and no formula runs
- **And** a value containing a comma, quote or newline stays inside its own cell

**AC-5** — Export screen downloads and shares
- **Given** the admin is on More → Export
- **When** they choose "Verifications", leave the phone toggle off and tap "Export"
- **Then** the button shows progress and is disabled until the OS share sheet opens with the CSV file
- **And** turning the toggle on shows the warning "Only turn this on if you need to contact people. Don't share this file."
- **And** a network failure shows an error with retry

**AC-6** — Create an invite code with or without a custom code
- **Given** an admin on the Invite codes screen
- **When** they create a code with source `rwa`, label "Sunrise RWA" and no code, and then another with custom code `sunrise2026`
- **Then** the first gets a generated uppercase code, the second is stored as `SUNRISE2026`, and both appear in the list with complaint count 0 and active status
- **And** creating `SUNRISE2026` again in any letter case returns 409 `INVITE_CODE_TAKEN`, shown inline as "That code is invalid or already in use."

**AC-7** — Source tag cannot be changed; label, ward and active can
- **Given** an existing invite code
- **When** the admin PATCHes `{groupLabel:"New label", wardHint:"Navrangpura"}`, then `{isActive:false}`, then `{sourceTag:"social"}`
- **Then** the first two succeed and are audit-logged
- **And** the third returns 400 `VALIDATION_FAILED` with the source tag unchanged in the database

**AC-8** — A deactivated invite code stops attributing
- **Given** code `SUNRISE2026` has been deactivated
- **When** a citizen enters it on the invite screen, and a report is submitted carrying that code
- **Then** validate returns 404 `INVITE_CODE_INVALID`
- **And** the report is stored with `source_tag = unknown` and no invite code, not rejected

**AC-9** — Share an invite code
- **Given** the invite code list is loaded
- **When** the admin taps "Share" on a code
- **Then** the OS share sheet opens with "Install the app and enter code {CODE}" with the real code filled in

**AC-10** — Manage categories
- **Given** an admin on the Categories screen with the placeholder note visible
- **When** they add "Stray cattle", rename it, and try to add a duplicate of an existing name
- **Then** the add and edit succeed and are audit-logged
- **And** the duplicate returns 409 and is shown inline on the name field

**AC-11** — Reorder and deactivate categories reach citizens
- **Given** active categories A, B, C in that order
- **When** the admin drags C to the top and deactivates B
- **Then** after refresh the admin list shows C, A, B with B marked inactive (icon + word)
- **And** citizen `GET /categories` returns C, A only
- **And** a historical complaint filed under B still shows category B in admin detail and exports

**AC-12** — More tab navigation and access control
- **Given** a logged-in admin
- **When** they open the More tab
- **Then** Invite codes, Categories and Export tiles open their screens
- **And** with an expired or revoked JWT, any of these API calls returns 401 and the app returns to login (TASK-05 handler)

**AC → Requirement traceability**

| AC | Requirements |
|---|---|
| AC-1, AC-2, AC-3 | REQ-F-072 |
| AC-4 | REQ-S-017 |
| AC-5 | REQ-F-073 |
| AC-6, AC-7, AC-8 | REQ-F-074 |
| AC-6, AC-9 | REQ-F-075 |
| AC-10, AC-11 | REQ-F-076, REQ-F-077 |
| AC-12 | REQ-F-078 |

### 7.2 Non-Functional Checklist

- [ ] All seven endpoints validate query/body with strict schemas; unknown fields rejected; errors use the standard shape with `requestId`
- [ ] Invite-code complaint counts come from one aggregate query (no N+1)
- [ ] Every create/patch/export writes one `info` audit line with adminId and targetId/type; no CSV contents, phones or notes in logs
- [ ] Phone column absent from every export unless `includePhone=true`; `token_hash`/`password_hash` never exported
- [ ] Invite codes, Categories and Export screens each have loading, empty (where a list), error-with-retry, in-flight (disabled button) and success states
- [ ] Reorder failure reverts the visible order and shows an error; no partial order is left unexplained
- [ ] Toggle, drag handles, share buttons and status markers have screen-reader labels; active/inactive shown with icon + word, not colour alone
- [ ] Screens usable at 320 px wide and the largest system text size; admin screens rotate
- [ ] All copy in ARB files; no colours outside the theme tokens
- [ ] Follows TASK-05/06 patterns: providers refetch after mutations, no optimistic updates, shared API client and error mapping

## 8. Validation & Testing

API base: `http://localhost:4000/api/v1`. `$JWT` is from `POST /admin/auth/login`.

| ID | Level | What to test | Proves |
|---|---|---|---|
| S-09-01 | Static | `npm run typecheck && npm run lint` in `apps/api`; `dart analyze && dart format --set-exit-if-changed .` in `apps/mobile` — zero errors | All |
| M-09-01 | API manual | `curl -s -D- -H "Authorization: Bearer $JWT" "$API/admin/export?type=complaints" -o c.csv` → 200, `Content-Type: text/csv`, `Content-Disposition` filename. `grep -cE '\+91[0-9]{10}' c.csv` → 0; header has status/latestResult columns | AC-1 |
| M-09-02 | API manual | Same with `&includePhone=true` → phone column present. `grep` the API log for `"action":"export"` → one line with `includePhone:true`, no `+91` anywhere in the log | AC-2 |
| M-09-03 | API manual | `type=verifications`, `type=reminders` → 200 CSVs (header of reminders has no `token`/`hash`); `type=bogus` → 400 `VALIDATION_FAILED`; no `Authorization` header → 401 | AC-3 |
| M-09-04 | DB + App manual | `UPDATE verifications SET note='=HYPERLINK("http://x")' WHERE id=…;` plus a complaint with CCRS `+123` and a note containing `a,"b"\nc`. Export, open in Sheets/Excel → text shown, no formula, columns intact | AC-4 |
| M-09-05 | App manual | More → Export: choose each type, toggle off → share sheet opens with the file; toggle on → warning visible; airplane mode → error + retry; button disabled during download | AC-5 |
| M-09-06 | API manual | `POST /admin/invite-codes {"sourceTag":"rwa","groupLabel":"Sunrise RWA"}` → 201 with generated code; `{"code":"sunrise2026",…}` → 201 `SUNRISE2026`; repeat `"SunRise2026"` → 409 `INVITE_CODE_TAKEN`; `{"sourceTag":"unknown",…}` → 400; `"code":"ab"` → 400 | AC-6 |
| M-09-07 | API + DB manual | PATCH label/ward → 200; PATCH `{"isActive":false}` → 200; PATCH `{"sourceTag":"social"}` → 400; `SELECT source_tag FROM invite_codes WHERE code='SUNRISE2026'` → unchanged | AC-7 |
| M-09-08 | API + DB manual | `POST /invite-codes/validate {"code":"sunrise2026"}` → 404 `INVITE_CODE_INVALID`; submit a report with that code (TASK-04 flow or curl) → 201; `SELECT source_tag, invite_code_id FROM complaints ORDER BY created_at DESC LIMIT 1` → `unknown`, NULL | AC-8 |
| M-09-09 | App manual | Invite codes screen: create via form (inline 409 error on duplicate), deactivate/activate, Share opens share sheet with the filled message; empty state on a DB with no codes; error state with API stopped | AC-6, AC-9 |
| M-09-10 | API + App manual | Add "Stray cattle" → 201; rename → 200; duplicate name → 409 inline; placeholder note visible | AC-10 |
| M-09-11 | App + API manual | Drag C to top, deactivate B; `curl $API/categories` → C, A only, in order; admin detail/export of a complaint under B still shows B; stop API mid-reorder → order reverts + error | AC-11 |
| M-09-12 | App manual | More tab tiles navigate; `POST /admin/auth/logout-all` from another session then tap a tile → returns to login with "Your session ended…" | AC-12 |
| M-09-13 | Manual (log) | Grep log for `invite_code.` and `category.` actions → one line per change with adminId and targetId; no request bodies | §7.2 |
| O-09-01 | Optional automated | 06 §8.1 #5: Vitest + Supertest — phone column absent by default; `=`-prefixed note escaped. **Optional, P2** | AC-1, AC-4 |

## 9. Deliverables

- API: `src/lib/csv` escaping utility; `export`, `invite-codes` and `categories-admin` modules with routes, schemas, services and audit logging.
- App: admin `data`/`application`/`presentation` code for export, invite codes and categories; More tab tiles; three routes behind the admin guard; ARB strings.
- share_plus (and path_provider if needed) added after version and maintenance checks; versions recorded in the Progress log.
- Coverage matrix rows for the 8 requirements updated with evidence.

## 10. Files Expected to Change

This is a prediction, not a constraint.

| Path | Change |
|---|---|
| `apps/api/src/lib/csv/` | New |
| `apps/api/src/modules/export/` | New |
| `apps/api/src/modules/invite-codes/` | New |
| `apps/api/src/modules/categories-admin/` | New |
| `apps/api/src/app.ts` (route registration) | Modified |
| `apps/mobile/lib/features/admin/data/` (export, invite codes, categories repositories) | New/Modified |
| `apps/mobile/lib/features/admin/application/` (providers) | New/Modified |
| `apps/mobile/lib/features/admin/presentation/` (more, invite_codes, categories, export screens) | New/Modified |
| `apps/mobile/lib/router/` | Modified |
| `apps/mobile/lib/core/l10n/*.arb` | Modified |
| `apps/mobile/pubspec.yaml` | Modified |
| `docs/tasks/coverage-verification.md`, `docs/tasks/00-task-summary.md`, this file | Modified |

## 11. Related Documentation

- `docs/03-backend-spec.md §2.2`: admin reference-data and export endpoint tables.
- `docs/03-backend-spec.md §4.2`: invite-code validation rule and message.
- `docs/03-backend-spec.md §4.6`: export behaviour, phone off by default, audit logging.
- `docs/03-backend-spec.md §9.1–9.2`: error codes (`INVITE_CODE_TAKEN`), logging levels and redaction.
- `docs/02-frontend-spec.md §4.22`: invite codes, categories and export screen content and copy.
- `docs/02-frontend-spec.md §5.2–5.3`: providers and refetch-after-mutation rule.
- `docs/04-database-design.md §3.2, §3.3, §3.5–3.7, §3.9`: columns to export, constraints, derived status.
- `docs/06-security-testing.md §3.1`: CSV formula escaping.
- `docs/06-security-testing.md §4.2`: phone exposure rules.
- `docs/06-security-testing.md §12.3`: release checklist items re-run in TASK-10.

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Phone-number CSV shared carelessly | Personal data exposure | Off by default; warning copy; audit log of every phone export; TASK-10 re-checks |
| Escaping applied before quoting incorrectly, or missed on numeric-looking values like `-5` | Formula execution in spreadsheets | Escape every string cell regardless of column; test with M-09-04 values in both Excel and Sheets |
| Reorder with several sequential PATCHes partially fails | Inconsistent order | Disable the list during save; revert and refetch on failure; steps of 10 limit how many rows change |
| Deactivating a category in use breaks history | Lost categorisation | Deactivate only (RESTRICT FK); admin detail and exports join regardless of `is_active` |
| Share sheet behaviour differs by platform and file provider | Export unusable on one OS | Verify on Android in this task; iOS re-checked in TASK-10 |
| Large export memory use | Slow or failed download | Pilot volume is tiny (04 §6); stream rows if the library supports it |

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
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-09` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `TASK-09: …`
- [ ] Validator passes
