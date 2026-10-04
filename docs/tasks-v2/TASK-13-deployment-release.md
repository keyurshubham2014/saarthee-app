# TASK-13: Deployment, Storage, Backups and Release

| Field | Value |
|---|---|
| Task ID | TASK-13 |
| Status | In Review |
| Priority | P0 |
| Size | M |
| Depends On | TASK-01 |
| Blocks | TASK-14 |
| Requirement IDs | REQ-S-013, REQ-S-014, REQ-O-004, REQ-O-005, REQ-O-006, REQ-O-007, REQ-O-008 |
| Primary Spec Refs | Spec §2 (D12), §11 (retention, notices, Data safety inputs), §12 (environments, storage, backups, monitoring, release) |
| Last Updated | 2026-10-04 |

## 1. Objective

Take Saarthee from a laptop to two real, low-cost environments in India — staging and pilot production — that are HTTPS-only, store photos in Cloudflare R2, back up every day with a rehearsed restore, alert the team when the API is down or erroring without sending personal data anywhere, and delete data on the retention schedule promised in Spec §11. On the app side, remove the last cleartext exception outside debug builds, sign release builds with a real upload key, and ship through Play internal and closed testing with a Data safety form that matches what the app actually does.

## 2. Scope

### In Scope
- `R2PhotoStorage` behind the existing `PhotoStorage` interface, selected by `STORAGE_DRIVER=cloudflare_r2`; per-row driver resolution for reads.
- Production container image, deploy scripts and GitHub Actions workflows (staging on merge to `main`, pilot on manual approval).
- Staging and pilot environments (§5.6 records the provider choice): VM per environment, managed PostgreSQL 17 + PostGIS, Cloudflare DNS/TLS/proxy, origin firewall, Caddy reverse proxy.
- Environment variable reference and secrets handling (`docs/ops/environments.md`).
- HTTPS everywhere outside local: HSTS, HTTP→HTTPS, correct client IP behind proxies, release/profile builds refuse non-HTTPS API URLs, profile cleartext exception removed.
- Backups: managed daily backups + own encrypted daily `pg_dump` to an R2 backup bucket; photo bucket protection; restore drill recorded.
- Monitoring: uptime checks on `/health`, job heartbeats, error alerting with PII scrubbing.
- Retention job `retention:run`: photos of closed issues after 2 years, logs 14 days, notifications 90 days; registered daily in the TASK-06 job runner (`src/jobs`). Host systemd timers in this task cover only backups and the photo mirror.
- Android release signing, Play App Signing, internal and closed testing tracks, store listing basics, privacy policy and account-deletion web pages, Data safety form.

### Out of Scope
- Firebase project setup and SHA registration for OTP (REQ-O-003) — TASK-04; this task only hands over the Play app-signing and upload-key fingerprints.
- Pilot data loading (representatives, services), launch go/no-go and physical-device verification — TASK-14.
- Production (open) Play release and iOS App Store (REQ-O-090, deferred).
- Load testing beyond the smoke checks here; p95 targets belong to TASK-07 (REQ-N-011).
- Migrating local photos to R2 (pilot starts with no real photos).

## 3. Prerequisites

- TASK-01 complete (PostGIS migrations, test harness, CI). Later tasks may still be in progress; staging deploys whatever is on `main`.
- Founder actions (Open Question 3): Play Console developer account; a domain on Cloudflare (written `<domain>` below); a DigitalOcean team account with billing; GitHub org/repo admin for environments and secrets; a password manager vault for keys.
- Local: Docker, `doctl`, `rclone`, `age`, Java 17 `keytool`, Android SDK `apksigner`.
- Read Spec §11 and §12 fully before the Data safety step.

## 4. Dependencies

| Task | Why it is required |
|---|---|
| TASK-01 | PostGIS-based migrations to deploy, `/health` with PostGIS check, Vitest harness and CI job this task extends, v2 seed for staging |

## 5. Technical Context

### 5.1 Requirements Covered

| Req ID | Requirement | Source |
|---|---|---|
| REQ-S-013 | HTTPS everywhere outside local; cleartext exceptions only in debug builds (profile exception removed) | Spec §12 |
| REQ-S-014 | Retention jobs: photos of closed issues after 2 years, logs 14 days, notifications 90 days | Spec §11 |
| REQ-O-004 | Cloudflare R2 storage driver implemented behind the storage interface and selectable by `STORAGE_DRIVER` | Spec D12 |
| REQ-O-005 | Staging and pilot environments: API behind HTTPS, managed PostgreSQL with PostGIS, environment variables documented | Spec D12 |
| REQ-O-006 | Daily database backup, R2 versioning, and a restore drill recorded before launch | Spec §12 |
| REQ-O-007 | Uptime monitoring on `/health` and error alerting without PII | Spec §12 |
| REQ-O-008 | Android release signing, Play internal and closed testing tracks, Data safety form matching §11 | Spec §12 |

### 5.2 Data Contracts

No schema migration is expected. Data touched:

- `photos.storage_driver` (`local` | `cloudflare_r2`, v1 enum) — written by the active driver; reads resolve the driver per row (`storageFor(row.storage_driver)`).
- `photos.deleted_at` — set by the retention job after the object is deleted (row kept for history; `PHOTO_DELETED` 410 on read, v1 behaviour).
- `notifications` (created in TASK-04) — rows older than 90 days deleted; the job checks `to_regclass('public.notifications')` and skips with a log line if the table does not exist yet.
- Audit: each retention run writes one `audit_log` entry via `src/lib/audit` with actor `system`, action `retention.run`, counts only.

**Retention rules (`apps/api/scripts/retention.ts`):**

