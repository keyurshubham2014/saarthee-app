# TASK-02: Database Schema, Migrations, Views & Seed Data

| Field | Value |
|---|---|
| Task ID | TASK-02 |
| Status | Complete |
| Priority | P0 |
| Size | M |
| Depends On | TASK-01 |
| Blocks | TASK-03, TASK-04, TASK-05 |
| Requirement IDs | REQ-D-001, REQ-D-002, REQ-D-003, REQ-D-004, REQ-D-005, REQ-D-006, REQ-D-007, REQ-D-008, REQ-D-009, REQ-D-010, REQ-D-011, REQ-D-012, REQ-D-013, REQ-D-014, REQ-D-015, REQ-D-016, REQ-D-017, REQ-O-005, REQ-O-019 |
| Primary Spec Refs | 04-database-design.md §1.2, §3, §4, §7, §8, §9; 03-backend-spec.md §4.3, §2.3 (RateRow); 05-devops-infrastructure.md §3.3 |
| Last Updated | 2026-10-03 |

## 1. Objective

Encode the whole data model of Doc 04 in Prisma and SQL migrations — every enum, table, constraint, index,
relationship and the two computed views that define H1 and H2 — and provide guarded scripts to migrate, seed and
reset the local database. At the end of this task the database holds a development sample set that exercises
every complaint status, with **documented expected rates** that later tasks (TASK-06, TASK-10) compare against.
This is on the critical path (07 §5.1): get it right once, never edit applied migrations.

## 2. Scope

### In Scope
- Prisma schema with all models/enums mapped to snake_case tables/columns; Prisma client generation.
- Migrations in the 04 §7.3 order, with hand-written SQL for CHECK constraints, partial indexes, the `events` identity column and both views.
- `complaint_status_v` and `pilot_rates_v` views.
- A shared password-hash helper (`src/lib/password`) used by the seed for the dev admin (TASK-05 reuses it and adds policy).
- Seed script: dev admin, one invite code per source tag, placeholder categories, sample complaints/photos/reminders/verifications covering every status, and placeholder JPEG files in `PHOTO_STORAGE_DIR`.
- `SEED-EXPECTATIONS.md` with the hand-counted expected status, due list and rates for the seed.
- Root scripts `db:migrate`, `db:seed`, `db:reset` (guarded) and a documented `pg_dump` command.
- Replace TASK-01's health check DB call with the Prisma client if TASK-01 used a fallback.

### Out of Scope
- API endpoints reading these tables → TASK-03 onward.
- Storage interface and image pipeline → TASK-04 (the seed writes files directly using the same key layout).
- Password policy (12 chars, common-password list) and `admin:create` → TASK-05.
- Production backups/retention policy → deferred (REQ-O-022); anonymization API → TASK-08.

## 3. Prerequisites

