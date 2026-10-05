# erp-deploy

Infrastructure for the ERPNext + Frappe CRM + `myerp` stack at **https://erp.arvum.tech**.

| Component | Version |
|---|---|
| Frappe | v16.36.1 |
| ERPNext | v16.37.0 |
| Frappe CRM | v1.86.0 |
| myerp | `main` of [VladimirFalkov/myerp](https://github.com/VladimirFalkov/myerp) |
| frappe_docker (build tooling) | v4.0.0 |

```
apps.json                      # apps baked into the image (no tokens)
.github/workflows/build.yml    # build image -> ghcr.io/vladimirfalkov/erp
compose/docker-compose.yml     # production stack (Traefik + Let's Encrypt, MariaDB, Redis, Frappe)
compose/.env.example           # template for /opt/erp/.env
scripts/deploy.sh              # backup -> pull -> up -d -> migrate
scripts/backup.sh              # bench backup --with-files + retention
```

## Image build

GitHub Actions builds the image with `frappe_docker/images/layered/Containerfile`.
`apps.json` is passed as a BuildKit secret (`apps_json`), so the token never ends up in image layers;
`.git` directories are removed inside the Containerfile.

Triggers: manual (**Actions → Build image → Run workflow**) or push to `main` touching `apps.json` / the workflow.
After a change in `myerp`, run the workflow manually.

Tags: `ghcr.io/vladimirfalkov/erp:<frappe>-<myerp sha7>-<run>` (immutable) and `:latest`.
The exact tag is shown in the run summary.

### Secrets (erp-deploy → Settings → Secrets and variables → Actions)

| Secret | Value |
|---|---|
| `MYERP_READ_TOKEN` | Fine-grained PAT, repository access: only `myerp`, permission **Contents: Read-only** |

Push to GHCR uses the built-in `GITHUB_TOKEN`.

## Server layout

```
/opt/erp/
  docker-compose.yml   # from compose/
  .env                 # from compose/.env.example, chmod 600
  scripts/deploy.sh
  scripts/backup.sh
```

The server pulls a private GHCR image, so log in once with a classic PAT that has only `read:packages`:

```bash
echo "$GHCR_PAT" | docker login ghcr.io -u VladimirFalkov --password-stdin
```

## First start

```bash
cd /opt/erp
docker compose pull && docker compose up -d
docker compose exec backend bench new-site erp.arvum.tech \
  --mariadb-user-host-login-scope=% --db-root-username root \
  --db-root-password "$DB_PASSWORD" --admin-password '<admin password>' \
  --install-app erpnext --install-app crm --install-app myerp
docker compose exec backend bench --site erp.arvum.tech enable-scheduler
```

Or restore from the local site instead of `new-site` (see "Migration" in the project CLAUDE.md;
`encryption_key` must be copied to the new `site_config.json`).

## Deploy

```bash
/opt/erp/scripts/deploy.sh 16.36.1-abc1234-12   # or without argument to redeploy CUSTOM_TAG from .env
```

Take a Hetzner snapshot before changing Frappe/ERPNext/CRM tags.

## Backups

- Local: cron `0 3 * * * /opt/erp/scripts/backup.sh >> /var/log/erp-backup.log 2>&1`
- Offsite: Frappe **S3 Backup Settings** → Hetzner Object Storage
- VM level: Hetzner Backups / snapshots
