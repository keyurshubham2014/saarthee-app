# TASK-10: Staff Console, Roles and Moderation

| Field | Value |
|---|---|
| Task ID | TASK-10 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | TASK-04, TASK-05 |
| Blocks | TASK-11 |
| Requirement IDs | REQ-F-048, REQ-F-049, REQ-F-050, REQ-F-051, REQ-F-052, REQ-D-011, REQ-S-002, REQ-S-010 |
| Primary Spec Refs | Spec §2 (D3, D7, D11), §3, §5 (rejected, merged), §6 (`moderation_flags`, `app_settings`), §7 (Staff, `POST /issues/{id}/flags`, `GET /staff/export`), §8 (`/staff/*`), §11 (abuse, audit, neutrality); DS §4 (console width), §5, §6, §8 (Staff) |
| Last Updated | 2026-10-03 |

## 1. Objective

Give the people who run Saarthee one console — the same Flutter codebase, built for the web and reachable in the app under `/staff` — with navigation that matches each person's role (admin, moderator, representative). Every staff endpoint is protected by one role guard and a written authorisation matrix, and representatives are limited to their wards. Moderators work a queue of sensitive, flagged and out-of-area reports and can reject with a reason, merge duplicates, recategorise or move ward, hide, and suspend abusive users. Citizens can flag issues and comments. Admins manage moderator roles, categories and app settings, and export CSVs without phone numbers by default. Every staff action is written to the audit log with actor, role and target and nothing personal. The v1 pilot-only admin screens (rates H1/H2, invite codes, manual reminders) are retired per D11 while the useful v1 admin pieces (login, categories pattern, CSV helper) are reused.

## 2. Scope

### In Scope
- Migration `<ts>_v2_moderation`: `moderation_flags`, `app_settings` (REQ-D-011; `app_settings` skipped if TASK-09 already created it from the DDL below), `issues.moderated_at/moderated_by/merged_into_id`, new `issue_events` types.
- Staff extension of TASK-04's `requireRole(...roles)` (made here if TASK-08/09 have not), ward-scope helper `assertWardScope`, the authorisation matrix (REQ-S-002) and a matrix-driven test over every `/staff/*` route.
- Audit helper v2 `auditStaff(req, action, target)` with an action allow-list, a dedicated audit log destination, and a test that every staff mutation writes one line (REQ-S-010).
- Moderation API: queue, reject, merge, recategorise / change ward, hide / unhide, mark reviewed, flag resolve, suspend / unsuspend user.
- Citizen flagging API `POST /issues/{id}/flags` (issue or comment) and the `FlagContentSheet` widget.
- Roles management (grant/revoke moderator), categories admin on v2 `categories`, app settings (feature flags) API.
- CSV exports (P1): issues, issue events, verifications; phone excluded unless an admin explicitly includes it with a reason.
- Flutter web: `lib/main_staff.dart` entrypoint, `web/` platform, staff login (phone OTP via Firebase web or v1 admin email/password), CORS allow-list on the API.
- Staff shell: responsive side navigation (≥ 840 dp: navigation rail/drawer, content max 1,200 dp; phone: drawer), role-aware nav registry, dashboard, 403 page; in-app entry "Staff tools" on `/me` for staff roles.
- Staff screens owned here: Dashboard, Moderation queue, Issue tools, Users & roles, Categories, Settings (incl. the Election mode section UI), Exports.
- Retire v1 pilot UI and endpoints: `/admin/rates`, `/admin/invite-codes`, `/admin` due/reminders screens and `/admin/complaints/:id/reminders`, `/admin/reminders/:id/revoke`; redirect `/admin*` app routes to `/staff`; tables stay read-only.
- Tests (Vitest + Supertest, Flutter widget tests) and manual checks.

### Out of Scope
- Alert composer and approvals screens — TASK-08 builds them; this shell mounts them.
- Representatives roster screens and the election-mode behaviour/API — TASK-09 (this task owns only the settings UI that calls `PUT /staff/settings/election-mode`).
- Representative claims, ward dashboard, representative issue actions — TASK-11 (uses `assertWardScope` and the nav registry).
- Services and initiatives admin — TASK-12.
- Generic issue state machine (acknowledge, in progress, marked fixed, verify) — TASK-06; this task implements only the moderator-only outcomes `rejected` and `merged`.
- Issue detail "Report a problem" button placement — TASK-07 wires `FlagContentSheet` if it lands after this task (else this task wires it).
- Hosting the web build — TASK-13.
- Citizen-side v1 endpoints (`/reports`, `/invite-codes/validate`, `/verify/*`) — not touched here.

## 3. Prerequisites