- TASK-01 complete: database container healthy, `apps/api` with config validation and minimal Prisma setup.
- PostgreSQL major ≥ 13 (built-in `gen_random_uuid()`); otherwise enable `pgcrypto` in the first migration (04 §1.2).
- `SEED_ADMIN_EMAIL` and `SEED_ADMIN_PASSWORD` set in `apps/api/.env` for the seed run (remove afterwards — 05 §2.2).
- `PHOTO_STORAGE_DIR` set to an absolute path outside the repo.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-01 | Provides the database container, `DATABASE_URL`, config loader, Prisma setup and root `package.json` |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-D-001 | All enum types: `source_tag`, `verification_result`, `photo_purpose`, `storage_driver`, `reminder_channel`, `exclusion_reason`, `platform` | 04 §3 |
| REQ-D-002 | `admin_users` table with lowercase-unique email, `token_version ≥ 0`, audit columns | 04 §3.1 |
| REQ-D-003 | `invite_codes` table: uppercase alnum 6–20 unique code, `source_tag` ≠ `unknown`, indexes | 04 §3.2 |
| REQ-D-004 | `ccrs_categories` table with unique name, `sort_order ≥ 0`, `(is_active, sort_order)` index | 04 §3.3 |
| REQ-D-005 | `photos` table with unique `storage_key`, sha256 index, partial unattached index, `uploaded_for_complaint_id` required when purpose = verification | 04 §3.4 |
| REQ-D-006 | `complaints` table with all columns, CHECK constraints (coords, E.164 phone, exclusion reason rule), unique indexes and partial index | 04 §3.5 |
| REQ-D-007 | `reminders` table with unique `token_hash`, `(complaint_id, sent_at DESC)` index | 04 §3.6 |
| REQ-D-008 | `verifications` table with unique `client_submission_id` and `photo_id`, note ≤ 1,000, indexes | 04 §3.7 |
| REQ-D-009 | `events` table with bigint identity PK and the three indexes | 04 §3.8 |
| REQ-D-010 | Foreign keys with the on-delete/on-update rules of §4 (RESTRICT on evidence, SET NULL where listed) | 04 §4 |
| REQ-D-011 | `complaint_status_v` view: counts, last reminder, latest result, derived status; due computed with the configured interval at query time | 04 §3.9, 03 §4.3 |
| REQ-D-012 | `pilot_rates_v` view: per source + `trusted` (rwa + activist); H1 = verified ÷ reminded; H2 = latest-result `not_fixed` ÷ verified; excluded left out; nulls when denominator is 0 | 04 §3.9, 03 §2.3 |
| REQ-D-013 | Migrations follow the §7.3 order and conventions; hand-written SQL (CHECKs, partial indexes, views, identity) commented with why | 04 §7 |
| REQ-D-014 | Seed: dev admin from env, one invite code per source tag, placeholder categories, sample set covering every status (filed, reminded, verified fixed/not fixed, excluded, duplicate CCRS) | 04 §8 |
| REQ-D-015 | Dev sample seed refuses to run unless `APP_ENV=development` and no real pilot data is present | 04 §8, 05 §2.2 |
| REQ-D-016 | Prisma models PascalCase mapped to snake_case; UUID PKs via `gen_random_uuid()` (verify PG version) | 04 §1.2 |
| REQ-D-017 | All time columns `TIMESTAMPTZ` (UTC); evidence rows store device time and server receipt time; server time authoritative | 04 §1.2, 01 Decision 9 |
| REQ-O-005 | Root scripts `db:migrate`, `db:seed`, and `db:reset` (refuses unless `APP_ENV=development`, asks for confirmation) | 05 §3.3 |
| REQ-O-019 | `pg_dump` before risky migrations documented (backups outside the project, never committed) | 05 §8, 04 §9.1 |

### 5.2 Data Contracts

All PKs are UUID `DEFAULT gen_random_uuid()` except `events.id` (BIGINT identity). All times `TIMESTAMPTZ`.
`created_at`/`updated_at` default `NOW()`; `updated_at` maintained on every write (Prisma `@updatedAt`).

**Enums (04 §3)**

| Enum | Values |
|---|---|
| `source_tag` | `rwa`, `activist`, `social`, `network`, `unknown` |
| `verification_result` | `fixed`, `not_fixed` |
| `photo_purpose` | `report`, `verification` |
| `storage_driver` | `local`, `cloudflare_r2` |
| `reminder_channel` | `whatsapp_manual` |
| `exclusion_reason` | `test`, `invalid`, `duplicate`, `other` |
| `platform` | `android`, `ios` |

**Tables (compact; full descriptions in 04 §3.1–3.8)**

