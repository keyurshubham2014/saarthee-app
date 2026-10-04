# Environments and configuration

V2 TASK-13 (REQ-O-005). No secret values in this file or anywhere in git. Secrets live in the founder's
password-manager vault, in `/etc/saarthee/*.env` (mode 600) on each host, and in GitHub environment secrets.

## Environments

| | Local | Staging | Pilot |
|---|---|---|---|
| Purpose | Development, tests | Every merge to `main`; Play internal testing | Pilot residents; Play closed testing |
| API URL | `http://10.0.2.2:4000/api/v1` (emulator) | `https://api-staging.<domain>/api/v1` | `https://api.<domain>/api/v1` |
| Compute | Laptop | DO Droplet `s-1vcpu-1gb`, BLR1, Ubuntu 24.04 | DO Droplet `s-1vcpu-2gb`, BLR1, Ubuntu 24.04 |
| Database | Docker PostGIS (`infra/docker-compose.yml`) | DO Managed PostgreSQL 17 + PostGIS, 1 GB, BLR1 | same, separate cluster |
| Photos | `local` driver, folder outside repo | R2 `saarthee-staging-photos` | R2 `saarthee-pilot-photos` |
| Backups | — | R2 `saarthee-staging-backups` + DO managed backups | R2 `saarthee-pilot-backups` + DO managed backups (PITR) |
| Seed | Dev seed | Dev seed (fictional data only) | Migrations + reference data only — never the dev seed |
| Deploy | — | Auto after green CI on `main` | Manual, GitHub environment approval |

**Status: Deferred — needs the founder to open the DigitalOcean team (billing), choose and add the domain to
Cloudflare, and create the R2 buckets/tokens** (Open Question 3). Everything below is ready to apply; record
real resource names, IDs and the monthly bill here once provisioned.

### Resources to record after provisioning (no secrets)

| Resource | Staging | Pilot | Monthly cost (USD, estimate — verify) |
|---|---|---|---|
| DO project / VPC | `saarthee-staging` / `vpc-blr1-saarthee` | `saarthee-pilot` / same VPC | 0 |
| Droplet | `saarthee-staging-1` | `saarthee-pilot-1` | 6 + 12 |
| Managed PostgreSQL 17 | `saarthee-staging-db` (1 GB) | `saarthee-pilot-db` (1 GB) | 15 + 15 |
| R2 buckets | `saarthee-staging-photos`, `-backups` | `saarthee-pilot-photos`, `-backups` | ~0–2 (10 GB free) |
| Cloudflare | DNS, proxy, Origin CA, Pages (free plan) | | 0 |
| Monitoring | UptimeRobot, Healthchecks.io, Sentry (free plans) | | 0 |
| **Total** | | | **≈ 50** (D12 budget; confirm with founder) |

Network rules: DO cloud firewall — 443 from Cloudflare IP ranges only (https://www.cloudflare.com/ips/,
same list as `infra/deploy/Caddyfile`), 22 from the build lead's and founder's IPs only, everything else
denied. Managed DB trusted source = the Droplet only; connections require TLS (`sslmode=require`).
Cloudflare: proxied DNS, SSL **Full (strict)** with an Origin CA certificate on Caddy, Always Use HTTPS,
minimum TLS 1.2, HSTS (6 months, include subdomains).

## API variables (`/etc/saarthee/api.env`; template `infra/deploy/api.env.example`)

