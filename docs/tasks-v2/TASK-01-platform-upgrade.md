# TASK-01: Platform Upgrade — PostGIS, v2 Data Model, Legacy Migration, Test Harness

| Field | Value |
|---|---|
| Task ID | TASK-01 |
| Status | Not Started |
| Priority | P0 |
| Size | L |
| Depends On | None |
| Blocks | TASK-02, TASK-04, TASK-13 |
| Requirement IDs | REQ-D-001, REQ-D-002, REQ-D-003, REQ-D-004, REQ-D-005, REQ-D-013, REQ-N-009, REQ-O-001, REQ-O-002 |
| Primary Spec Refs | Spec §2 (D10, D11), §5, §6, §12; v1 `docs/04-database-design.md` §3 (existing tables) |
| Last Updated | 2026-10-03 |

## 1. Objective

Move the v1 foundation onto the v2 platform without losing a row: the local database runs on PostGIS, the cross-cutting v2 tables (citizens, consents, devices, categories, issues and their children) exist through new migrations only, every v1 complaint is copied into `issues` and the v1 tables become read-only history, the Prisma schema and seed describe v2, and every later task can prove its work with automated API tests (Vitest + Supertest) that run against a disposable test database locally and in CI.

## 2. Scope

### In Scope
- Compose image switch `postgres:17.6` → `postgis/postgis:17-3.5`; a safe dump → switch → restore path for existing local data (`scripts/db-upgrade-postgis.sh`).
- New migrations: PostGIS extension; enums; `users`, `consents`, `devices`; `categories` (table only); `issues`, `issue_photos`, `issue_events`, `issue_verifications`, `me_toos`, `follows`; legacy read-only guard on v1 tables.
- Prisma schema for all of the above, PostGIS columns as `Unsupported(...)`, migration drift check.
- Legacy migration script `legacy:migrate` (complaints → issues, idempotent) and retirement of v1 write endpoints (HTTP 410).
- v2 development seed framework (ordered modules) with the modules whose tables exist after this task; `db:reset` and `demo:reset` updated.
- Test harness: Vitest + Supertest, `.env.test`, test-database guard, DB reset helper, factories, first suites (migrations, constraints, legacy, health, admin auth, permissions, rate limits), CI job with a PostGIS service container.

### Out of Scope
- `zones`, `wards` tables, ward seeding and the foreign keys from `issues`/`users` to them — TASK-02.
- Seeding the 14 production categories and `amc_problem_types` (REQ-D-007) — TASK-05. This task seeds a **development fixture** of the 14 slugs only.
- `representatives*`, `rep_*` (TASK-09), `alerts`, `alert_wards`, `subscriptions`, `notifications` (TASK-08), `services`, `initiatives`, `rsvps` (TASK-12), `moderation_flags`, `app_settings` (TASK-10). Their seed modules are added by those tasks.
- Any v2 endpoint (`/issues`, `/auth/firebase`, …) — TASK-04 onward. Lifecycle tests are written by the tasks that build the lifecycle.
- Managed database, staging, backups — TASK-13.
- Mobile changes (the v1 citizen flows that call retired endpoints are replaced in TASK-03/TASK-05).

## 3. Prerequisites

- Docker Desktop running; Node 20; repo installs cleanly (`npm ci` in `apps/api`).
- `apps/api/.env` from v1 with `APP_ENV=development`; `infra/.env` with `POSTGRES_*`.
- A free 1 GB of disk for the pre-switch dump in `~/saarthee-backups/` (outside the repo).
- Read Spec §5 (status names) and §6 (columns) before writing SQL.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| None | First backend task. It builds on the v1 code in `apps/api` (10 applied migrations, `createApp()`, `rateLimit()`, `AppError`, storage interface, seed). |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-D-001 | PostGIS enabled: compose image `postgis/postgis:17-3.5`, `CREATE EXTENSION postgis` in a new migration, local data migrated | Spec D10 |
| REQ-D-002 | New v2 tables per spec §6 created only through new migrations; applied v1 migrations untouched | Spec §6 |
| REQ-D-003 | `users`, `consents`, `devices` tables with constraints (unique phone, unique firebase uid, role enum) | Spec §6 |
| REQ-D-004 | `issues`, `issue_photos`, `issue_events`, `issue_verifications`, `me_toos`, `follows` with geography point, GIST index and status index | Spec §6 |
| REQ-D-005 | Legacy migration: every v1 complaint copied into `issues` with mapped status and `legacy_complaint_id`; v1 tables read-only | Spec §6, D11 |
| REQ-D-013 | Development seed for v2: wards, categories, sample citizens, issues in every status, representatives (fictional), alerts, services, initiatives | Spec §6 |
| REQ-N-009 | Automated tests: API integration tests (Vitest + Supertest) for auth, issue lifecycle, permissions and rate limits; run in CI | Spec §12 |
| REQ-O-001 | Prisma schema updated for v2 with PostGIS columns via `Unsupported` or raw SQL; `prisma generate`, typecheck and lint pass | Spec §6 |
| REQ-O-002 | `npm run demo:reset` and `db:reset` work with v2 seed | Spec §12 |