| Rule | Selection | Action |
|---|---|---|
| `photos.closed_issues` | photos linked through `issue_photos` to issues whose `status` ∈ (`verified`, `rejected`, `merged`) and `status_changed_at < now() - RETENTION_CLOSED_PHOTO_DAYS` (730), **or** status `marked_fixed` with `status_changed_at < now() - (730 + REOPEN_WINDOW_DAYS)` days; `photos.deleted_at IS NULL` | `storage.delete(key)` then `deleted_at = now()`; per-item failures logged by photo id, job exits 1 if any failed |
| `photos.legacy` | photos of imported legacy issues by the same rule | same |
| `notifications` | `created_at < now() - RETENTION_NOTIFICATION_DAYS` (90) | `DELETE` in batches of 1,000 |
| `logs.files` | files in `LOG_FILE_DIR` with mtime older than `RETENTION_LOG_DAYS` (14) | unlink (belt-and-braces to pino-roll `limit.count: 14`, daily frequency) |
| `photos.unattached` | existing v1 `photos:cleanup` | invoked by the same timer |

Flags: `--dry-run` (counts only, no change), `--rule <name>`. Output: `rule=<name> selected=N done=N failed=N` per rule. Never prints keys, phones or coordinates.

Backup objects (R2 bucket `saarthee-<env>-backups`, private): `db/<env>/<yyyy>/<mm>/saarthee-<env>-<UTC ts>.dump.age` (pg_dump `-Fc`, encrypted with `age` to the founder's offline public key). Lifecycle rule: delete `db/` objects after 35 days, `photos-deleted/` after 30 days.

### 5.3 API Contracts

No new endpoints. Behaviour changes:

| Item | Contract |
|---|---|
| `GET /api/v1/health` | Unchanged body (TASK-01); used by uptime checks; must answer < 2 s; 503 when DB down |
| HTTPS | Cloudflare "Always Use HTTPS" (HTTP 301 → HTTPS); API sends `Strict-Transport-Security: max-age=15552000; includeSubDomains` when `APP_ENV=production` (helmet), none locally |
| Client IP | Caddy overwrites `X-Forwarded-For` with `{http.request.header.CF-Connecting-IP}`; API `TRUST_PROXY=true`; API port is not published outside the Docker network, origin accepts 443 only from Cloudflare IP ranges — so rate limits key on the real client IP |
| Storage config | `STORAGE_DRIVER=local` requires `PHOTO_STORAGE_DIR`; `cloudflare_r2` requires `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET` (optional `R2_ENDPOINT` override for tests); missing → startup fails naming the variable (no secret values printed). The v1 "refuse to start with R2" rule is removed |
| Error reporting | `SENTRY_DSN` optional; when set, `beforeSend` keeps only: exception type/message/stack, route template (e.g. `/issues/:id`), method, status, request id, release, environment. Drops request body, query string, cookies, all headers except `user-agent`, `user`, IP, breadcrumbs with URLs (query stripped), and any string matching phone (`\+?91[6-9]\d{9}`), JWT (`eyJ…`) or coordinates pattern. `sendDefaultPii: false` |

**`R2PhotoStorage`** (`src/lib/storage/r2.ts`, *candidate* `@aws-sdk/client-s3`, pinned exact): endpoint `https://<R2_ACCOUNT_ID>.r2.cloudflarestorage.com`, region `auto`. Same `KEY_PATTERN` validation as local (traversal-proof). `save(bytes)` → `PutObject` (`ContentType image/jpeg`, `CacheControl private, max-age=0`) → key; `open(key)` → `GetObject` body stream, `NoSuchKey` → same error class the local driver throws for a missing file; `delete(key)` → `DeleteObject` (missing = success); `exists(key)` → `HeadObject` (404 → false). Timeouts 10 s, 2 retries (SDK default backoff). Bucket is private; photos are only served through the API.

Environment variables added (documented with every existing one in `docs/ops/environments.md`): `DEPLOY_ENV` (`local`/`staging`/`pilot`), `R2_*` above, `SENTRY_DSN`, `SENTRY_TRACES_SAMPLE_RATE` (0), `RETENTION_CLOSED_PHOTO_DAYS` (730), `RETENTION_NOTIFICATION_DAYS` (90), `RETENTION_LOG_DAYS` (14), `REOPEN_WINDOW_DAYS` (7, shared with TASK-06), `HEALTHCHECKS_URL_BACKUP`, `HEALTHCHECKS_URL_RETENTION` (ops scripts only).

### 5.4 UI Surfaces & States

| Surface | Content | States |
|---|---|---|
| App startup (profile/release) | `API_BASE_URL` must start with `https://`; otherwise the app shows the fatal config screen "This build is misconfigured. Please install the latest version from Play." (key `configErrorBody`) and logs nothing sensitive | debug builds allow `http://10.0.2.2`/`localhost` only |
| `https://<domain>/privacy` (static, Cloudflare Pages, `infra/site/`) | Privacy notice in Gujarati and English from Spec §11: data collected, purposes, public display rule ("A resident of <ward>"), sharing with representatives only when the citizen sends a message, retention (photos 2 years after closure, logs 14 days, notifications 90 days, backups 35 days), rights (export, delete), grievance contact, independence statement | Marked "Draft — pending legal review" until Open Question 6 closes |
| `https://<domain>/delete-account` | How to delete: in app **Me → Privacy & data → Delete my account**; or email the grievance contact from the registered number's account; what is deleted vs anonymised; timeline (30 days) | Required by Play for apps with accounts |
| Play store listing (en + gu) | Title "Saarthee — Amdavad civic issues"; first line of description: "Saarthee is an independent app. It is not made by or affiliated with the Amdavad Municipal Corporation." ; screenshots from staging with fictional data | No AMC logo or marks (D1) |
| Ops runbooks | `docs/ops/deploy.md`, `docs/ops/backup-restore.md`, `docs/ops/restore-drill.md` (drill record), `docs/ops/monitoring.md`, `docs/ops/release-android.md` | — |

Data safety form (Play Console), derived from Spec §11 and the actual code — any later change in data use must update this table and the form:

| Play data type | Collected | Shared | Purpose | Optional | Notes |
|---|---|---|---|---|---|
| Phone number | Yes | No | Account management, fraud prevention | No (needed to sign in) | Never shown publicly |
| Name (display name) | Yes | No | App functionality | Yes | |
| Precise location | Yes | No | App functionality (issue location, ward detection) | Yes (browsing works without) | Issue locations are public by design (disclosed in notice) |
| Photos | Yes | No | App functionality | Yes | EXIF stripped, faces/plates blurred |
| Other in-app messages | Yes | Yes — representative (user-initiated) | App functionality | Yes | Disclosed conservatively |
| Other user-generated content (descriptions, comments) | Yes | No | App functionality | Yes | |
| App interactions | Yes | No | Analytics | No | v1 events allow-list, no identifiers beyond install id |
| Device or other IDs | Yes | No | App functionality (push, install id) | No | FCM token |
| Crash logs / diagnostics | No | — | — | — | No crash SDK in the app; server errors scrubbed |

Plus: data encrypted in transit — Yes; users can request deletion — Yes (in app and via `/delete-account`); target audience 18+ (users under 18 blocked at sign-in, Spec §11); no ads.

### 5.5 Permissions & Roles

| Action | Who | Where |
|---|---|---|
| Deploy to staging | Any merge to `main` with green CI | GitHub Actions environment `staging` |
| Deploy to pilot | Founder or build lead approval | GitHub environment `pilot` with required reviewer |
| SSH to VMs | Build lead and founder keys only; from listed IPs | DO cloud firewall; password login disabled |
| Read DB backups | Founder (holds `age` private key offline) | Restore drill and incidents only |
| Managed DB console | Founder, build lead | DO team roles; 2FA required |
| Play Console | Founder (owner), build lead (release manager) | Play user permissions |
| Upload keystore | Founder vault + build lead machine | Never in git or CI logs; CI uses base64 secret only if CI signing is enabled later |
| Error tracker | Build lead | Sentry project; data scrubbed before sending |

### 5.6 Assumptions

- ASSUMPTION (integrator, 2026-10-04): profile builds keep a cleartext exception limited to `10.0.2.2` and `localhost` (`android/app/src/profile/res/xml/network_security_config.xml`, `apiBaseUrlIsAllowed` allows them in profile). Profile is the emulator verification build required by the v2 goal (debug cold starts ANR) and is never distributed; release remains HTTPS-only. `scripts/check-cleartext.sh` fails if the profile config names any other host or if release gains an exception.
- ASSUMPTION: Provider set — DigitalOcean BLR1 (Bengaluru) for compute (one Droplet per environment: staging `s-1vcpu-1gb`, pilot `s-1vcpu-2gb`, Ubuntu 24.04 LTS, Docker) and DigitalOcean Managed PostgreSQL 17 (single node, 1 GB, per environment) with the `postgis` extension; Cloudflare (free plan) for DNS, TLS, proxy and Pages; Cloudflare R2 for photos and backups — India-region compute/DB, low cost (estimate ~USD 50/month total before R2 overage; verify current prices), matches D12 ("one Linux VM … managed PostgreSQL with PostGIS"). Alternative if the founder prefers: AWS Lightsail + RDS in ap-south-1 (Mumbai), or Supabase (ap-south-1) for the database.
- ASSUMPTION: Managed PostGIS may be 3.4 rather than 3.5 — acceptable if `postgis_lib_version()` ≥ 3.4 and the CI suite passes against that version once (run the API tests against a staging-provisioned scratch database during M-13-02).
- ASSUMPTION: Separate managed databases for staging and pilot (not two databases in one cluster) — isolates restores and credentials; costs ~USD 15/month more.
- ASSUMPTION: "R2 versioning" (Spec §12) — Cloudflare R2 did not offer S3-style object versioning at last check; if it is available when this task runs, enable it; otherwise the equivalent is a nightly `rclone sync --backup-dir` of the photo bucket into `saarthee-<env>-backups/photos-mirror/` with replaced/deleted objects moved to `photos-deleted/<date>/` and purged after 30 days (also keeps the retention promise). TASK-14 L8 "R2 versioning on" is satisfied by whichever is in place, recorded in `docs/ops/backup-restore.md`.
- ASSUMPTION: Error alerting uses Sentry (free Developer plan) with the scrubber in §5.3 — Spec §12 says "error logging (no PII)"; a unit test proves scrubbing. If the founder rejects a third-party tracker, fall back to a log-based alert (pino `error` count via a cron that emails the build lead).
- ASSUMPTION: Uptime via UptimeRobot (free, 5-minute interval, email alerts) on both `/api/v1/health` URLs; job heartbeats via Healthchecks.io (free) — no request data leaves the servers.
- ASSUMPTION: "Closed issue" for photo retention = `verified`, `rejected`, `merged`, or `marked_fixed` past its reopen window; retention counts from `status_changed_at` — Spec §11 says "2 years after closure" without defining closure. A reopened issue restarts the clock.
- ASSUMPTION: Notifications retention lives here although the table arrives in TASK-08; the rule no-ops until the table exists and T-13-05 covers both cases.
- ASSUMPTION: Logs = API application logs (pino-roll daily files, 14 kept) and Docker/journald (`MaxRetentionSec=14day`); Caddy access logs are disabled (Cloudflare holds edge logs under its own policy).
- ASSUMPTION: The Play internal-testing build points at staging and the closed-testing build at pilot (same application id `in.saarthee.saarthee`, different `--dart-define-from-file` and build numbers) — matches TASK-14 §5.6.
- ASSUMPTION: The domain is chosen by the founder; hostnames `api.<domain>` (pilot), `api-staging.<domain>` (staging), `<domain>` (static pages).
- ASSUMPTION: Release signing happens on the build lead's machine for the pilot; CI signing is a later improvement.
- ASSUMPTION (W-OPS 2026-10-04): The audit "entry" for `retention.run` is the existing log-based `src/lib/audit` line (`admin_action`, action `retention_run`, actor `system`, counts only) — there is no `audit_log` table on `main`; `retention_run` was appended to `AUDIT_ACTIONS`.
- ASSUMPTION: Until TASK-06's `src/jobs` runner exists, retention runs daily from the host timer `saarthee-retention` (`infra/deploy/retention.sh` → `retention:run` inside the API container); disable the timer once the in-process job is registered.
- ASSUMPTION: Legacy rule `photos.legacy` = photos (via `issue_photos`) of issues with `legacy_complaint_id` set, same closure rule; `photos.closed_issues` = the rest.
- ASSUMPTION: Sentry `@sentry/node` 11.4.0 replaced `sendDefaultPii` with `dataCollection`; it is configured to collect nothing (no user info, cookies, bodies, query params, headers except user-agent, frame vars) and default integrations are off; the allow-list `scrubEvent` is the real guarantee (T-13-07).
- ASSUMPTION: Caddy's config is baked into a small `saarthee-caddy` image (`infra/deploy/caddy.Dockerfile`) instead of bind-mounted — the deployed config is versioned with the release, and Docker Desktop on the dev Mac hung starting containers with bind mounts from `~/Documents`. Client IP: Caddy `trusted_proxies` = Cloudflare ranges + `client_ip_headers CF-Connecting-IP`, `X-Forwarded-For := {client_ip}` (a direct caller cannot spoof it; verified locally).
- ASSUMPTION: The Prisma CLI moved from devDependencies to dependencies so the runtime image can run `prisma migrate deploy` (step 5 "plus Prisma CLI"); seed modules may be `.js` so the compiled seed runs in the image (staging seed).
- ASSUMPTION: The production compose has a `local-db` profile (PostGIS container on 127.0.0.1:${DB_PORT}) for local rehearsal only; staging/pilot use managed PostgreSQL.
- ASSUMPTION: Debug builds may also use plain HTTP to a LAN IP passed as `--dart-define=DEV_CLEARTEXT_HOST` (keeps `scripts/run-lan-phone.sh` working); profile/release never allow HTTP.
- ASSUMPTION: Release builds without an upload key fail at `preReleaseBuild`; `-Psaarthee.allowDebugSigning=true` (or `SAARTHEE_ALLOW_DEBUG_SIGNING=1`) is an explicit local-only escape hatch that signs with the debug key (Play rejects such uploads).
- ASSUMPTION: `pubspec.yaml` version set to `2.0.0+1`; the build number is raised per upload.
- ASSUMPTION: Only `app_en.arb` exists on `main` (TASK-03 adds `app_gu.arb`), so `configErrorBody` was added to `app_en.arb` only; Gujarati text for the integrator: "આ બિલ્ડ ખોટી રીતે ગોઠવાયેલ છે. કૃપા કરીને Play પરથી નવીનતમ વર્ઝન ઇન્સ્ટોલ કરો."
- ASSUMPTION: The privacy and deletion pages carry both languages on one URL each (`/privacy/`, `/delete-account/`, anchors `#en`/`#gu`); the grievance email is a visible placeholder (`data-todo`) and `scripts/check-site.mjs --release` fails until it and the draft banner are resolved.

## 6. Implementation Steps

1. **R2 driver.** `src/lib/storage/r2.ts` per §5.3; `storageFor(driver)` factory and per-row resolution in photo reads; config validation by driver; remove the v1 R2 refusal. Extend `scripts/check-storage.ts` (`storage:check`) to run against the configured driver.
2. **Storage contract tests.** One shared suite run against `LocalPhotoStorage` and `R2PhotoStorage` (MinIO via `R2_ENDPOINT` in CI: a `docker run -d minio/minio server /data` step); plus unit tests with a mocked S3 client for error mapping.
3. **Production hardening in the API.** `DEPLOY_ENV`; helmet HSTS when `APP_ENV=production`; `TRUST_PROXY` semantics documented; Sentry init + `beforeSend` scrubber in `src/lib/errors/report.ts` (no-op without DSN); pino-roll daily/14 in production; `POST /api/v1/admin/__test-error` (admin token, only when `DEPLOY_ENV=staging`) throws a test error for M-13-06.
4. **Retention job.** `scripts/retention.ts` + `retention:run` per §5.2 (batching, dry-run, per-rule output, audit entry, exit codes). Tests T-13-04…06.
5. **Container image.** `apps/api/Dockerfile` (multi-stage, Node 20 slim, `npm ci --omit=dev` plus Prisma CLI for `migrate deploy`, non-root user, `tsc` build to `dist/`, `CMD node dist/server.js`), `.dockerignore`; `build` and `start:prod` scripts. Image `ghcr.io/<owner>/saarthee-api:<sha>`.
6. **Provision (per environment, staging first).** DO project, VPC, Droplet, managed PostgreSQL (trusted source: the Droplet only; `sslmode=require`), `CREATE EXTENSION postgis`; R2 buckets `saarthee-<env>-photos`, `saarthee-<env>-backups` (private) with scoped API tokens; Cloudflare DNS (proxied), SSL Full (strict) with a Cloudflare Origin CA certificate on Caddy, Always Use HTTPS, min TLS 1.2, HSTS; DO cloud firewall (443 from Cloudflare ranges, 22 from admin IPs). Record every resource in `docs/ops/environments.md` (names, regions, sizes, monthly cost) — no secrets.
7. **Host setup.** `infra/deploy/` with `compose.yml` (services `api`, `caddy`; API not published), `Caddyfile`, `deploy.sh <sha>` (pull → `prisma migrate deploy` in a one-off container → `up -d` → poll `/health` 60 s → roll back to the previous tag on failure), systemd units/timers `saarthee-backup` (02:00 IST), `saarthee-retention` (03:00 IST), `saarthee-photo-mirror` (02:30 IST); secrets in `/etc/saarthee/api.env` (mode 600). Unattended security upgrades on.
8. **CI/CD.** `.github/workflows/deploy.yml`: build + push image on `main` after CI; job `staging` auto; job `pilot` on `workflow_dispatch` with environment approval; SSH via a deploy key secret; post-deploy smoke (`curl -fsS https://api-staging.<domain>/api/v1/health`).
9. **Seed staging.** Run migrations + v2 dev seed (fictional data only) on staging; `geo:import` (TASK-02) when available. Pilot gets migrations + reference data only (categories/wards by their tasks), never the dev seed.
10. **Backups.** `infra/deploy/backup.sh`: `pg_dump -Fc` (client from `postgis/postgis:17-3.5`) → `age -r <pubkey>` → `rclone copyto` to the backup bucket → Healthchecks ping; R2 lifecycle rules; confirm managed backups/PITR enabled. Photo protection per §5.6.
11. **Restore drill.** Follow `docs/ops/backup-restore.md`: decrypt the latest staging dump, restore into a fresh managed database (or DO "restore from backup" into a new cluster), `prisma migrate status`, compare row counts with the source, point a temporary API container at it and run `/health` + a photo read restored from the backup bucket; record times (RPO/RTO), commands and result in `docs/ops/restore-drill.md`; repeat on pilot before launch.
12. **Monitoring.** UptimeRobot monitors for both health URLs (5 min, alert after 2 failures, email to founder + build lead); Healthchecks for backup/retention/mirror timers; Sentry project per environment; test alert: stop the API on staging and confirm the email; throw a test error and inspect the event for PII.
13. **Cleartext removal.** Delete `apps/mobile/android/app/src/profile/res/xml/network_security_config.xml` and the `networkSecurityConfig` attribute in `src/profile/AndroidManifest.xml` (keep INTERNET); keep the debug-only config. Check iOS `Info.plist` has no `NSAllowsArbitraryLoads`. Add `apiBaseUrlIsAllowed(url, mode)` in `lib/core/config` with the fatal config screen; add `scripts/check-cleartext.sh` (fails if `cleartextTrafficPermitted="true"` or `usesCleartextTraffic` appears outside `src/debug/`) to CI.
14. **Release signing.** Generate the upload keystore outside the repo (`~/saarthee-keys/`), back it up to the vault; `android/key.properties` (git-ignored); `build.gradle.kts` release `signingConfig` from it and **fail** when missing (remove the debug-signing fallback); version from `pubspec.yaml` (`2.0.0+<n>`). `env/staging.json`, `env/pilot.json` dart-define files (no secrets). Build `flutter build appbundle --release --dart-define-from-file=env/<env>.json`; verify with `apksigner`/`bundletool`.
15. **Play Console.** Create the app, enrol in Play App Signing, upload the first AAB to **internal testing** (team list); hand the app-signing and upload-key SHA-1/SHA-256 to TASK-04 for Firebase; complete store listing (en + gu, independence line), content rating, target audience 18+, ads = none, app access instructions (Firebase test phone number + OTP for reviewers), privacy policy and deletion URLs (Cloudflare Pages from `infra/site/`); fill the **Data safety** form exactly per §5.4; create the **closed testing** track "Pilot – West zone" with a Google Group of testers. Screenshot every submitted page into `docs/ops/play/`.
16. **Docs.** `docs/ops/environments.md`, `deploy.md`, `backup-restore.md`, `restore-drill.md`, `monitoring.md`, `release-android.md`; root `README.md` links.
17. **Manual checks** M-13-01…M-13-10; record evidence in the coverage matrix.

## 7. Acceptance Criteria

### 7.1 Behavioral

**AC-1** — R2 storage behind the interface
- **Given** `STORAGE_DRIVER=cloudflare_r2` with valid `R2_*` variables
- **When** a photo is uploaded through `POST /photos`, read back, checked and deleted, and a traversal key `../x.jpg` is used
- **Then** the object exists in the photos bucket under `photos/<yyyy>/<mm>/<uuid>.jpg`, the row has `storage_driver='cloudflare_r2'`, `open` returns the same bytes, `exists` is true then false after `delete`, deleting a missing key succeeds, the traversal key is refused, and a photo row stored with `local` is still readable through the local driver

**AC-2** — Storage configuration is validated
- **Given** `STORAGE_DRIVER=cloudflare_r2` without `R2_BUCKET`, or `local` without `PHOTO_STORAGE_DIR`
- **When** the API starts
- **Then** it exits non-zero with a message naming the missing variable and printing no secret value

**AC-3** — Staging and pilot run behind HTTPS
- **Given** both environments provisioned
- **When** `curl -I http://api-staging.<domain>/api/v1/health` and `https://…/health` are called, and the Droplet IP is called directly on 443 and 3000
- **Then** HTTP returns 301 to HTTPS; HTTPS returns 200 with `postgis` in the body and an HSTS header; direct-to-origin connections time out (firewall); SSL Labs grade is A or better

**AC-4** — Managed PostGIS database and documented environment
- **Given** the pilot database
- **When** `SELECT postgis_lib_version()` runs and `docs/ops/environments.md` is reviewed
- **Then** PostGIS ≥ 3.4 is installed, all migrations are applied (`prisma migrate status` clean), the DB accepts connections only from the Droplet with TLS, and every environment variable used by the API is listed with purpose, example, secret flag and where it is stored, with no secret values in git

**AC-5** — Client IP and rate limits behind the proxy
- **Given** the staging API behind Cloudflare and Caddy
- **When** 121 `/health` requests are made from one client and 1 from another network in the same minute
- **Then** the first client's 121st request returns 429 and the second client gets 200 (limits keyed on the real client IP, not the proxy)

**AC-6** — Daily backups and photo protection
- **Given** 3 days of operation on staging
- **When** the backup bucket and Healthchecks are inspected
- **Then** there are 3 encrypted dumps under `db/staging/…` that cannot be read without the `age` key, Healthchecks shows 3 on-time pings, managed backups are listed in DO, lifecycle rules are set (35/30 days), and photo protection (native versioning or the nightly mirror with `photos-deleted/`) is active and documented

**AC-7** — Restore drill recorded
- **Given** the latest staging dump and backup photos
- **When** the drill in `docs/ops/backup-restore.md` is followed
- **Then** a fresh database is restored, migrations report up to date, row counts match the source at dump time, a temporary API serves `/health` 200 and one restored photo, and `docs/ops/restore-drill.md` records date, operator, commands, RPO and RTO (target RTO ≤ 4 h); the same drill is recorded for pilot before launch

**AC-8** — Uptime and error alerting without PII
- **Given** monitors configured
- **When** the staging API container is stopped for 15 minutes, and a test error is thrown from a request carrying a phone number in the body, a JWT in `Authorization` and coordinates in the query
- **Then** an email alert arrives within 10 minutes and a recovery email after restart; the Sentry event contains the exception, route template, request id and environment, and none of the phone, token, coordinates, IP or body

**AC-9** — Retention job
- **Given** issues closed 731 days ago (verified, rejected, merged), one `marked_fixed` 738 days ago, one verified 700 days ago, one `reopened` 800 days ago, notifications aged 91 and 89 days, and log files aged 15 and 13 days
- **When** `npm run retention:run -- --dry-run` and then `npm run retention:run` run twice
- **Then** the dry run reports counts and changes nothing; the first real run deletes the objects and sets `deleted_at` only for the 731-day closed issues and the 738-day `marked_fixed` one, deletes only the 91-day notifications and the 15-day log file, writes one audit entry; the second run selects 0; reading a retained-deleted photo returns 410 `PHOTO_DELETED`

**AC-10** — No cleartext outside debug
- **Given** the repository after this task
- **When** `scripts/check-cleartext.sh` runs, the profile and release builds are inspected with `apkanalyzer manifest print`, and a profile build is made with `API_BASE_URL=http://10.0.2.2:3000`
- **Then** the check passes, neither merged manifest has a network security config allowing cleartext or `usesCleartextTraffic=true`, and the profile app shows the fatal config screen instead of making the request

**AC-11** — Signed release and Play tracks
- **Given** the upload key and Play App Signing
- **When** the release AAB is built without `key.properties`, then with it, and uploaded
- **Then** the build without it fails with a clear message; with it `apksigner verify` shows the upload certificate; the AAB is live on internal testing (staging API) and a pilot build on closed testing "Pilot – West zone"; a tester installs from the opt-in link

**AC-12** — Data safety and policy pages match Spec §11
- **Given** the Play Console submission
- **When** the Data safety answers, privacy notice and deletion page are compared with §5.4 and Spec §11
- **Then** every row matches (screenshots in `docs/ops/play/`), the privacy URL and delete-account URL load over HTTPS in Gujarati and English, and the store listing carries the independence line and no AMC marks

| AC | Requirements |
|---|---|
| AC-1 | REQ-O-004 |
| AC-2 | REQ-O-004, REQ-O-005 |
| AC-3 | REQ-O-005, REQ-S-013 |
| AC-4 | REQ-O-005 |
| AC-5 | REQ-O-005, REQ-S-013 |
| AC-6 | REQ-O-006 |
| AC-7 | REQ-O-006 |
| AC-8 | REQ-O-007 |
| AC-9 | REQ-S-014 |
| AC-10 | REQ-S-013 |
| AC-11 | REQ-O-008 |
| AC-12 | REQ-O-008 |

### 7.2 Non-Functional Checklist

- [ ] No secret (DB URL, R2 keys, Sentry DSN, keystore, passwords) in git, CI logs, images or docs (`git log -p | grep` spot checks; `docker history` clean)
- [ ] API container runs as non-root; only Caddy publishes ports; Droplet password SSH disabled
- [ ] DB connections use TLS; DB trusted sources restricted to the Droplet
- [ ] Logs in staging/pilot contain no phone numbers, tokens, coordinates or request bodies (grep a day of logs)
- [ ] Deploy rolls back automatically when `/health` fails after a release (tested once on staging with a broken image)
- [ ] Monthly cost recorded in `docs/ops/environments.md` and within the founder's budget
- [x] Every scheduled job has a heartbeat and a documented manual run command (docs/ops/deploy.md §Timers)
- [ ] Release build size and minification recorded; no debug flags (`debuggable=false`)
- [ ] Privacy notice and deletion page reviewed against Spec §11; legal review status recorded (Open Question 6)

## 8. Validation & Testing

| Level | ID | What to test | Proves |
|---|---|---|---|
| Static | S-13-01 | API `typecheck`, `lint`; `dart analyze`; `scripts/check-cleartext.sh` in CI; `docker build` succeeds in CI | AC-10 |
| API integration | T-13-01 | `storage-contract.test.ts`: same suite for local and R2 (MinIO) — save/open/exists/delete, missing delete ok, traversal refused | AC-1 |
| API integration | T-13-02 | `storage-r2.test.ts` (mocked S3 client): `NoSuchKey`/404 mapping, timeout surfaced as `SERVICE_UNAVAILABLE`, per-row driver resolution | AC-1 |
| API integration | T-13-03 | `config.test.ts`: driver-specific required variables; error text names the variable, never the value | AC-2 |
| API integration | T-13-04 | `retention.test.ts` › photos: AC-9 fixtures (statuses, ages, legacy) → only qualifying photos deleted, `deleted_at` set, storage delete called, failures counted and exit 1 | AC-9 |
| API integration | T-13-05 | `retention.test.ts` › notifications + logs: table absent → skipped; present → only > 90 days deleted; temp log dir → only > 14-day file removed | AC-9 |
| API integration | T-13-06 | `retention.test.ts` › dry run + idempotency + audit entry + photo read → 410 | AC-9 |
| API integration | T-13-07 | `error-scrub.test.ts`: event with phone/JWT/coords/body/IP/headers → scrubbed fields absent, allow-listed fields present | AC-8 |
| API integration | T-13-08 | `proxy.test.ts`: `APP_ENV=production` → HSTS header; with `TRUST_PROXY=true` and `X-Forwarded-For` set, limiter keys on that IP (two IPs, separate budgets) | AC-3, AC-5 |
| Flutter unit | F-13-01 | `config_test.dart`: `apiBaseUrlIsAllowed` — https ok in all modes; http rejected in profile/release, allowed only for 10.0.2.2/localhost in debug | AC-10 |
| Manual | M-13-01 | Staging: `curl -I` HTTP/HTTPS, direct origin IP, SSL Labs report saved | AC-3 |
| Manual | M-13-02 | Pilot + staging DB: `postgis_lib_version()`, `prisma migrate status`, trusted-source test from a laptop (refused); run the API test suite once against a scratch DB on the managed cluster | AC-4 |
| Manual | M-13-03 | Rate limit from two networks (laptop + phone hotspot) | AC-5 |
| Manual | M-13-04 | After 3 days: list backup objects, try to open one without the key, Healthchecks history, DO backups, lifecycle rules, photo protection | AC-6 |
| Manual | M-13-05 | Restore drill on staging (then pilot before launch); fill `restore-drill.md` | AC-7 |
| Manual | M-13-06 | Stop the staging API 15 min → alert + recovery emails; trigger `/__test-error` (staging only, admin-guarded) → inspect Sentry event | AC-8 |
| Manual | M-13-07 | Staging retention dry run with seeded old data; then real run; check counts and audit row | AC-9 |
| Manual | M-13-08 | Build profile APK with an http URL → fatal screen; `apkanalyzer manifest print` for profile and release | AC-10 |
| Manual | M-13-09 | AAB build without/with `key.properties`; `apksigner verify --print-certs`; internal track upload; closed track opt-in install on a second device | AC-11 |
| Manual | M-13-10 | Data safety, listing, privacy and deletion pages compared row by row with §5.4; screenshots saved | AC-12 |

## 9. Deliverables

- `R2PhotoStorage`, driver factory, config validation, extended `storage:check`.
- Production Dockerfile, `infra/deploy/` (compose, Caddyfile, deploy/backup/mirror scripts, systemd timers), GitHub deploy workflow with environment approvals.
- Staging and pilot environments live on HTTPS with managed PostgreSQL + PostGIS and R2 buckets.
- Retention job and schedule; Sentry scrubber; HSTS and proxy settings.
- Backups (managed + encrypted dumps), photo protection, restore drill record.
- Uptime monitors, job heartbeats, error alerting.
- Cleartext exception removed, HTTPS guard in app config, CI cleartext check.
- Release signing, Play internal + closed testing tracks, store listing, Data safety form, privacy and deletion pages.
- Ops docs under `docs/ops/`; coverage matrix evidence for 7 requirements.

## 10. Files Expected to Change

Prediction only — exact paths may differ.

| Path | Change |
|---|---|
| `apps/api/src/lib/storage/{index,r2}.ts`, `src/config/index.ts`, `src/app.ts`, `src/lib/errors/report.ts`, `src/lib/logger/` | New / Modified |
| `apps/api/scripts/{retention,check-storage}.ts`, `apps/api/package.json`, `package-lock.json` | New / Modified |
| `apps/api/Dockerfile`, `.dockerignore`, `tsconfig.build.json` | New |
| `apps/api/test/{storage-contract,storage-r2,config,retention,error-scrub,proxy}.test.ts` | New |
| `infra/deploy/**` (compose, Caddyfile, `deploy.sh`, `backup.sh`, `photo-mirror.sh`, systemd units) | New |
| `infra/site/` (privacy and delete-account pages, en + gu) | New |
| `.github/workflows/{ci,deploy}.yml`, `scripts/check-cleartext.sh` | New / Modified |
| `apps/mobile/android/app/src/profile/AndroidManifest.xml`, `src/profile/res/xml/network_security_config.xml` (deleted) | Modified / Deleted |
| `apps/mobile/android/app/build.gradle.kts`, `android/.gitignore` (`key.properties`) | Modified |
| `apps/mobile/lib/core/config/`, `lib/core/l10n/app_en.arb`, `app_gu.arb`, `env/{staging,pilot}.json`, `test/core/config_test.dart` | New / Modified |
| `docs/ops/{environments,deploy,backup-restore,restore-drill,monitoring,release-android}.md`, `docs/ops/play/` | New |
| `README.md` | Modified |

## 11. Related Documentation

- Spec §2 D12 — deployment shape for the pilot
- Spec §11 — retention, notices, public display rule, under-18 block (Data safety inputs)
- Spec §12 — environments, storage, backups, monitoring, release sequence
- `docs/05-devops-infrastructure.md` (v1) — env var conventions, cleartext rule REQ-S-028 history
- `docs/tasks-v2/TASK-01-platform-upgrade.md` — PostGIS migrations, health, test harness
- `docs/tasks-v2/TASK-04-*.md` — Firebase SHA fingerprints (REQ-O-003) consuming this task's signing certificates
- `docs/tasks-v2/TASK-14-e2e-launch.md` — L8/L9 launch checks that rely on this task
- `docs/tasks-v2/00-task-summary.md` — Open Questions 3 (accounts) and 6 (legal review)

## 12. Risks & Considerations

| Risk | Impact | Mitigation |
|---|---|---|
| Founder accounts (Play, domain, cloud billing) not ready | Task blocked | Request in week 1; provision staging on build-lead account and transfer if needed |
| Lost upload keystore | Cannot ship updates without Play support reset | Play App Signing (Google holds signing key); keystore backed up in vault; reset procedure in `release-android.md` |
| Managed PostGIS version differs from CI | Subtle query differences | Run the suite once against the managed version (M-13-02); pin CI to the same minor if needed |
| Proxy misconfiguration makes all users share one IP | Rate limits lock out the city | T-13-08 + M-13-03 two-network check before pilot |
| Error tracker leaks PII | DPDP breach | Strict allow-list scrubber + test; staging inspection before enabling on pilot |
| Retention job deletes the wrong photos | Evidence lost | Dry run first on staging and pilot; per-rule counts reviewed; mirror keeps deleted objects 30 days |
| Backups exist but never restored | False safety | Recorded drills on staging and pilot (AC-7) before TASK-14 sign-off |
| Data safety form drifts from later features | Play policy strike | §5.4 table is the source; TASK-14 re-checks; any task adding data collection updates it |
| Single-node DB/VM outage | Pilot downtime | Uptime alerts, PITR, documented rebuild from image + backups; acceptable for pilot scale |

## 13. Progress Status

**Current status:** In Review — repo and local parts done and verified; live environments and Play are founder-blocked (Deferred below); M-13-08 needs the integrator.

**Progress:** 70% (all code, scripts, configs, pages and runbooks; local verification; the remaining 30% is provisioning, Play and the manual checks on real environments)

| Date | Progress | Commit |
|---|---|---|
| 2026-10-04 | R2 driver, `storageFor` per-row resolution, driver-specific config validation, `storage:check` on configured driver; T-13-01 (local + MinIO), T-13-02, T-13-03 | f833368 |
| 2026-10-04 | HSTS in production, Sentry + allow-list scrubber, staging-only `/admin/__test-error`; T-13-07, T-13-08 | 4e3cf30 |
| 2026-10-04 | `retention:run` (closed/legacy photos, notifications, logs, unattached) with dry run, counts, audit line; T-13-04…06 | 532e1ee |
| 2026-10-04 | Production API image (multi-stage, non-root uid 10001, tini, HEALTHCHECK), `tsconfig.build.json`, `build`/`start:prod` | 71625e1 |
| 2026-10-04 | `infra/deploy` compose (api, caddy, `local-db` profile), Caddy image, backup/restore scripts, local restore drill — stack verified on 127.0.0.1:4100 (DB 5440), `/health` 200 through Caddy, torn down | 3b4276e |
| 2026-10-04 | `deploy.sh` (rollback rehearsed), `photo-mirror.sh` (tested on MinIO), `retention.sh`, systemd timers, journald 14 d, `install-host.sh` | 0ee658b |
| 2026-10-04 | `infra/site` privacy + delete-account (en + gu, independence line, draft), brand favicon/og image, `_headers`, `scripts/check-site.mjs` | a45c211 |
| 2026-10-04 | Mobile: profile cleartext removed, `apiBaseUrlIsAllowed` + fatal config screen, release signing from key.properties, env files, `check-cleartext.sh`; F-13-01 | ac3d950 |
| 2026-10-04 | CI `ops` job + MinIO in the api job; `deploy.yml` (staging auto, pilot approval) | e29e31e |
| 2026-10-04 | `docs/ops/*` runbooks, README links, `.env.example` | 7b5fa51 |

### Deferred (founder-blocked)

| Item | Deferred — needs |
|---|---|
| Steps 6, 9; AC-3, AC-4, AC-5; M-13-01…03 | Founder: DigitalOcean team account with billing (Droplets + Managed PostgreSQL 17 in BLR1), a domain added to Cloudflare, GitHub environments `staging`/`pilot` with secrets — then follow `docs/ops/deploy.md` §Host setup |
| Step 10–11; AC-6, AC-7; M-13-04, M-13-05 | Founder: Cloudflare R2 buckets + scoped tokens, offline `age` key pair (public key to `backup.env`), DO managed backups on; then 3 days of backups and the staging/pilot drills in `docs/ops/restore-drill.md` |
| Step 12; AC-8; M-13-06, M-13-07 | Founder: UptimeRobot, Healthchecks.io and Sentry accounts; staging URL |
| Steps 14–15; AC-11, AC-12; M-13-09, M-13-10 | Founder: Play Console developer account, upload keystore generated into the vault, Pages site on the domain, grievance email, legal + native Gujarati review (Open Question 6). Integrator: `flutter build appbundle` with/without `key.properties`, `apksigner verify` |
| Real Firebase project | TASK-04 / founder (this task only hands over SHA fingerprints once Play App Signing exists) |

### Blocked > 10 min (logged)

- Docker Desktop hung starting containers with bind mounts from `~/Documents` (likely a macOS privacy prompt); worked around by baking the Caddy config into an image. `docker rm`/`start` of the stuck container recovered on its own after the CLI processes were killed.

## 14. Completion Checklist

- [ ] All implementation steps complete — repo/local steps 1–5, 7, 8, 10 (scripts), 13, 14 (config), 16 done; 6, 9, 11, 12, 15, 17 Deferred (founder)
- [ ] All behavioral acceptance criteria verified in the running application
- [ ] Non-functional checklist fully ticked
- [x] Static checks pass (tsc, eslint, dart analyze, dart format, check-cleartext, check-site, shellcheck, docker build); ACs needing live environments Deferred
- [x] Automated tests added and passing — API 104 pass / 2 skipped (the 4 R2 contract tests skip without R2_TEST_ENDPOINT; they passed against MinIO in a focused run), Flutter 6 pass
- [ ] Frontend and backend integrated end to end (no mocked data left in place)
- [ ] Error, loading, empty, and unauthorized states verified
- [x] Code reviewed against the patterns established in earlier tasks
- [x] Assumptions documented (§5.6); provider choices await founder confirmation
- [x] Coverage matrix rows set (2 Pass, 5 Deferred with exact founder actions; `check_coverage.py --task TASK-13` shows 0 unverified)
- [x] Task file progress log and status updated
- [ ] `00-task-summary.md` updated
- [x] Committed as `V2-TASK-13: …`
- [ ] Validator passes
