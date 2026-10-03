# TASK-07: Discovery — Home Feed, Map, Issue Detail and Social Actions

| Field | Value |
|---|---|
| Task ID | TASK-07 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | TASK-06 |
| Blocks | TASK-14 |
| Requirement IDs | REQ-F-028, REQ-F-029, REQ-F-030, REQ-F-031, REQ-F-032, REQ-F-033, REQ-F-034, REQ-N-008, REQ-N-011, REQ-S-006 |
| Primary Spec Refs | Spec §7 (Issues, Feed & map endpoints, rate limits), §8 (`/`, `/map`, `/issues/:id`, `/me/reports`, `/me/following`), §11 (reporter privacy); DS §2 (status, category colours), §4, §5 (app bar, issue card, status timeline, map, empty/loading/error), §6, §8 |
| Last Updated | 2026-10-03 |

## 1. Objective

Let anyone see what is happening in their ward and act on it. The Home tab shows the chosen ward's alerts strip, a clear "Report an issue" action, nearby issues, upcoming drives and service shortcuts — and keeps working when alerts or drives are not built or empty. The Map tab shows every public issue with fast clustering. Issue detail tells the whole story — before/after photos, status and timeline — and offers Me too, Follow, Share, Verify, Link CCRS and Escalate. Citizens see their own reports and the issues they follow. Reporters are never identified publicly: they are always "A resident of <ward>".

## 2. Scope

### In Scope
- `GET /issues` (filters, sort, cursor), `GET /issues/{id}` (detail with derived fields and viewer capabilities), `GET /feed?ward`, `GET /map/issues?bbox&zoom`.
- `DELETE /issues/{id}/me-too`, `POST/DELETE /issues/{id}/follow`; Me too auto-follows; counts kept consistent (TASK-05 built `POST …/me-too`).
- Shared public serializer `toPublicIssue()` enforcing REQ-S-006 everywhere (also adopted by TASK-05 nearby and TASK-06 events).
- Public share page `GET /i/{id}` (minimal HTML with Open Graph tags, no PII) used as the share and evidence link.
- Map SDK decision (`flutter_map` — §5.6), muted tiles, client clustering; server grid clustering.
- App: Home screen, Map tab, issue list screen (`/issues`), Issue detail (`/issues/:id`), My reports (`/me/reports`), Following (`/me/following`), share as image card + link (P1).
- Pagination on every list endpoint; performance seed and p95 measurement (REQ-N-011); 2,000-issue map smoothness (REQ-N-008).

### Out of Scope
- Alerts data, alert strip content and inbox — TASK-08 (feed consumes its contract and degrades when absent).
- Initiatives/drives, services and seasonal tips — TASK-12 (same degrade rule).
- Status changes, verification, escalation, CCRS-closed screens — TASK-06 (detail only opens them).
- Link CCRS screen — TASK-05; "Report a problem" flag sheet and endpoint — TASK-10 (menu item hidden until present).
- Representative actions UI beyond showing TASK-06 `IssueStatusActions` — TASK-11.
- Comments (structured comments are not specified for v2 detail beyond events).

## 3. Prerequisites