### 5.2 Data Contracts

Migrations (names fixed; timestamps after the last v1 migration `20261003000900_create_views`):

| Migration | Contents |
|---|---|
| `20261004000000_enable_postgis` | `CREATE EXTENSION IF NOT EXISTS postgis;` |
| `20261004000100_v2_enums` | `user_role` (citizen, moderator, admin, representative) · `user_status` (active, suspended, deleted) · `app_language` (gu, en) · `consent_purpose` (core_service, share_with_representatives, share_with_amc_handoff, notifications) · `issue_status` (reported, sent, acknowledged, in_progress, marked_fixed, verified, reopened, rejected, merged) · `issue_visibility` (public, hidden) · `issue_photo_kind` (report, after, verification) · `issue_event_type` (status_change, comment, ccrs_linked, escalated, merged, rejected) · `actor_role` (citizen, moderator, admin, representative, system). Reuse v1 `platform` and `verification_result` |
| `20261004000200_create_users_consents_devices` | tables below |
| `20261004000300_create_categories` | table below (no rows) |
| `20261004000400_create_issues` | `issues` + location trigger + indexes |
| `20261004000500_create_issue_children` | `issue_photos`, `issue_events`, `issue_verifications`, `me_toos`, `follows` |
| `20261004000600_legacy_read_only` | guard function + triggers on v1 tables |

All ids `uuid DEFAULT gen_random_uuid()`, all times `timestamptz(6)`, constraint/index names `pk_`/`uq_`/`fk_`/`ck_`/`idx_` + table (v1 convention).

**`users`** — `id`, `phone_e164 varchar(16) NULL` (`uq_users_phone`; `ck_users_phone` `phone_e164 ~ '^\+[1-9][0-9]{7,14}$'`), `firebase_uid varchar(128) NULL` (`uq_users_firebase_uid`), `display_name varchar(60) NULL`, `home_ward_id uuid NULL` (FK added by TASK-02), `language app_language NOT NULL DEFAULT 'gu'`, `role user_role NOT NULL DEFAULT 'citizen'`, `status user_status NOT NULL DEFAULT 'active'`, `token_version int NOT NULL DEFAULT 0`, `created_at`, `last_seen_at NULL`, `deleted_at NULL`. `ck_users_deleted`: `status <> 'deleted' OR (phone_e164 IS NULL AND firebase_uid IS NULL)`; `ck_users_active_identity`: `status = 'deleted' OR firebase_uid IS NOT NULL`. Index `idx_users_role` (role) WHERE role <> 'citizen'.

**`consents`** — `id`, `user_id → users ON DELETE CASCADE`, `purpose consent_purpose`, `text_version varchar(20)`, `granted_at`, `withdrawn_at NULL`; `uq_consents_active` UNIQUE (user_id, purpose) WHERE withdrawn_at IS NULL; `ck_consents_order` withdrawn_at ≥ granted_at.

**`devices`** — `id`, `user_id → users NULL ON DELETE SET NULL`, `install_id uuid NOT NULL` (`uq_devices_install`), `fcm_token varchar(4096) NULL` (`uq_devices_fcm_token`), `platform platform`, `app_version varchar(20)`, `created_at`, `last_seen_at`. Index `idx_devices_user`.

**`categories`** — `id`, `slug varchar(32)` (`uq_categories_slug`, `ck_categories_slug` `^[a-z][a-z_]{1,31}$`), `name_en varchar(60)`, `name_gu varchar(60)`, `icon varchar(64)`, `colour_token varchar(40)`, `sla_days smallint` (`ck_categories_sla` 1–365), `sensitive bool DEFAULT false`, `is_active bool DEFAULT true`, `sort_order int`, `created_at`, `updated_at`. Index (is_active, sort_order).

**`issues`** — `id`, `client_submission_id uuid NOT NULL` (`uq_issues_client_submission`), `reporter_id → users NULL ON DELETE SET NULL` (NULL only for legacy rows and erased accounts), `category_id → categories RESTRICT`, `title varchar(120)`, `description varchar(1000) NULL`, `lat numeric(9,6)`, `lng numeric(9,6)` (`ck_issues_coords` ranges), `location geography(Point,4326) NULL` filled by trigger `trg_issues_location` (BEFORE INSERT OR UPDATE OF lat, lng: `ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography`) plus `ck_issues_location` `location IS NOT NULL`, `gps_accuracy_m numeric(8,2) NULL`, `ward_id uuid NULL`, `zone_id uuid NULL` (FKs added by TASK-02), `address_text varchar(200) NULL`, `status issue_status DEFAULT 'reported'`, `status_changed_at`, `sla_due_at`, `me_too_count int DEFAULT 0`, `follower_count int DEFAULT 0` (`ck_issues_counts` ≥ 0), `ccrs_number varchar(50) NULL`, `ccrs_filed_at NULL`, `visibility issue_visibility DEFAULT 'public'`, `is_sensitive bool DEFAULT false`, `merged_into_id → issues NULL` (`ck_issues_merged` status = 'merged' ⇔ merged_into_id IS NOT NULL), `legacy_complaint_id → complaints NULL` (`uq_issues_legacy_complaint`), `created_at`, `updated_at`.
Indexes: `idx_issues_location` GIST (location); `idx_issues_status` (status, status_changed_at DESC); `idx_issues_ward_status` (ward_id, status); `idx_issues_category_created` (category_id, created_at DESC); `idx_issues_reporter` (reporter_id); `idx_issues_sla_open` (sla_due_at) WHERE status IN ('reported','sent','acknowledged','in_progress','reopened').

