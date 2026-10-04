# Database: migrate, seed, reset, backup

- `npm run db:migrate` — apply migrations (`prisma migrate dev`). Applied migrations are **never edited**; corrections go in a new migration (04 §7.2).
- `npm run db:seed` — reference data (idempotent) + dev sample set. Refuses unless `APP_ENV=development` and no non-seed complaints exist. Remove `SEED_ADMIN_PASSWORD` from `.env` after seeding outside the demo machine.
- `npm run db:reset` — refuses unless `APP_ENV=development`, asks you to type `RESET`, then drops the volume, recreates, migrates and seeds.
- Hand-written SQL (CHECKs, partial indexes, events identity, views) is in the migration files, each block commented with why.

## Backups before risky migrations (05 §8, 04 §9.1)

Write dumps **outside the project**; never commit them (`*.dump` is git-ignored):

```bash
mkdir -p ~/saarthee-backups
docker compose -f infra/docker-compose.yml --env-file infra/.env exec -T db \
  pg_dump -U saarthee -d saarthee -Fc > ~/saarthee-backups/saarthee-$(date +%Y%m%d-%H%M).dump
```

Restore: `docker compose ... exec -T db pg_restore -U saarthee -d saarthee --clean < <file>.dump`.

## v2: PostGIS, migration rules, legacy guard (V2 TASK-01)

- **PostGIS.** Local dev runs a native arm64 image built from `infra/postgis/Dockerfile` (postgres:17.6 + PGDG PostGIS 3.6); CI uses `postgis/postgis:17-3.5` (amd64). Migration `20261004000000_enable_postgis` runs `CREATE EXTENSION IF NOT EXISTS postgis`. Upgrade an existing v1 volume with `npm run db:upgrade-postgis` (dump to `~/saarthee-backups/`, switch, compare row counts; prints the `pg_restore` path if counts differ).
- **Additive only.** The 10 v1 migrations are frozen: `npm run db:check-v1` checks them against `migrations/V1_CHECKSUMS.sha256`. New work = new migration with a unique timestamp, created with `prisma migrate dev --create-only`, SQL hand-written (CHECKs, partial indexes, triggers, GIST).
- **Drift gate.** `npm run db:drift` (needs `SHADOW_DATABASE_URL`, an empty disposable DB) fails if `schema.prisma` and the migrations differ. Geography columns are `Unsupported("geography(Point, 4326)")?` in Prisma, filled by triggers in SQL; `extensions = [postgis]` in `schema.prisma` keeps PostGIS objects (`spatial_ref_sys`) out of the diff.
- **Legacy guard.** v1 tables `complaints`, `reminders`, `verifications`, `invite_codes`, `ccrs_categories` reject writes with `LEGACY_READ_ONLY` unless the transaction ran `withLegacyWrite()` (`src/lib/db`), which sets `saarthee.legacy_write=on` locally. Only the legacy import, v1 anonymize and seeds use it. `issue_events` is append-only through the same bypass.
- **Legacy import.** `npm run legacy:migrate` copies every v1 complaint into `issues` (hidden, no reporter, no phone), idempotently (`complaints=N imported=N skipped=N`). Photos of anonymized complaints or deleted photos are never linked; anonymizing later unlinks them from the issue and its events.
- **Seed (v2).** `prisma/seed/index.ts` runs ordered modules in `prisma/seed/modules/`; each declares `requires` (tables) and is skipped with a log line when one is missing. Expected counts: `SEED-EXPECTATIONS.md`.