- TASK-06 complete: `transition()`, derived fields (`isOverdue`, `displayStatus`, `verifyWindowClosesAt`), events endpoint, verify/mark-fixed/escalate routes, `IssueStatusActions`.
- TASK-05: issues, `issue_photos`, `GET /media/photos/{id}`, `POST …/me-too`, `CivicMap` wrapper, link-CCRS route.
- TASK-02: `GET /wards/{id}` with centroid/bbox; ward picker. TASK-03: shell, components (`IssueCard`, `StatusChip`, `CategoryBadge`, `StatusTimeline`, skeletons, banners). TASK-04: sign-in gate returning to the action, `requireUser` and optional-auth middleware.
- Env: `FEED_CACHE_SECONDS=30`, `MAP_CLUSTER_MAX_ZOOM=15`, `MAP_POINTS_MAX=500`, `ISSUES_PAGE_MAX=50`, `PUBLIC_WEB_BASE_URL`. Dart-defines: `MAP_TILE_URL`, `MAP_TILE_ATTRIBUTION`, `PUBLIC_WEB_BASE_URL`.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-06 | Detail and lists show lifecycle state (overdue, Fixed (not verified)) and link to verify, mark-fixed, escalate; timeline comes from its events endpoint |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-028 | Home feed for the selected ward: alerts strip, report action, nearby issues, upcoming drives, service shortcuts (`GET /feed`) | Spec §8 |
| REQ-F-029 | Map tab with clustered issue pins, category/status/"mine" filters, bottom-sheet preview (`GET /map/issues`) | Spec §8 |
| REQ-F-030 | Issue detail: photos with before/after, status and timeline, Me too, Follow, Share, Verify/Reopen, Link CCRS, Escalate, report a problem | Spec §8 |
| REQ-F-031 | Me too and Follow (`POST/DELETE`) with counts; one per user | Spec §7 |
| REQ-F-032 | Share an issue as an image card plus link to WhatsApp and other apps | Spec §8 |
| REQ-F-033 | My reports and Following lists with status chips | Spec §8 |
| REQ-F-034 | Issue list API with filters (ward, category, status, bbox), sort (newest, most affected, overdue) and cursor paging | Spec §7 |
| REQ-N-008 | Map renders 2,000 issues smoothly using server clustering and client clustering | Spec §7 |
| REQ-N-011 | All list endpoints paginated; p95 latency < 400 ms for feed, list and detail on pilot data | Spec §7 |
| REQ-S-006 | Public views never expose reporter phone or name; "A resident of <ward>" | Spec §11 |

### 5.2 Data Contracts

Migration `<ts>_v2_discovery_indexes` (add only what TASK-01/05/06 did not create; check with `\d issues`):
- `issues (ward_id, status, created_at DESC, id)` — ward lists and feed.
- `issues (status, sla_due_at)` exists from TASK-06; add `issues (me_too_count DESC, id)` partial `WHERE visibility='public'`.
- `follows (user_id, created_at DESC)`, `me_toos (user_id, created_at DESC)`.
- GIST on `issues.location` (TASK-01) and an expression index `GIST ((location::geometry))` for bbox and snap-to-grid.

Public issue shape (`src/modules/issues/public.ts#toPublicIssue`, the only serializer used by public routes):
`{id, title (localized "<category> · <ward>"), category:{slug, nameEn, nameGu, icon, colourToken}, status, displayStatus, isOverdue, slaDueAt, ward:{id, number, nameEn, nameGu}, zone:{code, nameEn, nameGu}, location:{lat, lng}, description, photos:{report:[url], after:[url], verification:[url]}, blurApplied, reporterLabel:{en:"A resident of Paldi", gu:"પાલડીના રહેવાસી"}, meTooCount, followerCount, createdAt, statusChangedAt, verifyWindowClosesAt, mergedIntoId}` — never `reporter_id`, phone, display name, `client_submission_id`, `ccrs_number`, device fields, `legacy_complaint_id`.

Card shape (lists/feed/map preview): `{id, title, categorySlug, status, displayStatus, isOverdue, wardNameEn, wardNameGu, createdAt, meTooCount, thumbnailUrl}`.

Seed for performance (`prisma/seed/perf-issues.ts`, not part of the default seed; `npm run seed:perf`): 5,000 issues across 48 wards (2,000 inside the Paldi–Vasna bbox), all statuses, 20,000 events, 30,000 me-toos, 15,000 follows, fictional users.

### 5.3 API Contracts