- TASK-04: `users` (role, status, token_version), session JWT + `requireUser`, Firebase Auth set-up (Android; web app config added here), push service for reporter notifications, consents.
- TASK-05: `categories` (14 seeded), `issues`, `issue_photos`, `issue_events` populated by `POST /issues`; sensitive-category flag.
- TASK-01: v2 tables, test harness, seed with sample citizens and issues in every status, v1 admin auth kept.
- TASK-03: tokens, component library, ARB, router structure.
- Env: `STAFF_WEB_ORIGINS` (comma list, HTTPS outside local), `AUDIT_LOG_FILE`, `AUDIT_RETENTION_DAYS=365`, `EXPORT_MAX_ROWS=50000`; Flutter web dart-defines `API_BASE_URL`, `FIREBASE_WEB_*`.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-04 | User model with roles and status, sessions and token version, Firebase Auth, push service for moderation notices |
| TASK-05 | Categories and issues to moderate, sensitive flag, issue events |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-048 | Staff console runs as a Flutter web build and in-app under `/staff`, role-aware navigation | Spec D7, §8 |
| REQ-F-049 | Moderation queue: new issues in sensitive categories, flagged content, out-of-area issues; actions reject (reason), merge, recategorise, hide, suspend user | Spec §11 |
| REQ-F-050 | Staff management of roles (grant/revoke moderator), categories, and app settings | Spec §3 |
| REQ-F-051 | Content flagging by citizens on issues and comments | Spec §11 |
| REQ-F-052 | Staff exports (CSV) of issues, events and verifications without phone numbers by default | Spec §7 |
| REQ-D-011 | `moderation_flags` and `app_settings` (election mode, flags) tables | Spec §6 |
| REQ-S-002 | Role-based authorisation on every staff endpoint; representatives scoped to their wards | Spec §3 |
| REQ-S-010 | Every staff action logged in the audit log with actor, role and target; no bodies or PII | Spec §11 |

### 5.2 Data Contracts

Migration `<ts>_v2_moderation`:

`moderation_flags`

| Column | Type | Rule |
|---|---|---|
| id | uuid PK | |
| target_type | enum `flag_target` (`issue`, `issue_event`) | `issue_event` = a comment |
| target_id | uuid NOT NULL | |
| issue_id | uuid NOT NULL → issues | denormalised for the queue |
| reporter_id | uuid NOT NULL → users | |
| reason | enum `flag_reason` (`spam`, `abusive`, `private_info`, `not_civic`, `wrong_location`, `duplicate`, `other`) | |
| note | text NULL | ≤ 200 |
| status | enum `flag_status` (`open`, `actioned`, `dismissed`) default `open` | `CHECK (status = 'open' OR (handled_by IS NOT NULL AND handled_at IS NOT NULL))` |
| handled_by, handled_at | uuid / timestamptz NULL | staff actor id |
| created_at | timestamptz | |

Unique open flag per person per target: partial UNIQUE `(reporter_id, target_type, target_id) WHERE status = 'open'`; index `(status, created_at)`.

`app_settings` (single DDL, also used by TASK-09): `key text PRIMARY KEY CHECK (key ~ '^[a-z][a-z0-9_]{2,63}$')`, `value jsonb NOT NULL`, `updated_by uuid NULL`, `updated_at timestamptz NOT NULL default now()`. Keys are an allow-list in code (`APP_SETTING_KEYS`) with a Zod schema each: `election_mode` (TASK-09), `relay_enabled` (bool, default true), `alerts_feed_drafts_enabled` (bool, default false), `scorecard_public` (bool, default true), `moderation_sensitive_review` (bool, default true). Missing key ⇒ default.

`issues` additions: `moderated_at timestamptz NULL`, `moderated_by uuid NULL`, `merged_into_id uuid NULL → issues` (`CHECK (merged_into_id <> id)`; `CHECK (status <> 'merged' OR merged_into_id IS NOT NULL)`). `issue_events.type` gains `recategorised`, `ward_changed`, `hidden`, `unhidden`, `reviewed` (`ALTER TYPE … ADD VALUE IF NOT EXISTS`, or the CHECK list if TASK-01 used text).
`users`: no schema change; suspension uses `status='suspended'` and `token_version + 1`.

Queue definitions (`GET /staff/moderation?queue=`):
- `sensitive` — `is_sensitive` and `moderated_at IS NULL` and status not `rejected`/`merged`.
- `flagged` — issues with ≥ 1 open flag (on the issue or its comments), ordered by open-flag count desc then oldest.
- `out_of_area` — `NOT EXISTS (SELECT 1 FROM wards w WHERE ST_Covers(w.geom, i.location::geometry))` and `moderated_at IS NULL`.

### 5.3 API Contracts

All `/staff/*` routes: `requireRole(...roles)` (staff extension) → per-actor limiter 300/min → handler → `auditStaff` on success for mutations. Errors use the v1 envelope; new codes: `UNAUTHENTICATED` 401, `FORBIDDEN` 403 "You don't have access to this.", `WARD_OUT_OF_SCOPE` 403 "This issue is outside your wards." (same code as TASK-11), `ISSUE_STATE_INVALID` 409, `MERGE_INVALID` 422, `SELF_ROLE_CHANGE` 409 "You can't change your own role.", `SETTING_UNKNOWN` 400.

