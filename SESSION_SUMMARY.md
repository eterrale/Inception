# Inception — Session Summary & Learning Notes

This file recaps everything that was changed in this working session, explains how the
stack is put together and *why* it's built that way, and gives you a step-by-step way to
verify it's actually working. It's a learning/reference doc for you, not one of the
subject's required files (`README.md`, `USER_DOC.md`, `DEV_DOC.md` still need to be
written separately).

## 1. What changed this session

### mariadb
- `srcs/docker-compose.yaml`: `image: mariadb` had no tag, which Docker silently resolves
  to `mariadb:latest` — the subject explicitly forbids the `latest` tag. Fixed to
  `mariadb:1.0`.
- `srcs/docker-compose.yaml`: the healthcheck had a stray `z` appended to the root
  password (`...db_root_password.txt)z\"`), which made the auth always fail and the
  healthcheck always report unhealthy even though the server was fine. Removed it.

### nginx (built from scratch — it was an empty stub before)
- `srcs/requirements/nginx/Dockerfile`: installs `nginx`, `openssl` (to generate a TLS
  cert), and `gettext` (for `envsubst`). Removes the Alpine package's default
  `http.d/default.conf`, which listens on port 80 — the subject requires nginx to be
  reachable on **443 only**.
- `srcs/requirements/nginx/conf/wordpress.conf.template`: the actual server block.
  Restricts TLS to `TLSv1.2`/`TLSv1.3`, proxies `.php` requests to `wordpress:9000` over
  fastcgi, serves everything else as static files from `/var/www/html`, and includes
  WordPress's standard permalink rewrite rule. It's a `.template` because it contains
  `${DOMAIN_NAME}`, only known at container start (from `.env`), not at build time.
- `srcs/requirements/nginx/tools/entrypoint.sh`: generates a self-signed cert for
  `${DOMAIN_NAME}` on first boot (`chmod 600` on the private key so only root can read
  it), renders the config template with `envsubst '${DOMAIN_NAME}'` — **note the
  explicit variable name**: a bare `envsubst` would also wipe out nginx's own variables
  like `$uri`/`$document_root` since they look like shell variables too — then
  `exec nginx -g "daemon off;"` so nginx runs in the foreground as PID 1 (no hacky
  `tail -f`/`sleep infinity` patches, which the subject explicitly forbids).

### wordpress
- `srcs/requirements/wordpress/Dockerfile`: was missing the `php-phar` package.
  `wp-cli` (used by the entrypoint to install WordPress and create users) is a `.phar`
  file and can't run without PHP's `phar` extension — this caused the container to
  crash-loop (`Class "Phar" not found`) on every real run until fixed.
- `srcs/requirements/wordpress/tools/entrypoint.sh`: `wp core install --url="$DOMAIN_NAME"`
  had no scheme, so `wp-cli` defaulted to `http://` even though nginx only ever serves
  the site over HTTPS — fixed to `--url="https://$DOMAIN_NAME"` to avoid mixed-content /
  redirect issues.

### docker-compose.yaml — wiring it all together
- Added the `wordpress` and `nginx` services (previously only `mariadb` was defined).
- **Split the network in two**: `backend` (internal, for mariadb/wordpress/nginx to talk
  to each other) and `frontend` (normal, non-internal, nginx only). This was a real bug
  I found by testing: Docker **silently refuses to publish a port on a network with
  `internal: true`** — if nginx had stayed on a single internal network, `443:443` would
  never actually work, even though every container would report "running". Confirmed
  this empirically before committing to the fix.
- Added the second required named volume `wp_data` (WordPress site files), bind-backed
  to `/home/ekeisler/data/wordpress`, mounted read-write in `wordpress` and read-only
  (`:ro`) in `nginx` (nginx never needs to write there).
- Added the two extra secrets `wordpress` needs (`wp_admin_password.txt`,
  `wp_user_password.txt`); `db_password.txt` is reused from `mariadb` since WordPress
  connects to the same database with the same app-level user.