| Method | Path | Auth | Request | Response | Errors | Rate limit |
|---|---|---|---|---|---|---|
| GET | `/api/v1/issues` | Optional (required for `mine`/`following`) | `ward`, `category` (csv slugs), `status` (csv of statuses + `overdue`, `fixed_unverified`), `bbox=minLng,minLat,maxLng,maxLat`, `mine=true`, `following=true`, `sort=newest\|most_affected\|overdue`, `cursor`, `limit` (1–50, default 20), `lang` | `{items:[Card], nextCursor\|null}` | 400 `VALIDATION_FAILED` (bad bbox > 0.5° span, unknown sort), 401 for `mine`/`following` | 120/IP/min |
| GET | `/api/v1/issues/{id}` | Optional | `lang` | `{issue: PublicIssue, viewer:{signedIn, isReporter, hasMeToo, isFollowing, canVerify, canMarkFixed, canAcknowledge, canLinkCcrs, canMarkCcrsClosed, canEscalate, canFlag}, ccrs:{linked, number? (reporter only), closedAt?}, timelinePreview:[≤ 5 events]}` | 404 (missing, or hidden/rejected for non-reporter non-staff) | 120/IP/min |
| POST | `/api/v1/issues/{id}/me-too` | Citizen | — (TASK-05) + auto-follow | 201/200 `{meTooCount, followerCount, isFollowing:true}` | 404, 409 `OWN_ISSUE`/`ISSUE_NOT_OPEN`, 429 | 100/user/day |
| DELETE | `/api/v1/issues/{id}/me-too` | Citizen | — | 200 `{meTooCount}` (204-equivalent idempotent: 200 when absent) | 404 | 100/user/day (shared key) |
| POST | `/api/v1/issues/{id}/follow` | Citizen | — | 200 `{followerCount, isFollowing:true}` | 404 | 120/user/min |
| DELETE | `/api/v1/issues/{id}/follow` | Citizen | — | 200 `{followerCount, isFollowing:false}` | 404 | 120/user/min |
| GET | `/api/v1/feed` | Optional | `ward` (required unless signed in with home ward), `lang` | `{ward:{id, number, nameEn, nameGu, zone}, sections:{alerts:{items, degraded}, nearbyIssues:{items ≤ 10, degraded}, drives:{items ≤ 5, degraded}, serviceShortcuts:{items ≤ 6, degraded}, tips:{items ≤ 1, degraded}}, generatedAt}` + `ETag`, `Cache-Control: public, max-age=30` | 400 `WARD_REQUIRED`, 404 ward | 120/IP/min |
| GET | `/api/v1/map/issues` | Optional | `bbox` (required), `zoom` (0–20), `category`, `status`, `mine` | zoom < `MAP_CLUSTER_MAX_ZOOM`: `{mode:'clusters', cellDeg, items:[{lat, lng, count, topCategory, hasOverdue}]}`; else `{mode:'points', items:[{id, lat, lng, categorySlug, status, isOverdue}], truncated}` (≤ `MAP_POINTS_MAX`; if exceeded → clusters) | 400 bbox span > 0.5°/zoom invalid | 120/IP/min |
| GET | `/i/{id}` (outside `/api/v1`) | None | — | HTML: title, status word, ward, age, report photo (1024 px), `og:title`, `og:description`, `og:image`, "Open in Saarthee", independence line; `noindex` | 404 page | 120/IP/min |

Cursor: opaque base64url of `{s: sortKey, id}` — `newest` keys `(created_at DESC, id DESC)`; `most_affected` `(me_too_count DESC, created_at DESC, id DESC)`; `overdue` `(sla_due_at ASC, id ASC)` restricted to `isOverdue`. Default visibility filter `public` and status ≠ `rejected`, `merged` (except `mine=true`, which includes hidden/rejected own issues with a reason).

Feed composition (`src/modules/feed/feed.service.ts`): section providers run in parallel, each wrapped with a 150 ms timeout and try/catch; failure or missing module → `{items:[], degraded:true}`, logged at `warn` once per minute. Providers: `alerts` → TASK-08 `alertsService.activeForWard(wardId, lang)` (absent before TASK-08); `nearbyIssues` → open public issues in the ward, `most_affected` then newest; `drives` → TASK-12 `initiativesService.upcomingForWard(wardId, 5)`; `serviceShortcuts` → TASK-12 `servicesService.shortcuts(6)`; `tips` → TASK-12 `tipsService.current()`. Responses cached in memory per `ward+lang` for `FEED_CACHE_SECONDS` (anonymous view only; viewer-specific bits are fetched by the app separately).

Map clustering: `ST_SnapToGrid(location::geometry, cell)` with `cell = 360 / 2^zoom / 4` (≈ 64 px cells), `GROUP BY` → centroid `ST_Centroid(ST_Collect(...))`, count, mode category; bbox filter with `location::geometry && ST_MakeEnvelope(...,4326)`.

Me too / Follow consistency: inserts/deletes and counter updates in one transaction (`UPDATE issues SET me_too_count = me_too_count ± 1 WHERE … AND row affected`); Me too on create also inserts a follow (ignore conflict). Removing Me too does not unfollow. Reporter can unfollow their own issue.

