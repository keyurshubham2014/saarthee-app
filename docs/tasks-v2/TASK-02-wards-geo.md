# TASK-02: Wards, Zones and Geo Services

| Field | Value |
|---|---|
| Task ID | TASK-02 |
| Status | Not Started |
| Priority | P0 |
| Size | M |
| Depends On | TASK-01 |
| Blocks | TASK-05, TASK-08, TASK-09, TASK-12 |
| Requirement IDs | REQ-F-001, REQ-F-002, REQ-F-003, REQ-D-006 |
| Primary Spec Refs | Spec §2 (D5, D9, D10), §6 (`zones`, `wards`), §7 (Geo), §8 (`/onboarding/ward`, My Ward); DS §5 (list rows), DS §7 |
| Last Updated | 2026-10-03 |

## 1. Objective

Give every part of Saarthee a reliable answer to "which ward is this?". The 48 AMC wards and 7 zones are loaded from the public OpenCity KML into PostGIS with a recorded boundary version, cross-checked against AMC's own ward list (names, zone, ward office address and public phone). The API resolves a GPS point to a ward and zone (with a nearest-ward fallback that asks the citizen to confirm), serves ward and zone lists in Gujarati and English, and the app gets a searchable, zone-grouped ward picker data source that also works offline.

## 2. Scope

### In Scope
- Source capture: OpenCity "AMC Wards Map" KML (public domain) and AMC ward list (amccrs.com WardList) recorded with URL, retrieval date and SHA-256.
- Conversion KML → GeoJSON (`geo:convert`), validation, and a committed normalised GeoJSON plus a hand-checked `amc-ward-list.json` (wards, zones, Gujarati names, office address, public phone).
- Migration creating `zones` and `wards`, then FKs from `issues.ward_id`, `issues.zone_id`, `users.home_ward_id`.
- Import script `geo:import` (idempotent, versioned) and cross-check script `geo:crosscheck` (fails on mismatch).
- Backfill of `ward_id`/`zone_id` on existing issues (`geo:backfill`), incl. TASK-01's imported legacy issues.
- Endpoints `GET /geo/locate`, `GET /wards`, `GET /wards/{id}`, `GET /zones`.
- `wards` seed module for the v2 dev seed (TASK-01 framework).
- Mobile data layer: align TASK-03's `WardsRepository` mapper with the final contract, `boundaryVersion`-aware cache refresh, and a shared ward search/grouping function (Gujarati, English, number incl. Gujarati digits) used by TASK-03's picker.

### Out of Scope
- Ward picker and onboarding UI — TASK-03 (this task supplies its data source).
- Representatives per ward, ward scorecard — TASK-09.
- Map ward-outline layer and issue clustering — TASK-07 (uses `?include=geometry` from here).
- Alert areas and ward topics — TASK-08 (uses ward numbers and zone codes from here).
- Reverse geocoding of street addresses (`issues.address_text`) — later.
- Assembly constituencies — TASK-09.

## 3. Prerequisites

- TASK-01 complete: PostGIS 3.5 running, `issues`/`users` with `ward_id`, `zone_id`, `home_ward_id` columns, seed framework with a `wards` placeholder module, test harness.
- Internet access to download the OpenCity KML and to read AMC's ward list once (manual; no scraping job).
- A Gujarati reader available to spot-check names (Open Question 5 in the summary).
- For the mobile steps 10–11 only: TASK-03's `lib/core/wards/` and ward picker merged (soft prerequisite; the API side does not need it).
- Env var (new): `GEO_NEAREST_MAX_M=3000` in `apps/api/.env` and `.env.test`.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-01 | PostGIS extension, `issues`/`users` columns that get ward FKs, seed framework, Vitest + Supertest harness, `src/lib/geo` helpers |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-F-001 | `GET /geo/locate?lat&lng` returns ward and zone via PostGIS point-in-polygon; nearest ward with `confirm:true` when outside all polygons | Spec §6, §7 |
| REQ-F-002 | `GET /wards`, `GET /wards/{id}`, `GET /zones` with Gujarati and English names, zone, ward office address and public phone | Spec §6, §7 |
| REQ-F-003 | Ward picker data: searchable list of 48 wards grouped by 7 zones | Spec §8 |
| REQ-D-006 | `zones` and `wards` seeded from the OpenCity KML (48 wards, 7 zones) with boundary version, cross-checked against AMC's ward list | Spec D10 |

