# TASK-12: AMC Services Directory & Civic Initiatives

| Field | Value |
|---|---|
| Task ID | TASK-12 |
| Status | Not Started |
| Priority | P1 |
| Size | M |
| Depends On | TASK-02, TASK-03, TASK-04 |
| Blocks | TASK-14 |
| Requirement IDs | REQ-F-057, REQ-F-058, REQ-F-059, REQ-F-060, REQ-F-061, REQ-D-010 |
| Primary Spec Refs | Spec §1 (independence), §3, §6 (`services`, `initiatives`, `rsvps`), §7 (Services & initiatives, Staff), §8 (`/services`, `/initiatives`), §9 (initiative reminders, quiet hours), §11; DS §1, §5, §7 |
| Last Updated | 2026-10-03 |

## 1. Objective

Make Saarthee the easiest way to find an AMC service and to join a civic drive. Citizens get a bilingual directory of the most-used AMC services — each with a plain-language summary, numbered how-to steps, a clear "online" or "visit your ward office" flag, the official link, and the address of their ward office — and every page says it is an independent guide that opens AMC's own website. A monthly link checker flags broken links for staff. Citizens see upcoming tree drives, clean-ups and health camps with organiser and source, RSVP after signing in, and get a push reminder 24 hours before; staff can mark attendance. Staff manage services, initiatives and seasonal tips (property-tax rebate window, monsoon, heat) through role-guarded APIs and minimal staff screens that TASK-10's console hosts.

## 2. Scope

### In Scope
- Migration creating `services`, `initiatives`, `rsvps` (REQ-D-010) and `service_tips` (P2, §5.6).
- Production seed of verified services (`npm run services:seed`, idempotent upsert by slug) and fictional dev-seed initiatives/tips.
- Public API: `GET /services`, `GET /services/{slug}` (with ward office), `GET /services/tips`, `GET /initiatives`, `GET /initiatives/{id}`, `POST/DELETE /initiatives/{id}/rsvp`.
- Staff API (role-guarded): CRUD `/staff/services`, `/staff/initiatives`, `/staff/tips`; link report and re-check; RSVP list and attendance marking.
- Scripts: `services:check-links` (monthly), `initiatives:remind` (every 15 min) using the TASK-04 push service.
- App: `/services`, `/services/:slug`, `/initiatives`, `/initiatives/:id` with RSVP (via `ensureSignedIn`), Home seasonal tip card; replace placeholders P-03 (Home drives + service shortcuts) and P-08 (My Ward services and drives).
- Minimal staff screens `/staff/services`, `/staff/initiatives`, `/staff/tips` (list + form + attendance) mounted in TASK-10's staff navigation (contract in §5.4).
- Vitest + Supertest tests for every endpoint and both scripts; Flutter widget tests for the citizen screens.

### Out of Scope
- Staff console shell, side navigation, role management and audit-log viewer — TASK-10 (this task writes audit entries through the existing helper).
- `GET /feed` composition — TASK-07 (it may include tips and drives from these services; see §5.6).
- Alerts of type `initiative` — TASK-08.
- Payments or any AMC system integration (Spec §1).
- Ward office data itself — TASK-02 (`wards.office_address`, `office_phone`).
- Notification inbox UI — TASK-08 (reminders are logged in `notifications` and appear there).

## 3. Prerequisites

- TASK-02: `wards`/`zones` with `office_address`, `office_phone`, `GET /wards/{id}`, `GET /geo/locate`.
- TASK-03: tokens, components (`ListRow`, `EmptyState`, `NoticeBanner` independence variant, `StatusChip` style), shell placeholders P-03 and P-08.
- TASK-04: `requireUser`, `optionalUser`, `requireRole`, `ensureSignedIn`, push service `notifyUser` with `sendAfter`, `notifications` table, privacy export/erasure registries.
- TASK-01: test harness, dev seed entry point, audit helper `src/lib/audit`.
- API env: `LINK_CHECK_USER_AGENT="SaartheeLinkCheck/1.0 (+mailto:<GRIEVANCE_EMAIL>)"`, `LINK_CHECK_TIMEOUT_MS=10000`, `INITIATIVE_REMINDER_HOURS=24`, `QUIET_HOURS="22:00-07:00"`, `TZ_CITY=Asia/Kolkata`.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-02 | Ward ids for initiatives and tips, ward office address/phone for service detail |
| TASK-03 | Design system, shell placeholders P-03/P-08, bilingual ARB setup |
| TASK-04 | Citizen auth for RSVP, role guard for staff APIs, push service for 24 h reminders, privacy registries for `rsvps` |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-057 | AMC services directory: categories, service pages (gu/en) with online/offline flag, official link, how-to steps | Spec §6, §8 |
| REQ-F-058 | Monthly link check marks broken service links for staff review | Spec §6 |
| REQ-F-059 | Initiatives (tree drives, clean-ups, health camps) list and detail with organiser and source | Spec §6, §8 |
| REQ-F-060 | RSVP to initiatives with reminder 24 h before; staff can mark attendance | Spec §6, §9 |
| REQ-F-061 | Seasonal service tips on Home (property-tax rebate window, monsoon, heat) managed by staff | Spec §8 |
| REQ-D-010 | `services`, `initiatives`, `rsvps` tables | Spec §6 |