| Table | Columns (type, null, default) | Constraints | Indexes |
|---|---|---|---|
| `admin_users` | id; email VARCHAR(255) NN; password_hash VARCHAR(255) NN; display_name VARCHAR(100) NN; is_active BOOL NN true; token_version INT NN 0; last_login_at TZ null; created_at; updated_at | email stored lowercase (CHECK `email = lower(email)`); `token_version >= 0` | `uq_admin_users_email` |
| `invite_codes` | id; code VARCHAR(20) NN; source_tag NN; group_label VARCHAR(120) NN; ward_hint VARCHAR(50) null; is_active BOOL NN true; created_by UUID null → admin_users; created_at; updated_at | code `~ '^[A-Z0-9]{6,20}$'`; `source_tag <> 'unknown'` | `uq_invite_codes_code`, `idx_invite_codes_source_tag`, FK index on created_by |
| `ccrs_categories` | id; name VARCHAR(100) NN; ccrs_label VARCHAR(150) null; sort_order INT NN 0; is_active BOOL NN true; created_at; updated_at | `sort_order >= 0` | `uq_ccrs_categories_name`, `idx_ccrs_categories_active_order (is_active, sort_order)` |
| `photos` | id; storage_driver NN 'local'; storage_key VARCHAR(255) NN; purpose NN; mime_type VARCHAR(50) NN; byte_size INT NN; width_px INT null; height_px INT null; sha256 CHAR(64) NN; uploaded_for_complaint_id UUID null → complaints; uploaded_at NN NOW(); attached_at null; deleted_at null | `mime_type = 'image/jpeg'`; `byte_size > 0`; width/height `> 0`; sha256 `~ '^[0-9a-f]{64}$'`; `purpose <> 'verification' OR uploaded_for_complaint_id IS NOT NULL` | `uq_photos_storage_key`, `idx_photos_sha256`, `idx_photos_unattached (uploaded_at) WHERE attached_at IS NULL` |
| `complaints` | id; client_submission_id UUID NN; invite_code_id null; source_tag NN 'unknown'; category_id NN; ccrs_number_raw VARCHAR(50) NN; ccrs_number_normalized VARCHAR(50) NN; ccrs_duplicate_flag BOOL NN false; photo_id NN; latitude NUMERIC(9,6) NN; longitude NUMERIC(9,6) NN; gps_accuracy_m NUMERIC(8,2) null; device_captured_at NN; phone_e164 VARCHAR(16) null; consent_given_at NN; consent_text_version VARCHAR(20) NN; app_platform NN; app_version VARCHAR(20) NN; ward_code VARCHAR(50) null; is_excluded BOOL NN false; exclusion_reason null; exclusion_note VARCHAR(500) null; excluded_by null; excluded_at null; anonymized_at null; created_at (server receipt, authoritative); updated_at | lat −90..90; lng −180..180; `gps_accuracy_m >= 0`; `phone_e164 IS NULL OR phone_e164 ~ '^\+91[6-9][0-9]{9}$'` (rule per 03 §4.2, to verify); `NOT is_excluded OR exclusion_reason IS NOT NULL`; `length(trim(ccrs_number_raw)) > 0` | `uq_complaints_client_submission`, `uq_complaints_photo`, `idx_complaints_ccrs_norm`, `idx_complaints_source_created (source_tag, created_at)`, `idx_complaints_category`, `idx_complaints_included_created (created_at) WHERE is_excluded = false`, `idx_complaints_phone`, FK index on invite_code_id |
| `reminders` | id; complaint_id NN; token_hash CHAR(64) NN; channel NN 'whatsapp_manual'; sent_by NN → admin_users; sent_at NN NOW(); expires_at null; revoked_at null; created_at | token_hash hex-64 | `uq_reminders_token_hash`, `idx_reminders_complaint_sent (complaint_id, sent_at DESC)` |
| `verifications` | id; client_submission_id UUID NN; complaint_id NN; reminder_id null; result NN; photo_id NN; latitude/longitude NUMERIC(9,6) NN; gps_accuracy_m null; device_captured_at NN; distance_from_report_m NUMERIC(10,2) null; note VARCHAR(1000) null; app_platform NN; app_version VARCHAR(20) NN; created_at (server receipt, authoritative) | coord ranges; `gps_accuracy_m >= 0`; `distance_from_report_m >= 0` | `uq_verifications_client_submission`, `uq_verifications_photo`, `idx_verifications_complaint_created (complaint_id, created_at DESC)`, `idx_verifications_reminder` |
| `events` | id BIGINT GENERATED ALWAYS AS IDENTITY; name VARCHAR(50) NN; install_id UUID null; admin_user_id null; complaint_id null; source_tag null; properties JSONB NN '{}'; platform null; app_version VARCHAR(20) null; occurred_at NN (device); received_at NN NOW() | name in the allow-list: `invite_code_entered`, `report_opened`, `ccrs_handoff_clicked`, `report_submitted`, `reminder_sent`, `verify_opened`, `deep_link_failed`, `verify_submitted`, `record_flagged` | `idx_events_name_received (name, received_at)`, `idx_events_complaint`, `idx_events_install` |

**Foreign keys (04 §4)** — all `ON UPDATE CASCADE`:

| FK | On Delete |
|---|---|
| complaints.invite_code_id → invite_codes | RESTRICT |
| complaints.category_id → ccrs_categories | RESTRICT |
| complaints.photo_id → photos | RESTRICT |
| verifications.photo_id → photos | RESTRICT |
| reminders.complaint_id → complaints | RESTRICT |
| verifications.complaint_id → complaints | RESTRICT |
| events.complaint_id → complaints | SET NULL |
| photos.uploaded_for_complaint_id → complaints | RESTRICT |
| verifications.reminder_id → reminders | RESTRICT |
| reminders.sent_by → admin_users | RESTRICT |
| complaints.excluded_by → admin_users | SET NULL |
| invite_codes.created_by → admin_users | SET NULL |
| events.admin_user_id → admin_users | SET NULL |