### 5.4 UI Surfaces & States

| Route | Content | States |
|---|---|---|
| `/` Home | App bar: "Saarthee" + ward subtitle "Paldi · West zone" (tap → ward picker "Change ward"), language switch (અ/A), bell with unread badge (TASK-08; hidden until available). Alerts strip (horizontal alert cards, hidden when empty). Primary "Report an issue" (or "Continue your report" when a draft exists). "Issues near you" — up to 10 `IssueCard`s + "See all" → `/issues?ward=<id>`. "Upcoming drives" strip (hidden when empty). "Services" shortcuts grid (hidden when empty). | skeleton rows; error "We couldn't load your ward. Try again"; offline → last cached feed with "You're offline. Showing what we had at 10:42."; empty issues → icon + "No issues reported in Paldi yet." + "Report an issue"; no ward set → ward picker prompt |
| `/issues` | Title "Issues in Paldi"; filter chips: Category (sheet, multi), Status (Open, Overdue, Fixed, Verified), sort menu (Newest, Most affected, Overdue first); infinite list of `IssueCard`s | skeleton; empty "No issues match these filters." + "Clear filters"; error retry; end-of-list "That's all." |
| `/map` | `CivicMap` (muted tiles, attribution), category-coloured teardrop pins with status ring; slate cluster bubbles with counts; chips Category, Status, "Mine" (signed in); "My location" button; tap pin → bottom sheet `IssueCard` + "View details"; tap cluster → zoom in | loading bar at top (map stays interactive); error snackbar "Couldn't load issues here. Try again"; empty area → chip "No issues in this area"; offline → banner, last pins kept; location denied → map centred on home ward, button hidden |
| `/issues/:id` | Photo carousel with tabs "Before" / "After" (after + verification photos; tab hidden when none); caption "Faces and number plates blurred" when applicable; status chip (icon + word, DS §2) + "Overdue" tag; title; "<Category> · <Ward> · 3 days ago"; "Reported by a resident of Paldi"; "Saarthee target: fixed by 10 Oct" (helper "This is Saarthee's target, not an AMC deadline."); action row: "Me too (12)", "Follow", "Share"; contextual card: Fixed → "Is it fixed?" with "Yes, it's fixed" / "Still not fixed" (TASK-06 verify); `fixed_unverified` → "Fixed (not verified)"; reporter → "Add AMC complaint number" (TASK-05) or "AMC closed it?" (TASK-06 sheet); open + `canEscalate` → "Escalate" (suggested when overdue); `IssueStatusActions` for staff/representatives; timeline (TASK-03 `StatusTimeline`, "See full history" pages events); overflow "Report a problem" (TASK-10) | skeleton; 404 → "This issue isn't available. It may have been removed."; merged → banner "This report was merged into another one." + "Open it"; rejected (reporter only) → "Not accepted: <reason>"; offline → cached detail read-only, actions disabled with "You're offline"; signed-out tap on Me too/Follow → sign-in then the action runs |
| `/me/reports` | "My reports" list of own issues (incl. hidden/rejected), status chips, "Moderator check pending" tag for hidden sensitive ones | signed out → "Sign in to see your reports" + "Sign in"; empty "You haven't reported anything yet." + "Report an issue"; skeleton; error retry |
| `/me/following` | "Following" list, status chips, swipe or overflow "Unfollow" | signed out → sign-in prompt; empty "Follow an issue to get updates when its status changes." |
| Share (P1) | Off-screen `IssueShareCard` (1080×1350): Saarthee wordmark, report photo, category badge, title, ward, status chip, "<n> residents affected", "Independent citizen app. Not run by or linked to AMC."; rendered via `RepaintBoundary` → PNG; `share_plus` sheet with text "<title> — <status>. See it on Saarthee: <PUBLIC_WEB_BASE_URL>/i/<id>" | render failure → share link text only |

ARB keys under `home.*`, `issues.*`, `map.*`, `issueDetail.*`, `share.*`, `me.reports.*`, `me.following.*`, `reporter.residentOf` ("A resident of {ward}" / "{ward}ના રહેવાસી").

