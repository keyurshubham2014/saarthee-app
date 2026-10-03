# TASK-07: Discovery — Home Feed, Map, Issue Detail and Social Actions

| Field | Value |
|---|---|
| Task ID | TASK-07 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | TASK-06 |
| Blocks | TASK-14 |
| Requirement IDs | REQ-F-028, REQ-F-029, REQ-F-030, REQ-F-031, REQ-F-032, REQ-F-033, REQ-F-034, REQ-N-008, REQ-N-011, REQ-S-006, REQ-F-064 |
| Primary Spec Refs | Spec §7 (Issues, Feed & map endpoints, rate limits), §8 (`/`, `/map`, `/issues/:id`, `/me/reports`, `/me/following`), §11 (reporter privacy); DS §2 (Neem tokens, `sunrise` for the Report card only, status, category colours), §3 (Baloo Bhai 2 / Mukta Vaani), §4 (radii, Home header band, Material Symbols Rounded, photos), §5 (Home header, Report card, app bar, issue card, status timeline, map, empty/loading/error), §6 (Motion: Home first load, Report card, Feed card → detail, "Me too", Pull to refresh, Map), §7 (accessibility), §8 |
| Last Updated | 2026-10-03 |

## 1. Objective

Let anyone see what is happening in their ward and act on it. The Home tab shows the chosen ward's alerts strip, the green header band with the sunrise "Report a problem" card, nearby issues, upcoming drives and service shortcuts — and keeps working when alerts or drives are not built or empty. The Map tab shows every public issue with fast clustering. Issue detail tells the whole story — before/after photos, status and timeline — and offers Me too, Follow, Share, Verify, Link CCRS and Escalate. Citizens see their own reports and the issues they follow. Reporters are never identified publicly: they are always "A resident of <ward>". Discovery moves the way DS §6 describes — Home rises in once on first load, the sunrise Report card springs in, a feed card grows into its detail, "Me too" springs and its count rolls, refresh turns the route chevron and map pins drop in — always with the TASK-03 `SaartheeMotion` tokens and an instant equivalent when animations are off.

## 2. Scope

### In Scope
- `GET /issues` (filters, sort, cursor), `GET /issues/{id}` (detail with derived fields and viewer capabilities), `GET /feed?ward`, `GET /map/issues?bbox&zoom`.
- `DELETE /issues/{id}/me-too`, `POST/DELETE /issues/{id}/follow`; Me too auto-follows; counts kept consistent (TASK-05 built `POST …/me-too`).
- Shared public serializer `toPublicIssue()` enforcing REQ-S-006 everywhere (also adopted by TASK-05 nearby and TASK-06 events).
- Public share page `GET /i/{id}` (minimal HTML with Open Graph tags, no PII) used as the share and evidence link.
- Map SDK decision (`flutter_map` — §5.6), muted tiles, client clustering; server grid clustering.
- App: Home screen, Map tab, issue list screen (`/issues`), Issue detail (`/issues/:id`), My reports (`/me/reports`), Following (`/me/following`), share as image card + link (P1).
- Pagination on every list endpoint; performance seed and p95 measurement (REQ-N-011); 2,000-issue map smoothness (REQ-N-008).
- Home layout per DS §4/§5: green `primary` header band (ward line, greeting, language + bell buttons) with the `sunrise` Report card overlapping the page.
- Discovery motion per DS §6 (REQ-F-064): Home first-load stagger (first load only), Report card spring + one-time first-launch pulse, feed card → detail `Hero` on photo and title, "Me too" spring + rolling count + light haptic, branded pull-to-refresh (route chevron drawn with `CustomPainter`), map pin drop (30 ms stagger, max 20 animated), cluster tap zoom (`long`), preview sheet `springIn`; reduced-motion variants of all of them.