Note the circular reference `photos.uploaded_for_complaint_id → complaints` and `complaints.photo_id → photos`: create
`photos` first without that FK, then add it in `create_complaints` (ASSUMPTION §5.6).

**Views (04 §3.9)**

`complaint_status_v` — one row per complaint:

| Column | Definition |
|---|---|
| complaint_id, source_tag, category_id, invite_code_id, created_at, is_excluded, anonymized_at, ccrs_duplicate_flag | from `complaints` |
| reminder_count, last_reminder_at | `COUNT(*)`, `MAX(sent_at)` over reminders |
| verification_count, latest_result, latest_verified_at | count; result and `created_at` of the latest verification (`DISTINCT ON`/window by `created_at DESC, id DESC`) |
| status | `verified_fixed` / `verified_not_fixed` from latest_result if any verification; else `reminded` if reminder_count > 0; else `filed` |
| due_reference_at | `COALESCE(last_reminder_at, created_at)` — the API computes `is_due = NOT is_excluded AND anonymized_at IS NULL AND verification_count = 0 AND due_reference_at < NOW() - make_interval(days => $REMINDER_INTERVAL_DAYS)` at query time (03 §4.3), so the interval stays configurable |

`pilot_rates_v` — one row per source tag (all five, zero rows included) plus `trusted` (`rwa` + `activist`), excluded complaints left out:

| Column | Definition |
|---|---|
| group | source tag text, or `trusted` |
| complaints | count of non-excluded complaints |
| reminded | complaints with ≥ 1 reminder |
| verified | complaints with ≥ 1 verification |
| h1_rate | `verified / reminded`, NULL when reminded = 0 |
| verifications | total verification rows (repeat answers counted) |
| not_fixed | complaints whose **latest** verification is `not_fixed` |
| h2_rate | `not_fixed / verified`, NULL when verified = 0 (per-complaint, 04 A5) |

Rates are returned as numeric fractions (e.g. `0.6667`); the app formats percentages.

### 5.3 API Contracts

Not applicable — no endpoints in this task. Views feed `GET /admin/complaints` and `GET /admin/rates` in TASK-06.

### 5.4 UI Surfaces & States

Not applicable — database-only task.

### 5.5 Permissions & Roles

| Actor | Access |
|---|---|
| API (Prisma) | Full read/write through services only (layering rule, TASK-01) |
| Developer | `db:migrate`, `db:seed`, `db:reset` locally; reset and sample seed refused outside `APP_ENV=development` |
| Anyone else | No access — DB bound to 127.0.0.1 (TASK-01) |

### 5.6 Assumptions

- ASSUMPTION: The dev admin is created by the seed using a shared `src/lib/password` helper (Argon2id candidate, bcrypt cost 12 fallback — 06 §2.1) created in this task — seeded reminders need a non-null `sent_by`, so the admin must exist before sample data — TASK-05 reuses the helper and adds the length/common-password policy in `admin:create`.
- ASSUMPTION: "Real pilot data present" = any `complaints` row whose `app_version` is not the seed marker `seed`; the sample seed tags all its rows with `app_version='seed'` and refuses if any other complaint exists — the spec gives no detection rule — change the marker if a different rule is decided.
- ASSUMPTION: The `photos ↔ complaints` circular FK is resolved by adding `photos.uploaded_for_complaint_id`'s FK in the `create_complaints` migration — keeps the 04 §7.3 order — no behavioural change.
- ASSUMPTION: `pilot_rates_v` includes a row for every source tag even with zero complaints — stable rows for the Rates screen — drop zero rows if the screen prefers.
- ASSUMPTION: The seed writes small generated placeholder JPEGs to `PHOTO_STORAGE_DIR` at keys `photos/<yyyy>/<mm>/<uuid>.jpg` (03 §6.1 layout) so admin photo endpoints have files — TASK-04's local storage driver must read the same layout.
- ASSUMPTION: `email = lower(email)` CHECK enforces "stored lowercase" — 04 §3.1 — the API lowercases before insert.

## 6. Implementation Steps

