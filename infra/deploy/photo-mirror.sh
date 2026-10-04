#!/usr/bin/env bash
# Nightly photo protection (V2 TASK-13 §5.6 "R2 versioning" fallback; REQ-O-006).
# Mirrors the private photo bucket into the backup bucket. Objects that were replaced or deleted since the
# last run (retention, anonymisation, accidents) are moved to photos-deleted/<date>/ instead of being lost;
# an R2 lifecycle rule purges photos-deleted/ after 30 days, which keeps the retention promise.
# If native R2 object versioning is enabled instead, disable the saarthee-photo-mirror timer and record it
# in docs/ops/backup-restore.md.
# Config (/etc/saarthee/backup.env): DEPLOY_ENV, PHOTOS_REMOTE (r2:saarthee-<env>-photos),
#   BACKUP_REMOTE (r2:saarthee-<env>-backups), HEALTHCHECKS_URL_MIRROR (optional).
set -euo pipefail
[[ -f /etc/saarthee/backup.env ]] && set -a && . /etc/saarthee/backup.env && set +a
: "${DEPLOY_ENV:?}" "${PHOTOS_REMOTE:?set PHOTOS_REMOTE}" "${BACKUP_REMOTE:?set BACKUP_REMOTE}"
HC="${HEALTHCHECKS_URL_MIRROR:-}"
ping_hc() { [[ -n "$HC" ]] && curl -fsS -m 10 --retry 3 -o /dev/null "$HC$1" || true; }
ping_hc /start

day="$(date -u +%Y-%m-%d)"
if rclone sync "$PHOTOS_REMOTE/photos" "$BACKUP_REMOTE/photos-mirror/photos" \
  --backup-dir "$BACKUP_REMOTE/photos-deleted/$day" \
  --s3-no-check-bucket --fast-list --checksum --transfers 8 --stats-one-line --stats 0 --log-level NOTICE; then
  echo "photo-mirror: ok env=${DEPLOY_ENV} day=${day}"
  ping_hc ""
else
  echo "photo-mirror: FAILED" >&2
  ping_hc /fail
  exit 1
fi