### Out of Scope
- Alerts data, alert strip content and inbox — TASK-08 (feed consumes its contract and degrades when absent).
- Initiatives/drives, services and seasonal tips — TASK-12 (same degrade rule).
- Status changes, verification, escalation, CCRS-closed screens — TASK-06 (detail only opens them).
- Link CCRS screen — TASK-05; "Report a problem" flag sheet and endpoint — TASK-10 (menu item hidden until present).
- Representative actions UI beyond showing TASK-06 `IssueStatusActions` — TASK-11.
- Comments (structured comments are not specified for v2 detail beyond events).
- Motion tokens, shared transitions (shared axis, fade-through, sheets), press scale, skeleton shimmer, `CountUp`, `MotionCheck`, haptics helper and the reduced-motion switch — TASK-03 (this task only uses them). Status-chip cross-fade and timeline-step expand — TASK-06. Frame-time audit on the low-end phone — TASK-14 (REQ-N-013).

## 3. Prerequisites

- TASK-06 complete: `transition()`, derived fields (`isOverdue`, `displayStatus`, `verifyWindowClosesAt`), events endpoint, verify/mark-fixed/escalate routes, `IssueStatusActions`.
- TASK-05: issues, `issue_photos`, `GET /media/photos/{id}`, `POST …/me-too`, `CivicMap` wrapper, link-CCRS route.
- TASK-02: `GET /wards/{id}` with centroid/bbox; ward picker. TASK-03: Neem shell, components (`IssueCard`, `StatusChip`, `CategoryBadge`, `StatusTimeline`, skeletons, banners) and the motion foundation — `SaartheeMotion` tokens (`lib/core/theme/motion.dart`), `animations` + `flutter_animate`, press-scale wrapper, haptics helper, `MotionCheck`, `CountUp`, `StaggeredColumn`, reduced-motion resolution (system "Remove animations" + in-app Animations switch). TASK-04: sign-in gate returning to the action, `requireUser` and optional-auth middleware.
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
| REQ-F-064 | Discovery motion per DS §6: Home first-load stagger, Report card spring and one-time first-launch pulse, feed card → detail shared element, "Me too" spring with rolling count, branded pull-to-refresh, map pin drop and cluster zoom | DS §6 |

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
| `/` Home | **Header band** (DS §4/§5 "Home header"): `primary` #14674A band under a transparent status bar holding the ward line "Paldi · West zone" in `onPrimarySubtle` (tap → ward picker "Change ward"), the greeting in displaySmall (Baloo Bhai 2 28/36, white), language (અ/A) and bell buttons as 36 dp circles in white 14% with 48 dp hit areas (bell carries the unread badge from TASK-08; hidden until available). **Report card** (DS §5) sits at the bottom of the band and overlaps the page: `sunrise` #C24A1F fill, min height 56 dp, radius 14, `sunrise` glow (0 10 22 −10 at 70%), white filled "+" in a 32 dp circle, title "Report a problem" (or "Continue your report" when a draft exists), one-line hint "Pothole, garbage, water, anything", trailing arrow; it is the only `sunrise` element on the screen. Below the band on `background` #F3F6F1: alerts strip (horizontal alert cards, radius 18, hidden when empty), stat tiles if any, "Issues near you" section title (titleLarge, Baloo Bhai 2 19/26) with up to 10 `IssueCard`s (radius 18, 14 dp apart) + "See all" → `/issues?ward=<id>`, "Upcoming drives" strip (hidden when empty), "Services" shortcuts grid (hidden when empty). Icons are Material Symbols Rounded. | skeleton rows with shimmer; error "We couldn't load your ward. Try again"; offline → last cached feed with "You're offline. Showing what we had at 10:42."; empty issues → 56 dp icon on a `primaryContainer` circle + "No issues reported in Paldi yet." + "Report a problem"; no ward set → ward picker prompt |
| `/issues` | Title "Issues in Paldi"; filter chips: Category (sheet, multi), Status (Open, Overdue, Fixed, Verified), sort menu (Newest, Most affected, Overdue first); infinite list of `IssueCard`s | skeleton; empty "No issues match these filters." + "Clear filters"; error retry; end-of-list "That's all." |
| `/map` | `CivicMap` (muted tiles, attribution), category-coloured teardrop pins with status ring; slate cluster bubbles with counts; chips Category, Status, "Mine" (signed in); "My location" button; tap pin → bottom sheet `IssueCard` + "View details"; tap cluster → zoom in | loading bar at top (map stays interactive); error snackbar "Couldn't load issues here. Try again"; empty area → chip "No issues in this area"; offline → banner, last pins kept; location denied → map centred on home ward, button hidden |
| `/issues/:id` | Photo carousel with tabs "Before" / "After" (after + verification photos; tab hidden when none); caption "Faces and number plates blurred" when applicable; status chip (icon + word, DS §2) + "Overdue" tag; title; "<Category> · <Ward> · 3 days ago"; "Reported by a resident of Paldi"; "Saarthee target: fixed by 10 Oct" (helper "This is Saarthee's target, not an AMC deadline."); action row: "Me too (12)", "Follow", "Share"; contextual card: Fixed → "Is it fixed?" with "Yes, it's fixed" / "Still not fixed" (TASK-06 verify); `fixed_unverified` → "Fixed (not verified)"; reporter → "Add AMC complaint number" (TASK-05) or "AMC closed it?" (TASK-06 sheet); open + `canEscalate` → "Escalate" (suggested when overdue); `IssueStatusActions` for staff/representatives; timeline (TASK-03 `StatusTimeline`, "See full history" pages events); overflow "Report a problem" (TASK-10) | skeleton; 404 → "This issue isn't available. It may have been removed."; merged → banner "This report was merged into another one." + "Open it"; rejected (reporter only) → "Not accepted: <reason>"; offline → cached detail read-only, actions disabled with "You're offline"; signed-out tap on Me too/Follow → sign-in then the action runs |
| `/me/reports` | "My reports" list of own issues (incl. hidden/rejected), status chips, "Moderator check pending" tag for hidden sensitive ones | signed out → "Sign in to see your reports" + "Sign in"; empty "You haven't reported anything yet." + "Report a problem"; skeleton; error retry |
| `/me/following` | "Following" list, status chips, swipe or overflow "Unfollow" | signed out → sign-in prompt; empty "Follow an issue to get updates when its status changes." |
| Share (P1) | Off-screen `IssueShareCard` (1080×1350): Saarthee wordmark, report photo, category badge, title, ward, status chip, "<n> residents affected", "Independent citizen app. Not run by or linked to AMC."; rendered via `RepaintBoundary` → PNG; `share_plus` sheet with text "<title> — <status>. See it on Saarthee: <PUBLIC_WEB_BASE_URL>/i/<id>" | render failure → share link text only |