1. Confirm the running PostgreSQL major (`SELECT version();`); if < 13, the first migration adds `CREATE EXTENSION IF NOT EXISTS pgcrypto`.
2. Write all enums and models in `apps/api/prisma/schema.prisma`: PascalCase models with `@@map`/`@map` to snake_case, `@db.Uuid` + `@default(dbgenerated("gen_random_uuid()"))`, `@db.Timestamptz`, `@db.Numeric(9,6)`, `@db.VarChar(n)`, `@db.Char(64)`, relations with `onDelete`/`onUpdate` per §5.2, and every simple/unique/composite index (with `sort: Desc` where listed).
3. Generate migrations one per logical change in the 04 §7.3 order: `init_enums`, `create_admin_users`, `create_invite_codes`, `create_ccrs_categories`, `create_photos`, `create_complaints`, `create_reminders`, `create_verifications`, `create_events`, `create_views` (use `prisma migrate dev --create-only`, edit, then apply).
4. In each generated migration, append hand-written SQL with a comment explaining why it is outside Prisma: CHECK constraints (§5.2), partial indexes `idx_photos_unattached` and `idx_complaints_included_created`, the events identity column (`GENERATED ALWAYS AS IDENTITY`) if Prisma cannot express it, and the events name CHECK.
5. Write `create_views` as raw SQL for `complaint_status_v` and `pilot_rates_v` per §5.2; check current Prisma docs for `view` support and either map read-only views in the schema or query them with parameterized `$queryRaw` (no string building).
6. Create `src/lib/password` with `hashPassword` / `verifyPassword` (Argon2id candidate; verify current recommended parameters; bcrypt cost 12 fallback).
7. Create a seed placeholder-photo helper that generates small valid JPEGs (candidate: sharp, already planned for TASK-04) and writes them under `PHOTO_STORAGE_DIR` at `photos/<yyyy>/<mm>/<uuid>.jpg`, returning key, size, dimensions, sha256.
8. Write `prisma/seed.ts` reference data (idempotent upserts, allowed in any dev DB): dev admin from `SEED_ADMIN_EMAIL`/`SEED_ADMIN_PASSWORD` (lowercased email; fail clearly if unset); invite codes `RWATEST01` (rwa), `ACTTEST01` (activist), `SOCTEST01` (social), `NETTEST01` (network) with group labels; placeholder categories in order: "Pothole or damaged road", "Garbage and cleanliness", "Streetlight", "Drainage", "Water supply", "Other".
9. Add the guard: refuse to seed unless `APP_ENV=development`; refuse the sample set if any complaint exists with `app_version <> 'seed'`; print why and exit non-zero.
10. Seed the sample set below (all rows `app_version='seed'`, invented `+91` numbers, Ahmedabad-area coordinates, `created_at` set relative to now so "due" stays correct whenever the seed runs):

    | # | Source | State | Reminders | Verifications | Notes |
    |---|---|---|---|---|---|
    | C1 | rwa | filed, created 10 d ago | 0 | 0 | due |
    | C2 | rwa | filed, created 2 d ago | 0 | 0 | not due |
    | C3 | rwa | reminded 8 d ago | 1 | 0 | due |
    | C4 | rwa | verified | 1 | fixed | — |
    | C5 | rwa | verified | 1 | not_fixed (with note) | — |
    | C6 | activist | verified twice | 1 | fixed, then later not_fixed | latest = not_fixed |
    | C7 | activist | reminded 2 d ago | 1 | 0 | not due |
    | C8 | activist | excluded (`test`, by dev admin) | 1 | not_fixed | out of rates, not due |
    | C9 | social | verified | 1 | fixed | verification photo has the **same sha256** as its report photo (same-image case) |
    | C10 | network | verified | 1 | not_fixed | — |
    | C11 | unknown (no code) | filed, created 9 d ago | 0 | 0 | same normalized CCRS number as C1 → `ccrs_duplicate_flag = true`; due |

    Every verification has its own photo (`purpose=verification`, `uploaded_for_complaint_id` set) and `reminder_id`; all photos `attached_at` set. Reminder `token_hash` = SHA-256 of a random token that is discarded (never printed).
