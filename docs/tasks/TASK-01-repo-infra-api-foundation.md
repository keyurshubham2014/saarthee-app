# TASK-01: Repository, Local Infrastructure & API Foundation

| Field | Value |
|---|---|
| Task ID | TASK-01 |
| Status | In Review |
| Priority | P0 |
| Size | M |
| Depends On | None |
| Blocks | TASK-02, TASK-03 |
| Requirement IDs | REQ-N-016, REQ-N-023, REQ-S-013, REQ-S-015, REQ-S-016, REQ-S-018, REQ-S-019, REQ-S-020, REQ-S-021, REQ-S-030, REQ-S-032, REQ-O-001, REQ-O-002, REQ-O-003, REQ-O-004, REQ-O-006, REQ-O-007, REQ-O-008, REQ-O-009, REQ-O-010, REQ-O-017, REQ-O-018, REQ-O-021 |
| Primary Spec Refs | 05-devops-infrastructure.md §1–§4, 03-backend-spec.md §1.2, §2.1, §9, §10, 06-security-testing.md §3, §5 |
| Last Updated | 2026-10-03 |

## 1. Objective

Create the Git repository, the local PostgreSQL container and a running Express + TypeScript API skeleton
that every later task builds on. At the end of this task the developer can start the database, start the API,
call `GET /api/v1/health` and get database status, and every push runs static checks in GitHub Actions. The
cross-cutting backend machinery (config validation, redacting logger, request IDs, uniform errors, request
validation, security headers, body limits and a rate-limit factory) exists once, so feature tasks only plug into it.

## 2. Scope

