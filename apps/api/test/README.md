# API tests (Vitest + Supertest)

Integration tests run the real Express app (`createApp()`, in-process via Supertest — no port is opened)
against a real PostGIS database. No mocks for the database.

## Setup (once)

```bash
cd apps/api
cp .env.test.example .env.test   # point DATABASE_URL / SHADOW_DATABASE_URL at your own *_test / *_shadow DBs
npm run test:db:create           # creates both databases in the compose container if absent
npm test                         # or from the repo root: npm run api:test
```

Parallel worktrees: give each its own names, e.g. `saarthee_test_task05` and `saarthee_shadow_task05`.

## How a run works

1. **Guard** (`test/env.ts`, before anything connects): the database name must end in `_test` or `_test_<suffix>`.
   Pointing `.env.test` at `saarthee` aborts the run before any query (tested in `platform/test-db-guard.test.ts`).
2. **Global setup** (`test/global-setup.ts`, once per run): drops and recreates the `public` schema of the
   template database named in `.env.test`, then `prisma migrate deploy` (no seed). Each attempt is capped at
   90 s and retried up to 3 times (it stalled now and then on the dev machine).
3. **Per file** (`test/setup.ts`): each test file gets its own copy `<template>_w<poolId>` created with
   `CREATE DATABASE … TEMPLATE … STRATEGY FILE_COPY`, so files never see each other's rows.
4. **Per test**: call `resetDb()` (`helpers/db.ts`) in `beforeEach` where a test needs empty tables — it
   truncates every table except `_prisma_migrations` and `spatial_ref_sys`.
5. **Teardown** drops the per-worker copies (`TEST_KEEP_DBS=1` keeps them for debugging).

Files run one after another by default (`TEST_PARALLEL=1` tries parallel files).

## Helpers

| File | Purpose |
|---|---|
| `helpers/app.ts` | `api()` — Supertest agent on `createApp()` |
| `helpers/db.ts` | `resetDb()` |
| `helpers/factories.ts` | `makeUser`, `makeCategory`, `makeIssue`, `makePhoto`, v1 `makeCcrsCategory` / `makeComplaint` (through `withLegacyWrite`) |
| `helpers/auth.ts` | `createAdmin()` → v1 admin and its `Authorization` header |

`resetRateLimitStores()` (from `src/middleware/rateLimit.ts`) clears in-memory rate-limit counters between tests.

## Layout

- `test/platform/` — TASK-01 suites (migrations, constraints, legacy import, guard, permissions, admin auth,
  rate limits, health, seed, geo helpers, test-db guard).
- `test/geo/` — TASK-02 suites (import, crosscheck, locate, wards/zones, search, backfill, wards seed); `test/fixtures/geo/`
  holds the 3-ward fixture and the ward-search case table shared with the app (`ward-search-cases.json`).
- `test/<module>/` — one directory per later task's module.

## Opt-in checks

```bash
LEGACY_PERF=1 npx vitest run test/platform/legacy-perf.test.ts   # 10,000 complaints through legacy:migrate < 60 s
GEO_PERF=1 npx vitest run test/geo/geo-perf.test.ts               # /geo/locate p95 < 50 ms, GIST index used
```

## CI

`.github/workflows/ci.yml` (job `api`) starts `postgis/postgis:17-3.5` as a service, copies `.env.test.example`,
runs the v1 checksum gate, typecheck, lint, the drift gate and `npm test`, and uploads `test-results/junit.xml`.