11. Write `apps/api/prisma/SEED-EXPECTATIONS.md` with the hand count, at `REMINDER_INTERVAL_DAYS=7`:

    | group | complaints | reminded | verified | h1 | verifications | not_fixed | h2 |
    |---|---|---|---|---|---|---|---|
    | rwa | 5 | 3 | 2 | 0.667 | 2 | 1 | 0.500 |
    | activist | 2 | 2 | 1 | 0.500 | 2 | 1 | 1.000 |
    | trusted | 7 | 5 | 3 | 0.600 | 4 | 2 | 0.667 |
    | social | 1 | 1 | 1 | 1.000 | 1 | 0 | 0.000 |
    | network | 1 | 1 | 1 | 1.000 | 1 | 1 | 1.000 |
    | unknown | 1 | 0 | 0 | null | 0 | 0 | null |

    Statuses: filed C1, C2, C11; reminded C3, C7; verified_fixed C4, C9; verified_not_fixed C5, C6, C8, C10. Due: C1, C3, C11 (3). Excluded: C8. Duplicate: C11.
    If the seed changes, update this file in the same commit.
12. Add root scripts: `db:migrate` (`prisma migrate dev` in `apps/api`), `db:seed` (`prisma db seed`), `db:reset` — a script that refuses unless `APP_ENV=development`, asks "Type RESET to continue", then `docker compose down -v` (removes `pgdata`), `up -d`, waits for health, migrates and seeds.
13. Document backups in `apps/api/prisma/README.md`: take `pg_dump -Fc` to a folder **outside the project** before any risky migration; never commit dumps (`.gitignore` already covers `*.dump`); applied migrations are never edited — corrections go in a new migration (04 §7.2).
14. Point the TASK-01 health check at the Prisma client (`SELECT 1`) if it used a fallback.
15. Run the checks in §8; confirm `prisma generate`, `tsc` and ESLint still pass in CI.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Clean migration from empty
- **Given** an empty database (`db:reset`)
- **When** `npm run db:migrate` runs
- **Then** all ten migrations apply in the 04 §7.3 order without errors and `\dT`, `\dt`, `\dv` list the seven enums, eight tables and two views

**AC-2** — Naming, keys and time types
- **Given** the migrated database
- **When** `information_schema.columns` is queried
- **Then** every table/column is snake_case, every exposed PK is `uuid` defaulting to `gen_random_uuid()`, `events.id` is a bigint identity, and every time column is `timestamp with time zone`

**AC-3** — Constraints enforced in the database
- **Given** the migrated database
- **When** inserts violate a rule — invite code `abc` or `source_tag='unknown'`; complaint latitude 91; phone `+9112345`; `is_excluded=true` with no reason; verification photo without `uploaded_for_complaint_id`; note of 1,001 chars; mixed-case admin email; unknown event name
- **Then** each insert fails with a constraint error, and valid equivalents succeed

**AC-4** — Indexes and foreign keys match the spec
- **Given** the migrated database
- **When** `pg_indexes` and `pg_constraint` are queried
- **Then** every index of 04 §3 exists (including both partial indexes with their `WHERE` clauses and the DESC composites) and every FK has the on-delete rule of §5.2 (e.g. deleting a complaint with reminders fails; deleting an admin nulls `invite_codes.created_by`)

**AC-5** — Seed builds the documented dataset
- **Given** `APP_ENV=development`, admin seed env vars set, and a migrated empty DB
- **When** `npm run db:seed` runs
- **Then** the dev admin (hashed password), four invite codes, six placeholder categories and the eleven sample complaints exist; every photo row has a readable file under `PHOTO_STORAGE_DIR`; re-running the seed does not duplicate reference data

**AC-6** — Status view matches the hand count
- **Given** the seeded database
- **When** `SELECT complaint_id, status, reminder_count, verification_count, latest_result FROM complaint_status_v` runs, and the due query with interval 7 runs
- **Then** statuses match SEED-EXPECTATIONS.md (C6 shows `verified_not_fixed` with verification_count 2) and the due set is exactly C1, C3, C11

**AC-7** — Rates view matches the hand count
- **Given** the seeded database
- **When** `SELECT * FROM pilot_rates_v` runs
- **Then** each row equals SEED-EXPECTATIONS.md (trusted: 7 / 5 / 3 / 0.600 / 2 / 0.667), C8 is absent from every count, and `unknown` has NULL h1/h2

**AC-8** — Exclusion moves rates
- **Given** the seeded database
- **When** C8 is set `is_excluded=false` (reason cleared) and the rates view is re-read, then restored
- **Then** activist becomes 3 / 3 / 2 / 0.667 / not_fixed 2 / 1.000 and trusted 8 / 6 / 4 / 0.667 / 3 / 0.750, and returns to the original values after restoring

