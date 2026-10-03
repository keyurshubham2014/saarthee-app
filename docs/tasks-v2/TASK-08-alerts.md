# TASK-08: Civic Alerts and Notification Inbox

| Field | Value |
|---|---|
| Task ID | TASK-08 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | TASK-02, TASK-04 |
| Blocks | TASK-14 |
| Requirement IDs | REQ-F-035, REQ-F-036, REQ-F-037, REQ-F-038, REQ-F-039, REQ-F-040, REQ-F-041, REQ-D-009, REQ-S-011, REQ-F-065 |
| Primary Spec Refs | Spec §2 (D3, D9), §3, §6 (`alerts`, `alert_wards`, `subscriptions`, `notifications`), §7 (Alerts, Staff), §8 (`/alerts*`, `/staff/*`), §9, §11; DS §1, §2 (alert severity), §3, §4 (radii, Rounded icons), §5 (Alert card, Banners, Toast), §6 (Motion: New alert while open, Inbox), §7 (accessibility), §8 (Alert flow), §9 |
| Last Updated | 2026-10-03 |

## 1. Objective

Give Amdavadis trustworthy, ward-level civic alerts (water cuts, road closures, heat, rain and flooding, health) and one inbox for everything Saarthee tells them. Staff compose bilingual alerts with a named source and a validity window; Info and Advisory alerts need one approval, Warning and Critical need two different people. Published alerts reach the right FCM topics (`ward_<n>`, `zone_<code>`, `city_all`), wait for 07:00 during quiet hours unless Critical, expire on time, and can be retracted or superseded. Citizens see an Alerts tab, alert detail and alert settings, and a 90-day notification inbox with read state. NDMA SACHET (and IMD if access is granted) feed **drafts only** — nothing is ever published automatically. Every alert names its source and says Saarthee is independent. When an alert arrives while the app is open, a banner slides down from under the app bar (a Critical one pulses once, slowly — never a loop), and marking inbox items read by swiping compresses the row, fades its dot and rolls the badge count (DS §6).

## 2. Scope

### In Scope
- Migration `<ts>_v2_alerts`: `alerts`, `alert_wards`, `subscriptions` (REQ-D-009) and the extension of `notifications` (created by TASK-04 with `kind`, bilingual title/body, `send_after`, `read_at`): inbox indexes and the one-row-per-user-per-alert index.
- Prisma models for the new tables (geometry via `Unsupported`), sample alerts added to the v2 dev seed (fictional, every severity and status).
- API module `alerts`: public `GET /alerts`, `GET /alerts/{id}`; citizen `GET/PUT /me/subscriptions`, visitor `GET/PUT /devices/{installId}/subscriptions`, `GET /me/notifications`, `POST /me/notifications/read`.
- API module `staff-alerts`: `GET /staff/alerts`, `POST /staff/alerts`, `PATCH /staff/alerts/{id}`, `POST /staff/alerts/{id}/submit|approve|publish|retract|supersede`; two-person rule enforced in the service **and** by a DB CHECK.
- Publish pipeline: topic selection and sends through the TASK-04 push service (`notifyTopic`, language-suffixed topics), filtered per-device sends for devices with custom preferences (new `notifyDevices` in the push service), inbox fan-out, quiet hours 22:00–07:00 Asia/Kolkata via `sendAfter` (Critical exempt), retraction push and withdrawal of held sends.
- Background jobs on the `src/jobs` runner (created by TASK-06; created here with the same contract if TASK-06 has not landed): `alerts-expire`, `alerts-ingest-sachet` (P1), `alerts-ingest-imd` (P1, only with access). Held pushes are sent by TASK-04's `push:flush`.
- App (citizen): Alerts tab `/alerts` (Active / Past), `/alerts/:id`, `/alerts/settings`, notification inbox `/me/notifications` with bell badge; topic manager extension for extra wards and zones, and topic opt-out for devices with custom preferences.
- App (staff): `/staff/alerts` list, `/staff/alerts/new`, `/staff/alerts/:id` (composer, preview, approval panel, actions). **TASK-08 owns these screens; TASK-10 owns the staff shell and side navigation** and mounts them.
- Shared widgets: `AlertCard`, `SeverityBanner`, `SourceLine`, `IndependenceFooter` (used later by TASK-07 Home strip and TASK-12 services).
- Independence/source labelling audit across About, alerts, services and hand-offs (REQ-S-011).
- Alert motion per DS §6 (REQ-F-065): in-app alert banner sliding down from under the app bar with `springIn` for alerts received while the app is in the foreground; one slow attention pulse for Critical (no loop); inbox swipe-to-read (row compresses, unread dot fades, bell badge count rolls); reduced-motion variants. Uses TASK-03 `SaartheeMotion` tokens and helpers only.
- Automated tests (Vitest + Supertest, Flutter widget tests) and manual emulator checks.

### Out of Scope
- WhatsApp/SMS delivery of alerts — REQ-F-090/091, deferred to phase 3.
- Issue-update notifications (status change, verification request) — TASK-06 writes them into `notifications`; this task only lists them.
- Initiative reminders — TASK-12 writes them; this task only lists them.
- Deleting notifications older than 90 days — retention job is TASK-13 (REQ-S-014); this task only filters to 90 days.
- Staff shell, side navigation, role guard matrix and audit-log extension — TASK-10 (this task uses the contracts in §5.5).
- Home "alerts strip" — TASK-07 (reuses `AlertCard` and `GET /alerts`).
- `cat_<slug>` issue-category topics (D9) — not used by alerts in v2.
- Motion tokens, sheet/page transitions, press scale, skeleton shimmer and the reduced-motion switch — TASK-03 (used here, not built). Frame-time audit — TASK-14 (REQ-N-013).

## 3. Prerequisites

- TASK-02: `wards` (number, zone_id, geom), `zones` (code), `GET /wards`, ward picker widget.
- TASK-04: `users` with `role`, `status`, `language`, `home_ward_id`; `requireUser`, `optionalUser`, `requireRole(...)`; `devices` (`install_id`, `fcm_token`, `language`, `topics`); `notifications` table; push service `notifyTopic` / `notifyUser` / `flushQueued` with drivers `fcm`, `log`, `memory`; channels `critical_alerts`, `alerts`, `updates`; app topic manager (`ward_<home>__<lang>`, `city_all__<lang>`) and tap routing allow-list (includes `/alerts/<id>` and `/me/notifications`); `ensureSignedIn()`.
- TASK-03: Neem tokens (incl. severity tokens from DS §2), Baloo Bhai 2 / Mukta Vaani type scale, radii 14/18/24/pill, Material Symbols Rounded, component library, ARB set-up (gu + en), five-tab shell with an Alerts placeholder; motion foundation — `SaartheeMotion` tokens (`lib/core/theme/motion.dart`), `animations` + `flutter_animate`, press-scale wrapper, haptics helper, `MotionCheck`, `CountUp`, `StaggeredColumn`, reduced-motion resolution.
- TASK-04: foreground FCM message stream (`onMessage`) that this task listens to for the in-app banner.
- TASK-01: test harness (Vitest + Supertest, test DB reset), v2 seed module.
- Env (API): `JOBS_ENABLED=true`, `ALERT_MAX_VALIDITY_DAYS=14`, `QUIET_HOURS=22:00-07:00`, `APP_TIMEZONE=Asia/Kolkata`, `SACHET_ENABLED=false`, `SACHET_FEED_URL=https://sachet.ndma.gov.in/CapFeed`, `SACHET_POLL_MINUTES=10`, `IMD_ENABLED=false`, `IMD_DISTRICT_WARNINGS_URL` (unset until access is granted). `push:flush` must run every 5 min (cron from TASK-13) for held alerts.
- Founder action (Open Question 4): request IMD API access (IP whitelisting) for the pilot server's IP; SACHET is used meanwhile.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-02 | Wards and zones for alert areas, topic names (`ward_<number>`, `zone_<code>`), polygon intersection for SACHET areas, ward picker for settings |
| TASK-04 | Users/roles/language, session auth and `requireRole`, devices, `notifications` table, FCM push service (`notifyTopic`, `sendAfter`, `push:flush`) and the app topic manager |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-035 | Staff alert composer: type, severity, bilingual title/body, source name + URL, validity window, wards or zone/city | Spec §9 |
| REQ-F-036 | Alert approval: Info/Advisory by one moderator; Warning/Critical need two different approvers; publish, retract, supersede | Spec D3, §9 |
| REQ-F-037 | Published alerts pushed to ward/zone/city topics respecting quiet hours (except Critical); auto-expire at `valid_to` | Spec §9 |
| REQ-F-038 | Alerts tab: active and past alerts for my wards, severity banner, source line, validity; alert detail | Spec §8 |
| REQ-F-039 | Alert subscription settings: extra wards, categories of alerts, mute non-critical | Spec §9 |
| REQ-F-040 | Notification inbox (90 days) with read state, across alerts, issue updates and initiatives | Spec §9 |
| REQ-F-041 | Draft alerts created automatically from NDMA SACHET CAP RSS (and IMD district warnings if access is granted); never auto-published | Spec §9 |
| REQ-D-009 | `alerts`, `alert_wards`, `subscriptions`, `notifications` tables with status and validity constraints | Spec §6 |
| REQ-S-011 | Alerts always show source and validity; no AMC logo; "independent app" label on About, alerts, services and hand-offs | Spec §1, §11 |
| REQ-F-065 | Alert motion per DS §6: in-app banner slides in under the app bar, single attention pulse for Critical (no loop), swipe-to-read in the inbox with rolling badge count | DS §6 |

