*This project has been created as part of the 42 curriculum by ekeisler.*

# Inception

## Description 📜

Inception is a 42 curriculum system administration project: a small infrastructure of Docker containers built from custom Dockerfiles and managed with Docker Compose.

Services:

- **NGINX** — HTTPS entry point and reverse proxy.
- **WordPress** — PHP-FPM application.
- **MariaDB** — WordPress database.
- Named volumes for persistent MariaDB/WordPress data.
- Docker secrets for passwords.
- Two networks separating public and internal traffic.

```text
                         Browser
                            |
                     HTTPS :443
                            |
                       ┌─────────┐
                       │  NGINX  │
                       └────┬────┘
                            |
                      backend network
                    ┌───────┴────────┐
                    │                │
               WordPress         MariaDB
                PHP-FPM          Database
```

Only NGINX is exposed to the host (port `443`). WordPress talks to MariaDB on `3306`; NGINX talks to WordPress via PHP-FPM on `9000`. Neither publishes a host port.

### Technical Choices

- **Docker vs. VMs** — containers share the host kernel instead of emulating one, so they're lighter and faster to start. That lets each service (NGINX/WordPress/MariaDB) live in its own reproducible container, built and orchestrated with Compose.
- **Secrets vs. env vars** — non-sensitive config (`DOMAIN_NAME`, `MYSQL_DATABASE`, `MYSQL_USER`) lives in `srcs/.env`. Passwords live in `secrets/*.txt` files, mounted read-only at `/run/secrets/` at runtime, and are never baked into a Dockerfile, Compose file, or image layer. Secret files are git-ignored.
- **Docker networks vs. host network** — the host network trades isolation for convenience; Docker networks let containers reach each other by service name without exposing every port. This project uses a `frontend` network (NGINX only) and an internal `backend` network (NGINX ↔ WordPress ↔ MariaDB).
- **Volumes vs. bind mounts** — named volumes (`db_data`, `wp_data`) are backed by fixed host directories (`/home/ekeisler/data/{mariadb,wordpress}`) via driver options, so data survives `make down` and containers aren't tied to an arbitrary host path.

## Instructions 🤓

**Prerequisites:** Docker, Docker Compose, Make, Git (`docker --version`, `docker compose version`, etc.).

**Configure** `srcs/.env`:

```env
DOMAIN_NAME=<login>.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
```

Create the four secret files under `secrets/mariadb/` and `secrets/wordpress/` (each holding one real password), and map the domain locally:

```text
127.0.0.1 <login>.42.fr
```

**Run:**

```bash
make up      # build + start
make down    # stop, keeps volumes
```

Then visit `https://<login>.42.fr` (self-signed cert — a browser warning is expected).

Full setup, usage, and troubleshooting details: [`USER_DOC.md`](USER_DOC.md). Implementation and Compose internals: [`DEV_DOC.md`](DEV_DOC.md).

### Submission Checklist

- Custom Dockerfiles, no `latest` tags.
- Only NGINX publishes a port (`443`), TLSv1.2/1.3 only, TLSv1.1 rejected.
- WordPress site URL uses HTTPS.
- MariaDB has a healthcheck; data persists in named volumes backed by the required host paths.
- Passwords are Docker secrets, not committed to git, not in any Dockerfile or image layer.
- Each service's main process runs as PID 1 (no `tail -f` / `sleep infinity` workaround) and restarts after a crash.
- WordPress admin username doesn't contain `admin`/`administrator`.

## Resources 💻

**Networking concepts studied:** Docker bridge/internal networks, inter-container DNS via service names, reverse proxying, FastCGI, HTTPS/TLS (including version restriction), `/etc/hosts`, network isolation.

**References:** [Docker](https://docs.docker.com/) · [Compose](https://docs.docker.com/compose/) · [Dockerfile](https://docs.docker.com/reference/dockerfile/) · [Volumes](https://docs.docker.com/engine/storage/volumes/) · [Networking](https://docs.docker.com/engine/network/) · [Secrets](https://docs.docker.com/engine/swarm/secrets/) · [NGINX](https://nginx.org/en/docs/) · [PHP-FPM](https://www.php.net/manual/en/install.fpm.php) · [MariaDB](https://mariadb.com/kb/en/documentation/) · [WordPress](https://wordpress.org/documentation/) · [WP-CLI](https://developer.wordpress.org/cli/commands/)

### AI Usage 🤖

Perplexity was used to draft/organize this documentation, explain Docker/Compose concepts (networks, volumes, secrets, healthchecks, PID 1), help troubleshoot MariaDB/NGINX/WordPress/PHP-FPM issues, and suggest verification commands. All suggestions were reviewed, adapted, and tested against the actual project; final implementation and validation are my own responsibility.

#networking #42school