### 5.2 Data Contracts

Migration `apps/api/prisma/migrations/<ts>_v2_services_initiatives/`:

`services`

| Column | Type | Notes |
|---|---|---|
| id | UUID PK | |
| slug | TEXT UNIQUE NOT NULL | `^[a-z0-9-]{3,60}$` |
| category | TEXT NOT NULL CHECK in (`tax`,`certificates`,`building`,`health`,`education`,`transport`,`leisure`,`information`,`business`) | directory grouping |
| name_en, name_gu | TEXT NOT NULL (≤ 80) | |
| department | TEXT NOT NULL | e.g. "Property Tax", stored en; gu via `department_gu` |
| department_gu | TEXT NOT NULL | |
| summary_en, summary_gu | TEXT NOT NULL (≤ 300) | |
| how_to_en, how_to_gu | TEXT NOT NULL | Markdown, numbered list only (rendered as steps) |
| url | TEXT NOT NULL | `https://` only |
| online | BOOLEAN NOT NULL | can be done fully online |
| visit_ward_office | BOOLEAN NOT NULL DEFAULT false | some step needs a ward office / civic centre visit |
| sort_order | INT NOT NULL DEFAULT 100 | |
| is_active | BOOLEAN NOT NULL DEFAULT true | |
| link_ok | BOOLEAN NULL | NULL = never checked |
| link_status_code | INT NULL | last HTTP status |
| link_error | TEXT NULL | `timeout`, `dns`, `tls`, `http_404`… (no bodies) |
| last_checked_at | TIMESTAMPTZ NULL | |
| verified_at | TIMESTAMPTZ NULL | last human verification of content |
| created_at, updated_at | TIMESTAMPTZ | |

`initiatives`

| Column | Type | Notes |
|---|---|---|
| id | UUID PK | |
| title_en, title_gu | TEXT NOT NULL (≤ 100) | |
| description_en, description_gu | TEXT NOT NULL (≤ 1,000) | |
| type | TEXT NOT NULL CHECK in (`tree_drive`,`cleanup`,`health_camp`,`other`) | |
| organiser | TEXT NOT NULL CHECK in (`AMC`,`RWA`,`NGO`,`Saarthee`) | |
| organiser_name | TEXT NOT NULL (≤ 100) | e.g. "Paldi Residents' Association" |
| source_url | TEXT NULL | required when organiser = `AMC` (CHECK) |
| ward_id | FK wards NULL | NULL = city-wide |
| location_text_en, location_text_gu | TEXT NOT NULL (≤ 200) | meeting point |
| location | geography(Point,4326) NULL + `lat`, `lng` NUMERIC(9,6) NULL | for "Open in maps" |
| starts_at, ends_at | TIMESTAMPTZ NOT NULL | CHECK `ends_at > starts_at` |
| capacity | INT NULL CHECK > 0 | NULL = unlimited |
| status | TEXT NOT NULL CHECK in (`draft`,`published`,`cancelled`,`completed`) | |
| going_count | INT NOT NULL DEFAULT 0 | maintained in the RSVP transaction |
| reminder_sent_at | TIMESTAMPTZ NULL | |
| created_by, updated_by | FK users | |
| created_at, updated_at | TIMESTAMPTZ | |

Indexes: `(status, starts_at)`, `(ward_id, starts_at)`.

`rsvps`: `initiative_id` FK, `user_id` FK, `status` CHECK in (`going`,`cancelled`,`attended`), `created_at`, `updated_at`, `attendance_marked_by` FK users NULL; PK `(initiative_id, user_id)`.

`service_tips` (REQ-F-061, P2): `id`, `title_en/gu` (≤ 80), `body_en/gu` (≤ 240), `service_id` FK NULL (tip links to a service), `ward_id` FK NULL, `active_from` DATE, `active_to` DATE (CHECK `active_to >= active_from`), `is_active`, `created_by`, timestamps.

Privacy: register export section `rsvps` (initiative id, title, status, dates) and erasure step "delete own RSVPs and decrement `going_count` for future initiatives" in the TASK-04 registries.

Service seed (`apps/api/prisma/seed-data/services.ts`, run by `npm run services:seed` in every environment; URLs found on official sites on 2026-10-03 and must pass `services:check-links` before the pilot):