### 5.2 Data Contracts

**Source files** (`apps/api/prisma/data/geo/`, committed — public data):

| File | Content |
|---|---|
| `SOURCES.md` | For each source: title, publisher, URL, licence, retrieval date (IST), SHA-256 of the downloaded file, notes on known differences |
| `raw/amc-wards.kml` | The downloaded KML, unchanged |
| `amc-wards.<boundaryVersion>.geojson` | Output of `geo:convert`: FeatureCollection of 48 features, properties `{ kmlName, wardNumber? }`, coordinates rounded to 6 dp, WGS84 |
| `amc-ward-list.json` | Hand-compiled from AMC's ward list: `{ fetchedAt, sourceUrl, zones:[{code,nameEn,nameGu}], wards:[{number,nameEn,nameGu,zoneCode,officeAddressEn,officeAddressGu|null,officePhone|null,sourceUrl}] }` |
| `ward-aliases.json` | `{ "<kmlName>": <wardNumber> }` for names that differ in spelling between the KML and AMC's list |

Zone codes (used in FCM topics `zone_<code>`, D9): `central`, `north`, `south`, `east`, `west`, `north_west`, `south_west` — names: Central / મધ્ય ઝોન, North / ઉત્તર ઝોન, South / દક્ષિણ ઝોન, East / પૂર્વ ઝોન, West / પશ્ચિમ ઝોન, North West / ઉત્તર પશ્ચિમ ઝોન, South West / દક્ષિણ પશ્ચિમ ઝોન (Gujarati to be confirmed against AMC's Gujarati pages).

Boundary version: `opencity-amc-wards-<yyyy-mm of the dataset>` (e.g. `opencity-amc-wards-2025-11`), stored per ward.

**Migration `20261005000000_create_zones_wards`:**

`zones` — `id uuid` PK, `code varchar(20)` (`uq_zones_code`, `ck_zones_code` `^[a-z_]{3,20}$`), `name_en varchar(60)`, `name_gu varchar(60)`, `geom geometry(MultiPolygon,4326) NULL` (union of its wards), `created_at`, `updated_at`; GIST `idx_zones_geom`.

`wards` — `id uuid` PK, `number smallint` (`uq_wards_number`, `ck_wards_number` 1–99), `name_en varchar(60)`, `name_gu varchar(60)`, `zone_id → zones RESTRICT`, `geom geometry(MultiPolygon,4326) NOT NULL` (`ck_wards_geom_valid` `ST_IsValid(geom)`), `centroid geometry(Point,4326) NOT NULL` (`ST_PointOnSurface(geom)`, guaranteed inside), `boundary_version varchar(60) NOT NULL`, `office_address_en varchar(300) NULL`, `office_address_gu varchar(300) NULL`, `office_phone varchar(20) NULL` (public office number only, `ck_wards_phone` `^[0-9+ -]{6,20}$`), `population int NULL`, `source_url varchar(500)`, `last_verified_at timestamptz`, `created_at`, `updated_at`. Indexes: GIST `idx_wards_geom`, `idx_wards_zone`, trigram-free search is done in the app/API over 48 rows (no index needed).

Spec §6 lists a single `office_address`; it is split into `_en`/`_gu` because every surface is bilingual (see §5.6).

**Migration `20261005000100_ward_foreign_keys`:** `fk_issues_ward` (issues.ward_id → wards SET NULL), `fk_issues_zone` (issues.zone_id → zones SET NULL), `fk_users_home_ward` (users.home_ward_id → wards SET NULL); `ck_issues_ward_zone` is enforced in the service (zone = ward's zone), not by CHECK.

Prisma: `Zone`, `Ward` models with `geom`/`centroid` as `Unsupported("geometry(MultiPolygon, 4326)")` / `Unsupported("geometry(Point, 4326)")`; reads of geometry only through `$queryRaw`.

**Import (`geo:import`)** — one transaction: upsert 7 zones by `code`; upsert 48 wards by `number` with `geom = ST_Multi(ST_MakeValid(ST_SetSRID(ST_GeomFromGeoJSON($1),4326)))`, `centroid = ST_PointOnSurface(geom)`; then `UPDATE zones SET geom = (SELECT ST_Multi(ST_Union(geom)) FROM wards WHERE zone_id = zones.id)`. Refuses unless exactly 48 wards and 7 zones resolve. Re-running with the same version changes nothing; a new version updates geometry and `boundary_version`, logs per-ward area change (%).

**Cross-check (`geo:crosscheck`)** — fails (exit 1, report printed) if: any KML feature maps to no AMC ward (after normalising case, spaces, punctuation, `ward` suffix, and `ward-aliases.json`); any AMC ward has no polygon; two features map to one ward; any polygon invalid after `ST_MakeValid`; any two wards overlap by > 1,000 m²; total area outside 400–550 km² (AMC ~ 464 km²; sanity bound); any ward's `ST_PointOnSurface` resolves via `/geo/locate` logic to a different ward. Warnings only: gaps between wards > 10,000 m².

**Backfill (`geo:backfill`)** — for issues with `ward_id IS NULL`: set `ward_id`, `zone_id` from point-in-polygon (`ST_Covers(w.geom, i.location::geometry)`); outside all wards → nearest within `GEO_NEAREST_MAX_M`; prints `checked=N inside=N nearest=N outside=N`.

### 5.3 API Contracts

Base `/api/v1`. All public, no auth, shared limiter 120/IP/min (Spec §7). Responses carry `Cache-Control: public, max-age=3600` and `ETag` = `W/"<boundaryVersion>-<max(updated_at)>"` (except `/geo/locate`: `no-store`).

| Method | Path | Request | Response | Errors |
|---|---|---|---|---|
| GET | `/geo/locate` | `lat` −90..90, `lng` −180..180 (decimals, rounded to 6 dp) | 200 `{ward:{id,number,nameEn,nameGu,zone:{id,code,nameEn,nameGu}}, zone:{id,code,nameEn,nameGu}, match:"inside"|"nearest", confirm:boolean, distanceM:number, boundaryVersion}` | 400 `VALIDATION_FAILED`, 422 `OUTSIDE_SERVICE_AREA`, 429 |
| GET | `/wards` | `q?` (≤ 40 chars), `zone?` (zone code) | 200 `{items:[WardSummary], boundaryVersion}` ordered by zone sort then ward number | 400, 429 |
| GET | `/wards/{id}` | `id` uuid **or** ward number 1–99; `include?=geometry` | 200 `WardDetail` | 400, 404 `NOT_FOUND`, 429 |
| GET | `/zones` | — | 200 `{items:[{id,code,nameEn,nameGu,wardCount}]}` | 429 |

`WardSummary` = `{id, number, nameEn, nameGu, zone:{id,code,nameEn,nameGu}}` (exactly the shape TASK-03 §5.3 consumes).
`WardDetail` = `WardSummary` + `{office:{addressEn, addressGu|null, phone|null}, centroid:{lat,lng}, bbox:[minLng,minLat,maxLng,maxLat], boundaryVersion, source:{name:"AMC ward list", url, lastVerifiedAt}, geometry?: GeoJSON MultiPolygon simplified with ST_SimplifyPreserveTopology(geom, 0.00005)}`.

`/geo/locate` algorithm:
1. `SELECT … FROM wards WHERE ST_Covers(geom, point) ORDER BY number LIMIT 1` → `match:"inside"`, `confirm:false`, `distanceM:0` (boundary points go to the lower ward number — deterministic).
2. Else nearest: `ORDER BY geom::geography <-> point::geography LIMIT 1` with `ST_Distance(geography)`; if ≤ `GEO_NEAREST_MAX_M` → `match:"nearest"`, `confirm:true`, `distanceM` rounded to the metre.
3. Else 422 `OUTSIDE_SERVICE_AREA` (valid input, but no ward can be assigned; matches TASK-03's client handling).

`q` search (server): case-insensitive match on `name_en`, `name_gu`, or exact `number` (ASCII or Gujarati digits ૦–૯ converted). Same rules in the app (offline).

New error code: `OUTSIDE_SERVICE_AREA: { status: 422, message: "This place is outside Ahmedabad's municipal wards." }`.

Logging: never log `lat`/`lng` at info level (location is personal data); log `match` and ward number only.

### 5.4 UI Surfaces & States

UI is built in TASK-03 (onboarding ward step, ward picker sheet, settings) and TASK-09 (My Ward). TASK-03 already owns `lib/core/wards/` (`Ward`, `Zone`, `WardLocateResult`, `WardsRepository`, cache key `v2.wardsCache`) and all picker copy and states (TASK-03 §5.4). This task makes that data layer real and correct:

| Piece | Contract |
|---|---|
| `lib/core/wards/wards_repository.dart` (TASK-03 file, modified) | Mapper aligned to §5.3 (`zone.id` present, extra fields `match`, `distanceM`, `boundaryVersion` read and kept); `422 OUTSIDE_SERVICE_AREA` → typed `OutsideServiceArea` (TASK-03 already maps 422 to its "outside Ahmedabad" message); `v2.wardsCache` stores `boundaryVersion` and is refreshed when the API returns a different version |
| `lib/core/wards/ward_search.dart` (new, pure) | `List<ZoneGroup> groupAndFilter(List<Ward> wards, String query, Locale locale)` — 7 groups in fixed zone order (Central, North, South, East, West, North West, South West), wards by number; matches case-insensitively on `nameEn`, `nameGu`, or the number (ASCII or Gujarati digits ૦–૯; "ward 15" / "વોર્ડ ૧૫" prefixes ignored); keeps only groups with ≥ 1 match. TASK-03's picker calls it instead of any inline filter |
| `WardLocateResult` | gains `distanceM` and `match`; `confirm:true` drives TASK-03's "You seem to be just outside Ward {n} · {name}" card |
| Fixture `test/fixtures/wards.json` (TASK-03 file) | Regenerated from the real API response (`geo:fixture` script) so widget tests use the 48 real wards |

No new ARB keys: TASK-03's copy covers locating, nearest-confirm, outside-city, offline-with-cache, error and no-match states. Ward office details and their source line are shown by TASK-09 using `WardDetail.source`.

### 5.5 Permissions & Roles

| Action | Visitor | Citizen | Moderator / Admin | Notes |
|---|---|---|---|---|
| `GET /geo/locate`, `/wards`, `/wards/{id}`, `/zones` | ✅ | ✅ | ✅ | Public, rate-limited |
| Edit ward office address/phone | ❌ | ❌ | ❌ (this task) | Changed only by re-running `geo:import` from `amc-ward-list.json`; staff editing is out of scope |
| Run `geo:import`, `geo:backfill` | — | — | Operator CLI | Production run during TASK-13 deployment |

### 5.6 Assumptions

- ASSUMPTION: Ward ids are UUIDs (matching all other tables) and `/wards/{id}` also accepts the ward number — FCM topics and humans use numbers (`ward_<number>`).
- ASSUMPTION: `office_address` split into `office_address_en`/`_gu` — every surface is bilingual (D4); `_gu` may be NULL until AMC's Gujarati page is transcribed.
- ASSUMPTION: Only office numbers published on AMC's ward list are stored in `office_phone` (D2 spirit); no personal numbers.
- ASSUMPTION: Nearest-ward fallback limit `GEO_NEAREST_MAX_M=3000` — Spec §7 gives no distance; 3 km covers GPS drift and edge settlements without accepting Gandhinagar or Sanand.
- ASSUMPTION: Points on a shared boundary resolve to the lower ward number — deterministic and testable.
- ASSUMPTION: Boundary version string is derived from the OpenCity dataset month; if the 2026 delimitation changes boundaries (Open Question 2), a new version is imported with the same script and existing issues keep their stored ward.
- ASSUMPTION: Zone Gujarati names are the common forms listed in §5.2 until checked against AMC's Gujarati pages.
- ASSUMPTION: `zones.geom` is the union of its wards (Spec §6 allows NULL); used later for zone-wide alerts.
- ASSUMPTION: TASK-03 owns `lib/core/wards/` and the picker UI and runs in parallel; this task's mobile steps (10–11) run after TASK-03's repository exists. If TASK-03 is not merged yet, finish the API side, mark steps 10–11 pending in §13 and complete them once it lands.
- ASSUMPTION: No bundled ward snapshot — agrees with TASK-03 §5.6 (a bundled list would drift from the boundary-versioned data); offline use relies on TASK-03's `v2.wardsCache`.
- ASSUMPTION: "Outside all wards and beyond the nearest limit" is 422 `OUTSIDE_SERVICE_AREA` — TASK-03 already handles 422 as "outside city".

## 6. Implementation Steps

1. **Capture sources.** Download the OpenCity AMC wards KML into `prisma/data/geo/raw/`; record URL, licence, date, SHA-256 in `SOURCES.md`. Open AMC's ward list (amccrs.com WardList, English and Gujarati) and compile `amc-ward-list.json` by hand (48 wards, 7 zones, office address, published phone, source URL). Never store a personal number.
2. **Convert.** `apps/api/scripts/geo/kml-to-geojson.ts` + `geo:convert` (*candidate* `@tmcw/togeojson` + `@xmldom/xmldom`, pin exact): Polygon → MultiPolygon, drop Z, round 6 dp, keep `name` as `kmlName`; write `amc-wards.<version>.geojson`; print feature count.
3. **Migrations.** `20261005000000_create_zones_wards` and `20261005000100_ward_foreign_keys` per §5.2 (`--create-only`, hand SQL); Prisma models; drift gate green.
4. **Import.** `scripts/geo/import.ts` + `geo:import --version <v>` per §5.2; transactional; refuses on wrong counts.
5. **Cross-check.** `scripts/geo/crosscheck.ts` + `geo:crosscheck`; iterate `ward-aliases.json` until it passes; commit the passing report as `prisma/data/geo/CROSSCHECK.md` (counts, area, warnings).
6. **Backfill.** `scripts/geo/backfill.ts` + `geo:backfill`; run on the dev DB (legacy issues get wards).
7. **Geo service.** `src/modules/geo/`: `geo.service.ts` (`locate`, `listWards`, `getWard`, `listZones`, search normaliser incl. Gujarati digits), `geo.schemas.ts` (Zod), router with limiter and caching headers (ETag + 304). Add `OUTSIDE_SERVICE_AREA`. Mount in `src/routes.ts`. Export `resolveWard(lat,lng)` for TASK-05 (`POST /issues`).
8. **Seed module.** Fill TASK-01's `wards` seed module: runs `geo:import` logic from the committed files, then backfills seeded issues; `SEED-EXPECTATIONS.md` gains 48 wards / 7 zones; seed issues sit in the 5 pilot wards (D5).
9. **Fixture.** `geo:fixture` writes the live `/wards` response to `apps/mobile/test/fixtures/wards.json` (replacing TASK-03's hand-made fixture).
10. **Mobile data layer.** In TASK-03's `lib/core/wards/`: align the mapper with §5.3, add `match`/`distanceM`/`boundaryVersion`, refresh `v2.wardsCache` on version change, map 422 `OUTSIDE_SERVICE_AREA`; add `ward_search.dart` and switch the picker's filtering to it.
11. **Tests.** API suites T-02-xx and Flutter unit tests F-02-xx (§8).
12. **Manual checks** M-02-01…M-02-04; record evidence in the coverage matrix.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Wards and zones loaded with a version
- **Given** an empty `wards`/`zones` after migration
- **When** `npm run geo:import -- --version opencity-amc-wards-2025-11` runs twice
- **Then** there are exactly 48 wards and 7 zones, every ward has a valid MultiPolygon, a centroid inside it, `boundary_version` set and a zone; the second run changes no row (`updated_at` unchanged)

**AC-2** — Cross-checked against AMC's list
- **Given** the committed KML-derived GeoJSON and `amc-ward-list.json`
- **When** `npm run geo:crosscheck` runs
- **Then** it exits 0 with every KML feature matched to one AMC ward and every AMC ward to one polygon, no overlaps > 1,000 m², total area within bounds; removing one alias makes it exit 1 naming the unmatched ward

**AC-3** — Point inside a ward
- **Given** imported wards
- **When** `GET /geo/locate` is called with each ward's centroid (48 calls)
- **Then** each returns 200 with that ward, its zone, `match:"inside"`, `confirm:false`, `distanceM:0`

**AC-4** — Nearest-ward fallback and outside area
- **Given** a point 500 m outside the outer boundary of an edge ward, and a point in Gandhinagar (23.2156, 72.6369)
- **When** `/geo/locate` is called for each
- **Then** the first returns the edge ward with `match:"nearest"`, `confirm:true`, `distanceM` ≈ 500 (±50); the second returns 422 `OUTSIDE_SERVICE_AREA`

**AC-5** — Locate input validation
- **Given** the endpoint
- **When** called with `lat=abc`, missing `lng`, or `lat=95`
- **Then** 400 `VALIDATION_FAILED` with `details` naming the field; no coordinates appear in info-level logs

**AC-6** — Ward and zone lists
- **Given** imported data
- **When** `GET /wards`, `GET /wards?zone=west`, `GET /wards?q=પાલડી`, `GET /wards?q=paldi`, `GET /zones` are called
- **Then** `/wards` returns 48 items with Gujarati and English names and zone, ordered by zone then number; the zone filter returns only West-zone wards; both searches return Paldi; `/zones` returns 7 zones whose `wardCount` totals 48

**AC-7** — Ward detail
- **Given** Paldi's id and number
- **When** `GET /wards/{id}`, `GET /wards/{number}`, `GET /wards/{number}?include=geometry` and `GET /wards/999` are called
- **Then** the first two return the same `WardDetail` with office address, public phone (or null) and source line data; the third adds a simplified MultiPolygon; the last returns 404 `NOT_FOUND`

**AC-8** — Caching and rate limits
- **Given** a previous `/wards` response with an `ETag`
- **When** the request is repeated with `If-None-Match`, and 121 public geo requests are made in a minute from one IP
- **Then** the repeat returns 304 with no body; the 121st returns 429 `RATE_LIMITED` with `Retry-After`

**AC-9** — Issues and users linked to wards
- **Given** seeded and legacy issues with `ward_id` NULL
- **When** `npm run geo:backfill` runs
- **Then** every issue inside the city gets the ward and that ward's zone, issues within `GEO_NEAREST_MAX_M` get the nearest ward, the summary line reports the counts, and `pg_constraint` shows `fk_issues_ward`, `fk_issues_zone` and `fk_users_home_ward`

**AC-10** — Ward picker data (app)
- **Given** the app with the API reachable, then in airplane mode after one successful load
- **When** the ward picker opens and the user types "15", "૧૫", "nava" and "zzz"
- **Then** online it shows 7 zone groups with 48 wards; offline it shows the cached list with TASK-03's offline banner; "15" and "૧૫" both find ward 15; "nava" finds Nava Vadaj (and any other match) under their zones; "zzz" yields the no-match state

**AC-11** — Locate from the app
- **Given** the emulator location set inside Paldi, then 1 km outside the city edge, then in Gandhinagar
- **When** "Use my location" is tapped on the onboarding ward step each time
- **Then** it offers Paldi as "You're in Ward {n} · Paldi", then the nearest ward with the "just outside" confirmation, then the outside-Ahmedabad message with the list

| AC | Requirements |
|---|---|
| AC-1 | REQ-D-006 |
| AC-2 | REQ-D-006 |
| AC-3 | REQ-F-001 |
| AC-4 | REQ-F-001 |
| AC-5 | REQ-F-001 |
| AC-6 | REQ-F-002, REQ-F-003 |
| AC-7 | REQ-F-002 |
| AC-8 | REQ-F-002 |
| AC-9 | REQ-D-006, REQ-F-001 |
| AC-10 | REQ-F-003 |
| AC-11 | REQ-F-001, REQ-F-003 |

### 7.2 Non-Functional Checklist

- [ ] `/geo/locate` p95 < 50 ms on the dev machine with 48 wards (GIST index used — `EXPLAIN` shows index scan)
- [ ] `/wards` payload without geometry < 15 KB; `?include=geometry` for one ward < 60 KB
- [ ] Coordinates never logged at info level; ward number only
- [ ] Every AMC-derived field carries its source (`source` object in `WardDetail`) for TASK-09 to display
- [ ] Gujarati ward and zone names reviewed by a Gujarati reader (data, not ARB)
- [ ] Ward search is identical in API and app for the test table (same cases in T-02-07 and F-02-01)
- [ ] Source files and licence recorded in `SOURCES.md`; no AMC logo or scraped images committed
- [ ] Import, cross-check and backfill are idempotent and transactional

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-02-01 | API `typecheck`, `lint`, drift gate; mobile `dart format`, `dart analyze` | all |
| API integration | T-02-01 | `geo-import.test.ts`: import from a 3-ward fixture GeoJSON + list (test data in `test/fixtures/geo/`), counts, validity, centroid inside, idempotent second run, wrong count refused | AC-1 |
| API integration | T-02-02 | `geo-crosscheck.test.ts`: fixture with a missing alias → exit code 1 and the ward named; overlapping fixture → failure | AC-2 |
| API integration | T-02-03 | `geo-locate.test.ts`: every fixture ward's centroid → inside; boundary point → lower number; point 500 m outside → nearest + confirm; far point → 422 `OUTSIDE_SERVICE_AREA` | AC-3, AC-4 |
| API integration | T-02-04 | `geo-locate.test.ts` › validation: bad/missing/out-of-range → 400 with field details | AC-5 |
| API integration | T-02-05 | `wards.test.ts`: list order, zone filter, `q` in Gujarati/English/number, zones `wardCount`, detail by id and number, geometry include, 404 | AC-6, AC-7 |
| API integration | T-02-06 | `wards.test.ts` › caching + limits: ETag → 304; 121st call → 429 | AC-8 |
| API integration | T-02-07 | `ward-search.test.ts` (unit): normaliser table — case, spaces, "Ward 15", "૧૫", partial Gujarati | AC-6 |
| API integration | T-02-08 | `geo-backfill.test.ts`: issues inside/near/outside → ward+zone set / nearest / left NULL; FKs present | AC-9 |
| Flutter unit | F-02-01 | `ward_search_test.dart`: same table as T-02-07; grouping keeps only groups with matches | AC-10 |
| Flutter unit | F-02-02 | `wards_repository_test.dart` (mock dio): mapping of the real fixture, cache written with `boundaryVersion`, different version replaces cache, 422 `OUTSIDE_SERVICE_AREA` → `OutsideServiceArea` | AC-10, AC-11 |
| Manual | M-02-01 | Run `geo:convert`, `geo:import`, `geo:crosscheck` on the real KML; attach `CROSSCHECK.md`; spot-check 5 pilot wards visually (`ST_AsGeoJSON` pasted into geojson.io) | AC-1, AC-2 |
| Manual | M-02-02 | `curl` `/geo/locate` for known places: Paldi, Navrangpura, Vasna, Naranpura, Nava Vadaj (coordinates from a map) → expected ward each | AC-3 |
| Manual | M-02-03 | `curl -i` `/wards`, `/wards/{n}?include=geometry`, `/zones`; check headers and payload sizes | AC-6, AC-7, AC-8 |
| Flutter integration | F-02-03 | `integration_test/ward_locate_test.dart` on the emulator against the local API: geo fix inside Paldi / 1 km outside the edge / Gandhinagar → `WardLocateResult` (confirm false / true) or `OutsideServiceArea` | AC-11 |
| Manual | M-02-04 | Emulator onboarding: ward by GPS (`adb emu geo fix` for the three points) and by search in Gujarati and English, then airplane mode; screenshot each state | AC-10, AC-11 |

## 9. Deliverables

- Source files, `SOURCES.md`, `CROSSCHECK.md`, normalised GeoJSON, `amc-ward-list.json`, `ward-aliases.json`.
- Migrations for `zones`, `wards` and ward foreign keys; Prisma models.
- Scripts `geo:convert`, `geo:import`, `geo:crosscheck`, `geo:backfill`, `geo:fixture`.
- `geo` API module with four endpoints and `resolveWard()` for later tasks.
- `wards` seed module; updated seed expectations.
- Mobile `lib/core/wards/` alignment, `ward_search.dart`, real-data fixture.
- API and Flutter tests; coverage matrix evidence for 4 requirements.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/api/prisma/data/geo/**` | New |
| `apps/api/prisma/migrations/20261005000000_create_zones_wards/`, `20261005000100_ward_foreign_keys/` | New |
| `apps/api/prisma/schema.prisma`, `prisma/seed/modules/wards.ts`, `SEED-EXPECTATIONS.md` | Modified / New |
| `apps/api/scripts/geo/{kml-to-geojson,import,crosscheck,backfill,fixture}.ts`, `apps/api/package.json` | New / Modified |
| `apps/api/src/modules/geo/`, `src/routes.ts`, `src/lib/errors/index.ts`, `src/config/index.ts` (`GEO_NEAREST_MAX_M`) | New / Modified |
| `apps/api/test/geo-*.test.ts`, `wards.test.ts`, `ward-search.test.ts`, `test/fixtures/geo/` | New |
| `apps/mobile/lib/core/wards/` (`wards_repository.dart`, `ward.dart`, new `ward_search.dart`), ward picker widget from TASK-03 | Modified / New |
| `apps/mobile/test/fixtures/wards.json` | Modified (real data) |
| `apps/mobile/test/core/wards/`, `apps/mobile/integration_test/ward_locate_test.dart` | New |

## 11. Related Documentation

- Spec §2 D10 — PostGIS and OpenCity ward source; D9 — topic naming; D5 — pilot wards
- Spec §6 — `zones`, `wards` columns
- Spec §7 — Geo endpoints and public rate limit
- Spec §8 — `/onboarding/ward`, My Ward routes
- DS §5 (list rows), DS §7 (accessibility: labels, Gujarati) — for consumers of the picker data
- `docs/tasks-v2/TASK-01-platform-upgrade.md` — seed framework, test harness, geo helpers
- `docs/tasks-v2/TASK-03-design-system-shell.md` §5.3–5.6 — ward models, `WardsRepository`, picker states this task feeds
- `docs/tasks-v2/00-task-summary.md` — Open Question 2 (2026 delimitation)

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| OpenCity KML predates the 2026 delimitation | Wrong ward for addresses near changed boundaries | `boundary_version` stored; cross-check with AMC's current list; re-import script ready; nearest/confirm UX lets citizens correct |
| KML names don't match AMC spellings (e.g. Gujarati transliteration) | Import blocked or wrong mapping | Alias file + strict cross-check that fails loudly |
| Invalid or self-intersecting polygons | Points fall in no ward | `ST_MakeValid`, validity CHECK, centroid self-test in cross-check |
| Gaps/slivers between wards | Citizens "outside" while inside the city | Nearest fallback with confirmation; gaps reported as warnings |
| AMC ward list changes office addresses | Stale contact info | `last_verified_at` + source line shown; re-check in TASK-14 launch checklist |
| Location logging | Privacy exposure | Coordinates excluded from info logs (non-functional check) |

## 13. Progress Status

**Current status:** Not Started

**Progress:** 0%

| Date | Progress | Commit |
|---|---|---|

## 14. Completion Checklist

- [ ] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [ ] Static checks pass and every AC verified by the checks in §8
- [ ] Automated tests added and passing
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified
- [ ] Code reviewed against the patterns established in earlier tasks
- [ ] Assumptions documented and, where possible, confirmed
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-02` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `V2-TASK-02: …`
- [ ] Validator passes
