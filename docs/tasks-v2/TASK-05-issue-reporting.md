# TASK-05: Standalone Issue Reporting

| Field | Value |
|---|---|
| Task ID | TASK-05 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | TASK-02, TASK-04 |
| Blocks | TASK-06, TASK-10 |
| Requirement IDs | REQ-F-012, REQ-F-013, REQ-F-014, REQ-F-015, REQ-F-016, REQ-F-017, REQ-F-018, REQ-F-019, REQ-D-007, REQ-N-007, REQ-S-007, REQ-S-008 |
| Primary Spec Refs | Spec §1, §4, §5 (duplicates), §6 (`categories`, `amc_problem_types`, `issues`, `issue_photos`, `issue_events`), §7 (Categories, Issues, rate limits), §8 (`/report/*`), §11 (photos); DS §1, §4, §5, §6, §7 |
| Last Updated | 2026-10-03 |

## 1. Objective

A signed-in citizen reports any of 14 civic problems straight to Saarthee in three short steps — what, photo and place, details and check — without first filing with AMC. The server stores a complete issue with ward and zone, a Saarthee target date and an opening `issue_events` row; retries never duplicate it. Before submitting, the citizen sees open reports of the same problem nearby and can add "Me too" instead. After submitting, the citizen may optionally file with AMC too, guided by the matching AMC problem type, and link the CCRS number later. Faces and number plates are blurred on the phone before upload. The v1 six-step complaint flow is retired.

## 2. Scope

### In Scope
- Seed the 14 v2 categories (Spec §4) and the AMC CCRS problem-type mapping (113 problems, 22 departments, English + Gujarati) from a committed snapshot.
- `amc:problems:fetch` script: one polite request to the CCRS public JSON, at most once per 24 h, writes the snapshot and upserts `amc_problem_types`.
- `GET /categories` (v2 shape, replaces v1 `{id,name}`).
- `POST /photos` extended for signed-in citizens (owner, blur flag); public read of attached issue photos `GET /media/photos/{id}`.
- `GET /issues/nearby` (duplicate check), `POST /issues` (idempotent), `POST /issues/{id}/me-too` (create only — used by the duplicate suggestion), `POST /issues/{id}/ccrs` (link a CCRS number).
- Per-user daily quota helper (REQ-S-008) with all four Spec §7 limits configured; applied here to issues, photos and me-too; exported for TASK-06 (verifications) and TASK-09 (messages).
- App: three-step report flow `/report/what` → `/report/photo` → `/report/details` → `/report/done` (DS §7), mini-map with "Adjust pin", duplicate suggestions, persisted draft (reusing v1 draft/capture/upload code), image_picker `retrieveLostData()` recovery, idempotent submit, "File with AMC too" hand-off, `/issues/:id/link-ccrs` screen.
- On-device face and plate blur with a manual blur tool (P1); voice input for the description (P2).
- Retire v1 report routes and screens; `POST /reports` answers 410.
- Performance measurement for REQ-N-007.

### Out of Scope
- Status changes, verification, escalation, notifications, `GET /issues/{id}/events` — TASK-06.
- Issue detail screen, `GET /issues`, `GET /issues/{id}`, `DELETE …/me-too`, follow endpoints, feed, map tab — TASK-07 (the `CivicMap` wrapper created here is extended there).
- Moderation of sensitive categories, merge, recategorise, category CRUD — TASK-10.
- Reverse geocoding to `address_text` (Spec §6 "later").
- Gallery uploads (camera only, see §5.6).
- Any automatic filing with AMC (REQ-F-094 deferred; no AMC API).

## 3. Prerequisites

- TASK-01: v2 tables exist (`categories`, `issues`, `issue_photos`, `issue_events`, `me_toos`, `follows`, `users`), PostGIS enabled, Vitest + Supertest harness and v2 seed runner.
- TASK-02: `wards`/`zones` seeded; geo service `locate(lat, lng)` returning `{ ward, zone, confirm, distanceM }` (REQ-F-001).
- TASK-03: Civic Blue shell (Report tab), components (`StepHeader`, `CategoryBadge`, `ChoiceTile`, `PrimaryButton`, `ErrorSummary`, `OfflineBanner`, skeletons, banners), ARB in Gujarati + English.
- TASK-04: session JWT middleware `requireUser` (sets `req.user {id, role, status, language, homeWardId}`), sign-in gate that returns to the calling route, consent records, `AUTH_REQUIRED` / `ACCOUNT_SUSPENDED` error codes.
- Env (`apps/api/.env`): `DUPLICATE_RADIUS_M=50`, `DUPLICATE_WINDOW_DAYS=30`, `ISSUE_MAX_PHOTOS=3`, `QUOTA_ISSUES_PER_DAY=10`, `QUOTA_ME_TOO_PER_DAY=100`, `QUOTA_VERIFICATIONS_PER_DAY=20`, `QUOTA_MESSAGES_PER_REP_PER_DAY=5`, `QUOTA_PHOTOS_PER_DAY=40`, `WARD_SNAP_MAX_M=2000`, `AMC_PROBLEMS_URL=https://www.amccrs.com/AMCPortal/Home/GetDeptWiseProblems`, `AMC_PROBLEMS_MIN_INTERVAL_HOURS=24`.
- Dart-defines (existing v1): `CCRS_WEB_URL`, `CCRS_WHATSAPP_NUMBER`, `AMC_HELPLINE` (155303); new: `MAP_TILE_URL`, `MAP_TILE_ATTRIBUTION`.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-02 | Ward/zone lookup for every new issue and the "outside all wards → confirm nearest" rule |
| TASK-04 | Citizen identity (reporting requires sign-in, D6), session middleware, consent records, account status |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-012 | v2 category list (14 categories, Gujarati + English, icon, colour token, SLA days) via `GET /categories`, with AMC CCRS problem-type mapping | Spec §4 |
| REQ-F-013 | AMC problem types cached from the CCRS public JSON by a script (manual run, at most daily) | Spec §4 |
| REQ-F-014 | Three-step report flow (DS §7): category grid; photos (1–3) with auto location and adjustable pin; optional description and check-your-answers; submit | Spec §8, DS §7 |
| REQ-F-015 | Duplicate check before submit: open issues of the same category within 50 m in 30 days offered as "Me too" | Spec §5 |
| REQ-F-016 | `POST /issues` idempotent by `clientSubmissionId`; assigns ward/zone, SLA due date, status `reported` | Spec §5, §7 |
| REQ-F-017 | Report draft persists across app kill and camera hand-off; image_picker lost-data recovery handled | Spec §8 |
| REQ-F-018 | Optional "File with AMC too" hand-off (CCRS web, WhatsApp, 155303) showing the matching AMC problem type; citizen can link a CCRS number later | Spec §5, §1 |
| REQ-F-019 | Voice input for the description (device speech-to-text, gu/en) | Spec §8 |
| REQ-D-007 | `categories` seeded with the 14 v2 categories and `amc_problem_types` mapping | Spec §4 |
| REQ-N-007 | Report sheet completes in ≤ 4 taps after the photo for a typical issue; cold start ≤ 3 s on a low-end phone (profile/release build) | DS §7 |
| REQ-S-007 | Faces and number plates blurred on-device before upload, with manual blur fallback | Spec §11 |
| REQ-S-008 | Per-user rate limits per spec §7 (issues, me-too, messages, verifications) | Spec §7 |

