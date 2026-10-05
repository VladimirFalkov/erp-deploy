#!/usr/bin/env bash
# Local Frappe backup (DB + public/private files) with retention.
# Offsite copy goes to S3 via Frappe "S3 Backup Settings" (configured in UI).
# Cron (root): 0 3 * * * /opt/erp/scripts/backup.sh >> /var/log/erp-backup.log 2>&1
set -euo pipefail

ERP_DIR="${ERP_DIR:-/opt/erp}"
cd "$ERP_DIR"

env_value() { grep -E "^$1=" .env | tail -1 | cut -d= -f2-; }
KEEP_DAYS="$(env_value BACKUP_KEEP_DAYS)"
KEEP_DAYS="${KEEP_DAYS:-7}"

echo "==> $(date -Is) backup started"
docker compose exec -T backend bench --site all backup --with-files

echo "==> Removing local backups older than ${KEEP_DAYS} days"
docker compose exec -T backend \
  find sites -path '*/private/backups/*' -type f -mtime "+${KEEP_DAYS}" -print -delete

echo "==> $(date -Is) backup finished"