| Slug | Name (en) | Category | URL | online | visit_ward_office |
|---|---|---|---|---|---|
| property-tax-pay | Pay property tax | tax | https://ahmedabadcity.gov.in/PTAX/DuesSearch | true | false |
| property-tax-bill | See your property tax bill | tax | https://ahmedabadcity.gov.in/PTAX/Bill | true | false |
| property-name-transfer | Pay property name-transfer fee | tax | https://ahmedabadcity.gov.in/PTAX/TSFChargeSearch | true | true |
| professional-tax | Professional tax | tax | https://ahmedabadcity.gov.in/StaticPage/professional_tax | true | false |
| birth-death-search | Find a birth or death registration | certificates | https://ahmedabadcity.gov.in/OnlineSerWithoutLogin/RegistrationSearch | true | true |
| building-permission | Building plan permission (TDO) | building | https://ahmedabadcity.gov.in/StaticPage/buildingPermission_dept | true | false |
| fire-noc | Fire NOC (AMC Fire & Emergency Services) | building | https://ahmedabadcity.gov.in/StaticPage/fire_dept | true | false |
| amc-hospitals | AMC hospitals and health department | health | https://ahmedabadcity.gov.in/StaticPage/health_department | false | false |
| urban-health-centres | Urban health centres | health | https://ahmedabadcity.gov.in/SP/UrbanHealthCenters | false | false |
| amc-schools | AMC primary schools | education | (to verify — seeded `is_active=false`) | false | false |
| brts | Janmarg BRTS routes and passes | transport | https://www.ahmedabadbrts.org | true | false |
| amts | AMTS city buses | transport | https://ahmedabadcity.gov.in/SP/AMTS | false | false |
| kankaria-tickets | Kankaria Lakefront tickets | leisure | https://www.kankarialaketickets.com/ | true | false |
| riverfront | Sabarmati Riverfront | leisure | https://www.sabarmatiriverfront.com/ | false | false |
| rti | Right to Information (RTI) request | information | https://ahmedabadcity.gov.in/StaticPage/RTI | false | true |
| tenders | AMC tenders | business | https://tender.nprocure.com | true | false |
| civic-centres | City civic centres | information | https://ahmedabadcity.gov.in/SP/CityCivicCenters | false | true |
| amc-online-services | All AMC online services | information | https://ahmedabadcity.gov.in/SP/UseOnlineServices | true | false |

How-to steps per service are written in plain language from the official page (e.g. property-tax-pay: "1. Open the AMC property tax page. 2. Enter your tenement number and tap Search. 3. Check the owner name and amount due. 4. Pay by UPI, card or net banking. 5. Download the receipt and keep it."), never inventing fees or deadlines; anything date-bound goes in a tip with "Check the official page for this year's dates."

Seasonal tips seed (fictional dates for dev; staff set real windows): property-tax early-payment rebate (April–May, links `property-tax-pay`): "AMC usually offers a rebate for paying property tax early in the year. Check the official page for this year's dates."; monsoon (June–September): "Report waterlogging and open drains early. Keep AMC's flood helpline handy."; heat (April–June): "During heat alerts, drink water often and check on older neighbours. Urban health centres can help."

### 5.3 API Contracts

New error codes: `INITIATIVE_NOT_OPEN` 409 "This drive is not taking RSVPs.", `INITIATIVE_FULL` 409 "This drive is full.", `SLUG_TAKEN` 409 "That short name is already used.", `SERVICE_NOT_FOUND`/`INITIATIVE_NOT_FOUND` mapped to `NOT_FOUND` 404.

Public (rate limit 120/IP/min unless noted):

| Method | Path | Auth | Request | Response | Errors |
|---|---|---|---|---|---|
| GET | `/api/v1/services` | None | `?category&q` (q ≤ 50, matches en/gu name or summary, case-insensitive) | `{items:[{slug, category, nameEn, nameGu, summaryEn, summaryGu, online, visitWardOffice, linkOk}]}` active only, by `category, sort_order` | 400 |
| GET | `/api/v1/services/{slug}` | None | `?ward=<wardId>` optional | `{slug, …list fields, department, departmentGu, howToEn, howToGu, url, lastCheckedAt, verifiedAt, wardOffice:{wardId, number, nameEn, nameGu, officeAddress, officePhone}|null, source:{name:"Amdavad Municipal Corporation website", url}}` | 404 |
| GET | `/api/v1/services/tips` | None | `?ward&date` (default today, Asia/Kolkata) | `{items:[{id, titleEn, titleGu, bodyEn, bodyGu, serviceSlug|null}]}` max 3, active window, ward-specific first | 400 |
| GET | `/api/v1/initiatives` | Optional user | `?ward&upcoming=true&type&cursor&limit≤20` | `{items:[{id, titleEn, titleGu, type, organiser, organiserName, wardId, locationTextEn, locationTextGu, startsAt, endsAt, capacity, goingCount, status, myRsvp|null}], nextCursor}`; `upcoming` = published and `ends_at > now()`, sorted `starts_at`; with `ward`: that ward + city-wide | 400 |
| GET | `/api/v1/initiatives/{id}` | Optional user | — | list fields + `descriptionEn/Gu, sourceUrl, lat, lng, myRsvp` | 404 (draft is 404 for non-staff) |
| POST | `/api/v1/initiatives/{id}/rsvp` | User | — | 200 `{status:"going", goingCount}` (idempotent) | 401, 404, 409 `INITIATIVE_NOT_OPEN` (not published or started), 409 `INITIATIVE_FULL`; 30/user/day |
| DELETE | `/api/v1/initiatives/{id}/rsvp` | User | — | 200 `{status:"cancelled", goingCount}` (idempotent) | 401, 404, 409 after start |

RSVP transaction: `SELECT … FOR UPDATE` on the initiative; check status/start/capacity; upsert rsvp; adjust `going_count` only on a real state change. An RSVP made after `reminder_sent_at` is set does not get a reminder (the confirmation screen says when the drive starts).

Staff (all write an audit entry `{actor, role, action, targetType, targetId}` — no bodies, no PII):