### 5.2 Data Contracts

New migration `<ts>_v2_reporting` (timestamp after TASK-02's last migration; inspect TASK-01's schema first and add only what is missing):
- `amc_problem_types` (created in this task's migration; TASK-01 does not create it): `id`, `category_id`, `department`, `problem_category`, `problem`, plus `source_key TEXT UNIQUE NOT NULL` (sha1 of `department|problemCategory|problem`, the CCRS JSON has no stable id — only `row#`), `problem_category_en TEXT`, `is_primary BOOLEAN NOT NULL DEFAULT false`, `is_active BOOLEAN NOT NULL DEFAULT true`; `category_id` NOT NULL FK `categories`; partial unique index `(category_id) WHERE is_primary`.
- `photos`: add `uploaded_by_user_id UUID NULL REFERENCES users`, `blur_applied BOOLEAN NOT NULL DEFAULT false`; index `(uploaded_by_user_id, uploaded_at)`.
- `issues`: index `(reporter_id, created_at DESC)` (quota count); confirm GIST on `location` and `(category_id, status, created_at)` exist (TASK-01).

Seed (`apps/api/prisma/seed/v2-categories.ts`, idempotent upsert by slug; run by `db:seed` and `demo:reset`):

| slug | name_en | name_gu (native review) | icon | sla_days | sensitive | sort |
|---|---|---|---|---|---|---|
| roads | Roads & potholes | રસ્તા અને ખાડા | road | 7 | no | 1 |
| water | Water supply | પાણી પુરવઠો | water_drop | 2 | no | 2 |
| drainage | Drainage & waterlogging | ગટર અને પાણી ભરાવો | water_damage | 3 | no | 3 |
| garbage | Garbage & cleanliness | કચરો અને સફાઈ | delete | 2 | no | 4 |
| streetlight | Streetlights | સ્ટ્રીટલાઇટ | lightbulb | 3 | no | 5 |
| trees | Trees & parks | વૃક્ષો અને બગીચા | park | 7 | no | 6 |
| animals | Stray animals | રખડતાં પશુઓ | pets | 3 | no | 7 |
| health | Mosquitoes & health | મચ્છર અને આરોગ્ય | pest_control | 3 | no | 8 |
| toilets | Public toilets | જાહેર શૌચાલય | wc | 2 | no | 9 |
| encroachment | Encroachment | દબાણ | do_not_step | 15 | yes | 10 |
| traffic | Traffic & parking | ટ્રાફિક અને પાર્કિંગ | traffic | 7 | no | 11 |
| property | Property & tax | મિલકત અને વેરો | receipt_long | 15 | no | 12 |
| building | Building & construction | બાંધકામ | apartment | 30 | yes | 13 |
| other | Other | અન્ય | more_horiz | 7 | no | 14 |

`colour_token` = `category.<slug>` (DS §2 table). AMC mapping file `apps/api/prisma/data/amc-category-map.json` maps CCRS `department` + `problemCategory` → slug, with per-problem overrides and one `primary` problem per category:

| Category | CCRS department › problemCategory | Primary problem |
|---|---|---|
| roads | Engineering › Road, Footpath | "Road-Repair Require" |
| water | Engineering › Water>>Engineering; Health › Epidemic » Polluted Water | "Water-No Supply" |
| drainage | Engineering › Drainage>>Engineering, Storm Water | "Drainage- Choking Of Line" |
| garbage | S.W.M › Cleaning>>SWM, Solid Waste, Plastic collection, Soak Pit Cleaning | "SWM- Cleaning Not Done" |
| streetlight | Light › Streetlight; SRFDCL › SRF-light | "Streetlight- Streetlight Is Off" |
| trees | Garden › all | "Garden- Tree Falling" |
| animals | C.N.C.D › all; S.W.M › Dead Animals | "CNCD- To Capture Dog Nuisance…" |
| health | Health › Malaria, Medical Service; Food-Health › all; Urban Health Centre | "Health-Preventing Malaria/Dengue…" |
| toilets | S.W.M › Public Toilets and Urinals; Smart Toilet SWM; Engineering › Public Building | "SWM-Public Toilets and Urinals - Daily Cleaning…" |
| encroachment | Estate › Encroachment, TP Scheme Implementation, Advertisement | "Remove Encroachment From Road" |
| traffic | Estate › Parking; Traffic Engineering | "Parking Problem in Commercial Building" |
| property | Property Tax | "Property Tax Related" |
| building | Town Planning; Estate › Dangerous Building; Fire | "Unauthorised Construction" (Town Planning) |
| other | everything else (Gymnasium, I.C.D.S, Kankaria Lakefront, Library, Light Building, Swimming Pool, U.C.D, crematoria, school buildings) | none |

`dept_gu` comes from a hand-maintained 22-row department map in the same file (the JSON has Gujarati only for `problem`). Unmapped problems after a refresh go to `other` and are listed in the script output.

`issues` insert (`POST /issues`): `client_submission_id`, `reporter_id`, `category_id`, `title` (auto: `"<category.name_en> · <ward.name_en>"`), `description` (≤ 1,000, trimmed, NULL if empty), `location` (`ST_SetSRID(ST_MakePoint(lng,lat),4326)::geography`) + `lat`/`lng` (6 dp), `gps_accuracy_m`, `ward_id`, `zone_id`, `status='reported'`, `status_changed_at=now()`, `sla_due_at = now() + sla_days`, `me_too_count=0`, `follower_count=1`, `visibility` (`public`; `hidden` when `is_sensitive`), `is_sensitive` (from category). `issue_photos` rows (`kind='report'`, `position` 0..2); `photos.attached_at` set; `issue_events` row (`type=status_change`, `from_status NULL`, `to_status='reported'`, `actor_role='citizen'`); `follows` row for the reporter.

Local draft v2 (`features/report/data/report_draft.dart`, JSON in shared_preferences + photo files in app documents): `clientSubmissionId`, `categorySlug`, `photos[] {localPath, photoId?, capturedAt, blurApplied, uploadState}`, `fix {lat, lng, accuracyM}`, `pin {lat, lng, adjusted}`, `ward {id, nameEn, nameGu, confirm}`, `description`, `structuredReason`, `dismissedDuplicateIds[]`, `step`, `schemaVersion=2`. v1 drafts (`schemaVersion` absent) are discarded with their photo file.

### 5.3 API Contracts

| Method | Path | Auth | Request | Response | Errors | Rate limit |
|---|---|---|---|---|---|---|
| GET | `/api/v1/categories` | None | — | `{items:[{id, slug, nameEn, nameGu, icon, colourToken, slaDays, sensitive, sortOrder, amcProblemTypes:[{id, deptEn, deptGu, problemEn, problemGu, isPrimary}]}]}` + `ETag` | 304, 429 | 120/IP/min |
| POST | `/api/v1/photos` | Citizen | multipart `photo` (JPEG ≤ 5 MB), `purpose=report`, `blurApplied=true\|false` | 201 `{photoId}` | 400, 401 `AUTH_REQUIRED`, 413, 415, 429 | 60/IP/h + `QUOTA_PHOTOS_PER_DAY`/user |
| GET | `/api/v1/media/photos/{id}?w=320\|1024` | None | — | JPEG (attached to a `public` issue; owner/staff also see hidden) | 404 | 120/IP/min |
| GET | `/api/v1/issues/nearby?lat&lng&category` | None | `category` = slug | `{items:[{id, title, categorySlug, status, distanceM, meTooCount, createdAt, thumbnailUrl}]}` ≤ 5, nearest first | 400, 429 | 120/IP/min |
| POST | `/api/v1/issues` | Citizen | see below | 201 (new) / 200 (repeat) `{issue:{id, status, wardId, wardNameEn, wardNameGu, slaDueAt, createdAt, visibility}, amcHandoff:{problemTypes:[…]}}` | see below | quota `QUOTA_ISSUES_PER_DAY` |
| POST | `/api/v1/issues/{id}/me-too` | Citizen | — | 201/200 `{meTooCount}` | 404, 409 `OWN_ISSUE` / `ISSUE_NOT_OPEN`, 429 | quota `QUOTA_ME_TOO_PER_DAY` |
| POST | `/api/v1/issues/{id}/ccrs` | Citizen (reporter) | `{ccrsNumber, filedVia: web\|whatsapp\|phone}` | 200 `{ccrsNumber, ccrsFiledAt, status}` | 400, 403 `FORBIDDEN`, 404, 409 `CCRS_ALREADY_LINKED` | 20/user/day |
| POST | `/api/v1/reports` (v1) | — | — | — | 410 `ENDPOINT_RETIRED` "Please update Saarthee to report issues." | — |

`POST /issues` request:

| Field | Required | Validation |
|---|---|---|
| clientSubmissionId | Yes | UUID v4 |
| categorySlug | Yes | exists and active, else 422 `CATEGORY_INACTIVE` |
| photoIds | Yes | 1–`ISSUE_MAX_PHOTOS` distinct; each `purpose=report`, uploaded by this user, unattached, ≤ 24 h old, else 422 `PHOTO_UNUSABLE` |
| latitude / longitude | Yes | pin position; −90..90 / −180..180, rounded to 6 dp |
| gpsAccuracyM | No | ≥ 0 (of the device fix, not the pin) |
| pinAdjusted | Yes | boolean; when true the server also records `pinDistanceFromFixM` in the event note |
| deviceCapturedAt | Yes | first photo time, ≤ 10 min ahead of server time |
| description | No | ≤ 1,000 chars after trim; forbidden for sensitive categories |
| structuredReason | Sensitive only | one of the category's preset codes (§5.4) |
| confirmedWardId | Conditional | required when `locate` returns `confirm:true`; must equal the suggested ward |
| platform / appVersion | Yes | `android`/`ios`; ≤ 20 chars |

Workflow (`modules/issues/issues.service.ts#createIssue`): Zod validate → look up `client_submission_id` (same reporter → 200 existing; other reporter → 409 `IDEMPOTENCY_KEY_REUSED`) → `req.user.status=active` else 403 `ACCOUNT_SUSPENDED` → `assertDailyQuota(user,'issues')` → category active → photos usable → `geo.locate(lat,lng)`: inside a ward → use it; `confirm:true` and `distanceM ≤ WARD_SNAP_MAX_M` → require `confirmedWardId` else 422 `WARD_CONFIRMATION_REQUIRED {details:[{field:'confirmedWardId', suggestedWardId}]}`; farther → 422 `OUTSIDE_SERVICE_AREA` "This place is outside Ahmedabad's wards. Saarthee can only take reports inside the city." → one `$transaction`: insert issue (raw SQL for geography), `issue_photos`, attach photos (conditional `updateMany … attachedAt IS NULL`, count must match), `issue_events`, reporter `follows` → record analytics `issue_submitted {categorySlug, wardNumber, photoCount, pinAdjusted}` → 201. Unique violation on `client_submission_id` → re-read → 200.

`GET /issues/nearby`: `status IN (reported, sent, acknowledged, in_progress, reopened)`, `visibility='public'`, same category, `ST_DWithin(location, point, DUPLICATE_RADIUS_M)`, `created_at > now() - DUPLICATE_WINDOW_DAYS`, `ORDER BY ST_Distance`, `LIMIT 5`.

`POST /issues/{id}/ccrs`: CCRS number normalised with the v1 rule (`src/lib/validation`: uppercase, spaces/dashes removed, 1–50 chars). Sets `ccrs_number`, `ccrs_filed_at=now()`; appends `issue_events(type='ccrs_linked', note='via:<filedVia>')`; if status is `reported`, also moves it to `sent` with a `status_change` event (TASK-06 later routes this through its state machine). Re-linking the same number returns 200; a different number → 409.

Quota helper `src/lib/quota/index.ts`: `assertDailyQuota(userId, key, opts?)` counts rows in the last rolling 24 h from the source table (`issues.reporter_id`, `me_toos.user_id`, `issue_verifications.user_id`, `rep_messages(citizen_id, representative_id)`, `photos.uploaded_by_user_id`). Over the limit → 429 `RATE_LIMITED` with `details:[{field:'quota', issue:'<key>_per_day'}]` and `Retry-After` = seconds until the oldest counted row is 24 h old. Keys/limits from env (§3).

New `AppError` codes: `WARD_CONFIRMATION_REQUIRED` 422, `OUTSIDE_SERVICE_AREA` 422, `IDEMPOTENCY_KEY_REUSED` 409, `OWN_ISSUE` 409, `ISSUE_NOT_OPEN` 409, `CCRS_ALREADY_LINKED` 409, `FORBIDDEN` 403 (if TASK-04 has not added it), `ENDPOINT_RETIRED` 410.

AMC fetch script `apps/api/scripts/fetch-amc-problems.ts` (`npm run amc:problems:fetch`): refuses (exit 2, "Last fetched <time>; run again after <time>") if `max(fetched_at)` is less than `AMC_PROBLEMS_MIN_INTERVAL_HOURS` old; one `GET` with 20 s timeout, `User-Agent: Saarthee/2 (+contact email from env)`, no retry loop (one retry after 60 s on network error, then exit 1); validates 50–500 rows with the 5 expected keys; writes `apps/api/prisma/data/amc-problem-types.snapshot.json` (sorted, pretty); upserts by `source_key`, sets `fetched_at`, marks vanished rows `is_active=false`; prints counts (new, changed, deactivated, unmapped). `--from-snapshot` loads the committed file without network (used by seed and tests). Never scheduled.

### 5.4 UI Surfaces & States

| Route | Content | States |
|---|---|---|
| `/report/what` (Step 1 of 3) | Title "What is the problem?"; grid of 14 tiles (40 dp `CategoryBadge` + label, 2 columns, ≥ 96 dp tall) | skeleton tiles; error "We couldn't load the list. Try again"; offline → cached list; signed out → tapping a tile opens sign-in, then returns to step 2 with the category saved |
| `/report/photo` (Step 2 of 3) | Title "Add a photo and check the place"; camera opens on entry for a new draft; up to 3 thumbnails (4:3, radius 8) with remove; "Add another photo"; mini-map with pin, ward label "In ward: Paldi (West zone)" and "Adjust pin"; duplicate panel "Already reported nearby" with cards "Me too — this is it" and "No, mine is different"; primary "Continue" | location permission denied → "We need your location to place the report on the map." + "Open settings" (Continue disabled); weak GPS (> 50 m) → "Location is approximate. Drag the pin to the exact spot."; upload progress per photo, failed → "Retry upload"; blurring → "Blurring faces and number plates…"; `confirm:true` → "This spot is just outside ward boundaries. Is it in Vasna?" Yes/Choose another ward; offline → photos kept, uploads resume on reconnect |
| `/report/photo/blur` | Full-screen photo; auto-blurred boxes outlined; "Tap or drag to blur more", "Undo", "Done"; caption "Faces and number plates blurred" | detector unavailable → manual tool only + note "Automatic blurring isn't available on this phone. Blur faces and number plates by hand." |
| `/report/details` (Step 3 of 3) | Title "Add details and check"; "Description (optional)" field with mic button (P2) and 1,000-char counter; for sensitive categories a single-choice list instead (encroachment: "Blocking the footpath", "Blocking the road", "Hawkers or stalls", "Other obstruction"; building: "Construction without permission", "Unsafe building", "Debris on the road", "Other"); summary rows Category / Photos / Place (ward) / Description each with "Change"; consent line "Your report, photos and place will be public. Your name and phone number are never shown."; primary "Submit report" | sending → button progress, disabled; server errors → `ErrorSummary` with links to steps, focus moved to it; `PHOTO_UNUSABLE` → "Your photo upload expired. Please retake the photo." link to step 2; offline → banner "You're offline. Your report is saved and will send automatically." and auto-retry on reconnect with the same `clientSubmissionId`; quota → "You've sent 10 reports today. You can send more tomorrow." |
| `/report/done` | "Report sent. Thank you." / "Neighbours can now see it and add Me too. We'll tell you when its status changes." (sensitive: "A moderator will check it before it is public.") Section "File with AMC too (optional)": "AMC's category for this: <dept> › <problem>"; buttons "Open AMC complaint website", "Use AMC's WhatsApp", "Call 155303", "Copy details for AMC"; independence line "Independent citizen app. Not run by or linked to AMC."; "Already filed? Add your AMC complaint number" → link screen; "Done" → Home | external app fails → "Couldn't open <target>. Try another way."; category `other` → "Choose the closest type on AMC's site." |
| `/issues/:id/link-ccrs` | Title "Add your AMC complaint number"; field + help "It's in the SMS or WhatsApp message AMC sent you."; "How did you file?" Website / WhatsApp / Phone; "Save" | inline "Enter the complaint number you got from AMC."; 409 → "A different number is already linked to this report."; offline → banner, Save disabled |

Tap budget (REQ-N-007), typical issue after the photo is accepted in the camera: Continue (1) → Submit report (2); with a duplicate shown: "No, mine is different" (+1) = 3; with pin adjust: drag + Continue = 4 max.

Copy-for-AMC text (clipboard, user's language): "<category> problem at <lat>,<lng> (https://maps.google.com/?q=<lat>,<lng>), ward <ward>. Reported on Saarthee <date>." The first hand-off tap records consent `share_with_amc_handoff` via TASK-04 `POST /me/consents` (once).

ARB keys (gu + en) under `report.*`, `report.handoff.*`, `report.blur.*`, `report.dup.*`, `linkCcrs.*`, `error.<CODE>`; Gujarati strings marked for native review.

TalkBack: "Step 1 of 3, What is the problem?"; photo labels "Photo 1 of the problem, taken 3 Oct, 2:19 pm"; pin has a non-drag alternative ("Move pin" with arrow buttons, 5 m steps) for accessibility.

### 5.5 Permissions & Roles

| Action | Visitor | Citizen | Moderator / Admin | Representative | Notes |
|---|---|---|---|---|---|
| `GET /categories`, `GET /issues/nearby`, public photo read | ✅ | ✅ | ✅ | ✅ | Public, IP limited |
| Upload report photo, `POST /issues`, me-too | ❌ (sign-in) | ✅ | ✅ | ✅ | Suspended → 403 |
| Link CCRS number | ❌ | Reporter only | ❌ | ❌ | Staff cannot change a citizen's CCRS link |
| Read hidden (sensitive) issue photo | ❌ | Own only | ✅ | Own ward (TASK-11) | |
| Run `amc:problems:fetch` | — | — | Operator CLI | — | Never exposed over HTTP |

### 5.6 Assumptions

- ASSUMPTION: SLA days in §5.2 are Saarthee starting targets (spec gives none) — shown as "Saarthee target", configurable in TASK-10.
- ASSUMPTION: `encroachment` and `building` are the sensitive categories (they point at private people/property) — issues start `hidden` until a moderator approves (TASK-10) and use structured reasons only, no free text.
- ASSUMPTION: Sign-in is requested when a signed-out visitor taps a category tile (before the camera), so photo uploads are always owned — D6 requires an account to report.
- ASSUMPTION: Camera only, no gallery — v1 evidence rule kept; the photo time and place must be the report's.
- ASSUMPTION: The mini-map uses `flutter_map` with a configurable tile provider (decision logged in TASK-07 §5.6); TASK-05 adds the package and `lib/core/map/civic_map.dart`, TASK-07 extends it.
- ASSUMPTION: `POST /issues/{id}/me-too` (create) is built here because the duplicate suggestion needs it; `DELETE`, counts on detail and auto-follow live in TASK-07 (REQ-F-031).
- ASSUMPTION: Quotas use rolling 24 h counts of DB rows, not calendar days, so they survive restarts and multiple API instances; photo quota 40/day is an added safety limit.
- ASSUMPTION: Stored `title` is English auto text; responses compute a localized `title` (`<category> · <ward>`) from the caller's language — no title editing in the 3-step flow (keeps the tap budget).
- ASSUMPTION: Plate detection = ML Kit on-device text recognition + Indian plate regex `^[A-Z]{2}\s?\d{1,2}\s?[A-Z]{0,3}\s?\d{4}$` on text blocks; blur = pixelate 12 px blocks over the padded box. Spec names only "plate heuristic".
- ASSUMPTION: CCRS JSON has no stable problem ID; `source_key` = sha1 of department + category + problem text. A text edit at AMC appears as one deactivated and one new row.
- ASSUMPTION: Reporter auto-follows their own issue (`follower_count=1`) so TASK-06 notifications reach them through one path.
- ASSUMPTION: v1 drafts are discarded on upgrade and `POST /reports` returns 410 — pilot v1 data was test data (D11); v1 complaints are already migrated by TASK-01.

## 6. Implementation Steps

1. **Migration `<ts>_v2_reporting`** per §5.2; `prisma generate`; never edit earlier migrations.
2. **AMC snapshot + map.** Commit `prisma/data/amc-problem-types.snapshot.json` (from one fetch; the snapshot taken 2026-10-03 has 113 rows, 22 departments) and `amc-category-map.json` (department/category rules, overrides, primaries, 22 `dept_gu` names).
3. **Fetch script** `scripts/fetch-amc-problems.ts` with interval guard, single request, validation, upsert, deactivation, `--from-snapshot`; `package.json` script `amc:problems:fetch`.
4. **Seed** `seed/v2-categories.ts`: 14 categories (§5.2) + `amc_problem_types` from the snapshot via the same mapping code; wired into `db:seed` / `demo:reset`; assert every category except `other` has exactly one primary.
5. **`GET /categories` v2** in `modules/categories` (replace v1 handler; v1 admin `ccrs_categories` screens untouched), ETag on the max `updated_at`.
6. **Quota helper** `src/lib/quota` with the five keys; unit tests for counting and `Retry-After`.
7. **Photos.** Extend `POST /photos`: `requireUser`, `uploaded_by_user_id`, `blurApplied`, user quota; add `GET /media/photos/{id}` reusing v1 `sendJpeg` and a cached 320/1024 resize (sharp), visibility check.
8. **Issues module** `src/modules/issues/`: `nearby`, `createIssue` (§5.3 workflow), `meToo` (insert ignore-conflict, `me_too_count` via `UPDATE … SET me_too_count = (SELECT count(*) …)` in the same transaction; reporter → `OWN_ISSUE`; closed status → `ISSUE_NOT_OPEN`), `linkCcrs`. Register router in `routes.ts`.
9. **Retire v1 reports API**: `/reports` → 410 `ENDPOINT_RETIRED`; remove the reports service from routing (keep code for TASK-01's legacy migration reference only if still imported).
10. **API tests** T-05-01…T-05-16 (§8) with Vitest + Supertest against the test database; run in CI.
11. **App: retire v1 report.** Delete `category_screen`, `file_with_amc_screen`, `number_screen`, `phone_screen`, `check_screen`; redirect `/report/category|file-with-amc|number|phone|check` → `/report/what`; drop v1 draft fields; ARB keys for removed screens deleted in both languages.
12. **Draft v2.** Rework `report_draft.dart` / `report_draft_controller.dart` to the §5.2 shape (persist on every change, restore step on launch); reuse `ReportUploadController` per photo; categories provider with cache.
13. **Lost-data recovery.** In `EvidenceCapture`, add `recoverLostPhoto()` calling `ImagePicker().retrieveLostData()` on Android at app start and when `/report/photo` mounts; a recovered file is compressed, added to the draft and the fix re-read; errors show "We couldn't recover the last photo. Please take it again."
14. **Blur (P1).** `lib/core/capture/blur/`: `FaceAndPlateDetector` (*candidate* `google_mlkit_face_detection`, `google_mlkit_text_recognition`), `BlurRenderer` (*candidate* `image`, runs in an isolate), manual blur screen; auto-run after capture before upload; `blurApplied` sent with the upload.
15. **Map.** Add *candidate* `flutter_map` + `latlong2`; `CivicMap` (muted tiles from `MAP_TILE_URL`, attribution, draggable pin, arrow-button pin mover).
16. **Screens** `/report/what`, `/report/photo`, `/report/photo/blur`, `/report/details`, `/report/done`, `/issues/:id/link-ccrs` per §5.4; duplicate panel calls `/issues/nearby` when the pin settles (debounce 500 ms); ward label from `GET /geo/locate`.
17. **Submit.** Idempotent submit (same `clientSubmissionId` on every retry; 200 = success); auto-retry on reconnect; error mapping to `ErrorSummary`; on success delete draft + photo files, go to `/report/done`.
18. **Hand-off** via `url_launcher` using existing dart-defines; consent record on first use; copy-to-clipboard text.
19. **Voice (P2).** *candidate* `speech_to_text`; locale `gu-IN` / `en-IN` from app language; mic hidden when unavailable; `RECORD_AUDIO` permission with rationale "So you can speak instead of typing."
20. **Widget + integration tests** W-05-01…W-05-07, I-05-01 (§8).
21. **Performance** M-05-06: count taps; measure cold start in a profile build; record numbers in §13.
22. **Manual emulator checks** M-05-01…M-05-07; update coverage matrix.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Categories with AMC mapping
- **Given** a freshly seeded database
- **When** `GET /categories` is called
- **Then** 14 active categories return in sort order with both names, icon, `colourToken`, `slaDays`, `sensitive`; every category except `other` lists ≥ 1 AMC problem type with exactly one `isPrimary`; all 113 snapshot problems are mapped to a category

**AC-2** — Polite AMC cache script
- **Given** problem types fetched less than 24 h ago
- **When** `npm run amc:problems:fetch` runs
- **Then** it exits 2 without any network request; after the interval it makes exactly one request, rewrites the snapshot, upserts by `source_key`, deactivates vanished rows and prints unmapped problems; `--from-snapshot` never touches the network

**AC-3** — Three-step happy path
- **Given** a signed-in citizen in Paldi with location on
- **When** they pick "Roads & potholes", take one photo, tap Continue and Submit report
- **Then** `/report/done` shows; the issue has ward Paldi, its zone, status `reported`, `sla_due_at` = created + 7 days, one `issue_photos` row, one `issue_events` row (`null → reported`), a reporter `follows` row; at most 4 taps were needed after the photo

**AC-4** — Adjustable pin and ward confirmation
- **Given** the device fix is 30 m off and the spot lies just outside every ward polygon
- **When** the citizen drags the pin and submits
- **Then** the issue stores the pin position, `pinAdjusted=true`; the app first asks "Is it in <ward>?" and the server rejects a submit without `confirmedWardId` with 422 `WARD_CONFIRMATION_REQUIRED`; a point 5 km outside the city returns 422 `OUTSIDE_SERVICE_AREA`

**AC-5** — Duplicate suggestions
- **Given** an open public "garbage" issue 30 m away created 10 days ago, a closed one 20 m away, and an open one 80 m away
- **When** the citizen reaches step 2 with category garbage at that spot
- **Then** only the 30 m issue is suggested; "Me too — this is it" records a me-too (count +1), discards the draft and opens a confirmation; "No, mine is different" hides it and continues

**AC-6** — Idempotent submission
- **Given** a submitted issue
- **When** the same body is posted again, two new identical bodies are posted concurrently, and another user reuses the `clientSubmissionId`
- **Then** the repeat returns 200 with the same id; the concurrent pair yields one 201 and one 200 and one row; the other user gets 409 `IDEMPOTENCY_KEY_REUSED`

**AC-7** — Draft survives kill and camera hand-off
- **Given** a draft at step 2 with one uploaded photo
- **When** the app is force-stopped while the camera is open, then relaunched
- **Then** the draft reopens on step 2 with category, photo and pin intact; if Android returned the photo via lost data, it is recovered into the draft; Home shows "Continue your report"

**AC-8** — Business-rule rejections keep the draft
- **Given** an expired photo, an inactive category, a photo uploaded by another user, or a description on a sensitive category
- **When** Submit report is tapped
- **Then** 422 `PHOTO_UNUSABLE` / 422 `CATEGORY_INACTIVE` / 422 `PHOTO_UNUSABLE` / 400 `VALIDATION_FAILED`; the app shows an error summary linking to the right step and keeps the draft

**AC-9** — File with AMC too and link later
- **Given** a submitted roads issue
- **When** the done screen shows and the citizen taps "Open AMC complaint website", then later saves "AMC-2026-1234" via WhatsApp on the link screen
- **Then** the screen shows "Engineering › Road-Repair Require" (in Gujarati when the app is Gujarati) with the independence line; consent `share_with_amc_handoff` is recorded once; the issue stores `AMC20261234`, `ccrs_filed_at`, a `ccrs_linked` event and moves `reported → sent`; a different number later → 409; a non-reporter → 403

**AC-10** — Per-user quotas
- **Given** a citizen with 10 issues in the last 24 h, and quota rows seeded for me-too (100), verifications (20) and messages (5 to one representative)
- **When** they submit an 11th issue, and the helper is asked for each other key
- **Then** the issue returns 429 `RATE_LIMITED` with `issues_per_day` and a correct `Retry-After`; the helper reports over-limit for each key; the app shows "You've sent 10 reports today. You can send more tomorrow."

**AC-11** — On-device blur
- **Given** a photo containing a face and a GJ number plate
- **When** it is captured on step 2
- **Then** both are pixelated before upload, the thumbnail shows "Faces and number plates blurred", the upload carries `blurApplied=true`; the manual tool can blur an extra area and undo; the server never receives the unblurred image

**AC-12** — Voice input
- **Given** the app in Gujarati with speech recognition available
- **When** the citizen taps the mic on step 3 and speaks
- **Then** the transcript appears in the description in Gujarati and can be edited; with no recogniser the mic is hidden

**AC-13** — Performance
- **Given** a profile build on a low-end Android phone (or the reference emulator profile when no phone is available, recorded as such)
- **When** cold start is measured 5 times and the typical report is completed
- **Then** median time to first frame ≤ 3 s and the report needs ≤ 4 taps after the photo

**AC-14** — v1 retired
- **Given** the v2 app and API
- **When** `/report/number` is opened or `POST /reports` is called
- **Then** the app redirects to `/report/what` and the API returns 410 `ENDPOINT_RETIRED`

### AC → Requirement

| AC | Requirements |
|---|---|
| AC-1 | REQ-F-012, REQ-D-007 |
| AC-2 | REQ-F-013 |
| AC-3 | REQ-F-014, REQ-F-016, REQ-N-007 |
| AC-4 | REQ-F-014, REQ-F-016 |
| AC-5 | REQ-F-015 |
| AC-6 | REQ-F-016 |
| AC-7 | REQ-F-017 |
| AC-8 | REQ-F-014, REQ-F-016, REQ-F-017 |
| AC-9 | REQ-F-018 |
| AC-10 | REQ-S-008 |
| AC-11 | REQ-S-007 |
| AC-12 | REQ-F-019 |
| AC-13 | REQ-N-007 |
| AC-14 | REQ-F-014 |

### 7.2 Non-Functional Checklist

- [ ] Every report screen has loading, error, empty, offline and in-flight states; Submit disabled while sending
- [ ] "Step n of 3" announced by TalkBack; focus moves to `ErrorSummary`; pin movable without dragging
- [ ] All copy in ARB (gu + en), including server error codes; no hard-coded strings or colours
- [ ] Usable at 320 dp width and 2.0× font; primary button stays above the keyboard on step 3
- [ ] Issue insert, photo attach, event and follow happen in one transaction (rollback verified by forcing a failure)
- [ ] No reporter id, name or phone in `GET /issues/nearby` or photo responses
- [ ] Request bodies, descriptions and CCRS numbers never logged
- [ ] AMC JSON fetched only by the script; tests and seed use the snapshot; no AMC logo anywhere
- [ ] Report screens import providers only — no API client in `presentation/`
- [ ] Blur runs off the UI thread; completes ≤ 1.5 s per photo on the emulator

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-05-01 | `npm run typecheck && npm run lint`; `dart format --set-exit-if-changed . && flutter analyze` | all |
| API (Vitest+Supertest) | T-05-01 | `GET /categories`: 14 items, order, fields, one primary per non-other category, ETag → 304 | AC-1 |
| API | T-05-02 | Mapping covers all 113 snapshot rows; unknown department → `other` | AC-1 |
| API | T-05-03 | Fetch script with mocked `fetch`: interval guard (no call), one call after interval, upsert/deactivate, `--from-snapshot` no call | AC-2 |
| API | T-05-04 | `POST /issues` happy path: ward/zone from seeded polygon, SLA date, event, follow, photos attached | AC-3 |
| API | T-05-05 | Outside polygon near ward → 422 `WARD_CONFIRMATION_REQUIRED`; with `confirmedWardId` → 201; 5 km out → 422 `OUTSIDE_SERVICE_AREA` | AC-4 |
| API | T-05-06 | `GET /issues/nearby`: radius, category, open statuses, 30-day window, hidden excluded, order, no reporter fields | AC-5 |
| API | T-05-07 | Me-too create: 201 then 200, count, `OWN_ISSUE`, `ISSUE_NOT_OPEN` | AC-5 |
| API | T-05-08 | Idempotency: repeat 200, 8 concurrent → one 201, other user 409 | AC-6 |
| API | T-05-09 | Rejections: expired / foreign / reused photo, inactive category, description on sensitive, clock +15 min, 0 or 4 photos | AC-8 |
| API | T-05-10 | Sensitive category → `visibility=hidden`; hidden photo 404 publicly, 200 for owner | AC-8 |
| API | T-05-11 | CCRS link: normalise, event, `reported→sent`, same number 200, different 409, non-reporter 403 | AC-9 |
| API | T-05-12 | Quota helper for issues, me_too, verifications, messages, photos; 429 body + `Retry-After` | AC-10 |
| API | T-05-13 | `POST /photos` without session → 401; `blurApplied` stored; EXIF stripped (v1 pipeline still applies) | AC-11 |
| API | T-05-14 | `POST /reports` → 410 `ENDPOINT_RETIRED` | AC-14 |
| API | T-05-15 | Suspended user → 403 `ACCOUNT_SUSPENDED` | AC-3 |
| API | T-05-16 | Transaction rollback: forced failure after insert leaves no issue and photos unattached | AC-3 |
| Widget | W-05-01 | Category grid renders 14 tiles from a fake provider; skeleton, error, offline-cached states | AC-1, AC-3 |
| Widget | W-05-02 | Step 2: duplicate panel actions; weak GPS and permission-denied states | AC-5 |
| Widget | W-05-03 | Step 3: sensitive category shows structured choices and no text field; Change links | AC-8 |
| Widget | W-05-04 | Error summary mapping for each server code, focus moved | AC-8, AC-10 |
| Widget | W-05-05 | Done screen: primary AMC type in gu/en, independence line, category `other` copy | AC-9 |
| Widget | W-05-06 | Draft controller restore from JSON (v2) and discard of v1 JSON | AC-7, AC-14 |
| Widget | W-05-07 | Blur renderer pixelates given boxes (golden test on a fixture image) | AC-11 |
| Integration | I-05-01 | Emulator: full report with fake camera + mock location against the local API; asserts tap count ≤ 4 after the photo | AC-3, AC-13 |
| Manual | M-05-01 | Kill with `adb shell am force-stop` during camera; relaunch; lost-data recovery (enable "Don't keep activities") | AC-7 |
| Manual | M-05-02 | Airplane mode at step 3 → Submit → reconnect → one issue | AC-6, AC-8 |
| Manual | M-05-03 | Hand-off buttons open CCRS web, WhatsApp, dialer; link CCRS screen | AC-9 |
| Manual | M-05-04 | Photo with a face and a plate (printed test card) → blurred upload; manual tool | AC-11 |
| Manual | M-05-05 | Voice input in Gujarati and English | AC-12 |
| Manual | M-05-06 | `flutter run --profile --trace-startup` ×5 → `build/start_up_info.json`; tap count | AC-13 |
| Manual | M-05-07 | TalkBack pass through the three steps; 2.0× font | AC-3 |

## 9. Deliverables

- Migration `<ts>_v2_reporting`; category seed; AMC snapshot + mapping files; `amc:problems:fetch` script.
- API modules `categories` (v2), `issues` (nearby, create, me-too create, CCRS link), photos extensions, `media` read, `lib/quota`; v1 `/reports` retired.
- App: three-step report feature, blur tool, `CivicMap`, link-CCRS screen, voice input; v1 report screens removed.
- Tests T-05-01…16, W-05-01…07, I-05-01; performance numbers in §13; coverage evidence for 12 requirements.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/api/prisma/migrations/<ts>_v2_reporting/` | New |
| `apps/api/prisma/data/amc-problem-types.snapshot.json`, `amc-category-map.json` | New |
| `apps/api/prisma/seed/v2-categories.ts`, `prisma/seed.ts` | New / Modified |
| `apps/api/scripts/fetch-amc-problems.ts`, `apps/api/package.json` | New / Modified |
| `apps/api/src/modules/{categories,issues,media}/`, `src/modules/photos/`, `src/modules/reports/` | New / Modified |
| `apps/api/src/lib/quota/`, `src/lib/errors/index.ts`, `src/routes.ts` | New / Modified |
| `apps/api/test/issues/*.test.ts`, `test/categories.test.ts`, `test/quota.test.ts` | New |
| `apps/mobile/lib/features/report/` (data, application, presentation) | Rewritten |
| `apps/mobile/lib/core/capture/` (lost data, blur), `lib/core/map/civic_map.dart` | Modified / New |
| `apps/mobile/lib/router/citizen_routes.dart`, `lib/core/l10n/app_en.arb`, `app_gu.arb` | Modified |
| `apps/mobile/pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist` | Modified |
| `apps/mobile/test/report/*`, `integration_test/report_flow_test.dart` | New |

## 11. Related Documentation

- `docs/v2/saarthee-v2-spec.md` §4 (taxonomy), §5 (duplicates, CCRS link), §6 (tables), §7 (endpoints, rate limits), §8 (routes), §11 (blur, independence)
- `docs/v2/design-system.md` DS §1 (independence line), §2 (category colours), §5 (step header, buttons, inputs, error summary), §6, §7 (report flow, 4-tap target)
- `docs/tasks/TASK-04-report-flow.md` — v1 photo pipeline, draft and idempotency patterns reused
- `docs/tasks-v2/TASK-02-*.md` (geo `locate`), `TASK-04-*.md` (session, consents), `TASK-07-discovery.md` (map package decision)

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| CCRS JSON changes shape or blocks requests | Mapping stale | Committed snapshot is the source for seed/tests; script validates shape and never runs automatically |
| ML Kit adds APK size and misses some faces/plates | Bigger download; privacy gaps | Manual blur tool always offered; measure APK delta; moderators can hide photos (TASK-10) |
| Camera hand-off kills the app on low-RAM phones | Lost photo | Draft persisted before camera; `retrieveLostData()`; M-05-01 with "Don't keep activities" |
| Ward polygons wrong near boundaries (TASK-02 open question 2) | Issue in wrong ward | Confirm-nearest flow; moderators can change ward (TASK-10) |
| Duplicate check too strict/loose | Split or wrongly merged reports | Radius/window configurable; moderators merge |
| Quota counts on large tables slow | Slow submit | Indexed `(reporter_id, created_at)`; counts bounded to 24 h |
| Tile provider free tier exceeded | Map blank | Configurable `MAP_TILE_URL`; cache tiles; monitor usage (TASK-07) |

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
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-05` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `V2-TASK-05: …`
- [ ] Validator passes
