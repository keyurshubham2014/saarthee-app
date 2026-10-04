# Monitoring and alerting

V2 TASK-13 step 12, REQ-O-007. Principle: nothing personal leaves the servers — uptime checks see only the
health JSON, heartbeats carry no payload, and error events pass an allow-list scrubber first.

## Hooks in the code (done, tested)

| Hook | Where | Proof |
|---|---|---|
| `GET /api/v1/health` → `{"status":"ok","db":"up","postgis":"…"}`, 503 when the DB is down | TASK-01 health module | T-01 tests; verified through Caddy locally |
| Container health check (30 s) | `apps/api/Dockerfile` `HEALTHCHECK` | `docker ps` shows `(healthy)` |
| Deploy gate: 60 s `/health` poll, automatic rollback | `infra/deploy/deploy.sh` | rehearsed locally |
| Error reporting: Sentry, only when `SENTRY_DSN` is set; default integrations off; `beforeSend` = `scrubEvent` keeps exception type/message/stack, route template, method, status, request id, release, environment; drops body, query, cookies, headers except user-agent, user, IP, extra, contexts; masks phones, JWTs, coordinates | `src/lib/errors/report.ts`, `scrub.ts`, `middleware/errorHandler.ts` | T-13-07 `test/ops/error-scrub.test.ts` |
| Test error: `POST /api/v1/admin/__test-error` (admin token; exists only when `DEPLOY_ENV=staging`) | `src/modules/ops` | T-13-07 / T-13-08 |
| Job heartbeats: `/start`, success, `/fail` pings | `backup.sh`, `photo-mirror.sh`, `retention.sh` | scripts |
| Logs: JSON to stdout (Docker json-file 10 MB × 5) + pino-roll daily files, 14 kept; journald 14 days; Caddy access logs off | logger, compose, `systemd/journald-saarthee.conf` | — |

## Services to configure — Deferred: needs the founder's accounts and the domain

| Service | Setting |
|---|---|
| UptimeRobot (free) | HTTP(s) keyword monitor on `https://api-staging.<domain>/api/v1/health` and `https://api.<domain>/api/v1/health`, keyword `"status":"ok"`, interval 5 min, alert after 2 failures, contacts: founder + build lead email |
| Healthchecks.io (free) | Checks `saarthee-<env>-backup` (period 1 day, grace 2 h), `-mirror`, `-retention`; ping URLs into `/etc/saarthee/backup.env` |
| Sentry (free Developer) | One project per environment (`saarthee-api-staging`, `-pilot`); DSN into `api.env`; in project settings also turn on "Data Scrubber", "Use Default Scrubbers", "Prevent Storing of IP Addresses"; alert rule: new issue → email build lead |

Fallback if the founder rejects a third-party tracker: leave `SENTRY_DSN` empty and add a daily cron that
counts `"level":50` lines in the API logs and emails the count (no log content).

## Manual checks (M-13-06)

1. Stop the staging API: `sudo docker compose -f /opt/saarthee/compose.yml stop api`; wait 15 min → alert
   email within 10 min; `start api` → recovery email.
2. `curl -X POST -H "Authorization: Bearer <admin token>" "https://api-staging.<domain>/api/v1/admin/__test-error?lat=23.02&lng=72.57" -d '{"phone":"+919876543210"}' -H 'Content-Type: application/json'`
   → 500 `INTERNAL_ERROR`; in Sentry the event shows the exception, `route` `/api/v1/admin/__test-error`,
   `requestId`, environment `staging`, and **no** phone, token, coordinates, IP or body.
3. Grep one day of staging logs for phone numbers, `eyJ`, coordinates: `docker logs saarthee-api-1 --since 24h | grep -cE '\+?91[6-9][0-9]{9}|eyJ|[0-9]{2}\.[0-9]{4,},'` → 0.

## Weekly

`npm audit` (existing `audit.yml` workflow), review Sentry issues, `systemctl list-timers 'saarthee-*'`,
check the newest backup object date.
