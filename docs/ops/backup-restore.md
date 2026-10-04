# Backups and restore

V2 TASK-13 step 10–11, REQ-O-006. Scripts: `infra/deploy/backup.sh`, `restore.sh`, `photo-mirror.sh`,
`drill-local.sh`. Drill records: `docs/ops/restore-drill.md`.

## What is backed up

| Layer | How | Kept | Who can read |
|---|---|---|---|
| Managed PostgreSQL | DigitalOcean daily backups + point-in-time recovery (7 days) — confirm enabled in the DO console | 7 days | DO team (2FA) |
| Own encrypted dumps | `backup.sh` 02:00 IST: `pg_dump -Fc` → `age` (founder's public key) → `r2:saarthee-<env>-backups/db/<env>/<yyyy>/<mm>/saarthee-<env>-<UTC ts>.dump.age` | 35 days (R2 lifecycle on `db/`) | Founder only (offline `age` private key) |
| Photos | Nightly `photo-mirror.sh` 02:30 IST: `rclone sync` photos bucket → `photos-mirror/`, replaced/deleted objects moved to `photos-deleted/<date>/` | Mirror: current; deleted: 30 days (lifecycle on `photos-deleted/`) | Backup token holders |

**Photo protection choice (TASK-14 L8 "R2 versioning on"):** R2 had no S3-style object versioning at the time
of writing, so the nightly mirror with `photos-deleted/` is the equivalent. If native versioning is available
when provisioning, enable it on the photos bucket, disable `saarthee-photo-mirror.timer`, and record that here.

The plaintext dump never touches disk: `pg_dump | age -r … -o file`; restores stream `age -d | pg_restore`.

## R2 setup (per environment) — Deferred: needs the founder's Cloudflare account

1. Buckets `saarthee-<env>-photos` and `saarthee-<env>-backups`, both private (no public access, no r2.dev URL).
2. API token "saarthee-<env>-api": Object Read & Write on the photos bucket only → `R2_*` in `api.env`.
3. API token "saarthee-<env>-backup": Object Read & Write on the backups bucket, Object Read on photos →
   `RCLONE_CONFIG_R2_*` in `backup.env`.
4. Lifecycle rules on the backups bucket: prefix `db/` delete after 35 days; prefix `photos-deleted/`
   delete after 30 days.
5. `age-keygen -o saarthee-backup.agekey` on the founder's offline machine; the private key goes to the vault
   (and a printed copy in a safe); only the `age1…` public key goes into `AGE_RECIPIENT`.

## Backup by hand

```bash
sudo systemctl start saarthee-backup.service && journalctl -u saarthee-backup -n 20
rclone lsl r2:saarthee-staging-backups/db/staging/ | tail -3
```

## Restore (incident or drill)

Never restore over the live database. Restore into a new database or cluster, verify, then repoint.

1. **Choose the source**: managed PITR (fastest, up to the minute; DO console → Restore → new cluster) or the
   latest encrypted dump (independent of DO). For the drill use the dump.
2. **Fresh target**: a new managed cluster or a new database `saarthee_restore_<date>` on the same cluster,
   with `CREATE EXTENSION postgis;`.
3. On a trusted machine holding the age key (founder):
   ```bash
   export TARGET_DATABASE_URL='postgresql://…/saarthee_restore_2026xxxx?sslmode=require'
   export AGE_IDENTITY=~/vault/saarthee-backup.agekey
   infra/deploy/restore.sh r2:saarthee-staging-backups/db/staging/2026/10/saarthee-staging-<ts>.dump.age
   ```
   `restore.sh` refuses a non-empty target and the live `DATABASE_URL`, streams decrypt → `pg_restore
   --exit-on-error`, then prints migration count, PostGIS presence and row counts (users, issues, photos,
   complaints, categories). Compare with the source counts taken at dump time.
4. **Migrations**: `docker run --rm -e DATABASE_URL="$TARGET_DATABASE_URL" ghcr.io/<owner>/saarthee-api:<tag> npx prisma migrate status` → "Database schema is up to date".
5. **Temporary API**: run the image against the restored database (no published port) and call `/health`;
   read one restored photo: copy one object back from `photos-mirror/` to a scratch bucket (or check the
   mirror object's bytes/sha256 against `photos.sha256`).
6. **Cut over** (incident only): put the new `DATABASE_URL` in `/etc/saarthee/api.env`, `deploy.sh <current tag>`,
   check `/health`, then decommission the broken database after 7 days.
7. Record date, operator, commands, timings (RPO = time since the dump; RTO = incident → healthy) in
   `restore-drill.md`. Target RTO ≤ 4 h, RPO ≤ 24 h (dumps) or minutes (PITR).

## Local drill

`infra/deploy/drill-local.sh` runs the whole loop against the `local-db` compose stack with a throwaway age
key: backup → "cannot read without the key" check → restore into `saarthee_restore_drill` → row counts must
match → temporary API on the restored database answers `/health` 200. See `restore-drill.md` for the record.
