# User Documentation

> Commands below assume `alias dc='docker compose -p inception -f srcs/docker-compose.yaml'`.

## 1. Overview

The stack runs three services via Docker Compose:

- **NGINX** — only service reachable from outside; terminates HTTPS on `443` and forwards PHP requests to WordPress.
- **WordPress** — the website, served via PHP-FPM.
- **MariaDB** — WordPress's database.

`frontend` network exposes NGINX to the host; `backend` connects all three internally. MariaDB and WordPress publish no host ports. The site is HTTPS-only.

## 2. Prerequisites & Configuration

Install Docker, Docker Compose, Make (and Git, if cloning). Docker must be running.

Set the domain in `srcs/.env`:

```env
DOMAIN_NAME=<login>.42.fr
```

For local testing, point the domain at the Docker host:

```text
127.0.0.1 <login>.42.fr   # in /etc/hosts — use the VM's IP instead if Docker runs in one
```

## 3. Start / Stop

```bash
make up      # creates data dirs, builds images if needed, starts everything
make build   # build images only
make down    # stop + remove containers/networks, KEEPS volumes
```

Never run `dc down -v` unless you intend to delete all persistent data — it removes the named volumes.

## 4. Using the Site

- Site: `https://<login>.42.fr`
- Admin panel: `https://<login>.42.fr/wp-admin`, using the credentials below.

A certificate warning is expected (self-signed cert) — accept it only for your own local instance.

## 5. Credentials & Secrets

```text
secrets/mariadb/db_root_password.txt     # MariaDB root password
secrets/mariadb/db_password.txt          # MariaDB app-user password
secrets/wordpress/wp_admin_password.txt  # WP admin password
secrets/wordpress/wp_user_password.txt   # WP secondary-user password
```

Mounted at runtime under `/run/secrets/`; never written to Dockerfiles or `docker-compose.yaml`. Never commit these files, share the passwords, or paste them into logs/screenshots. The admin username must not contain `admin`/`administrator`. If a password ever leaks, rotate it and recreate the affected service.

## 6. Checking Status & Logs

```bash
dc ps                          # mariadb: healthy · wordpress/nginx: running
docker port nginx              # only NGINX should list a port (443)
dc logs -f                     # all services
docker logs wordpress --tail 20
```

`wp-config.php already exists, skipping generation` in the WordPress logs means existing data was reused rather than reinstalled.

## 7. Verification Tests

**HTTPS / TLS:**

```bash
curl -k -s -o /dev/null -w "%{http_code}\n" --resolve <login>.42.fr:443:127.0.0.1 https://<login>.42.fr/
# → 200

curl -k --tlsv1.1 --tls-max 1.1 --resolve <login>.42.fr:443:127.0.0.1 https://<login>.42.fr/
# → must fail (only TLSv1.2/1.3 are accepted)
```

**WordPress users** (expect one admin + one regular user, admin login without "admin"):

```bash
docker exec wordpress wp user list --allow-root --fields=user_login,roles
```

**Persistence** — data must survive a restart:

```bash
make down && make up
docker logs wordpress --tail 10   # should skip reinstall
docker logs mariadb --tail 30     # should skip first-run init
```

Volumes `db_data`/`wp_data` are backed by `/home/ekeisler/data/{mariadb,wordpress}`.

**Crash recovery** — kill PID 1 *inside* the container (an external `docker kill` looks intentional and may skip the restart policy):

```bash
docker exec nginx sh -c 'kill -9 1'; sleep 3
docker inspect nginx --format '{{.State.Status}}'   # → running
```

## 8. Troubleshooting

| Symptom | Check |
|---|---|
| Site doesn't load | `dc ps`, then `docker logs nginx/wordpress/mariadb`; confirm `/etc/hosts` and domain match |
| Cert warning | Expected — self-signed, local only |
| MariaDB unhealthy | `docker logs mariadb`; verify secret files hold the intended passwords with no stray characters |
| WordPress restart-looping | `docker logs wordpress`; check DB credentials, `DOMAIN_NAME`, or DB not yet ready |
| Data missing | `docker volume ls` and `ls -la /home/ekeisler/data/{mariadb,wordpress}` before assuming loss — don't run cleanup commands |

## 9. Useful Commands

```bash
make up / make build / make down
dc ps
dc logs -f
dc config --services
docker port nginx
docker volume ls
docker exec wordpress wp user list --allow-root
curl -k https://<login>.42.fr
```