### 5.2 Data Contracts

New migration `apps/api/prisma/migrations/<ts>_v2_alerts/migration.sql` (created with `prisma migrate dev --create-only`, hand-edited for CHECKs and PostGIS; applied migrations untouched).

Enums: `alert_type` (`water_cut`, `water_timing`, `road_closure`, `heat`, `rain_flood`, `health`, `initiative`, `other`) · `alert_severity` (`info`, `advisory`, `warning`, `critical`) · `alert_status` (`draft`, `pending_approval`, `published`, `expired`, `retracted`) · `alert_origin` (`manual`, `sachet`, `imd`) · `alert_scope` (`wards`, `zone`, `city`) · `subscription_scope` (`ward`, `zone`, `city`).

`alerts`

| Column | Type | Rule |
|---|---|---|
| id | uuid PK | `gen_random_uuid()` |
| type / severity | enums above | NOT NULL |
| title_en, title_gu | text | 5–80 chars when status ≠ `draft` (drafts from feeds may have empty `title_gu`) |
| body_en, body_gu | text | 10–500 chars when status ≠ `draft` |
| source_name | text NOT NULL | `CHECK (char_length(btrim(source_name)) BETWEEN 2 AND 80)` |
| source_url | text NOT NULL | `CHECK (source_url ~ '^https://')`, ≤ 500 |
| valid_from, valid_to | timestamptz NOT NULL | `CHECK (valid_to > valid_from)`; span ≤ `ALERT_MAX_VALIDITY_DAYS` checked in service |
| target_scope | `alert_scope` NOT NULL | `zone` requires `target_zone_id` (`CHECK`) |
| target_zone_id | int NULL → zones | |
| area | `geometry(MultiPolygon,4326)` NULL | from CAP polygons; GIST index |
| status | `alert_status` NOT NULL default `draft` | |
| origin / origin_ref | enum / text NULL | `UNIQUE (origin, origin_ref)` — CAP identifier de-dup |
| created_by | uuid NULL | staff actor id (NULL for feed drafts) |
| approved_by | uuid[] NOT NULL default `{}` | distinct actor ids, in order |
| submitted_at, published_at | timestamptz NULL | `CHECK (status NOT IN ('published','expired') OR published_at IS NOT NULL)` |
| supersedes_id | uuid NULL → alerts | an alert can be superseded once: `UNIQUE (supersedes_id)` |
| retracted_at, retracted_by, retraction_reason | NULL | `CHECK (status <> 'retracted' OR retracted_at IS NOT NULL)`; reason 5–200 |
| created_at, updated_at | timestamptz | |

Two-person rule in the database: `CHECK (status NOT IN ('published','expired') OR cardinality(approved_by) >= CASE WHEN severity IN ('warning','critical') THEN 2 ELSE 1 END)`.
Indexes: `(status, valid_to)`, `(published_at DESC)`, GIST `(area)`.

`alert_wards`: `alert_id` → alerts ON DELETE CASCADE, `ward_id` → wards, PK `(alert_id, ward_id)`, index `(ward_id)`. Always holds the concrete wards — a zone alert lists the zone's wards, a city alert lists all 48 — so "alerts for my wards" is one join.