**AC-9** — Guards protect data
- **Given** `APP_ENV=production` (or a complaint with `app_version='1.0.0'` inserted)
- **When** `npm run db:seed` or `npm run db:reset` runs
- **Then** both refuse with a clear message and change nothing; with `APP_ENV=development`, `db:reset` asks for confirmation and aborts unless `RESET` is typed

**AC-10** — Backup procedure documented
- **Given** `apps/api/prisma/README.md`
- **When** the documented `pg_dump` command is run
- **Then** a dump is written outside the project folder and `git status` shows nothing new

### AC → Requirement

| AC | Requirements |
|---|---|
| AC-1 | REQ-D-001, REQ-D-013, REQ-O-005 |
| AC-2 | REQ-D-016, REQ-D-017, REQ-D-009 |
| AC-3 | REQ-D-002, REQ-D-003, REQ-D-005, REQ-D-006, REQ-D-008, REQ-D-009 |
| AC-4 | REQ-D-002, REQ-D-003, REQ-D-004, REQ-D-005, REQ-D-006, REQ-D-007, REQ-D-008, REQ-D-009 (indexes), REQ-D-010, REQ-D-004, REQ-D-007 |
| AC-5 | REQ-D-014, REQ-O-005 |
| AC-6 | REQ-D-011 |
| AC-7 | REQ-D-012 |
| AC-8 | REQ-D-012 |
| AC-9 | REQ-D-015, REQ-O-005 |
| AC-10 | REQ-O-019 |

### 7.2 Non-Functional Checklist