**`issue_photos`** — `issue_id → issues CASCADE`, `photo_id → photos RESTRICT` (`uq_issue_photos_photo`), `kind issue_photo_kind`, `position smallint` (0–2 for report); PK (issue_id, photo_id); `uq_issue_photos_position` (issue_id, kind, position).

**`issue_events`** — `id`, `issue_id → issues CASCADE`, `actor_id → users NULL SET NULL`, `actor_role actor_role`, `type issue_event_type`, `from_status issue_status NULL`, `to_status issue_status NULL`, `note varchar(500) NULL`, `photo_id → photos NULL`, `created_at`. `ck_issue_events_status`: type <> 'status_change' OR to_status IS NOT NULL. Index (issue_id, created_at). Append-only: trigger `trg_issue_events_append_only` rejects UPDATE/DELETE (erasure in TASK-04 nulls `actor_id` through the bypass setting below).

**`issue_verifications`** — `id`, `issue_id → issues CASCADE`, `user_id → users`, `answer verification_result`, `photo_id → photos NULL`, `lat`, `lng numeric(9,6) NULL`, `distance_m numeric(8,1) NULL`, `created_day date NOT NULL` (service sets the Asia/Kolkata date), `created_at`; `uq_issue_verifications_daily` (issue_id, user_id, created_day).

**`me_toos`**, **`follows`** — `issue_id → issues CASCADE`, `user_id → users CASCADE`, `created_at`; PK (issue_id, user_id); index (user_id, created_at DESC).

**Legacy guard** — function `legacy_read_only()` raises `SQLSTATE 'P0001'` message `LEGACY_READ_ONLY` unless `current_setting('saarthee.legacy_write', true) = 'on'`; BEFORE INSERT/UPDATE/DELETE triggers on `complaints`, `reminders`, `verifications`, `invite_codes`, `ccrs_categories`. `photos` and `events` stay writable (v2 reuses them). Helper `withLegacyWrite(tx)` in `src/lib/db` runs `SET LOCAL saarthee.legacy_write = 'on'` inside a transaction — used only by the legacy script, the v1 anonymize path and seeds.

**Legacy mapping** (`apps/api/scripts/legacy-migrate.ts`):

| v1 | v2 |
|---|---|
| `complaint_status_v.status` filed / reminded / verified_fixed / verified_not_fixed | `reported` / `sent` / `verified` / `reopened` (Spec §6) |
| `ccrs_categories.name` Pothole or damaged road · Garbage and cleanliness · Streetlight · Drainage · Water supply · Other | `roads` · `garbage` · `streetlight` · `drainage` · `water` · `other` (unknown name → fail with list) |
| `client_submission_id`, `latitude`, `longitude`, `gps_accuracy_m`, `created_at` | same columns |
| `ccrs_number_raw`, `created_at` | `ccrs_number`, `ccrs_filed_at` |
| `photo_id` | `issue_photos` kind `report`, position 0 |
| each `verifications` row | `issue_photos` kind `verification` + `issue_events` status_change (verified / reopened), actor_role `system` |
| each `reminders` row | `issue_events` status_change → `sent` at `sent_at` (first only), actor_role `system` |
| — | `reporter_id` NULL, `title` = category `name_en`, `visibility` `hidden`, `sla_due_at` = created_at + category `sla_days`, `status_changed_at` = time of last mapped event, `legacy_complaint_id` = complaint id; plus one `status_change` (null → reported) event at `created_at` |

Phones, invite codes and source tags are **not** copied. Re-running inserts nothing new (`ON CONFLICT (legacy_complaint_id) DO NOTHING`); the run prints `complaints=N imported=N skipped=N`.

