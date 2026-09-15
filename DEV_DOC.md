# Developer Documentation

> Commands below assume `alias dc='docker compose -p inception -f srcs/docker-compose.yaml'`.

## 1. Overview & Layout

Three services, defined in `srcs/docker-compose.yaml`, each built from a custom Dockerfile + entrypoint (no preconfigured application images):

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/{mariadb,wordpress}/*.txt
└── srcs/
    ├── .env
    ├── docker-compose.yaml
    └── requirements/{mariadb,nginx,wordpress}/
```

## 2. Prerequisites

Docker, Docker Compose, Make, Git, a POSIX shell. Docker must be running.

The project needs write access to `/home/ekeisler/data/{mariadb,wordpress}`. If your login/host path differs, update `DATA_DIR` in the `Makefile` and the matching `device` paths in `srcs/docker-compose.yaml`.

## 3. Environment & Secrets

`srcs/.env` (non-sensitive, but still don't commit anything unexpected):

```env
DOMAIN_NAME=<login>.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
```

`DOMAIN_NAME` drives the NGINX TLS cert, the NGINX server block, and the WordPress site URL. Map it locally in `/etc/hosts` (`127.0.0.1 <login>.42.fr`, or the VM's IP).

Four secret files, each one deliberate password, no placeholders/stray bytes:

```text
secrets/mariadb/{db_root_password,db_password}.txt
secrets/wordpress/{wp_admin_password,wp_user_password}.txt
```

Mounted by Compose under `/run/secrets/`; MariaDB reads the DB passwords, WordPress reads the DB + WP account passwords. Never placed in Dockerfiles, `docker-compose.yaml`, build args, or tracked files — verify with:

```bash
git ls-files | grep -iE 'secret|\.env'   # should print nothing
```

## 4. Makefile & Compose

```bash
make help    # list targets
make build   # prepare host dirs + build images
make up      # build (if needed) + start
make down    # stop, keep volumes
make clean   # read the Makefile first — may remove containers/images/networks/volumes
make re      # rebuild + restart (verify exact behavior in the Makefile)
```

Direct Compose equivalents:

```bash
dc build [--no-cache]     # --no-cache only when a change isn't being picked up
dc up -d [--build]
dc config --services      # → mariadb, wordpress, nginx
dc config                 # full resolved config: networks/volumes/secrets/env/ports/restart policies
```

## 5. Network Architecture

- **`backend`** — `internal: true`; connects MariaDB, WordPress, NGINX. Internal flag blocks it as a route to the outside.
- **`frontend`** — NGINX only; publishes `443:443`.

Internal routes: `nginx → wordpress:9000` (PHP-FPM), `wordpress → mariadb:3306`. Neither MariaDB nor WordPress publishes a host port.

## 6. Service Implementations

### NGINX (`srcs/requirements/nginx/Dockerfile`)

Installs nginx, openssl, gettext. Removes Alpine's default config (listens on `80`; this project is HTTPS-only on `443`).

Server config is a template at `srcs/requirements/nginx/conf/wordpress.conf.template` (TLS setup restricted to TLSv1.2/1.3, WP document root, FastCGI to `wordpress:9000`, permalink rewriting, static file handling) containing `${DOMAIN_NAME}`, rendered at container start with:

```bash
envsubst '${DOMAIN_NAME}'   # NOT bare envsubst — that would also mangle nginx vars like $uri, $document_root
```

Entrypoint also generates a self-signed cert for `${DOMAIN_NAME}` on first boot (key `chmod 600`; dev-only, not a trusted prod cert), then runs NGINX as PID 1:

```bash
exec nginx -g "daemon off;"
```

### WordPress (`srcs/requirements/wordpress/Dockerfile`)

PHP-FPM + WP-CLI. Requires the PHP Phar package (`php84-phar` or equivalent for your PHP version) since WP-CLI ships as a `.phar`.

Entrypoint: read secrets → wait for MariaDB → generate `wp-config.php` if absent → install WP + create admin/regular users on first run only (skips if data already exists) → `exec php-fpm84 -F` (foreground, so Docker tracks it as PID 1).

Install must use HTTPS or the site URL will be wrong:

```bash
wp core install --url="https://$DOMAIN_NAME"
```

### MariaDB (`srcs/requirements/mariadb/Dockerfile`)

Pinned version tag (e.g. `mariadb:1.0` — never `latest`).

Entrypoint: read root/app passwords from secrets → initialize DB only if `/var/lib/mysql/mysql` is absent → create DB + app user → `exec mariadbd` (foreground/PID 1). Healthcheck exercises auth against the secret path — watch for stray trailing characters there (e.g. `/run/secrets/db_root_password)z`).

## 7. Volumes

```yaml
driver_opts:
  type: none
  device: /home/ekeisler/data/mariadb   # (or .../wordpress)
  o: bind
```

`db_data` → `/var/lib/mysql`, `wp_data` → `/var/www/html`, backed by `/home/ekeisler/data/{mariadb,wordpress}` (created by the Makefile's `prepare-dirs`). WordPress mounts `wp_data` read-write; NGINX mounts it read-only (it serves but never modifies the files).

```bash
docker volume ls
docker volume inspect db_data
```

Never run `dc down -v` outside a deliberate wipe — it deletes both volumes.

## 8. Container Management

```bash
dc ps / docker ps -a
dc restart [service]
dc up -d --force-recreate [--build service]
docker exec -it <service> sh
```

## 9. Verification & Testing

**Restart policy** — kill PID 1 from inside the container; an external `docker kill` counts as intentional and may not trigger the restart:

```bash
docker exec nginx sh -c 'kill -9 1'; sleep 3
docker inspect nginx --format '{{.State.Status}}'   # → running
```

**Persistence:**

```bash
make down && make up
docker logs wordpress --tail 10   # "wp-config.php already exists, skipping generation"
docker logs mariadb --tail 30 | grep -i init   # no first-run init
```

If it reinitializes, check the volumes, `device` paths in `docker-compose.yaml`, permissions on `/home/ekeisler/data`, and the `prepare-dirs` target.

**WordPress users:**

```bash
docker exec wordpress wp user list --allow-root --fields=user_login,roles
# admin login must not contain admin/Admin/administrator/Administrator
```

**Image tags / secret leaks:**

```bash
docker images --format '{{.Repository}}:{{.Tag}}' | grep ':latest'      # must be empty
docker history wordpress:1.0 --no-trunc | grep -iE "password|secret"    # must be empty
git status --short; git ls-files | grep -iE "secret|\.env"              # must be empty
```

**Full pre-submission pass:**

```bash
make build && make up
dc ps
docker port nginx
curl -k -s -o /dev/null -w "%{http_code}\n" --resolve <login>.42.fr:443:127.0.0.1 https://<login>.42.fr/
docker exec wordpress wp user list --allow-root --fields=user_login,roles
git status --short
git ls-files | grep -iE "secret|\.env"
```

Confirm: all 3 services running, MariaDB healthy, only NGINX on `443`, site returns `200`, TLSv1.2/1.3 accepted, TLSv1.1 rejected, WP users correct, data survives `make down && make up`, no tracked secrets, no `latest` tags.

## 10. Backups

```bash
docker exec mariadb mariadb-dump -u root -p DATABASE_NAME > backup.sql
docker exec -i mariadb mariadb -u root -p DATABASE_NAME < backup.sql
```

Don't commit `backup.sql` if it holds private data.

## 11. Common Problems

| Problem | Fix |
|---|---|
| Host data dir missing | `make prepare-dirs`, or `sudo mkdir -p /home/ekeisler/data/{mariadb,wordpress}` |
| Volume uses wrong host path | Check `device:` under `db_data`/`wp_data` in `dc config` and `docker volume inspect` |
| WordPress can't reach MariaDB | Use service name `mariadb`, never `localhost`/`127.0.0.1`; check `.env` + secrets |
| NGINX can't reach WordPress | Confirm WordPress is running; FastCGI target must be `wordpress:9000` |
| NGINX vars vanish from config | Template must render with `envsubst '${DOMAIN_NAME}'`, not bare `envsubst` |
| WP-CLI Phar error | Dockerfile must install the PHP Phar package matching the image's PHP version |
| Site URL is `http://` | `wp core install` must use `--url="https://$DOMAIN_NAME"` |

Rebuild after touching a Dockerfile, package list, entrypoint, or NGINX/PHP/Compose config:

```bash
make build && make up
# or, if a rebuild isn't being picked up:
dc up -d --build --force-recreate
```