Accessibility: pins and clusters have semantics labels ("Pothole, reported, in Paldi" / "12 issues here, zoom in"); map has a "Show as list" button opening `/issues` with the current bbox (TalkBack users don't need the map); Me too/Follow announce new state and count.

### 5.5 Permissions & Roles

| Action | Visitor | Citizen | Reporter | Moderator / Admin | Representative |
|---|---|---|---|---|---|
| Feed, list, map, public detail, `/i/{id}` | ✅ | ✅ | ✅ | ✅ | ✅ |
| See hidden/rejected issue detail | ❌ | ❌ | Own | ✅ | Own ward (TASK-11) |
| See CCRS number | ❌ | ❌ | ✅ | ✅ (staff views, TASK-10) | ❌ |
| Me too | ❌ (sign-in) | ✅ | ❌ (`OWN_ISSUE`) | ✅ | ✅ |
| Follow / unfollow | ❌ (sign-in) | ✅ | ✅ | ✅ | ✅ |
| `mine` / `following` filters, My reports, Following | ❌ | ✅ | ✅ | ✅ | ✅ |
| Reporter identity in any public response | ❌ | ❌ | ❌ | Staff endpoints only (TASK-10) | ❌ |

### 5.6 Assumptions

- ASSUMPTION: **Map SDK = `flutter_map` (+ `flutter_map_marker_cluster`) with a configurable raster tile provider.** Evaluation: `google_maps_flutter` — Maps SDK for Android map loads currently carry no usage charge, but it needs an API key with billing, Google Play services, and the staff console's web build would use the Maps JavaScript API (billed after the free monthly allowance); custom muted styling is possible. `flutter_map` — BSD-licensed, identical on Android, iOS and web (D7), easy muted basemap and offline caching, no Play-services dependency; cost depends on the tile host (OSM's public tile server forbids app-scale use, so a provider with an OSM-based free tier, or self-hosted tiles, is required; attribution "© OpenStreetMap contributors" always shown). Chosen for one code path across app and web console and no vendor billing account. Verify current pricing/terms of the chosen tile host before TASK-13.
- ASSUMPTION: Server clusters below zoom 15 and returns points (≤ 500) at zoom ≥ 15; the client clusters points — meets "server clustering and client clustering".
- ASSUMPTION: The CCRS number is shown only to the reporter (and staff) — it is tied to the citizen's phone at AMC.
- ASSUMPTION: Representatives appear in timelines by role + name (public officials acting in office); moderators as "Saarthee moderator"; all citizens as "A resident of <ward>".
- ASSUMPTION: Me too implies Follow (affected residents want updates); removing Me too keeps the follow.
- ASSUMPTION: `/i/{id}` is a minimal server-rendered page from the API with `noindex`; Android App Links (`assetlinks.json`) and the public domain are set up in TASK-13.
- ASSUMPTION: Feed is cached 30 s per ward + language for anonymous content; viewer-specific state (`hasMeToo`, draft) is not in the cached feed.
- ASSUMPTION: p95 measured locally on the perf seed with autocannon (*candidate*) at 50 concurrent connections; re-measured on staging in TASK-13/14.

## 6. Implementation Steps