| Method | Path | Roles | Request | Response | Errors |
|---|---|---|---|---|---|
| GET | `/api/v1/staff/services` | admin, moderator (read) | `?linkOk=false&active` | full rows incl. inactive | 401, 403 |
| POST | `/api/v1/staff/services` | admin | all §5.2 editable fields | 201 row | 400, 409 `SLUG_TAKEN` |
| PATCH | `/api/v1/staff/services/{id}` | admin | partial; `markVerified:true` sets `verified_at` | 200 row | 400, 404, 409 |
| DELETE | `/api/v1/staff/services/{id}` | admin | — | 204 (soft: `is_active=false`) | 404 |
| POST | `/api/v1/staff/services/{id}/link-check` | admin, moderator | — | 200 `{linkOk, statusCode, error, checkedAt}` | 404; 10/user/h |
| GET/POST/PATCH | `/api/v1/staff/initiatives[/{id}]` | admin | §5.2 fields; status transitions draft→published→completed, any→cancelled | rows | 400, 404, 409 invalid transition |
| GET | `/api/v1/staff/initiatives/{id}/rsvps` | admin | — | `{items:[{userId, displayName|"Resident", phoneLast4, status, createdAt}]}` | 404 |
| POST | `/api/v1/staff/initiatives/{id}/attendance` | admin | `{userIds:[…], attended:boolean}` (≤ 500) | 200 `{updated}`; only after `starts_at` | 400, 404, 409 before start |
| GET/POST/PATCH/DELETE | `/api/v1/staff/tips[/{id}]` | admin | §5.2 tip fields | rows / 204 | 400, 404 |

Cancelling a published initiative notifies every `going` RSVP via `notifyUser` (kind `initiative`, channel `updates`): "Cancelled: {title}" / "The organiser cancelled this drive."

Scripts:
- `npm run services:check-links` (registered in the TASK-06 job runner `src/jobs` at `0 6 1 * *` Asia/Kolkata; also runnable by hand): for each active service, `HEAD` with `LINK_CHECK_USER_AGENT`, timeout 10 s, ≤ 5 redirects; on 405/403/501 retry with `GET` (body discarded after headers); one retry after 30 s on network error; concurrency 2 and ≥ 1 s between requests to the same host; `link_ok = status < 400`; store status, error code, `last_checked_at`; prints a summary table and exits 0 (broken links are data, not script failure; exit 1 only on DB error).
- `npm run initiatives:remind` (TASK-06 job runner, every 15 min): select published initiatives with `reminder_sent_at IS NULL` and `starts_at` within the next `INITIATIVE_REMINDER_HOURS` and > now + 1 h; mark `reminder_sent_at` in the same transaction that reads them (`FOR UPDATE SKIP LOCKED`); for each `going` RSVP call `notifyUser(userId, {kind:'initiative', refId, route:'/initiatives/<id>', channel:'updates', title:{en:"Tomorrow: {title}", gu:"આવતીકાલે: {title}"}, body:{en:"{time} at {place}. Tap for details.", gu:"…"}, sendAfter: quiet-hours end if now is within QUIET_HOURS})`. Re-running sends nothing twice.

### 5.4 UI Surfaces & States

Citizen app:

| Route | Content | States |
|---|---|---|
| `/services` (from Home shortcuts and My Ward) | App bar "AMC services"; independence banner "Independent guide. Links open AMC's official websites."; search "Search services"; category chips (All, Tax, Certificates, Building, Health, Education, Transport, Leisure, Information, Business); `ListRow`s with name, summary, badges "Online" (`language` icon) / "Visit ward office" (`apartment` icon) | Loading skeletons; error + "Try again"; offline → last cached list + offline banner; no match → "No service matches “{q}”." |
| `/services/:slug` | Title, department, badges, summary; "How to do it" numbered steps; primary "Open on AMC website" (external browser via `url_launcher`, `LaunchMode.externalApplication`); caption "Opens {host}. Saarthee is an independent app, not run by AMC."; if `visitWardOffice`: card "Your ward office" with ward name, address, "Call" (tel:) and "Change ward"; source line "Source: Amdavad Municipal Corporation website · Last checked {date}"; if `linkOk == false`: warning banner "We couldn't open this page when we last checked on {date}. It may have moved." | Loading; 404 → "This service is no longer listed."; no home ward → card "Set your home ward to see your ward office" → picker; launcher failure → snackbar "Couldn't open the link." |
| `/initiatives` (from Home and My Ward) | "Drives and events"; segmented "My ward" / "All city"; cards: type icon + label, title, date/time ("Sun 12 Oct, 7:00–9:00 am"), place, organiser ("By Paldi RWA"), going count | Empty → "No upcoming drives in your ward." + "See all city"; loading; error; offline (cached) |
| `/initiatives/:id` | Title, type, organiser + "Source" link if present, description, when, where ("Open in maps" → `geo:` URI when lat/lng), capacity "{n} of {cap} going"; primary "I'm going" → `ensureSignedIn(reason: rsvp)` then POST; when going: status chip "You're going" + secondary "Cancel RSVP"; footer "We'll remind you a day before." | Full → disabled "This drive is full"; cancelled → banner "Cancelled by the organiser"; started/past → no RSVP button; in flight → button progress; 409 → message |
| Home tip card (replaces part of P-03) | `NoticeBanner` info variant: tip title + body + "Open" (→ service) + dismiss (dismissed tip ids stored on device) | Hidden when no tip or offline without cache |
| Home "Upcoming drives" + "Services" shortcuts (replaces P-03) | Next 2 initiatives for home ward; 4 shortcut tiles: Pay property tax, Birth/death records, Kankaria tickets, All services | Empty drives → section hidden |
| My Ward "Services and drives" (replaces P-08) | 3 services with `visitWardOffice` + ward office card; next 3 ward initiatives | — |

