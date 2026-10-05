#!/usr/bin/env bash
# Deploy a new image on the server.
# Usage: scripts/deploy.sh [IMAGE_TAG]
#   IMAGE_TAG — tag from the GitHub Actions summary; if omitted, CUSTOM_TAG from .env is used.
set -euo pipefail

ERP_DIR="${ERP_DIR:-/opt/erp}"
cd "$ERP_DIR"

env_value() { grep -E "^$1=" .env | tail -1 | cut -d= -f2-; }

if [ -n "${1:-}" ]; then
  sed -i "s|^CUSTOM_TAG=.*|CUSTOM_TAG=$1|" .env
fi

SITE_NAME="$(env_value SITE_NAME)"
echo "==> Image: $(env_value CUSTOM_IMAGE):$(env_value CUSTOM_TAG), site: $SITE_NAME"

if docker compose ps --status running --services | grep -qx backend; then
  echo "==> Backup before deploy"
  docker compose exec -T backend bench --site "$SITE_NAME" backup
fi

echo "==> Pull"
docker compose pull

echo "==> Up"
docker compose up -d --remove-orphans

echo "==> Migrate"
docker compose exec -T backend bench --site "$SITE_NAME" migrate

echo "==> Prune old images"
docker image prune -f

docker compose ps