1. **Migration `<ts>_v2_discovery_indexes`**; `EXPLAIN ANALYZE` the list, feed and map queries on the perf seed and record plans.
2. **`toPublicIssue()` + card serializer** in `modules/issues/public.ts`; switch TASK-05 `nearby` and TASK-06 events/detail paths to it; add a privacy test helper that scans response JSON for seeded phones/names/ids.
3. **`GET /issues`** with Zod query schema, cursor encode/decode, filter builder (parameterised SQL / Prisma raw), `mine`/`following` auth.
4. **`GET /issues/{id}`** with viewer capabilities computed from TASK-06 rules (single source: `lifecycle/capabilities.ts`).
5. **Me too DELETE, Follow POST/DELETE**, auto-follow on Me too; counter consistency in transactions.
6. **`GET /map/issues`** clustering/points per §5.3.
7. **`GET /feed`** with section providers, timeouts, degrade flags, cache + ETag; provider registry so TASK-08/12 register by import without editing feed code.
8. **`GET /i/{id}`** HTML template (escaped output, CSP `default-src 'none'; img-src 'self'; style-src 'unsafe-inline'`).
9. **Perf seed + script** `npm run seed:perf`, `npm run perf:read` (autocannon on feed, list, detail, map) printing p50/p95.
10. **API tests** T-07-01…T-07-15.
11. **App data layer** `features/discovery/data` (repositories, models), providers with cache (feed last-good in shared_preferences), optimistic Me too/Follow with rollback on error.
12. **Home screen** replacing the TASK-03 placeholder; ward picker hook.
13. **Map tab**: extend `CivicMap` with pins (category colour, status ring), cluster layer, debounce 300 ms on camera idle, filters, bottom sheet, "Show as list".
14. **Issue list, detail, My reports, Following** screens per §5.4; wire TASK-05/06 routes and TASK-06 `IssueStatusActions`; timeline via `issueEventsProvider`.
15. **Share (P1)**: `IssueShareCard`, PNG render, *candidate* `share_plus`.
16. **Widget + integration tests** W-07-01…W-07-07, I-07-01.
17. **Performance**: map with perf seed in a profile build (performance overlay / DevTools frame chart); record numbers in §13.
18. **Manual checks** M-07-01…M-07-06; coverage matrix.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Feed composes and degrades
- **Given** ward Paldi with 12 open issues and no alerts/initiatives/services modules installed
- **When** `GET /feed?ward=<paldi>` is called and the Home tab opens
- **Then** the response has 10 nearby issues and `alerts`, `drives`, `serviceShortcuts`, `tips` as empty with `degraded:true`; Home shows the ward header, "Report an issue" and issues, and hides the empty strips without errors; with a stub provider that throws or sleeps 500 ms, the feed still returns within 400 ms

**AC-2** — Issue list filters, sort and paging
- **Given** the perf seed
- **When** `GET /issues` is called with each filter (ward, category list, status incl. `overdue`, bbox) and sort, following `nextCursor` to the end
- **Then** every item matches the filters, order is correct, no item repeats or is skipped across pages, `limit > 50` → 400, and `mine=true` without auth → 401

**AC-3** — Map clustering
- **Given** 2,000 public issues in the Paldi–Vasna bbox
- **When** the map is opened at zoom 12, then zoomed to 16
- **Then** zoom 12 returns `mode:'clusters'` with counts summing to 2,000; zoom 16 returns points (≤ 500) clustered on the client; filters by category/status/Mine change results; tapping a pin opens the bottom-sheet preview and "View details"

**AC-4** — Map smoothness
- **Given** a profile build with the perf seed
- **When** the map is panned and zoomed continuously for 30 s over the 2,000-issue area
- **Then** average frame build + raster time stays under 16 ms with no frame over 50 ms after the first load (DevTools frame chart recorded; low-end phone re-check in TASK-14)

**AC-5** — Issue detail
- **Given** an issue that was reported, marked fixed with an after photo and is in its verify window
- **When** a signed-in neighbour opens `/issues/:id`
- **Then** Before/After tabs, status chip "Fixed" with icon, timeline with actors, Me too/Follow/Share, and "Is it fixed?" are shown; the reporter sees "Add AMC complaint number" instead of Me too; an overdue open issue shows "Overdue" and "Escalate (suggested)"; a merged issue shows the merge banner

**AC-6** — Me too and Follow
- **Given** a signed-in citizen on someone else's open issue
- **When** they tap Me too twice (on, off), Follow, Unfollow, and the reporter tries Me too on their own
- **Then** counts change by exactly one each way, Me too also follows, repeats are idempotent (one row), the reporter gets 409 `OWN_ISSUE`; a signed-out tap opens sign-in and then applies the action

**AC-7** — Share card (P1)
- **Given** an issue with a photo
- **When** the citizen taps Share and picks WhatsApp
- **Then** a PNG card (photo, category, title, ward, status, affected count, independence line, no reporter info) and the text with `<base>/i/<id>` are shared; opening the link in a browser shows the public page with OG tags and no personal data

**AC-8** — My reports and Following
- **Given** a citizen with 3 reports (one hidden sensitive) and 2 followed issues
- **When** they open `/me/reports` and `/me/following`
- **Then** all 3 reports show with status chips and "Moderator check pending" on the hidden one; Following shows 2 and unfollow removes one; signed out → sign-in prompt