| Method | Path | Roles | Request | Response | Errors |
|---|---|---|---|---|---|
| GET | `/staff/me` | all staff | — | `{actorId, role, displayName, wardIds, nav:[keys]}` | 401, 403 |
| GET | `/staff/summary` | Moderator, Admin | — | `{queues:{sensitive, flagged, outOfArea}, alertsAwaitingApproval, openFlags}` | |
| GET | `/staff/moderation` | Moderator, Admin | `queue`, `cursor`, `limit ≤ 50` | `{items:[{issue summary, ward, category, createdAt, openFlags:[{reason,count}], photoThumbUrl}], nextCursor}` | 400 |
| POST | `/staff/issues/{id}/reject` | Moderator, Admin | `{reason: spam\|duplicate\|out_of_area\|private_individual\|not_civic\|other, note ≤ 500}` | 200 issue; event `rejected`; reporter notified (push + inbox) "Your report wasn't accepted: <reason>" | 404, 409 |
| POST | `/staff/issues/{id}/merge` | Moderator, Admin | `{targetIssueId, note?}` | 200; source `merged`, `merged_into_id`; me-toos and follows moved (`ON CONFLICT DO NOTHING`), reporter follows target, counts recomputed; events on both | 409, 422 `MERGE_INVALID` (self, target closed/merged/rejected/hidden, chain) |
| POST | `/staff/issues/{id}/recategorise` | Moderator, Admin | `{categoryId?, wardId?, note?}` (≥ 1 field) | 200; `sla_due_at` recomputed from `created_at` + new category SLA; events `recategorised` / `ward_changed` | 404, 422 inactive category |
| POST | `/staff/issues/{id}/hide` · `/unhide` | Moderator, Admin | `{reason ≤ 200}` | 200; `visibility` hidden/public; event | 409 |
| POST | `/staff/issues/{id}/reviewed` | Moderator, Admin | — | 200; sets `moderated_at/by`; event `reviewed`; removes from sensitive/out-of-area queues | |
| POST | `/staff/comments/{eventId}/hide` | Moderator, Admin | `{reason}` | 200; comment hidden from public timeline | 404 |
| POST | `/staff/flags/{id}/resolve` | Moderator, Admin | `{outcome: actioned\|dismissed}` | 200 | 409 already handled |
| POST | `/staff/users/{id}/suspend` · `/unsuspend` | Moderator (citizens only), Admin (anyone but self) | `{reason ≤ 200}` | 200; `status` changes; `token_version + 1` on suspend | 403, 409 self |
| GET | `/staff/users` | Admin | `q` (name or last 4 digits), `role`, `cursor` | `{items:[{id, displayName, phoneMasked:'+91 ••••••3210', role, status, createdAt}]}` | |
| POST | `/staff/users/{id}/role` | Admin | `{role: 'moderator'\|'citizen'}` | 200; `token_version + 1` | 409 `SELF_ROLE_CHANGE`; 422 if target is admin or representative |
| GET/POST/PATCH | `/staff/categories[/{id}]` | Admin (GET also Moderator) | name_en/gu, icon (allow-list), colour_token (DS §2 list), sla_days 1–90, sensitive, is_active, sort_order; slug immutable; no DELETE | list / 201 / 200 | 400, 409 slug taken |
| GET | `/staff/settings` | Admin, Moderator (read) | — | `{items:[{key, value, updatedAt}]}` | |
| PUT | `/staff/settings/{key}` | Admin | value per key schema; `election_mode` routed to TASK-09's handler | 200 | 400 `SETTING_UNKNOWN` |
| GET | `/staff/export` (P1) | Admin | `dataset=issues\|issue_events\|verifications`, `from`, `to` (≤ 366 days), `ward?`, `includePhone=false`, `reason` (required, 10–200, when `includePhone=true`) | `text/csv` stream, `Content-Disposition` dated filename; reporter as `reporter_ref` (HMAC of user id); phone column only when included | 400, 413 over `EXPORT_MAX_ROWS` |
| POST | `/issues/{id}/flags` | Citizen | `{reason, note?, eventId?}` | 201 `{flagId}`; 200 if the same open flag exists | 401, 404, 429 (20/day/user) |

Moderator-only transitions (`rejected`, `merged`) run in one transaction: lock issue, check it is not already `rejected`/`merged`, update status + `status_changed_at`, append `issue_events` (actor id, actor role, from, to, note), resolve the issue's open flags as `actioned`. If TASK-06's transition service exists, call it; otherwise this module owns these two transitions and TASK-06 must treat them as terminal.

**Authorisation matrix (REQ-S-002)** — source of truth `src/middleware/staffMatrix.ts`, exported so the test can iterate every registered `/staff/*` route and fail on any route missing from it:

| Area | Admin | Moderator | Representative | Citizen / Visitor |
|---|---|---|---|---|
| `/staff/me` | ✅ | ✅ | ✅ | 403 / 401 |
| Moderation queue, issue tools, flags, comment hide | ✅ | ✅ | ❌ | 403 / 401 |
| Suspend / unsuspend citizen | ✅ | ✅ | ❌ | 403 / 401 |
| Suspend staff, users & roles | ✅ | ❌ | ❌ | 403 / 401 |
| Categories write, settings write, exports | ✅ | ❌ (read categories/settings) | ❌ | 403 / 401 |
| Alerts (TASK-08) | per TASK-08 §5.5 | per TASK-08 §5.5 | ❌ | 403 / 401 |
| Representatives, election mode (TASK-09) | ✅ | read | ❌ | 403 / 401 |
| Ward dashboard, ward issues, ward export (TASK-11) | ✅ all wards | ✅ all wards | own wards only (`assertWardScope` → 403 `WARD_OUT_OF_SCOPE`) | 403 / 401 |