### Makefile
- `SECRETS` listed a `credentials.txt` that nothing in the project actually reads (a
  leftover from the subject's example directory listing, not a real requirement) and
  was missing `wp_admin_password.txt` entirely. Fixed the list to match what's really
  used: `mariadb/db_root_password.txt`, `mariadb/db_password.txt`,
  `wordpress/wp_admin_password.txt`, `wordpress/wp_user_password.txt`.
- Cleaned up leftovers from a different project this Makefile seems to have been copied
  from: header/`PROJECT_NAME` said `transcendance` (now `inception`), and there were
  `front`/`back`/`postgres` targets that don't correspond to anything in this project —
  removed.
- Added a `prepare-dirs` target (`mkdir -p $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress`,
  run automatically before `build`/`up`). Docker's bind-backed named volumes need the
  host directory to already exist — it won't create it for you — so without this,
  `make up` on a fresh clone (e.g. an evaluator's machine) would crash on the very first
  run.

### secrets/
- Removed `secrets/credentials.txt` (empty, unused, same reasoning as the Makefile fix).
- The four secret files the project actually needs now exist:
  `secrets/mariadb/db_root_password.txt`, `secrets/mariadb/db_password.txt`,
  `secrets/wordpress/wp_admin_password.txt`, `secrets/wordpress/wp_user_password.txt`.
  **Double-check what's actually in these** — they had short (4-byte) placeholder-looking
  content before this session touched anything, and I never overwrote or verified them.
  Make sure they hold real, deliberate passwords before considering this "done".

## 2. How the stack is put together

```
                       WWW / browser
                            |
                        443 (TLS)
                            |
                       ┌─────────┐
             frontend  │  nginx  │
              network  └────┬────┘
                            │ backend network
                ┌───────────┼───────────┐
                │                       │
          ┌──────────┐           ┌──────────┐
          │ wordpress│──3306────▶│  mariadb │
          │ (php-fpm)│  :9000    └──────────┘
          └──────────┘  (fastcgi from nginx)
                │                       │
           wp_data volume         db_data volume
     /home/ekeisler/data/wordpress   /home/ekeisler/data/mariadb
```

- **Networks**: `backend` is `internal: true` (mariadb/wordpress have no route out to the
  internet — nothing they do at runtime needs one). `frontend` is a normal bridge network
  that only `nginx` joins, purely so its published port (`443:443`) actually works.
- **Volumes**: both `db_data` and `wp_data` are Docker *named volumes* (required — bind
  mounts are explicitly forbidden by the subject), but declared with
  `driver_opts: {type: none, device: /home/ekeisler/data/..., o: bind}` so they're
  physically backed by a specific host path, satisfying both constraints at once. This is
  the standard trick for this requirement.
- **Secrets flow**: real passwords never appear in any Dockerfile or in `docker-compose.yaml`
  directly. They live in `secrets/*.txt` (gitignored), get mounted by Compose's `secrets:`
  block into each container at `/run/secrets/<name>`, and each entrypoint script `cat`s
  them into a shell variable at runtime. Non-secret config (`DOMAIN_NAME`, `MYSQL_USER`,
  `MYSQL_DATABASE`) comes from `srcs/.env` via `env_file:` instead.
- **PID 1 / entrypoints**: every entrypoint script ends with `exec <real process>` (e.g.
  `exec mariadbd ...`, `exec php-fpm84 -F`, `exec nginx -g "daemon off;"`). `exec` replaces
  the shell script process with the real server process instead of running it as a child —
  so the real server *is* PID 1 and receives Docker's stop/restart signals correctly. This
  is also why none of them "daemonize" (fork to background) — a backgrounded process would
  leave nothing for Docker to track as PID 1, which is exactly the kind of situation that
  tempts people into forbidden hacks like `tail -f` or `sleep infinity`.
- **Idempotency**: both `mariadb` and `wordpress` entrypoints check whether their setup
  already happened (`[ ! -d /var/lib/mysql/mysql ]`, `[ ! -f wp-config.php ]`) before doing
  first-run work — this is what makes `make down && make up` safe: it reuses the existing
  volume data instead of reinitializing everything from scratch.

## 3. How to test everything is working

Run these after `make build` (or `make up` if already built). All commands assume you're
at the repo root.

**1. Containers up and healthy**
```sh
docker compose -p inception -f srcs/docker-compose.yaml ps
```
Expect `mariadb` marked `(healthy)`, and all three `Up`.

**2. Only nginx publishes a port, only 443**
```sh
for c in mariadb wordpress nginx; do echo "$c:"; docker port "$c"; done
```
`mariadb`/`wordpress` should print nothing; `nginx` should show `443/tcp -> 0.0.0.0:443`.

**3. No `latest` tags**
```sh
docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^(mariadb|wordpress|nginx):'
```

**4. HTTPS actually serves the site**
```sh
curl -k -s -o /dev/null -w "%{http_code}\n" --resolve <login>.42.fr:443:127.0.0.1 https://<login>.42.fr/
```
Should print `200`. (In a real browser you need `<login>.42.fr` resolving to your VM's IP
via `/etc/hosts` or real DNS instead of curl's `--resolve` trick.)

**5. TLS version restriction is enforced**
```sh
curl -k -s -o /dev/null -w "%{http_code}\n" --tlsv1.2 --tls-max 1.2 --resolve <login>.42.fr:443:127.0.0.1 https://<login>.42.fr/   # expect 200
curl -k -s -o /dev/null -w "%{http_code}\n" --tlsv1.1 --tls-max 1.1 --resolve <login>.42.fr:443:127.0.0.1 https://<login>.42.fr/   # expect connection failure
```

**6. Containers restart after a real crash**
```sh
docker exec nginx sh -c 'kill -9 1'   # kills PID 1 from inside — simulates a real crash
sleep 3
docker inspect nginx --format '{{.State.Status}}'   # expect: running
```
Important: use `docker kill nginx` (from *outside*) and it will **not** restart — Docker
treats an externally issued `kill`/`stop` as an intentional user action and deliberately
skips the restart policy for it. Killing PID 1 from *inside* the container is what
correctly simulates an unexpected crash.

**7. Volumes actually persist data**
```sh
make down
make up
docker logs wordpress --tail 10   # expect "wp-config.php already exists, skipping generation"
docker logs mariadb --tail 30 | grep -i init   # expect NOT to see "Initializing MariaDB..."
```
If either service redoes its first-run setup after a down/up cycle, the volume isn't
actually persisting — investigate the volume/device path.

**8. WordPress users**
```sh
docker exec wordpress wp user list --allow-root --fields=user_login,roles
```
Expect two users, with the administrator's `user_login` **not** containing
`admin`/`Admin`/`administrator`/`Administrator`.

**9. No secrets leaked into image layers**
```sh
docker history wordpress:1.0 --no-trunc | grep -iE "password|secret"
```
Expect no output.

**10. No secrets committed to git**
```sh
git status --short
git ls-files | grep -iE "secret|\.env"
```
The second command should print nothing — `secrets/` and `*.env` must stay untracked.

## 4. What's still missing (mandatory part)

- `README.md` — still just a bare title. Needs the subject's required structure: an
  italicized first line crediting your login, Description (incl. Docker/sources
  explanation + comparisons of VM vs Docker, Secrets vs Env Variables, Docker Network vs
  Host Network, Docker Volumes vs Bind Mounts), Instructions, and Resources (incl. how AI
  was used and for what).
- `USER_DOC.md` — doesn't exist yet.
- `DEV_DOC.md` — doesn't exist yet.
- Confirm the four secret files hold real, deliberate passwords (see note in section 1).
- Bonus part not started (out of scope for this note, per your request).