**AC-9** — Reporter privacy everywhere
- **Given** seeded reporters with known names and phones
- **When** feed, list, detail, map, events, nearby and `/i/{id}` are requested anonymously and as another citizen
- **Then** no response contains any reporter id, name or phone; detail shows "Reported by a resident of <ward>" in English and Gujarati

**AC-10** — Latency and pagination
- **Given** the perf seed on the local stack
- **When** `npm run perf:read` runs feed, list, detail and map at 50 concurrent connections for 60 s each
- **Then** p95 < 400 ms for each, and every list endpoint (issues, events, mine, following) enforces a maximum page size

### AC → Requirement

| AC | Requirements |
|---|---|
| AC-1 | REQ-F-028, REQ-N-011 |
| AC-2 | REQ-F-034, REQ-N-011 |
| AC-3 | REQ-F-029, REQ-N-008 |
| AC-4 | REQ-N-008 |
| AC-5 | REQ-F-030 |
| AC-6 | REQ-F-031 |
| AC-7 | REQ-F-032, REQ-S-006 |
| AC-8 | REQ-F-033 |
| AC-9 | REQ-S-006 |
| AC-10 | REQ-N-011 |

### 7.2 Non-Functional Checklist

- [ ] Public routes use only `toPublicIssue()`/card serializers (lint rule or grep check in CI)
- [ ] Every list endpoint has a max page size and cursor; no unbounded queries (map capped at 500 points)
- [ ] Home, map, list, detail, My reports, Following have skeleton, empty, error, offline and signed-out states; no full-screen spinners
- [ ] Status and category always icon + word; colours only from tokens; dark theme checked
- [ ] Map pins/clusters have semantics labels; "Show as list" alternative; 48 dp targets
- [ ] All copy in ARB (gu + en); reporter label localised
- [ ] Tile attribution visible; no AMC logo on share card or `/i/{id}`
- [ ] `/i/{id}` HTML escapes all user text; CSP header set
- [ ] Optimistic Me too/Follow roll back on error with a snackbar

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-07-01 | API typecheck + lint; `flutter analyze`, `dart format` check | all |
| API (Vitest+Supertest) | T-07-01 | Feed with no optional providers → degraded sections, 10 issues | AC-1 |
| API | T-07-02 | Feed with throwing and slow (500 ms) stub providers → still 200 within budget, `degraded:true` | AC-1 |
| API | T-07-03 | Feed ETag/304 and `WARD_REQUIRED` | AC-1 |
| API | T-07-04 | `GET /issues` each filter and sort; bad bbox / limit → 400 | AC-2 |
| API | T-07-05 | Cursor walk over 500 rows: no duplicates or gaps for each sort, with inserts between pages | AC-2 |
| API | T-07-06 | `mine`/`following` auth and content incl. hidden own issue | AC-2, AC-8 |
| API | T-07-07 | Map: clusters vs points by zoom, count sum, points cap → clusters, filters | AC-3 |
| API | T-07-08 | Detail viewer capabilities per role/status (reporter, neighbour, visitor, moderator, representative) | AC-5 |
| API | T-07-09 | Hidden/rejected detail 404 for public, 200 for reporter/staff; merged → `mergedIntoId` | AC-5 |
| API | T-07-10 | Me too / Follow: idempotency, counts, auto-follow, `OWN_ISSUE`, concurrent toggles keep counts equal to row counts | AC-6 |
| API | T-07-11 | `/i/{id}`: OG tags, escaped text, no PII, 404 for hidden | AC-7 |
| API | T-07-12 | Privacy scan across feed, list, detail, map, events, nearby, `/i/{id}` with seeded PII strings | AC-9 |
| API | T-07-13 | Reporter label en/gu | AC-9 |
| API | T-07-14 | Page-size caps on issues, events, mine, following | AC-10 |
| Perf | T-07-15 | `npm run perf:read` on perf seed → p95 per endpoint < 400 ms (recorded, not in CI) | AC-10 |
| Widget | W-07-01 | Home: degraded sections hidden, empty ward state, offline cached feed note | AC-1 |
| Widget | W-07-02 | Issue list: filter chips, sort, infinite scroll, empty + clear filters | AC-2 |
| Widget | W-07-03 | Detail: before/after tabs, capability-driven actions, merged/rejected/404 states | AC-5 |
| Widget | W-07-04 | Me too/Follow optimistic update and rollback | AC-6 |
| Widget | W-07-05 | Share card golden (en + gu) contains no reporter info | AC-7 |
| Widget | W-07-06 | My reports / Following states incl. signed out | AC-8 |
| Widget | W-07-07 | Map bottom sheet and semantics labels with fake data | AC-3 |
| Integration | I-07-01 | Emulator: Home → issue card → detail → Me too → Following list shows it | AC-1, AC-5, AC-6, AC-8 |
| Manual | M-07-01 | Map with perf seed in profile build; DevTools frame chart screenshot | AC-3, AC-4 |
| Manual | M-07-02 | Share to WhatsApp on emulator; open link in browser | AC-7 |
| Manual | M-07-03 | Offline Home and detail; reconnect refresh | AC-1, AC-5 |
| Manual | M-07-04 | TalkBack on Home, map ("Show as list"), detail; 2.0× font | AC-3, AC-5 |
| Manual | M-07-05 | Signed-out Me too → sign-in → action applied | AC-6 |
| Manual | M-07-06 | Gujarati UI pass on Home, detail, lists | AC-9 |

