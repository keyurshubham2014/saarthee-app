# Deploy runbook

V2 TASK-13 steps 5–9. Files: `apps/api/Dockerfile`, `infra/deploy/` (compose, Caddy, scripts, systemd),
`.github/workflows/deploy.yml`. Variables: `docs/ops/environments.md`.

## Shape

```
Internet ─► Cloudflare (DNS, TLS, proxy, HSTS) ─► Droplet :443 (firewall: Cloudflare ranges only)
              └► caddy (Origin CA cert, X-Forwarded-For := CF-Connecting-IP from trusted ranges only)
                   └► api:3000 (internal network only, non-root, read-only rootfs) ─► Managed PostgreSQL (TLS)
                                                                                  └► R2 photos (private)
```

## Local rehearsal of the production stack (verified 2026-10-04)

```bash
docker build -t saarthee-api:local apps/api
docker build -f infra/deploy/caddy.Dockerfile -t saarthee-caddy:local infra/deploy
cd infra/deploy
# local.env: COMPOSE_PROJECT_NAME, API_IMAGE, CADDY_IMAGE, API_ENV_FILE=./api.local.env,
#   CADDYFILE=Caddyfile.local, CADDY_HTTP_BIND=127.0.0.1, CADDY_HTTP_PORT=4100, CADDY_HTTPS_PORT=4143,
#   CERTS_DIR=certs_local, POSTGRES_PASSWORD=<random>, DB_PORT=5440   (both *.env files are git-ignored)
# api.local.env: copy of api.env.example with DEPLOY_ENV=local, STORAGE_DRIVER=local,
#   PHOTO_STORAGE_DIR=/data/photos, DATABASE_URL=postgresql://saarthee:<pw>@db:5432/saarthee
docker compose -f compose.yml --env-file local.env --profile local-db up -d db
docker compose -f compose.yml --env-file local.env --profile local-db run --rm api npx prisma migrate deploy
docker compose -f compose.yml --env-file local.env --profile local-db up -d
curl -i http://127.0.0.1:4100/api/v1/health      # 200, HSTS header, "postgis":"3.x"
./drill-local.sh                                  # backup → restore → counts → API on restored DB
docker compose -f compose.yml --env-file local.env --profile local-db down -v
```

Result on the dev machine: `/health` 200 through Caddy with `Strict-Transport-Security`, `/` → 404, API port
not published; spoofed `X-Forwarded-For`/`CF-Connecting-IP` from a non-Cloudflare peer are ignored (125
requests → 119×200, 6×429, one budget); `storage:check` PASS and `retention:run --dry-run` inside the image;
`deploy.sh` rollback rehearsed (a crashing image tag → health fails 60 s → back to the previous tag, healthy).
Note (macOS): Docker Desktop could not start containers with bind mounts from `~/Documents` (privacy
prompt), which is why the Caddy config is baked into its image.

## Host setup (once per environment) — Deferred: needs the Droplet (founder account)

1. Create the Droplet (Ubuntu 24.04, BLR1, VPC, SSH keys of founder + build lead), attach the cloud firewall.
2. Managed PostgreSQL 17: trusted source = Droplet; `CREATE EXTENSION postgis;` as `doadmin`; create app
   user `saarthee_app` owning database `saarthee`; check `SELECT postgis_lib_version();` ≥ 3.4 (M-13-02).
3. Cloudflare: proxied `A` record `api-staging` → Droplet IP; SSL Full (strict); create an Origin CA cert for
   `api-staging.<domain>` → `/etc/saarthee/certs/origin.pem` + `origin.key` (mode 600).
4. `git clone` (or copy) `infra/deploy` to the host, then `sudo ./install-host.sh` (Docker, age, rclone,
   unattended upgrades, password SSH off, timers, journald 14 days).
5. Create `/etc/saarthee/api.env` (from `api.env.example`), `backup.env`, `deploy.env` (mode 600).
6. Deploy user: `adduser --disabled-password deploy`; its key in `authorized_keys`; sudoers line
   `deploy ALL=(root) NOPASSWD: /opt/saarthee/deploy.sh`; `docker login ghcr.io` as root with a read-only PAT.
7. First deploy: `sudo /opt/saarthee/deploy.sh <tag>`; staging only: seed fictional data with
   `docker compose -f /opt/saarthee/compose.yml exec -e APP_ENV=development -e SEED_ADMIN_EMAIL=… -e SEED_ADMIN_PASSWORD=… api node dist/prisma/seed/index.js`.
   Pilot: migrations + reference data only (`geo:import`, categories — their tasks), never the dev seed.

## Releasing

- **Staging**: merge to `main` → CI green → `Deploy` workflow builds `ghcr.io/<owner>/saarthee-api:<sha12>`
  and `saarthee-caddy:<sha12>` (linux/amd64), SSHes to the host and runs `deploy.sh`, then curls `/health`.
- **Pilot**: Actions → Deploy → Run workflow → target `pilot` (optionally a tag already proven on staging)
  → approve in the `pilot` environment.
- `deploy.sh <tag>`: pull → `prisma migrate deploy` (one-off container) → `up -d` → poll `/health` for 60 s →
  on failure redeploy the previous tag (`/var/lib/saarthee/current-release`). **Migrations are not rolled
  back**: every migration must be backward compatible with the previous release (expand → deploy → contract).
- Manual rollback: `sudo /opt/saarthee/deploy.sh $(cat /var/lib/saarthee/previous-release)`.

## Timers (host, IST)

| Unit | When | Command | Heartbeat |
|---|---|---|---|
| `saarthee-backup.timer` | 02:00 | `/opt/saarthee/backup.sh` | `HEALTHCHECKS_URL_BACKUP` |
| `saarthee-photo-mirror.timer` | 02:30 | `/opt/saarthee/photo-mirror.sh` | `HEALTHCHECKS_URL_MIRROR` |
| `saarthee-retention.timer` | 03:00 | `/opt/saarthee/retention.sh` (`retention:run` in the API container) | `HEALTHCHECKS_URL_RETENTION` |

Manual run: `sudo systemctl start saarthee-backup.service` (logs: `journalctl -u saarthee-backup`).
Retention dry run: `sudo /opt/saarthee/retention.sh --dry-run`. When TASK-06's in-process job runner
schedules retention, disable `saarthee-retention.timer` so it runs once a day only.