### In Scope
- `git init` in the project root (it is not a repository yet; `docs/` already exists), first commit, GitHub remote, push.
- Repo layout `apps/api`, `apps/mobile` (placeholder only — TASK-03 creates the Flutter project), `infra`, `docs`.
- Root `.gitignore` covering `.env` files, `node_modules`, build output, Flutter build dirs, local photo/data dirs, dumps.
- `apps/api/.env.example` with every variable of 05 §2.2; `infra/.env.example` with database name/user/password.
- `infra/docker-compose.yml` with one `db` service (05 §3.2–3.3).
- Root scripts `db:up`, `db:down`, `api:dev` (root `package.json` or Makefile — developer's choice, 05 §3.3).
- Express + TypeScript (strict) API with app/server split, startup config validation, structured logger with redaction,
  request ID, request logging, error classes + formatter with the full 03 §9.1 code table, validation middleware pattern,
  security headers, CORS off, 64 KB JSON limit, rate-limit middleware factory, `GET /api/v1/health`.
- Module folder skeleton per 03 §1.2 (empty modules with an index/router stub where useful).
- ESLint + TypeScript type-check scripts; GitHub Actions API job and path-filtered mobile job; optional weekly `npm audit` workflow.
- Optional rotating local log file (≤ 14 days).

### Out of Scope
- Prisma schema, migrations, seeds, `db:migrate`/`db:seed`/`db:reset` scripts → TASK-02.
- Flutter project creation and mobile static-check content → TASK-03 (the CI mobile job is wired here but skips until `apps/mobile/pubspec.yaml` exists).
- Applying concrete rate limits to endpoints → the task owning each endpoint (TASK-03, -04, -05, -07).
- Admin auth middleware → TASK-05. Verify-token middleware → TASK-07. Storage interface → TASK-04.
- Deployment, containerizing the API, HTTPS → deferred (REQ-O-022).

## 3. Prerequisites

- Docker installed and running; Node.js current LTS and npm (07 §2.2).
- A GitHub account and an empty repository created for the project (07 §2.2).
- Ability to generate secrets with a CSPRNG (e.g. `openssl rand -base64 48`) for `JWT_SECRET` and the DB password.
- Decision to record: the pinned PostgreSQL major version (latest stable at setup; ≥ 13 so `gen_random_uuid()` is built in — 04 §1.2).

## 4. Dependencies

| Task | Why it is required |
|---|---|
| None | First task; everything else builds on it |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-N-016 | Static checks pass with zero errors: TypeScript strict + ESLint; `dart analyze` with `flutter_lints`; `dart format` | 06 §7.2, 07 §7.1 |
| REQ-N-023 | Backend layering: handlers parse/shape; services hold business rules; only services and storage touch Prisma or the file system | 03 §1.2 |
| REQ-S-013 | Logger redaction: `Authorization`, `X-Verify-Token`, `password`, `phone`, `phoneE164`, `note` removed; bodies never logged; routes logged by template | 03 §9.2 |
| REQ-S-015 | Every request schema-validated (Zod candidate) before business logic; unknown fields stripped/rejected; only parameterized SQL | 06 §3.1 |
| REQ-S-016 | JSON body limit 64 KB | 06 §3.1 |
| REQ-S-018 | Error responses never include stack traces, SQL, file paths or internal IDs (except request ID) | 06 §3.1 |
| REQ-S-019 | Security headers (helmet candidate): nosniff, frame deny, no referrer, CSP `default-src 'none'` | 06 §3.4 |
| REQ-S-020 | CORS disabled by default; `CORS_ORIGINS` may enable a local tool | 06 §3.2 |
| REQ-S-021 | Rate-limit middleware (in-memory, per IP or admin, 429 `RATE_LIMITED` + Retry-After, `warn` log) available to all modules | 03 §10 |
| REQ-S-030 | Secrets only in git-ignored `.env`; committed `.env.example` files; secrets generated with CSPRNG; app ships no secrets | 06 §5.2, 05 §2.3 |
| REQ-S-032 | PostgreSQL bound to 127.0.0.1 only; API bound to `API_HOST` for LAN phones | 05 §3.2, D8 |
| REQ-O-001 | Repo layout `apps/api`, `apps/mobile`, `infra`, `docs`; `.gitignore` | 05 D4, 07 A1 |
| REQ-O-002 | `infra/docker-compose.yml`: one `db` service, pinned postgres major, `127.0.0.1:5432`, volume `pgdata`, `pg_isready` health check, `unless-stopped`, creds from `infra/.env` | 05 §3.2, §3.3 |
| REQ-O-003 | API validates all env vars of 05 §2.2 at startup and exits with a clear message when missing/invalid | 05 §2.2, 03 §1.2 |
| REQ-O-004 | Root scripts `db:up`, `db:down`, `api:dev` | 05 §3.3 |
| REQ-O-006 | `GET /health` returns `{status, db}`; 503 `SERVICE_UNAVAILABLE` when the database is unreachable | 03 §2.2, §9.1 |
| REQ-O-007 | Structured JSON logger (levels per §9.2); request ID accepted from header or generated, returned in a header and in `error.requestId`; one info line per request | 03 §9.2 |
| REQ-O-008 | Uniform error response `{error:{code,message,details?,requestId}}` and the full error-code table | 03 §2.1, §9.1 |
| REQ-O-009 | GitHub Actions: path-filtered API job (install, `prisma generate`, `tsc --noEmit`, ESLint) and mobile job (`flutter pub get`, `dart format` check, `dart analyze`) | 05 §4.1, §4.2 |
| REQ-O-010 | Optional weekly `npm audit --audit-level=high` workflow (notification only) | 05 §4.2 |
| REQ-O-017 | Optional rotating local log file kept ≤ 14 days | 05 §6.1, 06 §4.3 |
| REQ-O-018 | Express app built separately from the server entry point that listens | 03 §1.2 |
| REQ-O-021 | Git repository initialised, pushed to GitHub, spec docs in `docs/`, no `.env` committed | 07 §2.2, A1 |

### 5.2 Data Contracts

No schema in this task (TASK-02 owns it). Infrastructure contract for the database container (05 §3.2):

| Item | Value |
|---|---|
| Service | `db`, official `postgres:<major>` image, major pinned and recorded in 05 §3.2 |
| Ports | `127.0.0.1:5432:5432` — localhost only, never the LAN |
| Volume | named `pgdata` |
| Health check | `pg_isready` every 5 s |
| Restart | `unless-stopped` |
| Credentials | `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` from `infra/.env` (git-ignored); `infra/.env.example` committed |

`DATABASE_URL` example: `postgresql://saarthee:<pw>@127.0.0.1:5432/saarthee`.

### 5.3 API Contracts

Base path `/api/v1`. JSON camelCase; UTC `Z` timestamps in responses (03 §2.1).

| Method | Path | Auth | Request | Response | Errors |
|---|---|---|---|---|---|
| GET | /health | No | — | 200 `{status:"ok", db:"ok"}` | 503 `SERVICE_UNAVAILABLE` with `{status:"error", db:"unreachable"}` semantics carried in the standard error body |

**Error response shape (every error, 03 §2.1):**
```json
{ "error": { "code": "VALIDATION_FAILED", "message": "…", "details": [{ "field": "phone", "issue": "…" }], "requestId": "…" } }
```

**Error code table to implement as constants + classes (03 §9.1):**

| Code | HTTP | Default message |
|---|---|---|
| VALIDATION_FAILED | 400 | Per-field messages in `details` |
| INVITE_CODE_INVALID | 404 | "That code didn't work. Check it with whoever shared it." |
| INVITE_CODE_TAKEN | 409 | "That code already exists." |
| CATEGORY_INACTIVE | 422 | "Please choose the category again." |
| PHOTO_UNUSABLE | 422 | "Please retake the photo." |
| PHOTO_TOO_LARGE | 413 | "That photo is too large. Please try again." |
| PHOTO_TYPE_UNSUPPORTED | 415 | "We couldn't read that photo. Please retake it." |
| PHOTO_DELETED | 410 | "This photo was deleted." |
| VERIFY_TOKEN_INVALID | 401 | "This link isn't valid. Ask for a new one." |
| VERIFY_TOKEN_REVOKED | 410 | "This link is no longer active." |
| INVALID_CREDENTIALS | 401 | "Email or password is incorrect." |
| ADMIN_DISABLED | 403 | "This account is disabled." |
| TOKEN_EXPIRED | 401 | "Your session ended. Please log in again." |
| TOKEN_REVOKED | 401 | "Your session ended. Please log in again." |
| COMPLAINT_EXCLUDED | 409 | "This complaint is excluded." |
| COMPLAINT_ANONYMIZED | 409 | "This complaint's personal data was removed." |
| NOT_FOUND | 404 | "Not found." |
| RATE_LIMITED | 429 | "Too many attempts. Please wait a moment and try again." (+ `Retry-After`) |
| INTERNAL_ERROR | 500 | "Something went wrong. Please try again." |
| SERVICE_UNAVAILABLE | 503 | "The service is unavailable. Please try again later." |

Unknown routes return 404 `NOT_FOUND`; malformed JSON returns 400 `VALIDATION_FAILED`; oversize JSON (> 64 KB) returns an error in the standard shape (ASSUMPTION in §5.6).

**Environment variables validated at startup (05 §2.2)** — all declared now, even if consumed later:
`APP_ENV` (development|production), `API_HOST`, `API_PORT`, `DATABASE_URL`*, `JWT_SECRET`* (≥ 32 bytes), `JWT_ISSUER`,
`JWT_AUDIENCE`, `JWT_EXPIRES_IN` (`8h`), `STORAGE_DRIVER` (local|cloudflare_r2), `PHOTO_STORAGE_DIR` (absolute, outside repo),
`PHOTO_MAX_UPLOAD_BYTES` (5242880), `PHOTO_MAX_EDGE_PX` (2048), `UNATTACHED_PHOTO_TTL_HOURS` (24), `REMINDER_INTERVAL_DAYS` (7),
`VERIFY_LINK_BASE` (`saarthee://verify?t=`), `VERIFY_DISTANCE_WARN_M` (empty = off), `CONSENT_TEXT_VERSIONS` (`v1`),
`REMINDER_TEMPLATE_VERSION` (`v1`), `CORS_ORIGINS` (empty), `TRUST_PROXY` (`false`), `LOG_LEVEL` (`debug`),
`SEED_ADMIN_EMAIL`*, `SEED_ADMIN_PASSWORD`* (optional at runtime; used by seed/create-admin only). `*` = sensitive.

### 5.4 UI Surfaces & States

Not applicable — this task has no user interface. The mobile placeholder folder is created only so the layout exists.

### 5.5 Permissions & Roles

| Surface | Who | Rule |
|---|---|---|
| GET /api/v1/health | Anyone | Public; rate limit (120/IP/min) applied by TASK-03 together with `/categories` (REQ-S-022) |
| Rate-limit factory | Modules | Keyed by IP by default, or by a caller-supplied key (admin ID, IP+email); `TRUST_PROXY=false` locally |
| Database | API only | Port bound to 127.0.0.1; phones never reach it |

### 5.6 Assumptions

- ASSUMPTION: Health check uses the Prisma client with a trivial `SELECT 1` once TASK-02 adds the schema; in this task the Prisma client is initialised with an empty schema (datasource + generator only) so the CI `prisma generate` step is real — keeps one DB access path — if Prisma cannot generate with no models, use a raw `pg` connection for health and switch in TASK-02.
- ASSUMPTION: Payload-too-large on JSON maps to HTTP 413 with code `VALIDATION_FAILED` and message "Request body too large." — the error table has no generic body-size code — if a dedicated code is wanted, add it to 03 §9.1.
- ASSUMPTION: Root scripts live in a root `package.json` (npm, 05 D5) — simplest cross-platform option — a Makefile would change only the invocation.
- ASSUMPTION: The mobile CI job is gated on `apps/mobile/pubspec.yaml` existing — the Flutter project is created in TASK-03 — remove the guard there.
- ASSUMPTION: Unknown JSON fields are **stripped** (not rejected) by default in the validation middleware — keeps older app builds working — switch to strict per-schema if a field must be rejected.

## 6. Implementation Steps

1. `git init` in the project root; add a root `README.md` stub pointing to `docs/00-master-index.md` and `docs/tasks/00-task-summary.md`.
2. Create root `.gitignore`: `**/.env`, `!**/.env.example`, `node_modules/`, `dist/`, `coverage/`, `*.log`, `logs/`, `var/`, `*.dump`, `*.sql.gz`, Flutter `build/`, `.dart_tool/`, IDE folders, OS files.
3. Create folders `apps/api`, `apps/mobile` (with a `README.md` noting TASK-03 creates the Flutter app), `infra`.
4. Write `infra/docker-compose.yml` and `infra/.env.example` per §5.2; pin the postgres major and record it in `docs/05-devops-infrastructure.md` §3.2.
5. Add root `package.json` scripts: `db:up` (`docker compose -f infra/docker-compose.yml --env-file infra/.env up -d`), `db:down`, `api:dev` (runs the API watch script).
6. Initialise `apps/api`: `package.json`, TypeScript with `strict: true`, a watch runner (candidate: `tsx`), `typecheck` (`tsc --noEmit`) and `lint` scripts; ESLint with a TypeScript config. Verify each candidate package is current and maintained (03 §1.1).
7. Create the module skeleton of 03 §1.2: `prisma/`, `src/config`, `src/lib/{errors,logger,tokens,storage,images,geo,pagination}`, `src/middleware`, `src/modules/{public,reports,verify,photos,events,admin-auth,admin-complaints,reminders,invite-codes,categories-admin,rates,export,anonymize}`, `src/app.ts`, `src/server.ts`, `scripts/`. Add a short `apps/api/ARCHITECTURE.md` stating the layering rule (REQ-N-023).
8. `src/config`: schema-validate every variable in §5.3 (candidate: Zod); on failure print one clear line per bad variable (name + problem, never the value) and exit non-zero. Export a typed, frozen config object. Write `apps/api/.env.example` with placeholders and a comment on generating secrets.
9. `src/lib/logger`: structured JSON logger (candidate: pino) with `LOG_LEVEL`; redact paths for `req.headers.authorization`, `req.headers["x-verify-token"]`, and any `password`, `phone`, `phoneE164`, `note` keys at any depth; serializers that never include request/response bodies. Optional file transport with rotation ≤ 14 days, off by default (REQ-O-017).
10. `src/middleware/requestId`: accept a safe incoming request-ID header (e.g. `X-Request-Id`, bounded length/charset) or generate a UUID; set it on the response header and on the request context.
11. `src/middleware/requestLog`: one `info` line per request on finish — method, **route template** (e.g. `/api/v1/admin/complaints/:id`, never the raw URL), status, duration ms, requestId.
12. `src/lib/errors`: `AppError` with `code`, `status`, `message`, optional `details`; constants for every code in §5.3; a formatter producing the standard body with `requestId`. Error-handler middleware: AppErrors → their status; JSON parse errors → 400; body-too-large → §5.6; anything else → 500 `INTERNAL_ERROR` logged at `error` with stack **in logs only**. 404 handler for unknown routes.
13. `src/middleware/validate`: helper taking body/query/params schemas, stripping unknown fields, converting failures into `VALIDATION_FAILED` with `details[{field, issue}]`. Document that raw SQL must use Prisma's parameterized raw form only (REQ-S-015).
14. `src/middleware/rateLimit`: factory (candidate: express-rate-limit, in-memory store) taking `{windowMs, max, keyGenerator?}`; on exceed returns 429 `RATE_LIMITED` in the standard shape with `Retry-After`, and logs `warn` with route template and requestId. Respect `TRUST_PROXY` for client IP.
15. `src/app.ts`: build the Express app — `trust proxy` from config, security headers (candidate: helmet; `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`, CSP `default-src 'none'`; no HSTS yet), CORS only when `CORS_ORIGINS` is non-empty, `express.json({limit: "64kb"})`, request ID, request log, `/api/v1` router, 404, error handler. Export the app without listening (REQ-O-018).
16. `src/server.ts`: load config, create app, listen on `API_HOST:API_PORT`, graceful shutdown (close server, disconnect DB) on SIGINT/SIGTERM; log startup at `info` without secrets.
17. `modules/public`: `GET /health` — run `SELECT 1` through the DB client with a short timeout; 200 `{status:"ok", db:"ok"}` or 503 `SERVICE_UNAVAILABLE`. Handler stays thin; the DB check lives in a service.
18. Add a minimal `prisma/schema.prisma` (datasource from `DATABASE_URL`, client generator, no models) and the Prisma client singleton in `src/lib` (see §5.6) so `prisma generate` runs in CI.
19. `.github/workflows/ci.yml`: on push/PR; job `api` with `paths: apps/api/**` filter (or `dorny/paths-filter` candidate) running `npm ci`, `npx prisma generate`, `npm run typecheck`, `npm run lint` in `apps/api`; job `mobile` for `apps/mobile/**` running `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `dart analyze`, skipped when `apps/mobile/pubspec.yaml` is absent. No secrets used.
20. `.github/workflows/audit.yml` (optional, REQ-O-010): weekly schedule, `npm audit --audit-level=high` in `apps/api`, `continue-on-error` so it only notifies.
21. Create `infra/.env` and `apps/api/.env` locally from the examples with CSPRNG secrets; confirm `git status` shows neither.
22. First commit (`TASK-01: repo, infra and API foundation`), add the GitHub remote, push; confirm the CI run is green.
23. Run the manual checks in §8 and record results in §13 and the coverage matrix.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — Repository created safely
- **Given** the project folder with only `docs/`
- **When** TASK-01 is committed and pushed
- **Then** the GitHub repo contains `apps/api`, `apps/mobile`, `infra`, `docs`, `.gitignore`, both `.env.example` files, and `git ls-files | grep -E '(^|/)\.env$'` returns nothing

**AC-2** — Database container is healthy and private
- **Given** `infra/.env` exists
- **When** `npm run db:up` runs
- **Then** `docker compose ps` shows `db` healthy, the port is published only on `127.0.0.1:5432`, and data survives `db:down` + `db:up` (volume `pgdata`)

**AC-3** — Startup refuses bad configuration
- **Given** `apps/api/.env` with `JWT_SECRET` removed (or shorter than 32 bytes, or `APP_ENV=staging`)
- **When** `npm run api:dev` starts
- **Then** the process exits non-zero with a message naming the variable and the problem, and no secret value is printed

**AC-4** — Health reports database status
- **Given** the API and database are running
- **When** `GET /api/v1/health` is called
- **Then** it returns 200 `{status:"ok", db:"ok"}`; and after `npm run db:down` the same call returns 503 with `error.code = SERVICE_UNAVAILABLE` and a `requestId`

**AC-5** — Uniform, safe errors
- **Given** the API is running
- **When** an unknown route, a malformed JSON body, and a handler that throws an unexpected error are requested
- **Then** each returns the standard `{error:{code,message,requestId}}` body (404 `NOT_FOUND`, 400 `VALIDATION_FAILED`, 500 `INTERNAL_ERROR`), with no stack trace, SQL or file path in the response; the 500's stack appears only in the server log

**AC-6** — Request IDs correlate responses and logs
- **Given** a request with header `X-Request-Id: test-123` and one without
- **When** both are served
- **Then** the first response echoes `test-123`, the second gets a generated UUID, and each log line for the request carries the same `requestId`, method, route template, status and duration

**AC-7** — Logs never contain secrets or personal data
- **Given** a request sending `Authorization: Bearer abc`, `X-Verify-Token: tok123` and a JSON body `{"password":"p","phone":"9876543210","note":"x"}`
- **When** the log output is searched
- **Then** none of `abc`, `tok123`, `9876543210`, `p` values or the body appear; the route is logged by template

**AC-8** — Validation middleware rejects bad input
- **Given** a temporary dev-only route using the validate helper with a schema `{name: string 1–5}` (removed before commit, or kept behind `APP_ENV=development`)
- **When** `{"name":"toolong","extra":1}` is posted
- **Then** the response is 400 `VALIDATION_FAILED` with `details:[{field:"name", issue:…}]`, and a valid body reaches the handler without `extra`

**AC-9** — Body size, headers and CORS
- **Given** the API is running with `CORS_ORIGINS` empty
- **When** a 70 KB JSON body is posted, and any response's headers are inspected, and a request with `Origin: http://evil.test` is sent
- **Then** the large body is rejected in the standard error shape; responses carry `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`, `Content-Security-Policy: default-src 'none'`; and no `Access-Control-Allow-Origin` header is returned

**AC-10** — Rate-limit factory works
- **Given** a dev-only route wrapped with the factory at `max: 2` per minute
- **When** it is called three times from one IP
- **Then** the third call returns 429 `RATE_LIMITED` with a `Retry-After` header and a `warn` log line

**AC-11** — App/server split and layering
- **Given** the API source tree
- **When** `src/app.ts` is imported in a Node REPL
- **Then** an Express app is returned without opening a port; handlers in `src/modules` contain no Prisma or `fs` imports (`grep` check), only services/lib do

**AC-12** — CI static checks
- **Given** the repository is pushed to GitHub
- **When** a commit touching `apps/api/**` is pushed
- **Then** the API job runs install, `prisma generate`, `tsc --noEmit`, ESLint and passes with zero errors; a commit touching only `docs/` triggers neither job; the mobile job is skipped (no `pubspec.yaml`) until TASK-03

**AC-13** — Optional operational extras
- **Given** the optional workflow and log-file setting
- **When** the audit workflow is run manually (`workflow_dispatch`) and the API runs with file logging enabled
- **Then** the audit job reports without failing the repo status, and log files rotate with at most 14 days retained

### AC → Requirement

| AC | Requirements |
|---|---|
| AC-1 | REQ-O-001, REQ-O-021, REQ-S-030 |
| AC-2 | REQ-O-002, REQ-O-004, REQ-S-032 |
| AC-3 | REQ-O-003, REQ-S-030 |
| AC-4 | REQ-O-006, REQ-O-004 |
| AC-5 | REQ-O-008, REQ-S-018 |
| AC-6 | REQ-O-007 |
| AC-7 | REQ-S-013 |
| AC-8 | REQ-S-015 |
| AC-9 | REQ-S-016, REQ-S-019, REQ-S-020 |
| AC-10 | REQ-S-021 |
| AC-11 | REQ-O-018, REQ-N-023 |
| AC-12 | REQ-O-009, REQ-N-016 |
| AC-13 | REQ-O-010, REQ-O-017 |

### 7.2 Non-Functional Checklist

- [ ] `tsc --noEmit` and ESLint pass with zero errors and zero warnings suppressed without a comment
- [ ] Every env var of 05 §2.2 appears in `apps/api/.env.example` with a placeholder (no real secret) and in the config schema
- [ ] No value that belongs in config (port, limits, interval, link base) is hard-coded in source
- [ ] Error handler never sends `err.stack`, `err.message` of unexpected errors, SQL or paths to clients
- [ ] Logger redaction verified at nested depth (e.g. `{ "data": { "phone": … } }`)
- [ ] Request log uses `req.route.path` / router template, never `req.originalUrl`
- [ ] API binds to `API_HOST`; database bound to 127.0.0.1 only (`docker port` / `lsof` check)
- [ ] `photos` dir, dumps and `.env` files are git-ignored (`git check-ignore` passes)
- [ ] Graceful shutdown closes the HTTP server and DB client without errors
- [ ] Layering rule written in `apps/api/ARCHITECTURE.md` for later tasks to follow

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-01-01 | `npm run typecheck && npm run lint` in `apps/api` — zero errors | AC-11, AC-12 |
| Static | S-01-02 | `grep -rE "prisma\|from 'fs'\|node:fs" apps/api/src/modules/*/` matches only `*.service.ts` files | AC-11 |
| Manual (repo) | M-01-01 | `git ls-files \| grep -E '(^\|/)\.env$'` → empty; `git check-ignore apps/api/.env infra/.env` → both listed; GitHub shows layout | AC-1 |
| Manual (infra) | M-01-02 | `npm run db:up`; `docker compose -f infra/docker-compose.yml ps` → healthy; `docker port <db>` → `127.0.0.1:5432`; create a table, `db:down`/`db:up`, table still there | AC-2 |
| Manual (config) | M-01-03 | Remove `JWT_SECRET`, then set it to 10 chars, then `APP_ENV=staging`: `npm run api:dev` exits non-zero naming the variable each time; output contains no secret | AC-3 |
| API manual | M-01-04 | `curl -i localhost:$API_PORT/api/v1/health` → 200 `{"status":"ok","db":"ok"}`; `npm run db:down`; repeat → 503 `SERVICE_UNAVAILABLE` with `requestId` | AC-4 |
| API manual | M-01-05 | `curl -i localhost:$API_PORT/api/v1/nope` → 404 `NOT_FOUND`; `curl -i -H 'Content-Type: application/json' -d '{bad' …/health` (POST to any JSON route) → 400; dev-only throwing route → 500 without stack | AC-5 |
| API manual | M-01-06 | `curl -i -H 'X-Request-Id: test-123' …/health` → response header `test-123`; log line has `requestId:"test-123"`, `route:"/api/v1/health"`, status, duration | AC-6 |
| API manual | M-01-07 | Send the AC-7 headers/body to a dev route; `grep -E 'abc\|tok123\|9876543210' api.log` → no matches | AC-7 |
| API manual | M-01-08 | Post `{"name":"toolong","extra":1}` and `{"name":"ok","extra":1}` to the dev validation route; check 400 details and that the handler sees no `extra` | AC-8 |
| API manual | M-01-09 | `head -c 71680 /dev/zero \| tr '\0' 'a'` wrapped in JSON → rejected; `curl -I` shows the four headers; `curl -i -H 'Origin: http://evil.test'` → no ACAO header | AC-9 |
| API manual | M-01-10 | Call the dev limited route 3× → third is 429 with `Retry-After`; `warn` log present | AC-10 |
| Manual (REPL) | M-01-11 | `node -e "require('./dist/app')"` (or `tsx`) returns without listening (`lsof -i :$API_PORT` empty) | AC-11 |
| CI | M-01-12 | Push an `apps/api` change → API job green; push a `docs/` change → no jobs; mobile job shows skipped | AC-12 |
| Manual (optional) | M-01-13 | Trigger `audit.yml` via workflow_dispatch; enable file logging and confirm rotation config keeps ≤ 14 files/days | AC-13 |
| Optional automated | — | Logger redaction test (06 §8.1 #4) — scheduled in TASK-10 (REQ-N-019) | AC-7 |

Remove or dev-gate the temporary routes used by M-01-05/07/08/10 before the final commit.

## 9. Deliverables

- Git repository on GitHub with the agreed layout and `.gitignore`.
- `infra/docker-compose.yml`, `infra/.env.example`, `apps/api/.env.example`.
- Root `package.json` with `db:up`, `db:down`, `api:dev`.
- `apps/api`: TypeScript strict project, config validation, logger, request ID + request logging, error system, validation helper, rate-limit factory, security headers, body limit, app/server split, `GET /api/v1/health`, module skeleton, `ARCHITECTURE.md`, minimal Prisma setup.
- `.github/workflows/ci.yml` and optional `.github/workflows/audit.yml`.
- `docs/05-devops-infrastructure.md` §3.2 updated with the pinned postgres major.

## 10. Files Expected to Change

Prediction, not a constraint.

| Path | New/Modified |
|---|---|
| `.gitignore`, `README.md`, `package.json` (root) | New |
| `infra/docker-compose.yml`, `infra/.env.example` | New |
| `apps/api/package.json`, `tsconfig.json`, ESLint config, `.env.example`, `ARCHITECTURE.md` | New |
| `apps/api/src/{app.ts,server.ts}` | New |
| `apps/api/src/config/` | New |
| `apps/api/src/lib/{errors,logger,…}/` | New |
| `apps/api/src/middleware/{requestId,requestLog,validate,rateLimit,errorHandler}` | New |
| `apps/api/src/modules/public/` (health) + empty module folders | New |
| `apps/api/prisma/schema.prisma` (datasource/generator only) | New |
| `apps/mobile/README.md` (placeholder) | New |
| `.github/workflows/ci.yml`, `.github/workflows/audit.yml` | New |
| `docs/05-devops-infrastructure.md` (§3.2 pinned version) | Modified |

## 11. Related Documentation

- `docs/05-devops-infrastructure.md §1.1–1.2` — local architecture (DB in Docker, API native).
- `docs/05-devops-infrastructure.md §2.2–2.3` — env var list and secrets handling.
- `docs/05-devops-infrastructure.md §3.2–3.3` — compose service and root scripts.
- `docs/05-devops-infrastructure.md §4.1–4.3` — CI stages and branch strategy.
- `docs/03-backend-spec.md §1.1–1.2` — stack candidates and project structure/layering.
- `docs/03-backend-spec.md §2.1` — API conventions (error shape, headers).
- `docs/03-backend-spec.md §9.1–9.2` — error codes, logging and redaction.
- `docs/03-backend-spec.md §10` — rate-limit model (limits applied later).
- `docs/06-security-testing.md §3.1–3.4, §5.2` — input validation, CORS, headers, secrets.

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Candidate libraries outdated or incompatible with current Express major | Rework later | Check each on npm before adding; record versions in §13 |
| Redaction misses a nested field | Personal data in logs (T9) | Use wildcard redact paths; M-01-07 tests nested bodies |
| Raw URL logged accidentally (e.g. future query strings) | Tokens in logs if a client misuses query | Log route template only; verify tokens never go in URLs (TASK-07) |
| `.env` committed by mistake | Secret leak | `.gitignore` first commit; M-01-01 check; rotate if ever exposed |
| CI free minutes / private repo limits | Slow feedback | Path filters; check current GitHub limits (05 §4.2) |
| Postgres < 13 lacks built-in `gen_random_uuid()` | TASK-02 migration fails | Pin ≥ 13 now |

## 13. Progress Status

**Current status:** In Review — unfinished: GitHub remote + push and a CI run (AC-1 push part, AC-12, AC-13 audit run) — Deferred, 2-hour demo timebox / founder action
**Progress:** 100%

| Date | Progress | Commit |
|---|---|---|
| 2026-10-03 | Repo, compose (postgres 17.6, 127.0.0.1:5433), API foundation: config validation, redacting pino logger (+pino-roll 4.0.0), request ID/log by route template, error table, validate (zod 4.6.5), rate-limit factory (express-rate-limit 8.7.0), helmet 8.3.0, 64 KB limit, /health; express 5.2.1, prisma 6.19.3, TS 5.9.3. All §8 checks run locally (M-01-01…11, 13). CI workflow written; GitHub push deferred (no remote, founder action). ASSUMPTION: DB host port 5433 because 5432 is occupied on the dev machine. | 87b56d5, 2c7d50f |

## 14. Completion Checklist

- [x] All implementation steps complete
- [ ] All behavioral acceptance criteria verified in the running application (AC-12 CI run + push deferred)
- [x] Non-functional checklist fully ticked
- [x] Static checks pass and every AC verified by the manual checks in §8 (no automated tests in v1 — 06 §7.1)
- [x] Frontend and backend integrated end to end (no mocked data left in place) — not applicable beyond health; temporary dev routes removed or dev-gated
- [x] Error, loading, empty, and unauthorized states verified — API error states only (no UI in this task)
- [x] Code reviewed against the patterns established in earlier tasks (this task establishes them; documented in `ARCHITECTURE.md`)
- [x] Assumptions documented and, where possible, confirmed
- [x] Coverage matrix rows for this task's requirements set to Pass with evidence (`check_coverage.py --task TASK-01` shows 0 unverified)
- [x] Committed as `TASK-01: …`
- [x] Task file progress log and status updated
- [x] `00-task-summary.md` updated
- [x] Validator passes