Card titles stay in Mukta Vaani (titleMedium 16/22); Baloo Bhai 2 only for the greeting, section titles and numbers (DS §3). Photos 4:3, radius 14; thumbnails radius 14; filter chips are pills; the map preview and filter sheets use radius 24 top corners.

#### Motion (REQ-F-064, DS §6)

All motion uses TASK-03 `SaartheeMotion` tokens and helpers; no `Duration(` literal in `lib/features/**`. When reduced motion is on (`MediaQuery.disableAnimations` or the in-app Animations switch), each item below becomes an instant change or a ≤ 100 ms cross-fade with identical content.

| Moment | Behaviour | Tokens / helper | Reduced motion |
|---|---|---|---|
| Home first load | Header elements (ward line, greeting, buttons), then the Report card, alerts strip, stat tiles and issue cards rise (`rise` 14 dp + fade) with `stagger` 60 ms, max 6 items (later items appear with item 6). Runs only on the first successful feed render of the app session; returning to the tab (fade-through from TASK-03), pull-to-refresh rebuilds and feed updates do not replay it. Flag `homeIntroPlayed` held in a session-scoped provider | `StaggeredColumn`, `stagger`, `rise`, `medium` | Content shown at once |
| Report card | Springs in (`springIn`, scale 0.96 → 1 + fade) as part of the stagger. On a user's first launch only, one `sunrise` ring expands from the card edge and fades out once (≈ `long`), never repeated; persisted flag `reportPulseShown` in shared_preferences set when the pulse starts. Press: TASK-03 press-scale 0.97 (`instant`) + light haptic | `springIn`, `long`, press-scale wrapper, haptics helper | No spring, no pulse; flag still set |
| Feed card → detail | `Hero` tags `issue-photo-<id>` and `issue-title-<id>` on the `IssueCard` thumbnail and title (feed, `/issues`, My reports, Following, map preview) fly to the detail photo and title over `long`; the rest of the detail (meta line, actions, timeline) rises with `stagger`. Only one Hero per tag per route (list dedupes) | `Hero` + `long` flight curve, `StaggeredColumn` | No Hero flight (`HeroMode(enabled:false)`); detail cross-fades |
| "Me too" | Icon springs to 1.2 and back (`springIn`), the count rolls to the next digit (vertical digit roll, `short`), light haptic. Optimistic; on rollback the count rolls back and a snackbar explains | `springIn`, `short`, haptics helper | Icon and number swap instantly; haptic follows system setting |
| Pull to refresh | Branded indicator `ChevronRefreshIndicator`: the Saarthee route chevron with its end dot, drawn in `primary` with `CustomPainter` (not `sunrise`, which is reserved for the Report action), rotating with drag progress, then spinning while the request runs (spin allowed only while waiting, like a skeleton). New items that were not in the previous list rise in (`rise`, `stagger`); unchanged items do not animate. Used on Home, `/issues`, My reports, Following | `CustomPainter`, `medium`, `stagger`, `rise` | Static chevron + "Refreshing…" label; items appear at once |
| Map pins | When a new set of points/clusters arrives, pins drop in (translate-Y from −12 dp + fade, small settle) with a 30 ms stagger; only the first 20 pins in view are animated, the rest appear with pin 20. Pins already shown are not re-animated on pan | `springIn`, map stagger constant 30 ms from `SaartheeMotion` (TASK-03) | Pins appear at once |
| Cluster tap | Camera animates to the cluster bounds over `long` (`AnimatedMapController` or equivalent camera tween) | `long` | Camera jumps |
| Preview sheet | Bottom sheet with the `IssueCard` slides up with `springIn` (TASK-03 sheet transition), radius 24 top corners | `springIn` | Appears at once |