`subscriptions`: `id`, `user_id` NULL → users, `device_id` NULL → devices, `CHECK (num_nonnulls(user_id, device_id) = 1)`, `scope` NOT NULL, `scope_id` int NULL (`CHECK ((scope = 'city') = (scope_id IS NULL))`), `category` text NULL (reserved for `cat_<slug>`; unused), `channel` text NOT NULL default `push` (`CHECK (channel = 'push')`), `muted_types alert_type[] NOT NULL default '{}'`, `critical_only boolean NOT NULL default false`, `created_at`. UNIQUE `(user_id, scope, scope_id)` and `(device_id, scope, scope_id)` (NULLS NOT DISTINCT). Rows are keyed by `user_id` for signed-in people and by `device_id` for visitors. The home ward is implicit (`users.home_ward_id`, or the device's onboarding ward sent with the visitor PUT) and never stored; rows hold **extra** wards (max 5) plus one `city` row that carries the preference columns. A person or device has **custom preferences** when `muted_types` is non-empty or `critical_only` is true.

`notifications` (TASK-04 table, already has `kind` incl. `alert`, `ref_id`, `route`, `title_en/gu`, `body_en/gu`, `status`, `send_after`, `read_at`, index `(user_id, created_at DESC)`) — this migration adds only: partial index `(user_id) WHERE read_at IS NULL AND user_id IS NOT NULL`; partial unique index `(user_id, ref_id) WHERE kind = 'alert' AND user_id IS NOT NULL` (one inbox row per user per alert). Inbox rows written by this task use `status='sent'`, `sent_at=now()` (they are inbox copies; delivery is logged on the topic/device rows), `route='/alerts/<id>'`. Topic delivery-log rows (`user_id` NULL, `topic` set) stay as TASK-04 defined them.

Seed (dev only, fictional): one alert per severity, one pending Warning with one approval, one expired, one retracted, one superseded pair, one SACHET draft with empty Gujarati; extra-ward subscriptions for two sample citizens; inbox rows of every kind for the sample citizen.

### 5.3 API Contracts

Base `/api/v1`, v1 error envelope `{error:{code,message,details?,requestId}}`. Times are ISO-8601 UTC in JSON; the app formats in Asia/Kolkata.

| Method | Path | Auth | Request | Response | Errors | Rate limit |
|---|---|---|---|---|---|---|
| GET | `/alerts` | None | `wards=12,15` (1–6 ids, required) · `active=true\|false` · `cursor` · `limit` ≤ 50 | `{items:[AlertDto], nextCursor}` — active: published, `valid_to > now`, critical first then `valid_from`; past: expired/retracted/superseded in last 30 days, newest first | 400, 429 | 120/IP/min |
| GET | `/alerts/{id}` | None | — | `AlertDto` + `wards:[{id,number,nameEn,nameGu}]`, `zone`, `supersededById` | 404 (drafts and pending are 404 publicly) | 120/IP/min |
| GET | `/me/subscriptions` | Citizen | — | `{homeWardId, extraWardIds:[], mutedTypes:[], criticalOnly}` | 401 | 120/user/min |
| PUT | `/me/subscriptions` | Citizen | `{extraWardIds ≤ 5 distinct, ≠ home ward, mutedTypes:[alert_type], criticalOnly}` | 200 same shape + `customPreferences: bool` | 400 `VALIDATION_FAILED`, 401 | 30/user/h |
| GET/PUT | `/devices/{installId}/subscriptions` | Optional user (visitor) | PUT `{homeWardId, extraWardIds, mutedTypes, criticalOnly}` | 200 same shape; 404 unknown install; signed-in callers are told to use `/me/subscriptions` (409) | 400, 404, 409 | 30/IP/h |
| GET | `/me/notifications` | Citizen | `cursor`, `limit` ≤ 50 | `{items:[{id,kind,refId,route,title,body,createdAt,readAt,alert?:{severity,status}}], unreadCount, nextCursor}` — user rows only, `created_at ≥ now − 90 days`; `title`/`body` in the user's language; `kind=alert` rows return the alert's live title and status | 401 | 120/user/min |
| POST | `/me/notifications/read` | Citizen | `{ids:[uuid] ≤ 100}` or `{all:true}` | 200 `{unreadCount}`; only the caller's rows; idempotent | 400, 401 | 120/user/min |
| GET | `/staff/alerts` | Moderator, Admin | `status`, `origin`, `cursor` | `{items:[StaffAlertDto], counts:{draft,pending_approval,published}}` | 401, 403 | 300/actor/min |
| POST | `/staff/alerts` | Moderator, Admin | composer body (below) | 201 `StaffAlertDto` (status `draft`) | 400, 403 | 300/actor/min |
| PATCH | `/staff/alerts/{id}` | Moderator, Admin | partial composer body | 200; editing a `pending_approval` alert returns it to `draft` and clears `approved_by` | 404, 409 `ALERT_STATE_INVALID` (published/expired/retracted are immutable) | 300/actor/min |
| POST | `/staff/alerts/{id}/submit` | Moderator, Admin | — | 200 status `pending_approval` | 409, 422 `ALERT_INCOMPLETE` (missing Gujarati, past `valid_to`, span > max) | 300/actor/min |
| POST | `/staff/alerts/{id}/approve` | see §5.5 | — | 200 with `approvedBy`, `approvalsNeeded` | 403 `ALERT_SECOND_APPROVER_ADMIN`, 409 `ALERT_ALREADY_APPROVED`, 409 `ALERT_STATE_INVALID` | 300/actor/min |
| POST | `/staff/alerts/{id}/publish` | see §5.5 | — | 200 status `published`, `delivery:{held:bool, sendAfter?}` | 409 `ALERT_APPROVALS_MISSING`, 409 `ALERT_STATE_INVALID`, 422 `ALERT_INCOMPLETE` | 300/actor/min |
| POST | `/staff/alerts/{id}/retract` | Moderator, Admin | `{reason 5–200}` | 200 status `retracted` | 409 (not published) | 300/actor/min |
| POST | `/staff/alerts/{id}/supersede` | Moderator, Admin | — | 201 new draft copying the old one with `supersedes_id` set | 409 (old not published, or already superseded) | 300/actor/min |

Composer body (Zod): `type`, `severity`, `titleEn`, `titleGu`, `bodyEn`, `bodyGu`, `sourceName`, `sourceUrl` (https, ≤ 500), `validFrom`, `validTo` (`validTo > now`, `validTo > validFrom`, span ≤ 14 days, `validFrom ≥ now − 1 h`), `target: {scope:'wards', wardIds:[1..48]} | {scope:'zone', zoneId} | {scope:'city'}`.

`AlertDto`: `id, type, severity, titleEn, titleGu, bodyEn, bodyGu, sourceName, sourceUrl, validFrom, validTo, target:{scope, wardIds, zoneCode?}, status ('published'|'expired'|'retracted'), isActive, publishedAt, retractedAt, retractionReason, supersedesId, supersededById, origin`. A published alert whose `valid_to` has passed is returned as `expired` even before the job runs.

New error codes in `src/lib/errors`: `ALERT_STATE_INVALID` 409 "This alert can't be changed in its current state." · `ALERT_INCOMPLETE` 422 "Fill in both languages and a valid time window first." · `ALERT_APPROVALS_MISSING` 409 "This alert still needs approval." · `ALERT_ALREADY_APPROVED` 409 "You've already approved this alert. Another person must give the second approval." · `ALERT_SECOND_APPROVER_ADMIN` 403 "The second approval for Warning and Critical alerts must come from an admin." (`FORBIDDEN` 403 comes from TASK-04.)

**Publish pipeline** (one transaction, then pushes after commit):
1. Lock the row (`SELECT … FOR UPDATE`); check status `pending_approval` and approvals; set `published`, `published_at`; if `supersedes_id` set, the old alert gets `status='expired'`, `valid_to=now()`.
2. Inbox fan-out with one set-based `INSERT … SELECT … ON CONFLICT DO NOTHING`: active users whose home ward or extra-ward subscription is in `alert_wards` (city: all active users); both languages copied; `route='/alerts/<id>'`. Inbox rows are written regardless of mute settings.
3. Quiet hours: if `now` (Asia/Kolkata) is in 22:00–07:00 and severity ≠ `critical` → `sendAfter` = next 07:00 for every send below (TASK-04 stores them `queued`; `push:flush` sends them); else immediate.
4. Topic sends (devices with default preferences): `wards` → `notifyTopic('ward_<number>')` per ward; `zone` → `notifyTopic('zone_<code>')`; `city` → `notifyTopic('city_all')` (the push service appends `__gu`/`__en`). Message: `kind:'alert'`, `refId`, `route:'/alerts/<id>'`, title/body (body trimmed to 150), `channel` `critical_alerts` for Critical else `alerts`, Android notification `tag = alert:<id>` (added to `PushMessage` by this task) so a device on two matching topics shows one notification.
5. Filtered device sends (devices with custom preferences, which have opted out of alert topics): select devices with `fcm_token` whose area (home, extra wards, their zones, city) matches and whose preferences allow the alert (`type ∉ muted_types` and (`NOT critical_only` or severity = `critical`)); send through new `notifyDevices(deviceIds, msg)` in the push service (`sendEach` in batches of 500, one delivery-log row per batch with `ref_id`).
6. Retraction: if the alert's pushes were already sent, the same audiences get "Cancelled: <title>" / "રદ: <title>" (same quiet-hour rule); held sends still `queued` for this alert are withdrawn (`status='failed'`, `error_code='alert_withdrawn'`). Expiry and supersede withdraw held sends the same way.

**Jobs** (on the `src/jobs` runner: `JOBS_ENABLED`, one advisory lock per job, `npm run jobs:run -- <name>`): `alerts-expire` every minute — `UPDATE alerts SET status='expired' WHERE status='published' AND valid_to <= now()` + withdraw held sends; `alerts-ingest-sachet` every `SACHET_POLL_MINUTES` when enabled; `alerts-ingest-imd` every 30 min when enabled.

**SACHET ingestion (P1):** GET `SACHET_FEED_URL` (HTTPS, 10 s timeout, ≤ 2 MB, `If-Modified-Since`/`ETag`, no cross-host redirects, User-Agent `Saarthee/2 (+contact)`) → for each item fetch the CAP XML link (same limits) → parse (*candidate* `fast-xml-parser`). Keep an item if any `<info><area>` has `areaDesc` matching `/ahmedabad|અમદાવાદ/i` **or** a `<polygon>` that `ST_Intersects` the union of ward geometries. Skip `msgType=Cancel` (log only), items whose `expires` has passed, and identifiers already stored (`origin='sachet'`, `origin_ref=<identifier>`). Map: severity Extreme→`critical`, Severe→`warning`, Moderate→`advisory`, Minor/Unknown→`info`; event containing heat→`heat`, rain/flood/thunder/cyclone→`rain_flood`, else `other`. Create a **draft**: `title_en` from `headline` (trimmed to 80), `body_en` from `description` (trimmed to 500), Gujarati from an `info` block with `language` starting `gu` else empty, `source_name = "NDMA SACHET (<senderName>)"`, `source_url` = CAP link, `valid_from = onset|effective|sent`, `valid_to = expires`, `area` = polygon, target = wards whose geometry intersects the polygon (none → `city`). Never calls submit/approve/publish. IMD adapter implements the same `AlertSource` interface (`fetchDrafts(): Promise<DraftInput[]>`) once access and a sample response exist; until then it is not registered.

### 5.4 UI Surfaces & States

Severity visuals (DS §2, tokens from TASK-03 — no literals): Info `info` icon on #1F5FAE/#E5EEFA · Advisory `campaign` #6F5A00/#FBF5D9 · Warning `warning` #A34A00/#FFEEDD · Critical `emergency`, **solid** #B3261E banner with white text. Non-critical cards are tinted cards with the severity icon and **no side bar** (DS §2). Alert cards and banners use radius 18; severity chips are pills; icons are Material Symbols Rounded; card titles in Mukta Vaani titleMedium, screen titles in Baloo Bhai 2 headlineSmall (DS §3). Screens use the white app bar with a 1 px `border` bottom line once scrolled (DS §5). Severity is always icon + word ("Info / માહિતી", "Advisory / સૂચના", "Warning / ચેતવણી", "Critical / ગંભીર" — Gujarati to be checked by the native editor).

| Route | Content | States |
|---|---|---|
| `/alerts` (Alerts tab) | App bar "Alerts" + settings action; segmented "Active" / "Past"; Critical alerts first as `SeverityBanner`, others as `AlertCard` (severity, title, area "Ward 12 Paldi" / "West zone" / "All of Ahmedabad", validity "Today 10:00–16:00" / "Until Sat 5 Oct, 18:00", `SourceLine`); footer `IndependenceFooter` | loading: 3 skeleton cards; empty active: icon + "No active alerts for your wards." + "Alert settings"; empty past: "No alerts in the last 30 days."; error: "We couldn't load alerts." + "Try again"; offline: last loaded list + offline banner; visitor: uses the device's chosen ward |
| `/alerts/:id` | `SeverityBanner`; title; body; "Where" (ward list / zone / whole city); "When" (validity); "Source: <name> (link) · Relayed by Saarthee"; `IndependenceFooter`; "Turn off alerts like this" → settings with this type highlighted | expired: grey banner "This alert has ended."; retracted: "Cancelled by Saarthee: <reason>"; superseded: "There is a newer update" → link; 404: "This alert isn't available."; offline: cached copy if opened before |
| `/alerts/settings` | "Your wards": home ward (fixed, "Change in profile") + up to 5 extra via ward picker ("Add a ward"); "Alert types": 8 switches (Water cut, Water timing change, Road closure, Heat, Rain and flooding, Health, Civic drives, Other); switch "Only critical alerts"; info text "Between 10 pm and 7 am we hold non-critical alerts until 7 am. Critical alerts always come through." | signed out: settings saved for this phone (`/devices/{installId}/subscriptions`) + "Sign in to keep these settings on all your devices."; note under types "Muted alerts still appear in your notifications list."; saving: switch shows progress, reverts with snackbar "Couldn't save. Try again." on error; offline: changes saved locally and synced on reconnect; 6th ward → "You can add up to 5 extra wards." |
| `/me/notifications` (bell in app bar, badge = unread count, max "9+") | "Notifications"; groups "Today" / "Earlier"; unread rows bold with a `primary` dot (and "Unread" semantics label); icon by kind; tap → mark read → open alert / issue / initiative; swipe a row end-to-start → mark read (semantics custom action "Mark as read" for TalkBack); "Mark all as read" | signed out: "Sign in to see updates about your reports and alerts." + "Sign in"; empty: "No notifications yet."; loading skeleton rows; error + "Try again"; target gone: "This item is no longer available." |
| `/staff/alerts` | Tabs "Drafts" (badge for feed drafts "From NDMA SACHET"), "Awaiting approval", "Published", "Ended"; rows: severity chip, title, area, validity, approvals "1 of 2" | empty per tab; 403 → "You don't have access to this page."; loading; error |
| `/staff/alerts/new`, `/staff/alerts/:id` | Form (labels above fields, "(optional)" none — all required): Type, Severity (radio with help: "Warning and Critical need two approvers"), Title (English) 0/80, Title (ગુજરાતી) 0/80, Message (English) 0/500, Message (ગુજરાતી) 0/500, Source name, Source link, Valid from, Valid until (IST pickers), Area (Wards multi-select / Zone / Whole city); live preview of the citizen card in both languages; approval panel ("Approved by <name> (moderator), 3 Oct 14:05 · Needs 1 more approval from an admin"); actions by state: "Save draft", "Send for approval", "Approve", "Publish now", "Retract", "Create update" | error summary at top with links to fields (focus moves there); in-flight buttons disabled with progress; read-only when published/ended; confirm dialogs for Publish ("This will notify everyone in <area> now." / "…at 7:00 am (quiet hours).") and Retract (reason field) |

Device topics (extends the TASK-04 topic manager; all with the `__<lang>` suffix): default preferences → `ward_<home>`, `ward_<extra>` for each extra ward, `zone_<code>` for the zones of home and extra wards, `city_all`; custom preferences (any muted type or "Only critical alerts") → unsubscribe all `ward_`/`zone_`/`city_all` topics and rely on the server's filtered device sends. Uses TASK-04 channels `critical_alerts` and `alerts`; tap opens `/alerts/:id` (already in the TASK-04 route allow-list).

In-app alert banner (`InAppAlertBanner`): shown when the TASK-04 foreground message stream delivers `kind:'alert'` (or the active alerts list gains a new id) while the app is open, on any citizen screen. It sits directly under the current app bar (on Home, under the green header's top row), full width minus 16 dp gutters, radius 18: Critical as the solid `SeverityBanner`, others as a tinted compact `AlertCard` (severity icon + word, title, "View"). Tap → `/alerts/:id`; swipe up or the close button dismisses; one banner at a time (a newer one replaces it; Critical always wins). Live region announces "New critical alert: <title>".

#### Motion (REQ-F-065, DS §6)

All durations and curves come from TASK-03 `SaartheeMotion`; no `Duration(` literal in `lib/features/**`. With reduced motion (system "Remove animations" or the in-app Animations switch) every item becomes an instant change or a ≤ 100 ms cross-fade with identical content.

| Moment | Behaviour | Tokens / helper | Reduced motion |
|---|---|---|---|
| New alert while open | Banner slides down from under the app bar (translate-Y from −100% of its height + fade, clipped to the area below the app bar) with `springIn`; dismissal slides it back up over `medium` | `springIn`, `medium` | Banner appears/disappears at once |
| Critical attention | After the banner settles, exactly one slow attention pulse: a white/`error`-tint glow ring expands and fades (or scale 1.0 → 1.02 → 1.0) over two `long` segments, then stops. Never repeated, never looped; no blinking (< 3 flashes/s) | `long`, `MotionCheck`-style one-shot controller | No pulse |
| Inbox swipe-to-read | Swiping a row end-to-start past the threshold marks it read: the row compresses (transform scale 0.97 + `surfaceAlt` reveal behind it, `instant`) and springs back (`springIn`), the title weight cross-fades bold → regular and the unread dot fades out (`short`); the row stays in the list. "Mark all as read" fades every dot (`short`, no stagger) | `instant`, `springIn`, `short` | Dot and weight change at once |
| Badge count | The bell badge (`unreadCount`, max "9+") rolls to the new number (vertical digit roll, `short`); at 0 it fades out | `RollingCount` (`short`) | Number swaps at once |

ARB key prefixes: `alerts*`, `alertSeverity*`, `alertType*`, `inbox*`, `staffAlerts*`, `sourceLine`, `independenceLine` (gu + en for every key; DS §1 independence text verbatim).

### 5.5 Permissions & Roles

| Action | Visitor | Citizen | Moderator | Admin | Representative |
|---|---|---|---|---|---|
| Read published/expired/retracted alerts | ✅ | ✅ | ✅ | ✅ | ✅ |
| Manage own subscriptions / inbox | device subscriptions only | ✅ | ✅ | ✅ | ✅ |
| Create, edit, submit drafts; supersede | ❌ | ❌ | ✅ | ✅ | ❌ |
| Approve Info/Advisory (creator may approve) | ❌ | ❌ | ✅ | ✅ | ❌ |
| First approval of Warning/Critical | ❌ | ❌ | ✅ | ✅ | ❌ |
| Second approval of Warning/Critical (different person from the first) | ❌ | ❌ | ❌ | ✅ | ❌ |
| Publish Info/Advisory / Warning/Critical | ❌ | ❌ | ✅ / ❌ | ✅ / ✅ | ❌ |
| Retract any published alert | ❌ | ❌ | ✅ | ✅ | ❌ |

Staff identity contract (shared with TASK-09/TASK-10/TASK-11): staff routes use TASK-04's `requireRole(...roles)`, extended so that it also accepts a v1 admin JWT as role `admin` and sets `req.staff = {actorId, actorKind:'user'|'admin_user', role, wardIds}` (current DB role, status `active`, token version checked). The extension is made by whichever of TASK-08/09/10 lands first, exactly to this contract; TASK-10 owns the authorisation matrix and its tests. Every staff mutation here calls the audit helper with actions `alert_created`, `alert_updated`, `alert_submitted`, `alert_approved`, `alert_published`, `alert_retracted`, `alert_superseded` (actor, role, alert id only — no titles or bodies).

### 5.6 Assumptions

- ASSUMPTION: The creator may give the only approval for Info/Advisory and the first approval for Warning/Critical; the second must be an admin and a different person — Spec §3 (moderator: first approval; admin: second) + D3 "two-person". Two people always touch a Warning/Critical alert.
- ASSUMPTION: Publishing Warning/Critical is admin-only; retraction is open to moderators too, because a fast retraction reduces harm — spec silent.
- ASSUMPTION: Quiet hours are global (Asia/Kolkata) and decided on the server at publish time; held sends use TASK-04's `sendAfter` and go out on the first `push:flush` after 07:00 (≤ 07:05) if the alert is still valid — Spec §9 gives the window but not the mechanism.
- ASSUMPTION: "Mute non-critical" and "categories of alerts" are applied on the server: devices with custom preferences leave the alert topics and get filtered per-device sends (`notifyDevices`), because TASK-04 uses notification messages (shown by the OS, so the phone cannot filter them) and D9 fixes the topic names. Preferences are stored per user, or per device for visitors (Spec §6 `subscriptions` has `device_id`). Inbox rows are written regardless of mute settings.
- ASSUMPTION: Inbox rows for alerts are fanned out per user at publish (set-based insert) so read state is per user; fine at pilot scale (≤ 100k users). Revisit with a per-user read table if fan-out exceeds 2 s.
- ASSUMPTION: The inbox route is `/me/notifications` (matches the API and TASK-04's tap allow-list), opened from the app-bar bell (DS §5); Spec §8 lists no route for it.
- ASSUMPTION: Composer requires both Gujarati and English before submit (Gujarati-first audience); feed drafts may start with English only.
- ASSUMPTION: Maximum validity 14 days (`ALERT_MAX_VALIDITY_DAYS`); "Past" shows 30 days.
- ASSUMPTION: `created_by` / `approved_by` / `retracted_by` hold staff actor ids without FKs because staff may be v1 `admin_users` or v2 `users` (Spec §7 keeps v1 admin login); both are UUID v4.
- ASSUMPTION: SACHET feed structure is taken from a captured sample saved under `apps/api/test/fixtures/sachet/`; if it differs (inline CAP, Atom), only the parser changes, not the contract. Superseding a CAP alert by a newer CAP message creates a new draft; moderators supersede manually.
- ASSUMPTION: The in-app banner auto-hides after 8 s for Info/Advisory/Warning and stays until dismissed or opened for Critical; the timeout lives in a core constant (`lib/core/config/timings.dart`, not a motion token and not a literal in `lib/features/**`). DS §6 does not specify dismissal.
- ASSUMPTION: "One slow attention pulse" = one out-and-back of 2 × `SaartheeMotion.long` (900 ms total) after the slide-in settles.
- ASSUMPTION: Swipe-to-read marks read only (no delete; no undo); swiping an already-read row does nothing. TalkBack users get the same via a custom semantics action.
- ASSUMPTION: The digit-roll widget `RollingCount` comes from TASK-03 if it provides one; otherwise whichever of TASK-07/TASK-08/TASK-12 lands first creates it in `lib/core/widgets/rolling_count.dart` and the others reuse it.
- ASSUMPTION: TASK-08 does not depend on TASK-06; if TASK-06's `src/jobs` runner has not landed, this task creates it with TASK-06's contract (`JOBS_ENABLED`, advisory lock per job, `npm run jobs:run -- <name>`) and TASK-06 reuses it.

## 6. Implementation Steps

1. **Read and confirm contracts.** Check the landed TASK-04 names (push service, `notifications` columns and kind enum, topic helper, `requireUser`) and TASK-02 ward/zone fields; adjust the names in this file if they differ, never the behaviour.
2. **Migration `<ts>_v2_alerts`.** Enums, `alerts`, `alert_wards`, `subscriptions`, `notifications` additions, CHECKs and indexes per §5.2; Prisma models (`area` as `Unsupported("geometry(MultiPolygon,4326)")?`); `prisma generate`, typecheck.
3. **Seed.** Extend the v2 seed module with the fictional alerts, subscriptions and inbox rows of §5.2; `npm run db:reset` works.
4. **Clock + quiet hours.** `src/lib/clock` (`now()` injectable in tests) and `src/modules/alerts/quietHours.ts` (`isQuietHours(date)`, `nextQuietEnd(date)`) for Asia/Kolkata with unit tests at 21:59, 22:00, 06:59, 07:00.
5. **Staff identity.** If not yet done, extend TASK-04's `requireRole` per §5.5; add error codes; register audit actions.
6. **Public + citizen alerts API.** `src/modules/alerts`: Zod schemas, `GET /alerts`, `GET /alerts/{id}` (drafts/pending → 404, effective expiry), subscriptions GET/PUT (extra wards validated against `wards`, home ward excluded), inbox list (90-day window, live alert titles via join, `unreadCount`), mark-read.
7. **Staff alerts service.** `src/modules/staff-alerts`: state machine `draft → pending_approval → published → expired|retracted`, edit-resets-approvals, approval rules of §5.5 (row lock to stop two approvals racing), supersede copy, target expansion into `alert_wards`.
8. **Publish pipeline.** Transaction + fan-out SQL + topic selection + data payload + quiet-hour hold + retraction push, through the TASK-04 push service only.
9. **Push service + jobs.** Add `notifyDevices` and the optional `tag` to the TASK-04 push service (memory driver records both); held-send withdrawal helper; `src/jobs` runner if absent; register `alerts-expire`; script `npm run alerts:ingest -- --source sachet [--dry-run]` for manual runs.
10. **SACHET poller (P1).** Capture a real feed + 2 CAP files into fixtures; implement `AlertSource` + SACHET adapter + mapping + polygon intersection; register `alerts-ingest-sachet` when `SACHET_ENABLED=true`. IMD adapter only after access is granted (record the request date in §13).
11. **API tests** T-08-01…T-08-16 green; run M-08-01, M-08-02.
12. **App data layer.** `features/alerts/data` (API client, DTOs, cache of last list per ward set), `application` providers (alerts list, detail, subscriptions with local store for visitors, inbox + unread count).
13. **Shared widgets.** `lib/core/widgets/alerts/`: `SeverityBanner`, `AlertCard`, `SourceLine`, `IndependenceFooter`, validity formatter (Asia/Kolkata, locale-aware); widget tests.
14. **Citizen screens.** `/alerts` (replace TASK-03 placeholder), `/alerts/:id`, `/alerts/settings`, `/me/notifications` + app-bar bell badge; all ARB strings gu + en.
15. **Push handling.** Extend the TASK-04 topic manager per §5.4 (extra wards, zones, opt-out for custom preferences; diff against the stored set; re-post `POST /devices` with topics); visitors' preferences via `/devices/{installId}/subscriptions`; tap routing to `/alerts/:id`.
16. **Staff screens.** `features/staff/alerts/`: list, composer, preview, approval panel, confirm dialogs; routes `/staff/alerts*` guarded by role (UX only). If TASK-10's shell is not there yet, wrap in a minimal `StaffPageScaffold` (`features/staff/shared/`) and register a nav item via the staff nav registry contract (`StaffNavItem(route, labelKey, icon, roles)`) for TASK-10 to render.
17. **Independence audit (REQ-S-011).** Check About (TASK-03), AMC hand-off (TASK-05) and services (TASK-12, if landed) show `IndependenceFooter`/source line; add it where missing; `grep -ri "amc.*logo\|amc_logo" apps/mobile/assets apps/mobile/lib` returns nothing; record results in the coverage matrix (TASK-14 re-checks services).
18. **Alert motion (REQ-F-065).**
    1. `InAppAlertBanner` host (an overlay entry under the current app bar, mounted by the citizen shell) fed by the TASK-04 foreground message stream and new ids in the active-alerts provider; slide-in with `springIn`, slide-out with `medium`.
    2. Critical one-shot attention pulse (single forward + reverse of a controller using `SaartheeMotion.long`; disposed after; assert no `repeat()`).
    3. Inbox swipe-to-read (`Dismissible`-style gesture with `confirmDismiss` returning false so the row stays) → optimistic `POST /me/notifications/read`, row compress + spring back, dot fade, weight cross-fade; semantics action "Mark as read"; rollback on error with snackbar.
    4. Bell badge with `RollingCount`.
    5. Reduced-motion branches reading TASK-03's resolved `reduceMotion` flag; run the no-`Duration(`-literal test.
19. **Widget tests** W-08-01…W-08-08; emulator checks M-08-03…M-08-10 (motion recordings to `docs/demo/v2-evidence/motion/`); update coverage evidence.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Composer validation
- **Given** a moderator on `/staff/alerts/new`
- **When** they save with a 90-char title, an `http://` source link, `validTo` before `validFrom`, or a 20-day window, and submit with Gujarati empty
- **Then** the API returns 400 with field `details` (or 422 `ALERT_INCOMPLETE` on submit), the screen shows an error summary linking to each field, and no alert leaves `draft`

**AC-2** — Info/Advisory single approval
- **Given** a moderator's complete Advisory draft
- **When** the same moderator submits, approves and publishes it
- **Then** it becomes `published` with `approved_by` of length 1 and an `alert_published` audit line

**AC-3** — Warning/Critical two-person rule
- **Given** a Warning alert submitted and approved once by moderator M
- **When** M approves again, another moderator approves, someone publishes with one approval, and finally admin A approves and publishes
- **Then** the first three fail with 409 `ALERT_ALREADY_APPROVED`, 403 `ALERT_SECOND_APPROVER_ADMIN` and 409 `ALERT_APPROVALS_MISSING`; A's approval and publish succeed; a direct SQL update to `published` with one approver is rejected by the CHECK

**AC-4** — Edit resets approvals
- **Given** a Critical alert with one approval
- **When** its body is edited
- **Then** it returns to `draft`, `approved_by` is empty and it must be submitted again

**AC-5** — Topics and payload
- **Given** published alerts targeting wards 12 and 15, the West zone, and the whole city
- **When** each is published at 11:00 IST
- **Then** the memory push driver records sends to `ward_12` + `ward_15`, `zone_<west code>` and `city_all` (each as `__gu` and `__en`), with channel `critical_alerts` only for Critical, `tag = alert:<id>`, route `/alerts/<id>`, and one delivery-log row per base topic; a device with custom preferences in ward 12 gets one filtered device send instead

**AC-6** — Quiet hours
- **Given** the clock at 23:30 IST
- **When** an Advisory and a Critical alert are published
- **Then** the Critical is pushed immediately; the Advisory's sends are `queued` with `send_after` 07:00 IST next day, it is visible in `GET /alerts` and inboxes immediately, and `push:flush` at 07:00 sends it — or, if it was retracted or expired before then, its queued rows are `failed` with `error_code='alert_withdrawn'` and nothing is sent

**AC-7** — Auto-expiry
- **Given** a published alert with `valid_to` one minute ago
- **When** `GET /alerts?active=true` is called before and after the `alerts-expire` job runs
- **Then** it is never in the active list, appears under past as `expired`, and the row status is `expired` after the job

**AC-8** — Retract and supersede
- **Given** a published, pushed Warning
- **When** an admin creates an update (supersede), publishes it, and a moderator retracts another published alert with a reason
- **Then** the old alert is `expired` with `supersededById` and its detail shows "There is a newer update"; the retracted alert shows "Cancelled by Saarthee: <reason>" and a "Cancelled: …" push is sent to the same topics

**AC-9** — Alerts tab and detail
- **Given** a citizen with home ward 12, one Critical and two Info alerts active, one expired
- **When** they open Alerts and then an alert
- **Then** the Critical shows first as a solid red banner with `emergency` icon and the word "Critical"; Info cards are tinted (radius 18, severity icon + word, no side bar); Past lists the expired one; detail shows Where, When, "Source: <name> · Relayed by Saarthee" and the independence line; empty, loading, error and offline states match §5.4

**AC-10** — Subscription settings
- **Given** a signed-in citizen
- **When** they add 5 extra wards, try a 6th, mute "Road closure" and turn on "Only critical alerts"
- **Then** the 6th is refused with "You can add up to 5 extra wards."; `GET /me/subscriptions` returns the saved values with `customPreferences:true`; before muting, the phone was subscribed to the extra ward and zone topics; after muting it leaves the alert topics; a Road-closure Warning produces no push to that device but the alert is in the inbox; a Critical still arrives via a device send

**AC-11** — Visitor settings
- **Given** a visitor (no account)
- **When** they change alert settings
- **Then** settings are stored on the device and via `PUT /devices/{installId}/subscriptions`, topics follow them, filtered device sends respect them, and the screen shows "Sign in to keep these settings on all your devices."

**AC-12** — Inbox
- **Given** a citizen with notifications of kinds alert, issue_update and initiative, one 91 days old
- **When** they open `/me/notifications`, tap one, then "Mark all as read"
- **Then** the 91-day item is absent; the tapped item opens its target and becomes read; the badge and `unreadCount` drop to 0; another user's ids sent to `/me/notifications/read` change nothing

**AC-13** — SACHET drafts only
- **Given** the SACHET fixtures (one Ahmedabad heat alert, one Surat-only alert, one already-ingested identifier)
- **When** `npm run alerts:ingest -- --source sachet` runs twice
- **Then** exactly one draft exists with `origin=sachet`, severity mapped, source "NDMA SACHET (…)" and CAP link, wards from polygon intersection; nothing was submitted, approved, published or pushed; the second run creates nothing

**AC-14** — Source and independence everywhere
- **Given** any published alert, the About screen, the AMC hand-off screen and (if landed) a service page
- **When** each is viewed in Gujarati and English
- **Then** each shows the DS §1 independence line, alerts show source + validity, the API refuses an alert without `source_name`/`source_url`, and no AMC logo asset exists in the app

**AC-15** — Roles
- **Given** a citizen token, a representative token and no token
- **When** they call any `/staff/alerts*` endpoint
- **Then** they get 403, 403 and 401 respectively and nothing changes

**AC-16** — In-app alert banner motion
- **Given** a citizen with home ward 12 on Home with animations on
- **When** an Info alert for ward 12 is published, and later a Critical alert for ward 12 is published while they are on the Map tab
- **Then** each time a banner slides down from under the app bar with `springIn` showing the severity icon, word and title; the Info banner hides by itself after the set timeout; the Critical banner, as a solid red banner, pulses exactly once slowly after it settles and then stays still until dismissed or opened (no loop, no more than one flash); tapping opens `/alerts/:id`; TalkBack announces "New critical alert: <title>"

**AC-17** — Inbox swipe-to-read and rolling badge
- **Given** a signed-in citizen with 3 unread notifications (badge shows 3) and animations on
- **When** they swipe one row end-to-start, then use the TalkBack "Mark as read" action on another, then tap "Mark all as read"
- **Then** the swiped row compresses and springs back, stays in the list, its unread dot fades and its title becomes regular weight; the badge rolls 3 → 2 → 1 → 0 and then fades out; `unreadCount` from the API matches at every step; a failed request rolls the row and badge back with "Couldn't update. Try again."

**AC-18** — Alert motion with reduced motion
- **Given** the system "Remove animations" setting on (and separately the in-app Animations switch off)
- **When** the AC-16 and AC-17 steps are repeated
- **Then** the banner appears and disappears at once with no pulse, the dot, weight and badge change at once, the content and announcements are identical, and no `Duration(` literal exists in `lib/features/**`

### AC → Requirement

| AC | Requirements |
|---|---|
| AC-1 | REQ-F-035, REQ-D-009 |
| AC-2 | REQ-F-036 |
| AC-3 | REQ-F-036, REQ-D-009 |
| AC-4 | REQ-F-036 |
| AC-5 | REQ-F-037 |
| AC-6 | REQ-F-037 |
| AC-7 | REQ-F-037, REQ-D-009 |
| AC-8 | REQ-F-036, REQ-F-038 |
| AC-9 | REQ-F-038, REQ-S-011 |
| AC-10 | REQ-F-039, REQ-D-009 |
| AC-11 | REQ-F-039 |
| AC-12 | REQ-F-040, REQ-D-009 |
| AC-13 | REQ-F-041 |
| AC-14 | REQ-S-011 |
| AC-15 | REQ-F-035, REQ-F-036 |
| AC-16 | REQ-F-065, REQ-F-038 |
| AC-17 | REQ-F-065, REQ-F-040 |
| AC-18 | REQ-F-065 |

### 7.2 Non-Functional Checklist

- [ ] Severity always icon + word; colours only from DS §2 tokens; Critical banner contrast ≥ 4.5:1 (white on #B3261E 6.54)
- [ ] All alert, inbox and staff strings in ARB with gu + en; validity formatted in Asia/Kolkata in both locales
- [ ] Screens work at 2.0× font scale and 320 dp width; TalkBack reads "Critical alert: <title>, until <time>"; staff form error summary receives focus
- [ ] Alert titles/bodies, FCM tokens and notification bodies never logged; audit lines carry ids only
- [ ] `GET /alerts` p95 < 400 ms on seed data with 1,000 alerts (EXPLAIN uses the `alert_wards(ward_id)` and `(status, valid_to)` indexes)
- [ ] Fan-out for 50,000 seeded users completes < 2 s
- [ ] Jobs are single-runner (advisory lock verified by starting two API processes)
- [ ] Feed poller: timeouts, size cap and no auto-publish verified; poller failures logged without crashing the API
- [ ] Staff screens import providers only; no API client in `presentation/`
- [ ] Neem visuals only: alert cards radius 18 without side bars, pill chips, Material Symbols Rounded, Baloo Bhai 2 titles / Mukta Vaani body — all through TASK-03 tokens
- [ ] REQ-F-065 motion uses `SaartheeMotion` tokens only; only transform, opacity and colour animated; Critical pulse runs once and never loops
- [ ] Reduced motion (system and in-app switch) gives instant or ≤ 100 ms cross-fade equivalents

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-08-01 | API `typecheck` + `lint`; `dart format --set-exit-if-changed` + `dart analyze`; CI green | all |
| API (Vitest) | T-08-01 | Migration: CHECKs reject `valid_to <= valid_from`, `http://` source, published Warning with 1 approver, `scope=zone` without zone | AC-1, AC-3, AC-7 |
| API (Vitest) | T-08-02 | Composer Zod: lengths, https, 14-day span, missing Gujarati on submit → 422 | AC-1 |
| API (Vitest) | T-08-03 | Advisory: create → submit → approve (creator) → publish | AC-2 |
| API (Vitest) | T-08-04 | Warning: same-person second approval 409, moderator second 403, publish with 1 approval 409, admin approve + publish 200 | AC-3 |
| API (Vitest) | T-08-05 | Two concurrent approvals on one alert → exactly one recorded per actor (row lock) | AC-3 |
| API (Vitest) | T-08-06 | Edit pending alert → draft, approvals cleared | AC-4 |
| API (Vitest) | T-08-07 | Publish wards/zone/city → memory-driver topics (`__gu`/`__en`), channel, tag, route, delivery-log rows; custom-preference devices get filtered device sends only | AC-5, AC-10 |
| API (Vitest) | T-08-08 | Quiet hours with injected clock 23:30 / 06:59 / 07:00; queued with `send_after` → sent by `flushQueued`; retracted before 07:00 → withdrawn | AC-6 |
| API (Vitest) | T-08-09 | Effective expiry in reads; `alerts-expire` updates status and withdraws held sends | AC-7 |
| API (Vitest) | T-08-10 | Supersede and retract flows, retraction push, `supersededById` | AC-8 |
| API (Vitest) | T-08-11 | `GET /alerts` active/past ordering, drafts 404, `wards` validation, cursor paging | AC-9 |
| API (Vitest) | T-08-12 | Subscriptions PUT/GET: 5-ward cap, home ward excluded, unknown ward 400 | AC-10 |
| API (Vitest) | T-08-13 | Inbox: 90-day window, live alert title in user language, mark read own only, `{all:true}`, unreadCount | AC-12 |
| API (Vitest) | T-08-14 | Fan-out: home-ward user, extra-ward user, other-ward user, suspended user; second publish of same alert id inserts nothing | AC-5, AC-12 |
| API (Vitest) | T-08-15 | SACHET adapter on fixtures: filter, mapping, polygon → wards, de-dup, never publishes | AC-13 |
| API (Vitest) | T-08-16 | Role matrix for every `/staff/alerts*` route: none 401, citizen 403, representative 403 | AC-15 |
| Widget | W-08-01 | `SeverityBanner`/`AlertCard` for 4 severities: icon, word, solid vs tinted, semantics label | AC-9 |
| Widget | W-08-02 | Validity formatter: same day, multi-day, gu + en | AC-9 |
| Widget | W-08-03 | Alerts tab states: loading, empty, error, offline cache | AC-9 |
| Widget | W-08-04 | Settings: 6th ward refused, visitor sign-in prompt | AC-10, AC-11 |
| Widget | W-08-05 | Inbox: unread styling, mark all read, signed-out state | AC-12 |
| Widget | W-08-06 | Staff composer error summary focus and preview in both languages | AC-1 |
| Widget | W-08-07 | `InAppAlertBanner`: inject a fake foreground alert; banner offset is above its rest position at t=0 and at rest after pumping `SaartheeMotion.springIn`; Critical pulse: pump 2 × `SaartheeMotion.long` and assert the glow returns to rest and `hasScheduledFrame` is false afterwards (no loop); Info auto-hides after the timeout; semantics announcement fired; reduced-motion variant: after one `pump()` the banner is at rest and no pulse controller runs | AC-16, AC-18 |
| Widget | W-08-08 | Inbox swipe-to-read: drag a row, pump `SaartheeMotion.instant` + `springIn` → row back at scale 1, still present, dot opacity 0 after `SaartheeMotion.short`; badge `RollingCount` shows 2 after `short`; semantics action marks read; error rollback; reduced-motion variant: one `pump()` shows final state | AC-17, AC-18 |
| Manual | M-08-01 | `curl` the full Warning flow with two staff tokens; SQL check of `approved_by` | AC-3 |
| Manual | M-08-02 | `alerts:ingest --source sachet --dry-run` against the live feed; review mapped drafts | AC-13 |
| Manual | M-08-03 | Emulator: publish Critical to home ward with app killed → heads-up notification on `critical_alerts`; tap opens detail | AC-5, AC-9 |
| Manual | M-08-04 | Emulator: mute Road closure + critical-only, publish Warning road closure → no notification, inbox row present | AC-10 |
| Manual | M-08-05 | Emulator: add extra ward in another zone → `zone_` topic subscribed (log), alert for that zone arrives | AC-10 |
| Manual | M-08-06 | Set API clock/env to 23:30 IST, publish Advisory → no push until dispatch at 07:00 (advance clock) | AC-6 |
| Manual | M-08-07 | TalkBack + 2.0× font on Alerts tab, detail, settings, inbox, in Gujarati | AC-9, AC-14 |
| Manual | M-08-08 | Independence audit of About, hand-off, services; grep for AMC logo assets | AC-14 |
| Manual | M-08-09 | Emulator recordings (`adb shell screenrecord /sdcard/<name>.mp4`, `adb pull` to `docs/demo/v2-evidence/motion/`): `t08-banner-info.mp4`, `t08-banner-critical.mp4` (single slow pulse, no loop), `t08-inbox-swipe.mp4` (row compress, dot fade, badge roll) | AC-16, AC-17 |
| Manual | M-08-10 | Repeat M-08-09 with "Remove animations" on and with the in-app switch off; `t08-reduced-motion.mp4` | AC-18 |

## 9. Deliverables

- Migration `<ts>_v2_alerts`, Prisma models, seed additions.
- API modules `alerts`, `staff-alerts`; `requireRole` staff extension (if first); `src/lib/clock`; `src/jobs` runner (if first); push service `notifyDevices` + `tag`; alert jobs; SACHET adapter + fixtures; script `alerts:ingest`.
- App: `features/alerts` (Alerts tab, detail, settings), `features/inbox` (`/me/notifications`, bell badge), shared alert widgets, topic manager extension, `features/staff/alerts` screens.
- Alert motion (REQ-F-065): `InAppAlertBanner` with one-shot Critical pulse, inbox swipe-to-read, rolling bell badge, reduced-motion variants.
- Vitest suites T-08-01…16, widget tests W-08-01…08, manual evidence M-08-01…10 (motion recordings in `docs/demo/v2-evidence/motion/`).
- Coverage matrix evidence for 10 requirements; IMD access request recorded.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/api/prisma/migrations/<ts>_v2_alerts/migration.sql`, `apps/api/prisma/schema.prisma` | New / Modified |
| `apps/api/prisma/seed*` (v2 seed module) | Modified |
| `apps/api/src/modules/{alerts,staff-alerts}/` | New |
| `apps/api/src/modules/alerts/sources/{sachet,imd}.ts` | New |
| `apps/api/src/lib/clock/`, `src/jobs/` (if absent), `src/middleware/requireRole.ts`, `src/lib/push/` | New / Modified |
| `apps/api/src/lib/errors/`, `src/lib/audit/`, `src/routes.ts`, `src/server.ts`, `src/config/` | Modified |
| `apps/api/scripts/alerts-ingest.ts`, `src/jobs/alerts-*.ts`, `apps/api/package.json` | New / Modified |
| `apps/api/test/{alerts,staff-alerts,sachet}*.test.ts`, `apps/api/test/fixtures/sachet/` | New |
| `apps/mobile/lib/features/{alerts,inbox}/`, `lib/features/staff/alerts/`, `lib/features/staff/shared/` | New |
| `apps/mobile/lib/core/widgets/alerts/` (incl. `in_app_alert_banner.dart`), `lib/core/push/` (topic manager extension, foreground stream hook) | New / Modified |
| `apps/mobile/lib/core/widgets/rolling_count.dart` (only if absent), `lib/core/config/timings.dart` | New / Modified |
| `docs/demo/v2-evidence/motion/t08-*.mp4` | New |
| `apps/mobile/lib/router/{citizen_routes,staff_routes}.dart` | Modified / New |
| `apps/mobile/lib/core/l10n/app_en.arb`, `app_gu.arb` | Modified |
| `apps/mobile/test/alerts/`, `test/inbox/`, `test/staff/alerts/` | New |

## 11. Related Documentation

- `docs/v2/saarthee-v2-spec.md` §2 (D3, D9), §3, §6, §7, §8, §9, §11
- `docs/v2/design-system.md` DS §1 (independence line), §2 (alert severity), §3 (typography), §4 (radii, icons), §5 (Alert card, Banners, Toast), §6 (Motion: New alert while open, Inbox, rules), §7 (accessibility), §8 (Alert flow), §9
- `docs/tasks-v2/TASK-03-design-system-shell.md` — `SaartheeMotion`, motion helpers, reduced-motion switch
- `docs/tasks-v2/TASK-04-*.md` — push service, `notifications`, topic helper
- `docs/tasks-v2/TASK-10-staff-console.md` — staff shell, role matrix, audit helper
- NDMA SACHET CAP feed: https://sachet.ndma.gov.in/CapFeed · OASIS CAP 1.2 standard

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| A wrong Warning/Critical alert goes out | Loss of trust, possible panic | Two-person rule in service + DB CHECK; preview in both languages; fast retraction with push |
| Per-device filtered sends grow with users who customise preferences | Slow publish, FCM quota | Batches of 500 via `sendEach`; most devices stay on topics; measure in TASK-14 |
| Topic-based delivery cannot honour per-user quiet hours | Some users want different hours | Global quiet hours per spec; revisit with per-token sends after pilot |
| SACHET feed format or availability changes | No feed drafts | Parser behind `AlertSource`; failures logged; manual composer unaffected |
| IMD access not granted | Fewer automatic drafts | SACHET meanwhile (Open Question 4) |
| Fan-out cost grows with users | Slow publish | Set-based insert; measure at 50k users; move to per-user read table if needed |
| Gujarati wording errors in urgent alerts | Misunderstanding | Gujarati required for submit; native editor review of fixed strings before TASK-14 |
| Users unsure why muted alerts still appear in the inbox | Confusion | Settings copy: "Muted alerts still appear in your notifications list." |
| Critical attention pulse feels alarming or repeats | Anxiety; DS §6 "no loop" broken | One-shot controller, W-08-07 asserts no scheduled frames after; nothing flashes > 3/s |
| Swipe gesture undiscoverable or inaccessible | Inbox stays unread | Tap still marks read; "Mark all as read"; TalkBack custom action |

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
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-08` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `V2-TASK-08: …`
- [ ] Validator passes
- [ ] Alert cards and banners match Neem v2.2 (radius 18, no side bars, Rounded icons, Neem type)
- [ ] REQ-F-065 motion implemented with `SaartheeMotion` tokens only; W-08-07 and W-08-08 pass
- [ ] Reduced-motion variants verified (system setting and in-app switch)
- [ ] Motion screen recordings saved to `docs/demo/v2-evidence/motion/` (M-08-09, M-08-10)