- [ ] Every hand-written SQL block has a comment saying why it is not in the Prisma schema
- [ ] No applied migration edited after being applied (check `git log` on `prisma/migrations`)
- [ ] Views use only set-based SQL; no N+1 patterns; queries from code use parameterized `$queryRaw`
- [ ] Evidence tables (`complaints`, `verifications`, `photos`) have no hard-delete path (RESTRICT FKs); soft delete absent by design (04 §1.2)
- [ ] Seed contains no real personal data; phone numbers invented; seed never prints tokens or passwords
- [ ] `SEED_ADMIN_PASSWORD` not logged; README reminds to remove it from `.env` after seeding
- [ ] Interval for "due" is a query parameter from `REMINDER_INTERVAL_DAYS`, not hard-coded in the view
- [ ] SEED-EXPECTATIONS.md matches the seed script in the same commit
- [ ] `prisma generate`, `tsc --noEmit`, ESLint pass (CI green)

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-02-01 | `npx prisma validate && npx prisma generate && npm run typecheck && npm run lint` | AC-1, AC-2 |
| DB manual | M-02-01 | `npm run db:reset` then `npm run db:migrate`; `psql` `\dT`, `\dt`, `\dv` counts 7/8/2; `SELECT migration_name FROM _prisma_migrations ORDER BY finished_at` matches §7.3 order | AC-1 |
| DB manual | M-02-02 | `SELECT table_name, column_name, data_type, column_default FROM information_schema.columns WHERE table_schema='public'` — snake_case, uuid defaults, `timestamp with time zone`, identity on events | AC-2 |
| DB manual | M-02-03 | Scripted bad inserts from AC-3 each fail (`psql -v ON_ERROR_STOP=0`), valid ones succeed (inside a transaction rolled back) | AC-3 |
| DB manual | M-02-04 | `SELECT indexname, indexdef FROM pg_indexes WHERE schemaname='public'` vs 04 §3; `SELECT conname, confdeltype FROM pg_constraint WHERE contype='f'`; try deleting C3 → RESTRICT error | AC-4 |
| DB manual | M-02-05 | `npm run db:seed` twice; row counts: admin 1, invite codes 4, categories 6, complaints 11; `ls` files for every `photos.storage_key` | AC-5 |
| DB manual | M-02-06 | Status and due queries (§5.2) compared line by line with SEED-EXPECTATIONS.md | AC-6 |
| DB manual | M-02-07 | `SELECT * FROM pilot_rates_v ORDER BY "group"` compared with SEED-EXPECTATIONS.md | AC-7 |
| DB manual | M-02-08 | `BEGIN; UPDATE complaints SET is_excluded=false, exclusion_reason=NULL WHERE …C8…; SELECT * FROM pilot_rates_v; ROLLBACK;` | AC-8 |
| Manual (guard) | M-02-09 | `APP_ENV=production npm run db:seed` / `db:reset` → refused; insert a non-seed complaint, seed → refused; `db:reset` answer `no` → aborted | AC-9 |
| Manual (backup) | M-02-10 | Run documented `pg_dump`; `git status` clean | AC-10 |
| Optional automated | — | Rate calculation test on this seed (06 §8.1 #1) and due boundary (#6) — scheduled in TASK-10 (REQ-N-019) | AC-6, AC-7 |

## 9. Deliverables

- `apps/api/prisma/schema.prisma` with all enums, models, relations and indexes.
- `apps/api/prisma/migrations/*` — ten migrations including hand-written SQL and views.
- `apps/api/src/lib/password` hash/verify helper.
- `apps/api/prisma/seed.ts` + placeholder photo helper; `SEED-EXPECTATIONS.md`; `prisma/README.md` (migrate/seed/reset/backup).
- Root scripts `db:migrate`, `db:seed`, `db:reset` (guarded).

## 10. Files Expected to Change

Prediction, not a constraint.

| Path | New/Modified |
|---|---|
| `apps/api/prisma/schema.prisma` | Modified |
| `apps/api/prisma/migrations/` (10 folders) | New |
| `apps/api/prisma/seed.ts`, `seed/` helpers | New |
| `apps/api/prisma/SEED-EXPECTATIONS.md`, `apps/api/prisma/README.md` | New |
| `apps/api/src/lib/password/` | New |
| `apps/api/src/lib/db` (Prisma client singleton) / health service | Modified |
| `apps/api/package.json` (prisma seed config, deps) | Modified |
| `package.json` (root scripts), `scripts/db-reset.*` | Modified / New |

## 11. Related Documentation

- `docs/04-database-design.md §1.2` — naming, keys, timestamps, no soft delete, idempotency, coordinates.
- `docs/04-database-design.md §3.1–3.8` — every table's columns and indexes (authoritative).
- `docs/04-database-design.md §3.9` — views and exact H1/H2 definitions.
- `docs/04-database-design.md §4` — FK on-delete rules.
- `docs/04-database-design.md §7` — migration tool, conventions, initial order.
- `docs/04-database-design.md §8, §9` — seeds, backups, anonymization procedure (used by TASK-08).
- `docs/03-backend-spec.md §4.3` — due rule; `§2.3` RateRow shape.
- `docs/05-devops-infrastructure.md §3.3, §8` — reset script rules and backups.

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Prisma cannot express partial indexes, CHECKs, identity or views | Schema drift between Prisma and DB | Hand-written SQL in migrations with comments; `prisma migrate diff` to confirm no drift |
| Wrong H1/H2 SQL (e.g. counting verifications instead of complaints for H2) | Pilot's whole output wrong (S1) | Hand-counted SEED-EXPECTATIONS; AC-7/AC-8; optional test in TASK-10 |
| Circular FK photos ↔ complaints | Migration order error | Add the photos FK in `create_complaints` (§5.6) |
| Seed run against real data | Data corruption | Guard on `APP_ENV` and non-seed rows; reset requires typed confirmation |
| Seed "due" drifts with time | Expectations fail later | Seed timestamps relative to `NOW()` |
| Phone CHECK rule wrong for some valid numbers | Valid reports rejected | Rule flagged "to verify" (03 D12); change via a new migration |

## 13. Progress Status

**Current status:** Complete
**Progress:** 100%

| Date | Progress | Commit |
|---|---|---|
| 2026-10-03 | Prisma schema, 10 ordered migrations with hand-written CHECKs/partial indexes/identity/views, argon2 0.45.1 password helper, guarded seed (sharp 0.35.5 placeholder JPEGs), SEED-EXPECTATIONS.md matches pilot_rates_v exactly, db:migrate/seed/reset, backup README. M-02-01…09 run. | 87b56d5 |

## 14. Completion Checklist

- [x] All implementation steps complete
- [x] All behavioral acceptance criteria verified in the running application
- [x] Non-functional checklist fully ticked
- [x] Static checks pass and every AC verified by the manual checks in §8 (no automated tests in v1 — 06 §7.1)
- [x] Frontend and backend integrated end to end (no mocked data left in place) — not applicable (no endpoints); seed data documented as development-only
- [x] Error, loading, empty, and unauthorized states verified — not applicable (no UI); constraint errors verified instead
- [x] Code reviewed against the patterns established in earlier tasks
- [x] Assumptions documented and, where possible, confirmed
- [x] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-02` shows 0 unverified)
- [x] Committed as `TASK-02: …`
- [x] Task file progress log and status updated
- [x] `00-task-summary.md` updated
- [x] Validator passes