| Variable | Purpose | Example | Secret | Where stored |
|---|---|---|---|---|
| `APP_ENV` | `production` turns on HSTS and production behaviour | `production` | No | api.env |
| `DEPLOY_ENV` | `local`/`staging`/`pilot`; labels error events; enables `/admin/__test-error` on staging only | `staging` | No | api.env |
| `API_HOST` / `API_PORT` | Listen address inside the container (compose forces `0.0.0.0:3000`) | `0.0.0.0` / `3000` | No | api.env |
| `DATABASE_URL` | Managed PostgreSQL, TLS required | `postgresql://saarthee_app:…@host:25060/saarthee?sslmode=require` | **Yes** | vault, api.env |
| `JWT_SECRET` | Signs admin/citizen tokens (≥ 32 bytes) | `openssl rand -base64 48` | **Yes** | vault, api.env |
| `JWT_ISSUER` / `JWT_AUDIENCE` / `JWT_EXPIRES_IN` | Token claims and lifetime | `saarthee-api` / `saarthee-admin` / `8h` | No | api.env |
| `STORAGE_DRIVER` | `local` or `cloudflare_r2` (new photos); reads use each row's driver | `cloudflare_r2` | No | api.env |
| `PHOTO_STORAGE_DIR` | Required for `local`; absolute, outside the repo | `/data/photos` | No | api.env |
| `R2_ACCOUNT_ID` | Cloudflare account id (R2 endpoint) | `abc123…` | No | api.env |
| `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` | R2 API token scoped to the photos bucket (Object Read & Write) | — | **Yes** | vault, api.env |
| `R2_BUCKET` | Private photos bucket | `saarthee-staging-photos` | No | api.env |
| `R2_ENDPOINT` | Override endpoint (tests: MinIO) | `http://127.0.0.1:9000` | No | tests only |
| `PHOTO_MAX_UPLOAD_BYTES` / `PHOTO_MAX_EDGE_PX` | Upload limits | `5242880` / `2048` | No | api.env |
| `UNATTACHED_PHOTO_TTL_HOURS` | Orphan photo cleanup age | `24` | No | api.env |
| `REMINDER_INTERVAL_DAYS`, `VERIFY_LINK_BASE`, `VERIFY_DISTANCE_WARN_M`, `CONSENT_TEXT_VERSIONS`, `REMINDER_TEMPLATE_VERSION` | v1 pilot features (read-only history) | see template | No | api.env |
| `CORS_ORIGINS` | Allowed browser origins (web console) | `https://console.<domain>` | No | api.env |
| `TRUST_PROXY` | `true` behind Caddy: client IP from `X-Forwarded-For` (set by Caddy from `CF-Connecting-IP`) | `true` | No | compose (forced) |
| `LOG_LEVEL` / `LOG_FILE_DIR` | Logging; files rotate daily, 14 kept | `info` / `/data/logs` | No | api.env |
| `SENTRY_DSN` | Error alerting; empty = off; events scrubbed (`src/lib/errors/scrub.ts`) | `https://…@o0.ingest.sentry.io/0` | Semi (allows sending events) | vault, api.env |
| `SENTRY_TRACES_SAMPLE_RATE` | Performance tracing | `0` | No | api.env |
| `RETENTION_CLOSED_PHOTO_DAYS` | Photos of closed issues | `730` | No | api.env |
| `RETENTION_NOTIFICATION_DAYS` | Notification rows | `90` | No | api.env |
| `RETENTION_LOG_DAYS` | Log files | `14` | No | api.env |
| `REOPEN_WINDOW_DAYS` | Reopen window after `marked_fixed` (shared with TASK-06) | `7` | No | api.env |
| `APP_RELEASE` | Image build arg (git sha) shown in error events | `3b4276e…` | No | image |
| `SEED_ADMIN_EMAIL` / `SEED_ADMIN_PASSWORD` | Seed/admin:create only; remove after use | — | **Yes** | never on pilot |

## Host ops variables (`/etc/saarthee/backup.env`, `/etc/saarthee/deploy.env`)

| Variable | Purpose | Secret |
|---|---|---|
| `DEPLOY_ENV` | Backup object prefix `db/<env>/…` | No |
| `AGE_RECIPIENT` | Founder's **public** age key (`age1…`); the private key never touches a server | No |
| `BACKUP_REMOTE` / `PHOTOS_REMOTE` | rclone remotes, e.g. `r2:saarthee-staging-backups` / `r2:saarthee-staging-photos` | No |
| `RCLONE_CONFIG_R2_*` | rclone S3 remote for R2 (provider Cloudflare, endpoint, backup-scoped token) | **Yes** |
| `HEALTHCHECKS_URL_BACKUP` / `_MIRROR` / `_RETENTION` | Heartbeat ping URLs | Semi |
| `IMAGE_REPO` / `CADDY_REPO` / `SITE_ADDRESS` | `deploy.sh` image names and hostname | No |

## GitHub (Settings → Environments `staging`, `pilot`)

Secrets `DEPLOY_SSH_KEY` (deploy user's ed25519 key; sudo limited to `/opt/saarthee/deploy.sh`) and
`DEPLOY_KNOWN_HOSTS`; variables `DEPLOY_HOST`, `DEPLOY_USER`, `API_HOSTNAME`. Environment `pilot` has a
required reviewer (founder or build lead). GHCR images: `ghcr.io/<owner>/saarthee-api`, `…/saarthee-caddy`.

## App build defines

`apps/mobile/env/staging.json` and `pilot.json` (`--dart-define-from-file`): `APP_ENV`, `API_BASE_URL`
(must be `https://` — release/profile builds refuse anything else), `DEEP_LINK_SCHEME`, `APP_VERSION`. No secrets.
