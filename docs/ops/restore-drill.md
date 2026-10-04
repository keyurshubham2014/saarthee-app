# Restore drill record

V2 TASK-13 AC-7 / M-13-05. One row per drill; the staging and pilot drills must both be recorded before
TASK-14 sign-off. Procedure: `docs/ops/backup-restore.md`.

| # | Date (IST) | Environment | Operator | Source | Target | RPO | RTO (restore time) | Checks | Result |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 2026-10-04 | **local** (prod compose stack, `local-db` profile) | W-OPS (agent) | `backup.sh` encrypted dump (94 KB, `db/local/2026/10/saarthee-local-20261004T062354Z.dump.age`) | new database `saarthee_restore_drill` (same PostGIS 3.6 container) | 0 (dump taken at drill start) | restore 1 s; whole drill < 30 s | dump unreadable without key ✔; 17/17 migrations ✔; PostGIS ✔; row counts equal (users 6, issues 23, photos 33, complaints 11, categories 14) ✔; temporary API `/health` 200 on restored DB ✔ | **Pass** (local rehearsal only) |
| 2 | — | staging | — | latest R2 dump | new managed DB | — | — | — | **Deferred — needs staging provisioned (DO + Cloudflare R2, founder accounts) and the founder's age key** |
| 3 | — | pilot | — | latest R2 dump | new managed DB | — | — | — | **Deferred — needs pilot provisioned; run before launch** |

## Drill 1 commands (local)

```bash
cd infra/deploy
docker compose -f compose.yml --env-file local.env --profile local-db up -d
docker exec -e APP_ENV=development -e SEED_ADMIN_EMAIL=… -e SEED_ADMIN_PASSWORD=… \
  saarthee-prodlocal-api-1 node dist/prisma/seed/index.js         # fictional seed data
./drill-local.sh
```

Output (abridged):

```
backup: ok env=local bytes=94487 seconds=0 dest=…/db/local/2026/10/saarthee-local-20261004T062354Z.dump.age
not readable without the key: ok
restore: ok seconds=1
row counts match
restored API /health: 200 {"status":"ok","db":"up","postgis":"3.6.4"}
DRILL PASS: encrypted backup restored, row counts match, API healthy on the restored database
```

Photo restore was not part of the local drill (local photos live in a Docker volume, not in R2). The photo
mirror was exercised separately against MinIO: a deleted object moved to `photos-deleted/<date>/` and the
remaining object stayed in `photos-mirror/` (2026-10-04).

## Template for staging / pilot

- Date, operator, environment; dump object name and its timestamp (RPO = incident/drill start − dump time)
- Commands run (copy from the terminal, no secrets)
- Source row counts at dump time vs restored counts
- `prisma migrate status` output; `postgis_lib_version()`
- Temporary API `/health` response; restored photo id and sha256 match
- Start/end times → RTO; problems found and fixes made to the runbook