## 9. Deliverables

- Migration `<ts>_v2_discovery_indexes`; perf seed and `perf:read` script.
- API: issues list/detail, me-too delete, follow, feed (provider registry), map clustering, `/i/{id}` page, `toPublicIssue()`.
- App: Home, Map tab, issue list, issue detail, My reports, Following, share card.
- Tests T-07-01…15, W-07-01…07, I-07-01; performance numbers in §13; coverage evidence for 10 requirements.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/api/prisma/migrations/<ts>_v2_discovery_indexes/` | New |
| `apps/api/prisma/seed/perf-issues.ts`, `apps/api/scripts/perf-read.ts`, `apps/api/package.json` | New / Modified |
| `apps/api/src/modules/issues/` (list, detail, public serializer, follow, me-too delete) | Modified |
| `apps/api/src/modules/{feed,map,share-page}/`, `src/routes.ts`, `src/app.ts` (`/i/:id`) | New / Modified |
| `apps/api/test/discovery/*.test.ts`, `test/privacy.test.ts` | New |
| `apps/mobile/lib/features/{home,discovery,issue_detail,me}/` | New / Modified |
| `apps/mobile/lib/core/map/` (pins, clusters) | Modified |
| `apps/mobile/lib/router/citizen_routes.dart`, `lib/core/l10n/*.arb`, `pubspec.yaml` | Modified |
| `apps/mobile/test/discovery/*`, `integration_test/discovery_test.dart` | New |

## 11. Related Documentation

- `docs/v2/saarthee-v2-spec.md` §7 (endpoints, rate limits), §8 (screens), §11 (privacy)
- `docs/v2/design-system.md` DS §2 (status/category colours), §4 (photos, motion), §5 (issue card, timeline, map, states), §6 (accessibility)
- `docs/tasks-v2/TASK-05-issue-reporting.md` (`CivicMap`, me-too create, photos), `TASK-06-issue-lifecycle.md` (derived fields, events, actions), `TASK-08-*.md` / `TASK-12-*.md` (feed providers), `TASK-13-*.md` (domain, App Links)

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Tile provider limits or terms change | Blank or illegal map | `MAP_TILE_URL` configurable; usage monitored; self-host option noted for TASK-13 |
| Map jank on low-end phones | Poor first impression | Server clustering, point cap, marker widget reuse, debounce; re-test in TASK-14 |
| PII leaks through a new serializer | Privacy breach (REQ-S-006) | Single serializer, CI privacy scan T-07-12 |
| Feed blocked by a slow optional section | Home slow | Per-section timeout and degrade flags |
| Counter drift on Me too/Follow under concurrency | Wrong counts | Transactional updates; T-07-10 compares counters with row counts; repair query in runbook |
| Share link opens nothing for users without the app | Lost reach | `/i/{id}` web page with photo and status |

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
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-07` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `V2-TASK-07: …`
- [ ] Validator passes