ARB keys under `home.*`, `issues.*`, `map.*`, `issueDetail.*`, `share.*`, `me.reports.*`, `me.following.*`, `reporter.residentOf` ("A resident of {ward}" / "{ward}ના રહેવાસી").

Accessibility: motion never carries meaning alone (count text and button label change too); the Report-card pulse runs once (well under 3 flashes/s); pins and clusters have semantics labels ("Pothole, reported, in Paldi" / "12 issues here, zoom in"); map has a "Show as list" button opening `/issues` with the current bbox (TalkBack users don't need the map); Me too/Follow announce new state and count.

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
- ASSUMPTION: "First load" for the Home stagger means the first successful feed render per app process (cold start or process restart); tab returns and refreshes never replay it. The Report-card pulse is once per install (`reportPulseShown` in shared_preferences), not per account.
- ASSUMPTION: The map pin-drop stagger (30 ms) and the 20-pin cap are not in the DS §6 token table; they are read from `SaartheeMotion` constants (`mapPinStagger`, `mapPinMaxAnimated`) that TASK-03 exposes, or added there by this task if missing — never as literals in `lib/features/**`.
- ASSUMPTION: Pull-to-refresh is a custom indicator built on `RefreshIndicator`'s gesture handling (or `CustomRefreshIndicator`, *candidate*, pin on pub.dev) with the chevron drawn by `CustomPainter`; no Lottie/Rive (DS §6).
- ASSUMPTION: Home Report-card copy is "Report a problem" / hint "Pothole, garbage, water, anything" (DS §5); the earlier "Report an issue" label is retired on Home.
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
12. **Home screen** replacing the TASK-03 placeholder; ward picker hook. Build `HomeHeaderBand` (DS §5 Home header: `primary` band, ward line in `onPrimarySubtle`, displaySmall greeting, 36 dp white-14% language/bell buttons) and `ReportCard` (DS §5: `sunrise` fill, radius 14, 56 dp min, 32 dp "+" circle, title + hint, trailing arrow, `sunrise` glow) overlapping the page; tokens only (no hex literals).
13. **Map tab**: extend `CivicMap` with pins (category colour, status ring), cluster layer, debounce 300 ms on camera idle, filters, bottom sheet, "Show as list".
14. **Issue list, detail, My reports, Following** screens per §5.4; wire TASK-05/06 routes and TASK-06 `IssueStatusActions`; timeline via `issueEventsProvider`.
15. **Share (P1)**: `IssueShareCard`, PNG render, *candidate* `share_plus`.
16. **Discovery motion (REQ-F-064)** per §5.4 Motion, using only TASK-03 helpers and `SaartheeMotion` tokens:
    1. Home first-load stagger with `StaggeredColumn` gated by the session `homeIntroPlayed` flag; verify tab return does not replay.
    2. `ReportCard` `springIn` entry and the one-time `sunrise` pulse ring (`reportPulseShown` in shared_preferences); press-scale wrapper + light haptic.
    3. `Hero` tags on `IssueCard` photo/title and detail photo/title; detail body rises with `stagger`.
    4. `MeTooButton`: spring 1.0 → 1.2 → 1.0, `RollingCount` digit roll (from TASK-03 if provided; otherwise whichever of TASK-07/TASK-08/TASK-12 lands first creates `lib/core/widgets/rolling_count.dart` and the others reuse it), light haptic, rollback roll.
    5. `ChevronRefreshIndicator` (`CustomPainter` route chevron) on Home, `/issues`, My reports, Following; new-item rise only.
    6. Map: pin drop (30 ms stagger, max 20 animated, no re-animation on pan), cluster tap camera tween over `long`, preview sheet `springIn`.
    7. Reduced-motion branches for each, reading TASK-03's resolved `reduceMotion` flag.
    8. Run TASK-03's no-`Duration(`-literal test over `lib/features/**`.
17. **Widget + integration tests** W-07-01…W-07-10, I-07-01.
18. **Performance**: map with perf seed in a profile build (performance overlay / DevTools frame chart); record numbers in §13. Profile each REQ-F-064 moment once (DevTools timeline, note worst frame) as input to TASK-14's REQ-N-013 audit.
19. **Manual checks** M-07-01…M-07-08 including screen recordings (`adb shell screenrecord`) saved to `docs/demo/v2-evidence/motion/`; coverage matrix.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Feed composes and degrades
- **Given** ward Paldi with 12 open issues and no alerts/initiatives/services modules installed
- **When** `GET /feed?ward=<paldi>` is called and the Home tab opens
- **Then** the response has 10 nearby issues and `alerts`, `drives`, `serviceShortcuts`, `tips` as empty with `degraded:true`; Home shows the green header band, the "Report a problem" card and issues, and hides the empty strips without errors; with a stub provider that throws or sleeps 500 ms, the feed still returns within 400 ms

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

**AC-11** — Home layout and first-load motion
- **Given** a fresh install with ward Paldi set, animations on, and `reportPulseShown` unset
- **When** Home opens for the first time, the user switches to Map and back, kills and relaunches the app, and pulls to refresh
- **Then** the green `primary` header band shows the ward line, Baloo Bhai 2 greeting, language and bell buttons, and the `sunrise` Report card ("Report a problem", hint, "+" circle, trailing arrow) overlapping the page as the only `sunrise` element; on first open the header, Report card, alerts, stats and cards rise in with a 60 ms stagger (max 6 staggered) and the Report card springs in and its ring pulses exactly once; returning from Map shows Home at once with no stagger; after relaunch the stagger plays again but the pulse does not; pull-to-refresh shows the turning route chevron and only new items rise in

**AC-12** — Feed card → detail, "Me too" and map motion
- **Given** animations on and a signed-in neighbour on Home with an open issue card that has 12 "Me too"s, and the map at zoom 12 over Paldi
- **When** they tap the card, tap "Me too", go to the map, tap a cluster and then a pin
- **Then** the card's photo and title fly into the detail photo and title over `long` and the rest of the detail rises with `stagger`; the "Me too" icon springs to 1.2 and back, the count rolls from 12 to 13 and a light haptic fires; the cluster tap zooms the camera over `long`, the new pins drop in with a 30 ms stagger (at most 20 animated, the rest appear with the 20th), and the preview sheet springs up; every duration comes from `SaartheeMotion` and `lib/features/**` contains no `Duration(` literal

**AC-13** — Discovery with reduced motion
- **Given** the system "Remove animations" setting on (and separately, the in-app Animations switch off)
- **When** the AC-11 and AC-12 steps are repeated
- **Then** Home, the Report card, detail, "Me too" count, refresh, pins, cluster zoom and preview sheet change instantly or with a ≤ 100 ms cross-fade, no Report-card pulse runs, and every text, count and control is identical to the animated run

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
| AC-11 | REQ-F-064, REQ-F-028 |
| AC-12 | REQ-F-064, REQ-F-030, REQ-F-031, REQ-F-029 |
| AC-13 | REQ-F-064 |

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
- [ ] Neem visuals only: `primary` #14674A header band, `sunrise` #C24A1F on the Report card only, Baloo Bhai 2 headings/numbers and Mukta Vaani body, radii 14/18/24/pill, Material Symbols Rounded — all through TASK-03 tokens, no literals
- [ ] Every REQ-F-064 animation uses `SaartheeMotion` tokens; no `Duration(` literal in `lib/features/**`; only transform, opacity and colour animated
- [ ] Home stagger only on first load; Report-card pulse once per install; nothing loops except the refresh chevron while waiting
- [ ] Reduced motion (system and in-app switch) gives instant or ≤ 100 ms cross-fade equivalents with identical content

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
| Widget | W-07-08 | Home header band + Report card (tokens, only one `sunrise` widget, overlap); first-load stagger: pump `SaartheeMotion.stagger` × n and `rise` and assert opacity/offset per item; re-entering the tab pumps one frame and all items are at final state; Report-card pulse runs once (`pumpAndSettle` after `SaartheeMotion.long`, then rebuild with `reportPulseShown=true` → no pulse) | AC-11 |
| Widget | W-07-09 | Hero tags present on card and detail; navigation pumps through `SaartheeMotion.long`; "Me too" scale reaches ~1.2 mid-`springIn` and the rolled count reads 13 after `SaartheeMotion.short`; haptics helper fake records one light impact; `ChevronRefreshIndicator` paints and only new items animate; map pins: 25 pins → 20 animated with 30 ms offsets, 21–25 appear with pin 20; cluster tap triggers a camera tween of `SaartheeMotion.long` | AC-12 |
| Widget | W-07-10 | Reduced-motion variants of W-07-08/09 (`MediaQuery(disableAnimations: true)` and the in-app switch): after a single `pump()` every element is at its final state, no Hero flight, no pulse, counts identical | AC-13 |
| Integration | I-07-01 | Emulator: Home → issue card → detail → Me too → Following list shows it | AC-1, AC-5, AC-6, AC-8 |
| Manual | M-07-01 | Map with perf seed in profile build; DevTools frame chart screenshot | AC-3, AC-4 |
| Manual | M-07-02 | Share to WhatsApp on emulator; open link in browser | AC-7 |
| Manual | M-07-03 | Offline Home and detail; reconnect refresh | AC-1, AC-5 |
| Manual | M-07-04 | TalkBack on Home, map ("Show as list"), detail; 2.0× font | AC-3, AC-5 |
| Manual | M-07-05 | Signed-out Me too → sign-in → action applied | AC-6 |
| Manual | M-07-06 | Gujarati UI pass on Home, detail, lists | AC-9 |
| Manual | M-07-07 | Emulator screen recordings (`adb shell screenrecord /sdcard/<name>.mp4`, then `adb pull` into `docs/demo/v2-evidence/motion/`): `t07-home-first-load.mp4` (fresh install: stagger + Report card spring + single pulse, tab return, relaunch), `t07-card-to-detail.mp4` (Hero + Me too roll), `t07-refresh.mp4`, `t07-map-pins.mp4` (pin drop, cluster zoom, preview sheet) | AC-11, AC-12 |
| Manual | M-07-08 | Same flows with Developer options "Remove animations" on and with the in-app Animations switch off; recording `t07-reduced-motion.mp4` | AC-13 |

## 9. Deliverables

- Migration `<ts>_v2_discovery_indexes`; perf seed and `perf:read` script.
- API: issues list/detail, me-too delete, follow, feed (provider registry), map clustering, `/i/{id}` page, `toPublicIssue()`.
- App: Home (green header band + `sunrise` Report card), Map tab, issue list, issue detail, My reports, Following, share card.
- Discovery motion (REQ-F-064): first-load stagger, Report card spring + one-time pulse, Hero card → detail, "Me too" spring + `RollingCount`, `ChevronRefreshIndicator`, map pin drop / cluster zoom / preview sheet, reduced-motion variants.
- Tests T-07-01…15, W-07-01…10, I-07-01; performance numbers in §13; motion recordings in `docs/demo/v2-evidence/motion/`; coverage evidence for 11 requirements.

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
| `apps/mobile/lib/core/map/` (pins, clusters, pin-drop and camera tween) | Modified |
| `apps/mobile/lib/features/home/widgets/{home_header_band,report_card}.dart`, `lib/features/discovery/widgets/{me_too_button,chevron_refresh_indicator}.dart` | New |
| `apps/mobile/lib/core/widgets/rolling_count.dart` (only if TASK-03 does not provide one) | New |
| `docs/demo/v2-evidence/motion/t07-*.mp4` | New |
| `apps/mobile/lib/router/citizen_routes.dart`, `lib/core/l10n/*.arb`, `pubspec.yaml` | Modified |
| `apps/mobile/test/discovery/*`, `integration_test/discovery_test.dart` | New |

## 11. Related Documentation

- `docs/v2/saarthee-v2-spec.md` §7 (endpoints, rate limits), §8 (screens), §11 (privacy)
- `docs/v2/design-system.md` DS §2 (Neem colour tokens, `sunrise`, status/category colours), §3 (typography), §4 (radii, Home header, icons, photos), §5 (Home header, Report card, issue card, timeline, map, states), §6 (Motion: tokens, catalogue, rules), §7 (accessibility)
- `docs/tasks-v2/TASK-03-design-system-shell.md` (`SaartheeMotion`, motion helpers, reduced-motion switch); `TASK-14-e2e-launch.md` (REQ-N-013 frame-time audit)
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
| Hero flights or pin drops drop frames on low-end phones | Janky first impression | Animate only transform/opacity; cap animated pins at 20; profile each moment in step 18; reduced motion as fallback; TASK-14 audit |
| Home stagger replays on every tab return or refresh | Feels slow and decorative | Session flag `homeIntroPlayed`; W-07-08 asserts no replay |

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
- [ ] Home matches DS §5 "Home header" and "Report card" (green band, `sunrise` card only, Neem type, radii and Rounded icons)
- [ ] REQ-F-064 motion implemented with `SaartheeMotion` tokens only; W-07-08…W-07-10 pass
- [ ] Reduced-motion variants verified (system setting and in-app switch)
- [ ] Motion screen recordings saved to `docs/demo/v2-evidence/motion/` (M-07-07, M-07-08)