Staff screen contract (Flutter, same codebase, mounted under TASK-10's `/staff` shell and side navigation; standalone guarded routes until TASK-10 adds the nav entries):

| Route | Role | Content |
|---|---|---|
| `/staff/services` | admin (edit), moderator (read + re-check) | Table: name, category, online, ward-office flag, link status (OK / Broken {code} / Not checked), last checked, verified; filter "Broken links only"; actions Edit, "Check link now", Deactivate |
| `/staff/services/:id` (and `/new`) | admin | Form: slug, category, names en/gu, department en/gu, summary en/gu, how-to en/gu (numbered-list editor with preview), URL (https validator), online, visit ward office, sort order, active, "Mark content verified today" |
| `/staff/initiatives` + `/:id` + `/new` | admin | List by status/date; form: titles, descriptions, type, organiser + name, source URL (required for AMC), ward (or city-wide), place en/gu, map pin (lat/lng fields), start/end, capacity, status actions Publish / Cancel / Complete |
| `/staff/initiatives/:id/attendance` | admin | RSVP list (display name or "Resident", phone last 4), checkboxes "Attended", "Save attendance" (enabled after start) |
| `/staff/tips` | admin | List + form: titles/bodies en/gu, linked service, ward or city-wide, active window, active |

All staff forms: label-above inputs, error summary, bilingual fields side by side on ≥ 900 dp width, loading/error/forbidden ("You don't have access to this page.") states.

### 5.5 Permissions & Roles

| Action | Visitor | Citizen | Moderator | Admin | Representative |
|---|---|---|---|---|---|
| Read services, tips, published initiatives | ✅ | ✅ | ✅ | ✅ | ✅ |
| RSVP / cancel RSVP | ❌ → sign-in | ✅ own | ✅ own | ✅ own | ✅ own |
| Read staff service list, re-check a link | ❌ | ❌ | ✅ | ✅ | ❌ |
| Create/edit services, initiatives, tips; publish/cancel | ❌ | ❌ | ❌ | ✅ | ❌ |
| See RSVP list, mark attendance | ❌ | ❌ | ❌ | ✅ | ❌ |

Spec §3 gives admins management of services and initiatives; moderators only read and trigger link checks (§5.6).

### 5.6 Assumptions

- ASSUMPTION: `service_tips` is a new table owned here — REQ-F-061 needs staff-managed tips and REQ-D-010/REQ-D-011 list no place for them; `app_settings` (TASK-10) is for flags, not content.
- ASSUMPTION: The services seed is production data (verified public URLs), run by `services:seed` in every environment, not part of TASK-01's dev seed — TASK-01's seed runs before these tables exist; dev initiatives and tips are added to the dev seed by this task.
- ASSUMPTION: The AMC schools link was not verified on 2026-10-03, so `amc-schools` is seeded inactive until staff verify a URL — never publish an unverified official link.
- ASSUMPTION: "AMCFIRE" maps to AMC's Fire & Emergency Services page (`StaticPage/fire_dept`), which links to the Fire NOC application; staff update the URL if a dedicated portal is confirmed.
- ASSUMPTION: Moderators can read the staff service list and trigger link re-checks but cannot edit; attendance and all CRUD are admin-only — Spec §3 names admins for services and initiatives; conservative reading.
- ASSUMPTION: Broken links stay visible to citizens with a warning instead of being hidden — hiding a whole service on one failed check (AMC sites are often slow) would remove useful how-to steps; staff decide.
- ASSUMPTION: Reminders run as a job in TASK-06's in-process runner (`src/jobs`, advisory lock, every 15 min) — build-lead decision 2026-10-03: all recurring app jobs use that one runner; TASK-13 timers cover only host-level backups. Reminders inside quiet hours are deferred with `sendAfter` to 07:00.
- ASSUMPTION: TASK-07's `GET /feed` and TASK-09's My Ward may land before or after this task; whichever lands second wires tips/initiatives into the feed response and the My Ward slot, using the public endpoints here. This task always replaces placeholders P-03 and P-08 on the client.
- ASSUMPTION: Staff RSVP lists show display name (or "Resident") and the last 4 phone digits only — enough to take attendance at the event without exposing full numbers (Spec §11 minimisation).
- ASSUMPTION: Service and initiative copy in Gujarati is drafted by the implementer and reviewed by the native editor (Open Question #5) before TASK-14.

## 6. Implementation Steps

1. **Migration** `<ts>_v2_services_initiatives` (§5.2: four tables, CHECKs, indexes, geography column); update `schema.prisma` (`Unsupported("geography(Point,4326)")` for `location`); `prisma generate`; typecheck.
2. **Services seed.** `prisma/seed-data/services.ts` with the 18 rows (bilingual names, summaries, how-to steps, flags); `scripts/seed-services.ts` inserts missing slugs only, so staff edits are never overwritten; `--force` updates existing rows from the seed; `npm run services:seed`. Add fictional initiatives (one per type, wards in the 5 pilot wards, one full, one cancelled, one past) and the three tips to the dev seed.
3. **Services module** `src/modules/services`: list (search with `ILIKE` on en/gu fields, parameterised), detail with ward office join (`?ward`), tips query (date window in Asia/Kolkata), Zod schemas, rate limits.
4. **Initiatives module** `src/modules/initiatives`: list with cursor (`starts_at, id`), detail, RSVP/cancel transaction (§5.3), `myRsvp` via `optionalUser`.
5. **Staff endpoints** `src/modules/staff-content`: services, initiatives, tips CRUD; link-check-now; RSVP list; attendance; status transitions; cancellation notifications; `requireUser` + `requireRole`; audit entries.
6. **Link checker** `src/lib/linkcheck` (pure function `checkUrl(url, opts)` returning `{ok, statusCode, error}`; injectable fetch for tests) + `scripts/check-service-links.ts` + `npm run services:check-links`.
7. **Reminder job** `scripts/remind-initiatives.ts` + `npm run initiatives:remind` using `notifyUser` with `sendAfter` for quiet hours; quiet-hours helper `isQuietHours(now, window, tz)` in `src/lib/time` (shared with TASK-08 if it already exists).
8. **Privacy registries.** Register `rsvps` export section and erasure step.
9. **API tests** T-12-01…T-12-14.
10. **App data layer** `lib/features/services/` and `lib/features/initiatives/`: repositories (dio), models, providers with last-response cache for offline.
11. **Citizen screens** per §5.4; external link launch with independence caption; `ensureSignedIn(reason: rsvp)` before RSVP; Home tip card with on-device dismissal (`v2.dismissedTips`); replace P-03 and P-08; routes `/services`, `/services/:slug`, `/initiatives`, `/initiatives/:id` (allowed as push targets — matches the TASK-04 allow-list).
12. **Staff screens** per the contract in §5.4 under `lib/features/staff/content/`; register in TASK-10's navigation if present, else as standalone role-guarded routes.
13. **ARB** en + gu for all new strings (service and initiative content comes from the API, not ARB).
14. **Flutter tests** T-12-15…T-12-19.
15. **Manual checks** M-12-01…M-12-06; run `services:check-links` against the real sites and record the results table in §13.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Tables and constraints
- **Given** the new migration applied to an empty v2 database
- **When** rows violating constraints are inserted (end before start, AMC organiser without source URL, duplicate slug, `http://` URL, RSVP status `maybe`)
- **Then** each insert fails; valid rows insert; `prisma migrate status` is clean and no earlier migration changed

**AC-2** — Services directory
- **Given** the seeded services
- **When** a visitor opens `/services`, filters "Tax" and searches "property" (and "મિલકત" in Gujarati)
- **Then** only active tax services matching the text show, each with its Online / Visit ward office badge, in sort order; the independence banner is visible

**AC-3** — Service detail with ward office
- **Given** home ward 12 with a published office address and the `rti` service (`visit_ward_office=true`)
- **When** the citizen opens `/services/rti` and taps "Open on AMC website"
- **Then** the page shows summary, numbered how-to steps in the app language, the ward 12 office card with address and Call, the source line with last-checked date, and the official URL opens in the external browser with the independence caption shown

**AC-4** — Link checker
- **Given** three services whose URLs return 200, 404 and time out (test doubles), and one that answers HEAD with 405 but GET with 200
- **When** `npm run services:check-links` runs
- **Then** `link_ok` is true, false (`http_404`), false (`timeout`), true respectively, `last_checked_at` set for all, a summary is printed, exit code 0; `/staff/services?linkOk=false` lists the two broken ones and the app shows the "may have moved" warning on them

**AC-5** — Initiatives list and detail
- **Given** published initiatives in ward 12, city-wide and ward 30, plus a draft and a past one
- **When** a visitor opens `/initiatives` on "My ward" and then a detail page
- **Then** ward 12 and city-wide upcoming items show sorted by start, never the draft or past one; detail shows organiser, source link, time, place and going count

**AC-6** — RSVP with sign-in when needed
- **Given** a visitor on an open initiative with capacity 2 and 1 going
- **When** they tap "I'm going", sign in, and come back
- **Then** the RSVP is sent automatically after sign-in, the button becomes "You're going", `going_count` = 2; another citizen then gets 409 `INITIATIVE_FULL`; cancelling returns the count to 1; repeating POST or DELETE changes nothing

**AC-7** — 24-hour reminder
- **Given** an initiative starting in 23 h with two `going` and one `cancelled` RSVP
- **When** `initiatives:remind` runs twice
- **Then** exactly two `notifications` rows of kind `initiative` are created (one per going user, route `/initiatives/<id>`), `reminder_sent_at` is set, and the second run sends nothing; inside quiet hours the rows are `queued` with `send_after` 07:00

**AC-8** — Attendance by staff
- **Given** an initiative that has started and an admin
- **When** the admin marks two RSVPs attended (and a moderator tries the same; and an admin tries before start)
- **Then** the two rows become `attended` with `attendance_marked_by`; the moderator gets 403; before start → 409; the RSVP list shows only display name or "Resident" and last 4 phone digits; audit entries exist without bodies

**AC-9** — Staff CRUD and role guard
- **Given** admin, moderator and citizen tokens
- **When** each creates/edits a service, initiative and tip
- **Then** admin succeeds (201/200, audit logged), moderator and citizen get 403 (moderator can still GET the staff service list and trigger a link check), visitor gets 401; duplicate slug → 409 `SLUG_TAKEN`

**AC-10** — Cancellation notice
- **Given** a published initiative with three going RSVPs
- **When** an admin cancels it
- **Then** each going citizen gets an `initiative` notification "Cancelled: …"; the detail shows "Cancelled by the organiser"; RSVP is no longer possible (409 `INITIATIVE_NOT_OPEN`)

**AC-11** — Seasonal tips on Home
- **Given** tips active in April for ward 12 and city-wide, and none in November
- **When** `GET /services/tips?ward=<12>&date=2027-04-15` and `…&date=2027-11-15` are called and Home is opened
- **Then** April returns at most 3 tips with ward-specific first and Home shows the card with "Open" linking to the service; November returns none and Home shows no card; a dismissed tip stays hidden

**AC-12** — Placeholders replaced and privacy hooks
- **Given** the TASK-03 placeholder register
- **When** this task is complete
- **Then** P-03 and P-08 no longer appear; `GET /me/export` includes `rsvps`; `DELETE /me` removes the user's RSVPs and decrements counts for future initiatives

| AC | Requirements |
|---|---|
| AC-1 | REQ-D-010 |
| AC-2 | REQ-F-057 |
| AC-3 | REQ-F-057 |
| AC-4 | REQ-F-058 |
| AC-5 | REQ-F-059 |
| AC-6 | REQ-F-060 |
| AC-7 | REQ-F-060 |
| AC-8 | REQ-F-060 |
| AC-9 | REQ-F-057, REQ-F-059, REQ-F-061 |
| AC-10 | REQ-F-059, REQ-F-060 |
| AC-11 | REQ-F-061 |
| AC-12 | REQ-F-057, REQ-F-059, REQ-D-010 |

### 7.2 Non-Functional Checklist

- [ ] Independence line on services list, service detail and every external AMC link (DS §1)
- [ ] No AMC logo or imagery; official links open in the external browser, never a WebView
- [ ] All list endpoints paginated or bounded; p95 < 400 ms locally on seed data
- [ ] Link checker polite: custom User-Agent, ≥ 1 s per host, concurrency 2, no request bodies stored
- [ ] Every staff action audited with actor, role, target; no bodies or PII
- [ ] RSVP transaction safe under concurrency (capacity never exceeded — two parallel requests for the last seat)
- [ ] Loading, empty, error, offline and forbidden states on every new screen; 48 dp targets; Gujarati at 2.0×
- [ ] All new UI strings in en + gu ARB; parity test passes
- [ ] `npm run typecheck`, `lint`, `npm test`, `flutter analyze`, `flutter test` green

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-12-01 | API typecheck + lint; `dart format`, `flutter analyze` | Quality gate |
| API integration | T-12-01 | Migration constraints (end<start, AMC without source, dup slug, http URL, bad RSVP status) | AC-1 |
| API integration | T-12-02 | `GET /services` category filter, en/gu search, inactive hidden, order | AC-2 |
| API integration | T-12-03 | `GET /services/{slug}?ward=` ward office present/absent; 404 unknown | AC-3 |
| Unit | T-12-04 | `checkUrl`: 200, 404, timeout, HEAD 405 → GET 200, redirect chain > 5, TLS error (fake fetch) | AC-4 |
| API integration | T-12-05 | `services:check-links` updates rows and exits 0 with broken links; staff `?linkOk=false` | AC-4 |
| API integration | T-12-06 | `GET /initiatives` ward + city-wide, upcoming only, no drafts, cursor paging; detail 404 for draft | AC-5 |
| API integration | T-12-07 | RSVP: idempotent POST/DELETE, full → 409, not open → 409, counts correct; two parallel requests for the last seat → one 200, one 409 | AC-6 |
| API integration | T-12-08 | Reminder job: two notifications, `reminder_sent_at`, second run none; quiet hours → queued with `send_after` (memory push driver) | AC-7 |
| API integration | T-12-09 | Attendance: admin ok after start; before start 409; moderator 403; RSVP list masking | AC-8 |
| API integration | T-12-10 | Staff CRUD role matrix (admin/moderator/citizen/visitor) for services, initiatives, tips; `SLUG_TAKEN`; audit rows | AC-9 |
| API integration | T-12-11 | Cancel initiative → notifications to going users; RSVP afterwards 409 | AC-10 |
| API integration | T-12-12 | Tips date windows, ward-first ordering, max 3 | AC-11 |
| API integration | T-12-13 | Export includes `rsvps`; delete removes RSVPs and decrements future counts | AC-12 |
| API integration | T-12-14 | `services:seed` idempotent: second run inserts 0, does not overwrite edited rows without `--force` | AC-2 |
| Widget | T-12-15 | `/services` list: chips, search, badges, offline cache, empty state | AC-2 |
| Widget | T-12-16 | Service detail: steps rendered, ward office card / set-ward prompt, broken-link banner, launcher called with external mode | AC-3, AC-4 |
| Widget | T-12-17 | Initiative detail: RSVP calls `ensureSignedIn` then POST; full, cancelled, past states | AC-6, AC-10 |
| Widget | T-12-18 | Home tip card show/dismiss; drives section; P-03/P-08 absent (`find.byType(PlaceholderSection)` none on Home and My Ward) | AC-11, AC-12 |
| Widget | T-12-19 | Staff service form validation (https URL, required gu/en) and forbidden state for non-admin | AC-9 |
| Manual | M-12-01 | Emulator: browse services in Gujarati and English, open three official links | AC-2, AC-3 |
| Manual | M-12-02 | Run `services:check-links` against the live sites; record results in §13; fix or flag any broken seed URL | AC-4 |
| Manual | M-12-03 | RSVP as visitor → sign-in → back; cancel; full drive with a second test account | AC-6 |
| Manual | M-12-04 | Set an initiative to start in 23 h, run `initiatives:remind` with `PUSH_DRIVER=fcm` (staging) → reminder on the emulator, tap opens the drive | AC-7 |
| Manual | M-12-05 | Admin staff screens: create service, initiative, tip; mark attendance; moderator view | AC-8, AC-9 |
| Manual | M-12-06 | TalkBack + 2.0× text on services list/detail and initiative detail | AC-2, AC-3, AC-5 |

## 9. Deliverables

- Migration `<ts>_v2_services_initiatives` (`services`, `initiatives`, `rsvps`, `service_tips`).
- `services:seed` with 18 bilingual services; dev seed initiatives and tips.
- API modules `services`, `initiatives`, `staff-content`; `lib/linkcheck`; scripts `services:check-links`, `initiatives:remind`; privacy registrations.
- App features `services`, `initiatives`, Home tip card and drives/services sections, My Ward slot; minimal staff screens.
- Tests T-12-01…T-12-19; coverage matrix evidence for 6 requirements; link-check results table.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/api/prisma/migrations/<ts>_v2_services_initiatives/migration.sql`, `prisma/schema.prisma` | New / Modified |
| `apps/api/prisma/seed-data/services.ts`, `prisma/seed.ts` | New / Modified |
| `apps/api/src/modules/{services,initiatives,staff-content}/` | New |
| `apps/api/src/lib/{linkcheck,time}/` | New |
| `apps/api/src/lib/errors/index.ts`, `src/routes.ts`, `src/modules/me/privacy.registry.ts` | Modified |
| `apps/api/scripts/{seed-services,check-service-links,remind-initiatives}.ts`, `package.json` | New / Modified |
| `apps/api/test/{services,initiatives,staff-content,linkcheck}.*.test.ts` | New |
| `apps/mobile/lib/features/{services,initiatives}/` | New |
| `apps/mobile/lib/features/staff/content/` | New |
| `apps/mobile/lib/features/home/`, `lib/features/ward/` (placeholder slots) | Modified |
| `apps/mobile/lib/router/` | Modified |
| `apps/mobile/lib/core/l10n/app_en.arb`, `app_gu.arb` | Modified |
| `apps/mobile/test/{services,initiatives,staff}/` | New |

## 11. Related Documentation

- `docs/v2/saarthee-v2-spec.md` §1 independence; §3 roles; §6 `services`, `initiatives`, `rsvps`; §7 Services & initiatives, Staff CRUD; §8 routes; §9 reminders, quiet hours; §11 minimisation
- `docs/v2/design-system.md` DS §1 independence line; DS §5 list rows, banners, empty/error states; DS §8 services and initiatives screens
- `docs/research/saarthee-v2-proposal.html` — services and drives scope, seasonal reminders
- `docs/tasks-v2/TASK-02-*.md` — ward office data
- `docs/tasks-v2/TASK-04-accounts-privacy-push.md` — `ensureSignedIn`, push service, privacy registries
- `docs/tasks-v2/TASK-10-*.md` — staff console shell hosting the staff screens
- `docs/tasks-v2/TASK-06-*.md` — job runner where the two jobs are registered

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| AMC changes page URLs often | Broken links, lost trust | Monthly checker, "may have moved" banner, staff re-check button, `verified_at` |
| AMC sites block or rate-limit the checker | False "broken" flags | Polite UA and pacing, GET fallback, retry; staff confirm before editing |
| How-to steps go stale (fees, documents) | Citizens misled | No fees/dates in steps; source line + last verified date; staff review quarterly |
| Over-booking under concurrency | Capacity exceeded | Row lock in RSVP transaction; T-12-07 parallel test |
| Reminder spam if the job double-runs | Annoyed users | `reminder_sent_at` set under `FOR UPDATE SKIP LOCKED`; idempotent test |
| Looks like an official AMC app | Play policy / trust | Independence line on every service screen and link; no AMC marks |
| Gujarati service copy quality | Comprehension | Native editor review before TASK-14 |

## 13. Progress Status

**Current status:** Not Started

**Progress:** 0%

| Date | Progress | Commit |
|---|---|---|

## 14. Completion Checklist

- [ ] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [ ] Automated tests added and passing
- [ ] Static checks pass and every AC verified by the checks in §8
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-12` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `V2-TASK-12: …`
- [ ] Validator passes