Staff `requireRole(...roles)` contract (shared with TASK-08/09/11; TASK-04 created the base middleware returning 403 `FORBIDDEN`): accepts a v2 session JWT (re-reads `users.role`, `status='active'`, `token_version`) or, additionally, a v1 admin JWT (role `admin`, `actorKind='admin_user'`); sets `req.staff = {actorId, actorKind, role, wardIds}`; `wardIds` for representatives from `representatives.user_id → representative_areas` (TASK-11 replaces this with its `rep_scope_wards_v` view, which also counts MLA/MP wards via `ward_constituency` and requires a verified, in-term link). Missing/invalid token → 401; wrong role or suspended → 403.

**Audit (REQ-S-010):** `auditStaff(req, action, {targetType, targetId, extra?})` writes `{ts, requestId, actorId, actorKind, role, action, targetType, targetId, extra}` (extra: enums, counts, booleans only — never names, phones, notes, reasons' free text, bodies) to the main logger **and** to `AUDIT_LOG_FILE` (pino-roll, retention `AUDIT_RETENTION_DAYS`). Action allow-list (TS union) includes this task's `issue_rejected`, `issue_merged`, `issue_recategorised`, `issue_ward_changed`, `issue_hidden`, `issue_unhidden`, `issue_reviewed`, `comment_hidden`, `flag_resolved`, `user_suspended`, `user_unsuspended`, `role_changed`, `category_created`, `category_updated`, `setting_changed`, `export_downloaded` (`extra: {dataset, rows, includePhone}`), plus actions registered by TASK-08/09/11/12. v1 `auditLog` callers are migrated to it.

**Retired v1 endpoints (D11):** remove `ratesRouter`, invite-code routes in `referenceRouter`, `/admin/complaints/:id/reminders`, `/admin/reminders/:id/revoke` from the router (code deleted, tables untouched); keep `/admin/auth/login`, `/admin/me`, `/admin/auth/logout-all`; v1 `/admin/complaints*` read routes stay until TASK-14 confirms the legacy migration, then are removed.

### 5.4 UI Surfaces & States

Shell: DS §4 — staff content max width 1,200 dp; ≥ 840 dp a persistent side navigation with section labels; < 840 dp an app bar with a menu drawer. Header shows "Saarthee staff", role chip ("Admin" / "Moderator" / "Representative") and "Sign out". Nav items come from a registry `StaffNavItem(route, labelKey, icon, roles, ownerTask)`; items whose screens are not landed are not registered, so nothing dead is shown.

| Role | Navigation (in order) |
|---|---|
| Admin | Dashboard · Moderation · Alerts (TASK-08) · Representatives (TASK-09) · Claims (TASK-11) · Services, Initiatives (TASK-12) · Categories · Users & roles · Settings · Exports |
| Moderator | Dashboard · Moderation · Alerts (TASK-08) |
| Representative | Ward dashboard · Ward issues · Messages (TASK-11) |

| Route | Content | States |
|---|---|---|
| `/staff/login` (web) | "Sign in to Saarthee staff"; phone + OTP (Firebase web, invisible reCAPTCHA); link "Admin sign-in with email" (v1 form) | wrong OTP / not staff → "This account doesn't have staff access."; suspended → "This account is suspended."; network error + "Try again" |
| `/staff` Dashboard | Count cards: "Sensitive reports to review", "Flagged", "Outside city wards", "Alerts awaiting approval"; each links to its list | loading skeleton cards; error; all zero → "Nothing waiting. Good work." |
| `/staff/moderation` | Tabs Sensitive / Flagged / Outside city wards with counts; rows: thumbnail (blur caption kept), category badge, title, ward · age, flag reasons chips; multi-pane on wide screens (list left, issue tools right) | empty per tab "Nothing to review here."; loading; error; stale item (already handled by someone else) → snackbar "Already handled by another moderator." and row removed |
| `/staff/issues/:id` (Issue tools) | Photos, description, location map pin + ward, reporter shown only as "A resident of <ward>" (never phone), flags list, timeline; actions: "Looks fine", "Change category or ward", "Merge into…" (search nearby open issues of any category within 500 m, distance shown), "Hide", "Not accepted…" (reason radio + note), "Suspend reporter…"; every destructive action has a confirm dialog stating the effect | in-flight buttons disabled with progress; 409 → reload with message; hidden banner "Hidden from the public" |
| `/staff/users` | Search ("Name or last 4 digits"), table: name, masked phone, role, status; row actions "Make moderator" / "Remove moderator", "Suspend" / "Reinstate" | own row actions disabled with tooltip "You can't change your own role."; empty search "No matching people." |
| `/staff/categories` | Table of 14 categories (badge preview using DS §2 colour), edit drawer: names gu/en, icon, colour token picker (DS list only), SLA days, sensitive, active, order | validation inline; inactive rows greyed with "Inactive" chip |
| `/staff/settings` | Sections: "Election mode" (UI here; read/write through TASK-09's endpoint: switch, scope City/Wards with ward multi-select, From/To, notes gu/en, preview of the banner); "Features" (switches for the allow-listed flags with one-line explanations) | moderator: read-only with "Only admins can change settings."; save errors inline |
| `/staff/exports` (P1) | Dataset select, date range, ward, "Include phone numbers" (off; when on, reason field and warning "Phone numbers are personal data. Only include them if you must.") → "Download CSV" | over limit → "Too many rows. Narrow the date range."; in-flight |
| `/staff/forbidden` | "You don't have access to this page." + "Go to dashboard" | — |
| In-app `/me` | Row "Staff tools" (only when role ≠ citizen) → `/staff` | — |
| Citizen `FlagContentSheet` | "Report a problem with this post": reasons (Spam or advertising; Abusive or hateful; Shows private information; Not a civic issue; Wrong location; Duplicate; Something else) + optional note 0/200 → "Send" → "Thanks. Our moderators will look at it." | signed out → sign-in and return; already flagged → "You've already reported this."; offline/error messages |

ARB prefixes: `staff*`, `staffNav*`, `moderation*`, `flag*`, `staffUsers*`, `staffCategories*`, `staffSettings*`, `staffExport*` (gu + en; staff screens in both languages, English default on web).

Web build: `flutter build web -t lib/main_staff.dart --release --dart-define=API_BASE_URL=…`; the staff entry imports only `features/staff/**`, `core/**` (no camera/capture plugins); session token kept in memory + `sessionStorage` (12 h expiry), never `localStorage`; CSP-friendly (no inline scripts beyond Flutter bootstrap).

### 5.5 Permissions & Roles

The matrix in §5.3 is authoritative. Additional rules: staff cannot change their own role or suspend themselves; admin role is granted only by the CLI (`admin:create` / `npm run staff:grant-admin -- --phone`), never via API; representative role only via an approved claim (TASK-11); a representative who is also a citizen uses the citizen app normally; role or status changes bump `token_version` so existing sessions end; client-side route guards are UX only — the API is authoritative.

### 5.6 Assumptions

- ASSUMPTION: The audit log stays a log (no DB table, as Spec §6 lists none) but goes to a dedicated file with 365-day retention; it holds ids and enums only, so it is outside the 14-day PII log rule (REQ-S-014). Legal review (Open Question 6).
- ASSUMPTION: Moderators may suspend citizens but not staff; only admins reinstate staff — spec says "suspension" without roles.
- ASSUMPTION: No automatic hiding on flag counts; flagged items are sorted by count for human review (spec silent; avoids brigading).
- ASSUMPTION: Out-of-area is computed from geometry (no new column); sensitive and out-of-area items leave the queue when "Looks fine" sets `moderated_at`.
- ASSUMPTION: Merge allows any category and warns beyond 200 m; source issue's reporter becomes a follower of the target.
- ASSUMPTION: Recategorising recomputes `sla_due_at` from `created_at` with the new category's SLA days.
- ASSUMPTION: Feature-flag keys listed in §5.2 are the starting allow-list; later tasks add keys with a schema.
- ASSUMPTION: Staff web login supports Firebase phone OTP (moderators) and the v1 email/password admin login (Spec §7 keeps it); both yield `req.staff`.
- ASSUMPTION: Exports pseudonymise reporters with an HMAC (`EXPORT_HMAC_SECRET`) so rows can be grouped without identity.
- ASSUMPTION: v1 `/admin/complaints*` read routes remain until TASK-14 confirms the legacy migration (REQ-D-005).

## 6. Implementation Steps

1. **Confirm contracts** from TASK-04/05 (user fields, session claims, issue/event columns and enum form, push service) and whether TASK-06/08/09 already made the staff `requireRole` extension, `app_settings` or the `src/jobs` runner; reuse, don't duplicate.
2. **Migration `<ts>_v2_moderation`** per §5.2; Prisma models; seed: flags on sample issues, one out-of-area issue, settings defaults.
3. **Role guard + matrix.** Staff `requireRole` extension, `assertWardScope`, `staffMatrix.ts`; new `/staff` router mounted in `routes.ts` with per-actor limiter; matrix test T-10-01 that enumerates routes from the Express stack.
4. **Audit v2.** `auditStaff` + allow-list + audit file destination; migrate v1 `auditLog` callers; test T-10-02 (spy) asserting one line per mutation and no PII keys.
5. **Moderation service.** Queue queries (EXPLAIN-checked), reject/merge/recategorise/hide/unhide/reviewed/comment-hide/flag-resolve in transactions with `issue_events`; reporter notifications via the push service + inbox row.
6. **Flags.** `POST /issues/{id}/flags` (citizen, 20/day), duplicate-open handling, comment target validation.
7. **Users & roles, suspension.** List with masked phones, role change with self-guard and token bump, suspend/unsuspend rules; CLI `staff:grant-admin`.
8. **Categories admin + settings API** (allow-list, per-key Zod, `election_mode` delegated to TASK-09's handler when present).
9. **Exports (P1).** Stream CSV through the v1 `src/lib/csv` helper (formula-injection escaping), HMAC reporter ref, row cap, phone opt-in with reason, audit.
10. **Retire v1 pilot endpoints** (D11) and update v1 admin router; confirm tables untouched.
11. **API tests** T-10-01…T-10-14 green; manual M-10-01, M-10-02 with curl.
12. **CORS** for `STAFF_WEB_ORIGINS` (exact origins, credentials off, `Authorization` header allowed); HTTPS-only origins outside local.
13. **Flutter web platform.** Add `web/`; `lib/main_staff.dart`; staff router (`router/staff_routes.dart`) with role guard; import-boundary lint (custom `analysis_options` rule or test that scans imports).
14. **Staff shell.** Responsive layout, nav registry, header, forbidden page, session handling (memory + sessionStorage on web, secure storage on Android); migrate useful v1 admin widgets from `features/admin/presentation/widgets` into `features/staff/shared`.
15. **Screens.** Login, Dashboard, Moderation, Issue tools, Users & roles, Categories, Settings (election-mode section UI → TASK-09 endpoint), Exports; mount TASK-08/09 screens if present.
16. **Citizen pieces.** `FlagContentSheet`; "Staff tools" row on `/me`; wire into issue detail if TASK-07 has landed.
17. **Retire v1 admin UI.** Delete rates, invite codes, due/reminder screens and their providers; `/admin*` routes redirect to `/staff`; remove unused ARB keys.
18. **Widget tests** W-10-01…W-10-06; manual M-10-03…M-10-08 (web in Chrome + emulator); coverage evidence.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Web and in-app console
- **Given** a moderator account and an admin account
- **When** the staff web build is opened in Chrome and the Android app's `/me` → "Staff tools" is used
- **Then** both reach the same Dashboard; the moderator sees only Dashboard, Moderation and Alerts; the admin sees the full list of landed sections; a citizen sees no "Staff tools" row and `/staff` shows the forbidden page

**AC-2** — Authorisation matrix
- **Given** tokens for visitor (none), citizen, representative, moderator, admin and a suspended moderator
- **When** the matrix test calls every registered `/staff/*` route
- **Then** responses match the matrix exactly (401/403/2xx); any route missing from the matrix fails the test; the suspended moderator gets 403

**AC-3** — Representative ward scope
- **Given** a representative linked to ward 12 and a test route guarded by `assertWardScope`
- **When** they request ward 12 and ward 15 data
- **Then** ward 12 succeeds and ward 15 returns 403 `WARD_OUT_OF_SCOPE`

**AC-4** — Moderation queue
- **Given** a sensitive-category issue, an issue with 3 open flags, and an issue located outside all ward polygons
- **When** a moderator opens each queue tab
- **Then** each issue appears in its tab with counts on the dashboard; "Looks fine" removes the sensitive and out-of-area items; the reporter appears only as "A resident of <ward>"

**AC-5** — Reject and hide
- **Given** an open issue with flags
- **When** a moderator rejects it as spam with a note, and hides another issue
- **Then** the first is `rejected` with an `issue_events` row (actor, role, note), its flags are `actioned`, the reporter gets "Your report wasn't accepted: Spam"; the hidden issue disappears from public list/detail endpoints but stays visible to staff with "Hidden from the public"

**AC-6** — Merge duplicates
- **Given** issue A (2 me-toos, 1 follower) and open issue B, with one user in both
- **When** A is merged into B, then someone tries to merge B into A or A into itself
- **Then** A is `merged` with `merged_into_id = B`; B's me-too and follower counts include A's distinct users once; A's reporter follows B; events exist on both; the invalid merges return 422 `MERGE_INVALID`

**AC-7** — Recategorise and change ward
- **Given** an issue in `roads` (SLA 7) in ward 12
- **When** a moderator changes it to `drainage` (SLA 3) and ward 13
- **Then** category, ward and `sla_due_at = created_at + 3 days` update, with `recategorised` and `ward_changed` events

**AC-8** — Suspend user
- **Given** a citizen with an active session and a moderator
- **When** the moderator suspends the citizen, then tries to suspend an admin
- **Then** the citizen's next API call returns 401/403 (token version bumped) and sign-in shows "This account is suspended."; suspending the admin returns 403; both actions are audited

**AC-9** — Citizen flagging
- **Given** a signed-in citizen on an issue and a comment
- **When** they flag the issue as "Shows private information", flag it again, and flag the comment
- **Then** the first returns 201, the repeat returns 200 with the same flag, the comment flag is stored with `target_type=issue_event`; the 21st flag of the day returns 429; signed-out users are sent to sign-in and back

**AC-10** — Roles management
- **Given** an admin
- **When** they make a citizen a moderator, remove it, try to change their own role, and try to make someone admin via the API
- **Then** the first two succeed and end the target's sessions; self-change returns 409 `SELF_ROLE_CHANGE`; the admin request fails validation; phones are shown masked only

**AC-11** — Categories and settings
- **Given** an admin and a moderator
- **When** the admin renames a category in Gujarati, sets SLA 0, picks a colour outside DS §2, toggles `relay_enabled` off, and the moderator tries to change a setting
- **Then** the rename saves and shows in `GET /categories`; SLA 0 and the bad colour are rejected; the flag change is stored with `updated_by`; the moderator gets 403 and sees the read-only notice; the Election mode section saves through TASK-09's endpoint

**AC-12** — Exports without phone by default
- **Given** issues with reporters in the seed
- **When** an admin exports issues for a month without and with "Include phone numbers" (with and without a reason), and a moderator tries an export
- **Then** the default CSV has no phone column and a `reporter_ref`; including phones without a reason returns 400; with a reason the column appears and the audit line has `includePhone=true`; cells starting with `=+-@` are escaped; the moderator gets 403

**AC-13** — Audit log
- **Given** every staff mutation exercised in the API tests
- **When** the audit destination is inspected
- **Then** each mutation produced exactly one line with actorId, actorKind, role, action, targetType, targetId, and no phone, name, note, reason text or body

**AC-14** — v1 pilot UI retired
- **Given** the v2 build
- **When** an admin opens `/admin`, `/admin/rates` or `/admin/invite-codes` in the app, and calls `GET /admin/rates`
- **Then** the app redirects to `/staff`; the API returns 404; v1 tables `invite_codes`, `reminders` still contain their rows

### AC → Requirement

| AC | Requirements |
|---|---|
| AC-1 | REQ-F-048 |
| AC-2 | REQ-S-002 |
| AC-3 | REQ-S-002 |
| AC-4 | REQ-F-049 |
| AC-5 | REQ-F-049, REQ-S-010 |
| AC-6 | REQ-F-049 |
| AC-7 | REQ-F-049 |
| AC-8 | REQ-F-049, REQ-S-002, REQ-S-010 |
| AC-9 | REQ-F-051, REQ-D-011 |
| AC-10 | REQ-F-050, REQ-S-002 |
| AC-11 | REQ-F-050, REQ-D-011 |
| AC-12 | REQ-F-052, REQ-S-010 |
| AC-13 | REQ-S-010 |
| AC-14 | REQ-F-048 |

### 7.2 Non-Functional Checklist

- [ ] Staff console usable at 1,280 × 800 (side nav) and 360 dp phone width (drawer); keyboard navigation and visible focus ring on web
- [ ] Every staff screen has loading, empty, error, forbidden and in-flight states; destructive actions confirmed
- [ ] No reporter phone or name on any staff list or detail; masked phone only in Users & roles
- [ ] Audit lines carry ids/enums only; request bodies never logged
- [ ] Moderation queue queries p95 < 400 ms on seed data with 5,000 issues (EXPLAIN reviewed)
- [ ] CORS limited to `STAFF_WEB_ORIGINS`; web token not in `localStorage`
- [ ] Staff web bundle builds without camera/capture plugins (import boundary check passes)
- [ ] All strings in ARB gu + en; colours only from DS tokens
- [ ] v1 pilot tables untouched (row counts before/after recorded)

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-10-01 | API typecheck + lint; `dart format` + `dart analyze`; `flutter build web -t lib/main_staff.dart` succeeds | AC-1 |
| API (Vitest) | T-10-01 | Matrix test over all `/staff/*` routes × 6 identities; unknown route fails | AC-2 |
| API (Vitest) | T-10-02 | Audit spy: one line per mutation, required keys, forbidden keys absent | AC-13 |
| API (Vitest) | T-10-03 | `assertWardScope` with a test-only route | AC-3 |
| API (Vitest) | T-10-04 | Queue membership for sensitive/flagged/out-of-area; "reviewed" removes | AC-4 |
| API (Vitest) | T-10-05 | Reject: status, event, flags actioned, notification row; concurrent second reject 409 | AC-5 |
| API (Vitest) | T-10-06 | Hide/unhide: public endpoints exclude hidden; staff still sees | AC-5 |
| API (Vitest) | T-10-07 | Merge: counts, follower move, invalid merges 422, CHECK on `merged_into_id` | AC-6 |
| API (Vitest) | T-10-08 | Recategorise + ward change + SLA recompute | AC-7 |
| API (Vitest) | T-10-09 | Suspend/unsuspend rules and token-version invalidation | AC-8 |
| API (Vitest) | T-10-10 | Flags: create, duplicate open 200, comment target, 20/day limit, 401 | AC-9 |
| API (Vitest) | T-10-11 | Roles: grant/revoke, self 409, admin via API refused, masked phone | AC-10 |
| API (Vitest) | T-10-12 | Categories validation (SLA range, colour allow-list, slug immutable); settings allow-list + 403 | AC-11 |
| API (Vitest) | T-10-13 | Export: no phone default, reason required, HMAC ref, formula escaping, row cap, 403 | AC-12 |
| API (Vitest) | T-10-14 | Retired routes 404; kept v1 admin auth routes 200 | AC-14 |
| Widget | W-10-01 | Shell nav by role (admin/moderator/representative); registry hides unlanded items | AC-1 |
| Widget | W-10-02 | Responsive shell at 1,280 and 360 widths | AC-1 |
| Widget | W-10-03 | Moderation list states and stale-item handling | AC-4 |
| Widget | W-10-04 | Issue tools: reject dialog reasons, merge search, confirm dialogs | AC-5, AC-6 |
| Widget | W-10-05 | `FlagContentSheet`: reasons, note counter, already-reported, signed-out | AC-9 |
| Widget | W-10-06 | Export screen phone opt-in requires reason | AC-12 |
| Manual | M-10-01 | curl each moderation action with moderator token; SQL check of `issue_events` and flags | AC-4–AC-7 |
| Manual | M-10-02 | Inspect `AUDIT_LOG_FILE` after a session; grep for phone digits and names → none | AC-13 |
| Manual | M-10-03 | Chrome: staff web login with test phone (Firebase test number) and with v1 admin email | AC-1 |
| Manual | M-10-04 | Emulator: `/me` → Staff tools → moderation flow end to end; citizen sees rejected notice | AC-1, AC-5 |
| Manual | M-10-05 | Emulator: flag an issue as citizen → appears in Flagged tab on web | AC-9, AC-4 |
| Manual | M-10-06 | Suspend a signed-in emulator citizen from web → app session ends | AC-8 |
| Manual | M-10-07 | Old `/admin` deep links redirect; v1 table counts unchanged | AC-14 |
| Manual | M-10-08 | Keyboard-only and screen-reader pass (ChromeVox) on Dashboard and Moderation | AC-1 |

## 9. Deliverables

- Migration `<ts>_v2_moderation`; Prisma models; seed additions.
- API: staff `requireRole` extension, `assertWardScope`, `staffMatrix`, `auditStaff`; modules `staff` (me, summary), `staff-moderation`, `flags`, `staff-users`, `staff-categories`, `staff-settings`, `staff-export`; CLI `staff:grant-admin`; CORS; retired v1 routes removed.
- App: `main_staff.dart`, `web/`, `router/staff_routes.dart`, `features/staff/{shell,dashboard,moderation,issues,users,categories,settings,exports,shared}`, `FlagContentSheet`, "Staff tools" row; v1 admin pilot screens removed.
- Tests T-10-01…14, W-10-01…06; manual evidence M-10-01…08; coverage evidence for 8 requirements.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/api/prisma/migrations/<ts>_v2_moderation/`, `prisma/schema.prisma`, seed | New / Modified |
| `apps/api/src/middleware/{requireRole,staffMatrix,wardScope,cors}.ts` | Modified / New |
| `apps/api/src/lib/audit/` | Modified (v2 helper, audit destination) |
| `apps/api/src/modules/{staff,staff-moderation,flags,staff-users,staff-categories,staff-settings,staff-export}/` | New |
| `apps/api/src/modules/{admin,rates,reference,admin-complaints}/` | Modified / Removed (D11) |
| `apps/api/src/routes.ts`, `src/app.ts`, `src/config/`, `src/lib/errors/` | Modified |
| `apps/api/scripts/staff-grant-admin.ts`, `apps/api/package.json` | New / Modified |
| `apps/api/test/staff-*.test.ts`, `test/flags.test.ts`, `test/audit.test.ts` | New |
| `apps/mobile/web/`, `apps/mobile/lib/main_staff.dart` | New |
| `apps/mobile/lib/router/{staff_routes,admin_routes,app_router}.dart` | New / Modified |
| `apps/mobile/lib/features/staff/**` | New |
| `apps/mobile/lib/features/admin/**` | Removed / moved to `features/staff/shared` |
| `apps/mobile/lib/core/widgets/flag_content_sheet.dart`, `lib/features/me/` | New / Modified |
| `apps/mobile/lib/core/l10n/app_*.arb`, `pubspec.yaml` | Modified |
| `apps/mobile/test/staff/` | New |

## 11. Related Documentation

- `docs/v2/saarthee-v2-spec.md` §2 (D3, D7, D11), §3, §5, §6, §7, §8, §11
- `docs/v2/design-system.md` DS §4 (console width), §5, §6, §8 (Staff)
- `docs/tasks-v2/TASK-08-alerts.md` — alert screens and permissions mounted here
- `docs/tasks-v2/TASK-09-representatives-my-ward.md` — election-mode API, representative screens
- `docs/tasks-v2/TASK-11-*.md` — representative console sections using `assertWardScope`
- v1: `apps/api/src/lib/{audit,csv}`, `apps/mobile/lib/features/admin/` (reused patterns)

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| A staff route ships without a guard | Data exposure | Matrix test enumerates the Express stack and fails on unknown routes |
| Moderator over-reach or mistakes | Wrongly rejected reports, distrust | Reasons required, reporter notified, audit log, admin can review; unhide available |
| Audit log mixed with 14-day logs | Accountability lost | Separate audit destination with 365-day retention, ids only |
| Flutter web plugin incompatibility | Web build breaks | Separate entrypoint and import boundary; build in CI |
| Firebase phone auth on web (reCAPTCHA) friction | Moderators can't sign in | v1 email login for admins; Firebase test numbers in staging |
| Retiring v1 routes breaks legacy data access | Lost history | Tables untouched; read routes kept until TASK-14 confirms migration |
| Parallel tasks extend `requireRole` or create `app_settings` twice | Merge conflicts | One contract in this file; "create if absent" rule in TASK-08/09 |

## 13. Progress Status

**Current status:** Not Started

**Progress:** 0%

| Date | Progress | Commit |
|---|---|---|

## 14. Completion Checklist

- [ ] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [ ] Static checks pass and every AC verified by the tests and manual checks in §8
- [ ] Automated tests added and passing
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-10` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `V2-TASK-10: …`
- [ ] Validator passes