**Seed framework** (`apps/api/prisma/seed/`): `index.ts` runs registered modules in order; each module exports `{ name, requires: string[] /* tables */, run(prisma) }` and is skipped with a log line when a required table does not exist (`to_regclass`). Modules in this task: `admin` (v1 admin, kept), `legacy-v1` (v1 fixtures C1–C11 written through `withLegacyWrite`, then `legacy:migrate`), `categories-dev` (14 slugs/names from Spec §4, `icon` = slug, `colour_token` = `cat_<slug>`, `sla_days` 7 — dev only, replaced by TASK-05's reference data), `citizens` (6 fictional users, phones `+9190000000NN`, firebase uids `seed-uid-NN`, one moderator, one suspended, mixed gu/en), `issues` (≥ 1 public issue per `issue_status` incl. one `merged` pointing at its canonical issue, one overdue, one hidden, one sensitive; coordinates inside the 5 pilot wards of D5; photos generated by the v1 `seed-photo.ts`; matching `issue_events`, `me_toos`, `follows`, `issue_verifications`). Registered placeholders with `requires` set, to be filled by their tasks: `wards` (TASK-02), `representatives` (TASK-09), `alerts` (TASK-08), `services` + `initiatives` (TASK-12). Seed is idempotent (fixed UUIDs, upserts). Expected counts go in `prisma/SEED-EXPECTATIONS.md` (v2 section).

### 5.3 API Contracts

No new endpoints. Changes to existing v1 endpoints:

| Method | Path | Change | Response |
|---|---|---|---|
| POST | `/api/v1/reports` | Retired (v1 citizen write) | 410 `ENDPOINT_RETIRED` |
| GET/POST | `/api/v1/verify/*` | Retired | 410 `ENDPOINT_RETIRED` |
| POST/PATCH | `/api/v1/admin/invite-codes*`, `/admin/categories*`, `/admin/complaints/{id}/exclude`, `/admin/complaints/{id}/reminders` | Retired | 410 `ENDPOINT_RETIRED` |
| GET | `/api/v1/admin/complaints*`, `/admin/export*`, `/admin/rates*` | Kept (read history) | unchanged |
| POST | `/api/v1/admin/complaints/{id}/anonymize` | Kept; writes through `withLegacyWrite` and also nulls the imported issue's photos | unchanged |
| GET | `/api/v1/health` | Adds `postgis` to the body | 200 `{status:"ok", db:"up", postgis:"3.5.x"}`; 503 `SERVICE_UNAVAILABLE` when DB is down |

New error code in `src/lib/errors`: `ENDPOINT_RETIRED: { status: 410, message: 'Please update Saarthee to report issues.' }` (same code and copy TASK-05 §5.3 expects; TASK-05 then only removes the dead v1 report code). `LEGACY_READ_ONLY` is the database trigger message only; if it ever reaches the error handler it maps to 500 `INTERNAL_ERROR` (a bug). The exact list of retired routes is confirmed by reading `src/routes.ts` and `src/modules/admin*` (step 9); any v1 write not listed above is retired the same way and recorded in §5.6.

### 5.4 UI Surfaces & States

No UI in this task. Developer-facing outputs only:

| Surface | Content | States |
|---|---|---|
| `npm run db:upgrade-postgis` | "Dump written to ~/saarthee-backups/<ts>.dump (N bytes)", "PostGIS 3.5.x ready", "Row counts match: complaints=N photos=N …" | refuses if `APP_ENV` ≠ development; stops (data untouched) if the dump fails; prints the restore command if counts differ |
| `npm run legacy:migrate` | `complaints=N imported=N skipped=N` | exit 1 with the unknown category names; exit 1 if `categories` is empty ("Seed categories first") |
| `npm test` (apps/api) | Vitest summary | refuses to run unless the database name ends in `_test` |
| `npm run demo:reset` | v2 summary table (issues per status, users, categories) | no emulator → skips app reset with a message |

### 5.5 Permissions & Roles

| Action | Visitor | Citizen | Admin (v1 login) | Notes |
|---|---|---|---|---|
| v1 citizen writes (`/reports`, `/verify/*`) | ❌ 410 | ❌ 410 | ❌ 410 | D11 |
| Read v1 complaints, export, rates | ❌ | ❌ | ✅ | History stays visible to admins |
| Anonymize a v1 complaint | ❌ | ❌ | ✅ | Only legacy write allowed at runtime |
| `legacy:migrate`, seed, `db:reset` | — | — | CLI on a dev machine | `db:reset`/`demo:reset` refuse unless `APP_ENV=development` |
| Direct SQL write to v1 tables | — | — | ❌ (trigger) | Allowed only with `saarthee.legacy_write=on` in the same transaction |

### 5.6 Assumptions

- ASSUMPTION: Imported legacy issues are `visibility=hidden` and have no reporter — v1 consent (`v1`) covered storage and WhatsApp contact, not public display or a user account — an admin can publish individual issues later (TASK-10) if the founder decides the consent allows it.
- ASSUMPTION: `actor_role` includes `system` for imported and automatic events — Spec §6 lists `actor_role` without values.
- ASSUMPTION: `issues.merged_into_id` added now — Spec §5 needs a canonical issue for `merged` but §6 lists no column; adding it avoids a later migration on a hot table.
- ASSUMPTION: `issue_verifications` uniqueness per "day" uses a stored `created_day` (Asia/Kolkata) set by the service — a generated column on `timestamptz` is not immutable.
- ASSUMPTION: `users.token_version` added for session revocation (same pattern as v1 `admin_users`) — Spec §6 silent; TASK-04 relies on it.
- ASSUMPTION: `users.phone_e164` accepts any E.164 number; the app restricts to +91 — keeps the constraint correct if Firebase later allows other numbers.
- ASSUMPTION: Ward/zone foreign keys are added by TASK-02 (tables do not exist yet); `ward_id`/`zone_id`/`home_ward_id` are plain `uuid` here and TASK-02 backfills imported issues by point-in-polygon.
- ASSUMPTION: REQ-D-013 is met by the seed framework plus the modules whose tables exist after this task; TASK-02/08/09/12 each add their module under the same contract, and the requirement row is marked Pass here with that note (the full seed is re-checked in TASK-14).
- ASSUMPTION: REQ-N-009's "auth, permissions and rate limits" are covered now for the code that exists (v1 admin auth, `requireAdmin`, `rateLimit`); citizen auth (TASK-04) and lifecycle (TASK-06) tests are added by those tasks using this harness — CI enforces they run.
- ASSUMPTION: Retiring v1 write endpoints with 410 is acceptable because v1 was never deployed beyond local demos (v1 REQ-O-022 deferred deployment).
- ASSUMPTION: If `postgis/postgis:17-3.5` has no `linux/arm64` image for the dev Mac, use the same tag with `platform: linux/amd64` (Rosetta) locally; CI (amd64) is unaffected.

## 6. Implementation Steps

1. **Dump first.** Add `scripts/db-upgrade-postgis.sh` (+ root `db:upgrade-postgis`): refuse unless `APP_ENV=development`; `pg_dump -Fc` from the running v1 container to `~/saarthee-backups/saarthee-<UTC ts>.dump`; record row counts of all v1 tables to a sibling `.counts` file. Run it before touching compose.
2. **Switch the image.** `infra/docker-compose.yml` → `postgis/postgis:17-3.5` (comment: why, and the arm64 fallback). Same major version, so the existing volume is reused; the script then starts the new container, waits for health, and compares row counts. If start or counts fail: `down -v`, start fresh, `pg_restore --no-owner` the dump, recount. Print both paths.
3. **PostGIS migration.** `prisma migrate dev --create-only --name enable_postgis`, write the SQL by hand; apply. Enable `previewFeatures = ["postgresqlExtensions"]` and `extensions = [postgis]` in `schema.prisma`.
4. **Drift gate.** Add `scripts/check-prisma-drift.sh`: `prisma migrate diff --from-migrations prisma/migrations --to-schema-datamodel prisma/schema.prisma --shadow-database-url $SHADOW_DATABASE_URL --exit-code`. If the diff proposes dropping `spatial_ref_sys`, add the introspected model with `@@ignore` (from `prisma db pull --print`) and re-run until empty.
5. **v1 immutability gate.** Add `apps/api/prisma/migrations/V1_CHECKSUMS.sha256` (sha256 of the 10 v1 `migration.sql` files) and `scripts/check-v1-migrations.sh` (`shasum -a 256 -c`). Both gates run in CI.
6. **Enums and tables.** Create migrations `…0100` to `…0500` with `--create-only`, then hand-write SQL per §5.2 (CHECKs, partial indexes, triggers, GIST). Mirror every table in `schema.prisma` (`@@map`, `@map`, named constraints); `location` as `Unsupported("geography(Point, 4326)")?`. Run `prisma generate`, `typecheck`, `lint`, drift gate.
7. **Geo helpers.** `src/lib/geo/index.ts`: `pointSql(lat,lng)` (Prisma.sql fragment), `distanceMetres(issueId, lat, lng)` using `ST_Distance(location, …)`; used by later tasks, unit-tested here.
8. **Legacy guard.** Migration `…0600` (function + triggers). `withLegacyWrite()` in `src/lib/db`. Route the v1 anonymize service through it.
9. **Retire v1 writes.** Audit `src/routes.ts` and `src/modules/{reports,verify,reminders,invite-codes,categories-admin,admin-complaints}`; replace write handlers with a shared `endpointRetired` handler (410 `ENDPOINT_RETIRED`), keep reads/export/anonymize. Add the error code. Record the final list in §5.6.
10. **Legacy migration script.** `scripts/legacy-migrate.ts` + `legacy:migrate` (apps/api and root): one transaction per 200 complaints; mapping per §5.2; reads `complaint_status_v`; idempotent; prints counts; exits 1 on unknown category or empty `categories`.
11. **Health.** Extend `/health` with `SELECT postgis_lib_version()`.
12. **Seed framework.** Move `prisma/seed.ts` → `prisma/seed/index.ts` + modules per §5.2 (update `package.json#prisma.seed`). Keep v1 fixtures as the `legacy-v1` module. Write `SEED-EXPECTATIONS.md` v2 section (counts per status, users per role).
13. **Reset scripts.** `scripts/db-reset.sh`: unchanged guard, then migrate deploy + seed (now v2). `scripts/demo-reset.sh`: print `SELECT status, count(*) FROM issues GROUP BY 1` and user/category counts instead of `pilot_rates_v`; remove the invite-code line; keep the emulator reset.
14. **Test harness.** Add exact-pinned devDependencies `vitest`, `supertest`, `@types/supertest` (record versions). `vitest.config.ts`: `globalSetup: test/global-setup.ts`, `fileParallelism: false`, `testTimeout: 20000`. `test/global-setup.ts`: load `.env.test`, refuse unless the DB name ends `_test`, run `prisma migrate reset --force --skip-seed`. Helpers: `test/helpers/app.ts` (`createApp()` + `request`), `db.ts` (`resetDb()` truncates every table except `_prisma_migrations`/`spatial_ref_sys` with `RESTART IDENTITY CASCADE`), `factories.ts` (user, category, issue, photo, v1 complaint via `withLegacyWrite`), `auth.ts` (v1 admin token). Export `resetRateLimitStores()` from `middleware/rateLimit.ts` for tests only. `.env.test.example` committed; `.env.test` git-ignored. Scripts: `test`, `test:watch`, `test:db:create` (creates `saarthee_test` in the compose container if absent). Root `api:test`.
15. **First suites** (`apps/api/test/`): `migrations.test.ts`, `constraints.test.ts`, `legacy.test.ts`, `health.test.ts`, `admin-auth.test.ts`, `permissions.test.ts`, `rate-limit.test.ts`, `seed.test.ts`, `guard.test.ts` — the T-01 cases in §8.
16. **CI.** `.github/workflows/ci.yml` api job: service `postgis/postgis:17-3.5` (health-checked), env `DATABASE_URL`/`SHADOW_DATABASE_URL` to `saarthee_test`/`saarthee_shadow`, steps `npm ci` → `prisma generate` → v1 checksum gate → `typecheck` → `lint` → drift gate → `npm test`. Upload the Vitest JUnit report as an artifact.
17. **Docs.** Update `apps/api/prisma/README.md` (PostGIS, migration rules, legacy guard), `apps/api/ARCHITECTURE.md` (test layout), root `README.md` quick start (`db:upgrade-postgis`, `api:test`).
18. **Verify.** Run M-01-01…M-01-04 on the developer machine and record evidence in the coverage matrix.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — PostGIS switch keeps local data
- **Given** a running v1 database with demo data
- **When** `npm run db:upgrade-postgis` runs
- **Then** a dump exists in `~/saarthee-backups/`, the container image is `postgis/postgis:17-3.5`, `SELECT postgis_lib_version()` returns 3.5.x, and every v1 table's row count equals the pre-switch count

**AC-2** — Migrations are additive only
- **Given** the repository after this task
- **When** the v1 checksum gate and `prisma migrate deploy` run on an empty PostGIS database
- **Then** the 10 v1 migration files match `V1_CHECKSUMS.sha256`, 7 new migrations apply in order, and `prisma migrate status` reports no pending or failed migrations

**AC-3** — Prisma schema matches the database
- **Given** all migrations applied
- **When** `prisma generate`, `npm run typecheck`, `npm run lint` and the drift gate run
- **Then** all pass and the drift diff is empty; `Issue.location` is an `Unsupported` geography field

**AC-4** — User, consent and device constraints
- **Given** a user with phone `+919000000001` and firebase uid `u1`
- **When** another user is inserted with the same phone, or the same uid, or role `superuser`, or phone `9000000001`; a second active `notifications` consent for the same user; or a second device with the same `install_id`
- **Then** each insert fails with the named constraint (`uq_users_phone`, `uq_users_firebase_uid`, enum error, `ck_users_phone`, `uq_consents_active`, `uq_devices_install`); withdrawing the first consent then allows a new one

**AC-5** — Issue location and indexes
- **Given** a category and a user
- **When** an issue is created through Prisma with `lat 23.012345, lng 72.561234` and no `location`
- **Then** `ST_AsText(location::geometry)` is `POINT(72.561234 23.012345)`; an insert with lat 91 fails `ck_issues_coords`; a 1,001-character description fails; a repeated `client_submission_id` fails `uq_issues_client_submission`; `pg_indexes` shows a GIST index on `issues.location` and `idx_issues_status`

**AC-6** — Issue children rules
- **Given** an issue with one `me_toos` row and one verification by user A today
- **When** the same me-too is inserted again, user A verifies again the same day, an `issue_events` row is updated or deleted, or a `merged` issue has no `merged_into_id`
- **Then** each is rejected (PK, `uq_issue_verifications_daily`, append-only trigger, `ck_issues_merged`); user A can verify again on the next `created_day`

**AC-7** — Legacy complaints copied with mapped status
- **Given** the 11 v1 fixtures C1–C11 (statuses filed ×3, reminded ×2, verified_fixed ×2, verified_not_fixed ×4)
- **When** `npm run legacy:migrate` runs twice
- **Then** the first run prints `complaints=11 imported=11 skipped=0` and the second `imported=0 skipped=11`; there are 11 issues with `legacy_complaint_id` set, statuses reported ×3, sent ×2, verified ×2, reopened ×4, all `visibility=hidden`, `reporter_id` NULL, CCRS number kept, report photo linked at position 0, verification photos linked, and an ordered `issue_events` history ending in the mapped status; no phone number appears in any v2 table

**AC-8** — v1 tables are read-only
- **Given** migrated data
- **When** SQL inserts/updates/deletes a row in `complaints`, `reminders`, `verifications`, `invite_codes` or `ccrs_categories`, and when `POST /api/v1/reports` or a retired admin write is called
- **Then** SQL fails with `LEGACY_READ_ONLY`, the HTTP calls return 410 `{error:{code:"ENDPOINT_RETIRED"}}`, while admin complaint reads, export and anonymize still succeed (anonymize through the bypass)

**AC-9** — Test harness runs locally and in CI
- **Given** `.env.test` pointing at `saarthee_test`
- **When** `npm test` runs in `apps/api`, and when a pull request touches `apps/api/**`
- **Then** all T-01 suites pass locally; CI starts a PostGIS service, applies migrations, runs both gates and the suites, and fails the job if any test fails; pointing `.env.test` at `saarthee` makes the run abort before touching data

**AC-10** — Auth, permissions and rate limits are tested
- **Given** the harness and a seeded v1 admin
- **When** the auth, permission and rate-limit suites run
- **Then** they assert: correct login → token; wrong password → 401 `INVALID_CREDENTIALS`; bumped `token_version` → 401 `TOKEN_REVOKED`; `/admin/*` without a token → 401; 121 `/health` calls in a minute → 429 `RATE_LIMITED` with `Retry-After`

**AC-11** — v2 development seed
- **Given** an empty migrated database
- **When** `npx prisma db seed` runs twice
- **Then** the second run changes nothing; counts equal `SEED-EXPECTATIONS.md`: 14 categories, 6 citizens (1 moderator, 1 suspended), at least one public issue in each of the 9 statuses (merged one points at its canonical issue), one overdue, one hidden, one sensitive, 11 imported legacy issues; modules for missing tables log `skipped (requires wards)` etc.

**AC-12** — Reset commands
- **Given** `APP_ENV=development` and an emulator attached
- **When** `npm run db:reset -- --yes` and `npm run demo:reset` run
- **Then** both finish without error, the database contains exactly the v2 seed, and demo:reset prints the issues-per-status table; with `APP_ENV=production` both refuse with exit 1

| AC | Requirements |
|---|---|
| AC-1 | REQ-D-001 |
| AC-2 | REQ-D-001, REQ-D-002 |
| AC-3 | REQ-O-001 |
| AC-4 | REQ-D-002, REQ-D-003 |
| AC-5 | REQ-D-004, REQ-O-001 |
| AC-6 | REQ-D-004 |
| AC-7 | REQ-D-005 |
| AC-8 | REQ-D-005 |
| AC-9 | REQ-N-009 |
| AC-10 | REQ-N-009 |
| AC-11 | REQ-D-013 |
| AC-12 | REQ-O-002, REQ-D-013 |

### 7.2 Non-Functional Checklist

- [ ] No applied v1 migration file changed (checksum gate green)
- [ ] All SQL parameterised (`Prisma.sql` / tagged templates); no string-built SQL in scripts
- [ ] The dump file and `.env.test` are outside git (`git status` clean after the upgrade)
- [ ] Legacy script and seed never log phone numbers or CCRS numbers (counts only)
- [ ] Test run leaves no rows in the dev database `saarthee` (guard verified)
- [ ] Full test suite runs in under 60 s locally; CI api job under 6 min
- [ ] `legacy:migrate` on 10,000 synthetic complaints completes in under 60 s (batching works)
- [ ] Every new table, column and constraint name follows the v1 naming convention
- [ ] New dependencies pinned exactly; `npm audit --omit=dev` shows no high/critical

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-01-01 | `npm run typecheck`, `npm run lint`, `prisma generate`, drift gate, v1 checksum gate | AC-2, AC-3 |
| API integration | T-01-01 | `migrations.test.ts`: `postgis_lib_version()` 3.5.x; 17 rows in `_prisma_migrations`; expected tables exist; `amc_problem_types`, `wards`, `alerts` do **not** exist | AC-2 |
| API integration | T-01-02 | `constraints.test.ts` › users/consents/devices: each violation in AC-4 raises the named constraint; withdrawn consent allows re-grant; deleted user must have null phone/uid | AC-4 |
| API integration | T-01-03 | `constraints.test.ts` › issues: trigger fills `location`; coords CHECK; description length; unique client id; GIST and status index present in `pg_indexes` | AC-5 |
| API integration | T-01-04 | `constraints.test.ts` › children: me-too PK, verification daily unique (and next day ok), events append-only, merged check, counts ≥ 0 | AC-6 |
| API integration | T-01-05 | `legacy.test.ts`: factory builds C1–C11; run migration function twice; assert counts, status mapping table, hidden, photos, events order, no phone in `users`/`issues`/`issue_events` | AC-7 |
| API integration | T-01-06 | `guard.test.ts`: raw insert/update/delete on each v1 table → `LEGACY_READ_ONLY`; same inside `withLegacyWrite` succeeds | AC-8 |
| API integration | T-01-07 | `permissions.test.ts`: retired routes → 410 `ENDPOINT_RETIRED`; admin reads/export 200 with token, 401 without; anonymize 200 | AC-8, AC-10 |
| API integration | T-01-08 | `admin-auth.test.ts`: login ok, wrong password 401, disabled 403, token_version bump 401 `TOKEN_REVOKED` | AC-10 |
| API integration | T-01-09 | `rate-limit.test.ts`: 121st `/health` in a window → 429 + `Retry-After`; `resetRateLimitStores()` isolates tests | AC-10 |
| API integration | T-01-10 | `health.test.ts`: 200 with `postgis`; DB unreachable (bad URL client) → 503 | AC-3 |
| API integration | T-01-11 | `seed.test.ts`: run seed twice; counts per §5.2; every `issue_status` present; skipped modules logged | AC-11 |
| API integration | T-01-12 | `global-setup` guard: DB name without `_test` → setup throws before any query (unit test of the guard function) | AC-9 |
| CI | C-01-01 | Push a branch with a deliberately failing test → api job red; revert → green | AC-9 |
| Manual | M-01-01 | Run `db:upgrade-postgis` on the existing v1 demo DB; compare `.counts` with post-switch counts; screenshot terminal | AC-1 |
| Manual | M-01-02 | Restore path: `down -v`, `pg_restore` the dump into a fresh PostGIS container, counts match | AC-1 |
| Manual | M-01-03 | `psql`: `INSERT INTO complaints …` → `LEGACY_READ_ONLY`; `curl -XPOST $API/reports` → 410 | AC-8 |
| Manual | M-01-04 | `npm run demo:reset` with emulator attached; then with `APP_ENV=production` → refused | AC-12 |

## 9. Deliverables

- PostGIS compose image and `db:upgrade-postgis` script with dump/restore path.
- 7 new migrations, updated `schema.prisma`, drift and v1-checksum gates.
- `withLegacyWrite`, legacy guard, retired v1 write routes, `ENDPOINT_RETIRED` error code.
- `legacy:migrate` script.
- Modular v2 seed with expectations doc; updated `db:reset` and `demo:reset`.
- Vitest + Supertest harness, helpers, 12 test suites, CI job with PostGIS service.
- Coverage matrix evidence for 9 requirements.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `infra/docker-compose.yml` | Modified (image) |
| `scripts/db-upgrade-postgis.sh`, `scripts/db-reset.sh`, `scripts/demo-reset.sh`, root `package.json` | New / Modified |
| `apps/api/prisma/migrations/20261004000000_…` to `20261004000600_…`, `V1_CHECKSUMS.sha256` | New |
| `apps/api/prisma/schema.prisma` | Modified |
| `apps/api/prisma/seed/` (index + modules), `prisma/seed.ts` (removed), `SEED-EXPECTATIONS.md`, `README.md` | New / Modified |
| `apps/api/scripts/legacy-migrate.ts`, `check-prisma-drift.sh`, `check-v1-migrations.sh` | New |
| `apps/api/src/lib/{db,geo,errors}/`, `src/middleware/rateLimit.ts` | Modified / New |
| `apps/api/src/modules/{reports,verify,reminders,invite-codes,categories-admin,admin-complaints,anonymize,public}/`, `src/routes.ts` | Modified |
| `apps/api/test/**`, `vitest.config.ts`, `.env.test.example`, `.gitignore`, `package.json`, `package-lock.json` | New / Modified |
| `.github/workflows/ci.yml` | Modified |
| `apps/api/ARCHITECTURE.md`, `README.md` | Modified |

## 11. Related Documentation

- `docs/v2/saarthee-v2-spec.md` Spec §2 D10, D11 — PostGIS and retirement of v1 constructs
- Spec §5 — status names used by `issue_status`
- Spec §6 — table columns (source of §5.2)
- Spec §12 — environments, tests reversal
- `docs/04-database-design.md` §3 — v1 tables, naming convention, CHECK style
- `apps/api/prisma/SEED-EXPECTATIONS.md` — v1 fixtures C1–C11 reused as legacy fixtures
- `docs/tasks-v2/00-task-summary.md` — conventions, migrations rule

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Image switch corrupts or cannot open the old volume | Local demo data lost | Dump first (step 1), counts compared, documented `pg_restore` path (M-01-02) |
| Prisma drift tries to drop `spatial_ref_sys` or reorder PostGIS objects | Broken `migrate dev`, accidental destructive migration | `postgresqlExtensions`, `@@ignore` model, drift gate in CI |
| Required `Unsupported` column disables Prisma `create` | Services cannot insert issues | `location` optional in Prisma, enforced by trigger + CHECK in SQL (AC-5) |
| No arm64 PostGIS image | Slow emulated DB on Apple silicon | `platform: linux/amd64` fallback noted in compose; CI unaffected |
| Shared test DB makes tests order-dependent | Flaky CI | `fileParallelism: false`, `resetDb()` in `beforeEach`, rate-limit store reset |
| Legacy import publishes citizens' reports without consent | Privacy breach | Imported as `hidden`, no reporter, no phone (AC-7) |
| Later tasks skip writing tests | REQ-N-009 erodes | CI runs every suite; each later task's §8 lists T-NN tests; completion checklist item |

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
- [ ] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-01` shows 0 unverified)
- [ ] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [ ] Committed as `V2-TASK-01: …`
- [ ] Validator passes
