# Developer Documentation

## 1. Project Overview

This project is an Inception stack built with Docker Compose.

It contains three services:

- **NGINX**: The HTTPS entry point and reverse proxy.
- **WordPress**: The PHP-FPM application service.
- **MariaDB**: The database service.

The services are defined in:

```text
srcs/docker-compose.yaml
```

The project uses custom Dockerfiles and entrypoint scripts instead of relying on preconfigured application containers.

The project structure is organized as follows:

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/
│   ├── mariadb/
│   │   ├── db_root_password.txt
│   │   └── db_password.txt
│   └── wordpress/
│       ├── wp_admin_password.txt
│       └── wp_user_password.txt
└── srcs/
    ├── .env
    ├── docker-compose.yaml
    └── requirements/
        ├── mariadb/
        ├── nginx/
        └── wordpress/
```

## 2. Prerequisites

Install the following tools:

- Docker Engine or Docker Desktop.
- Docker Compose.
- Make.
- Git.
- A POSIX-compatible shell.
- An editor such as Vim, Nano, or Visual Studio Code.

Check the installed versions:

```bash
docker --version
docker compose version
make --version
git --version
```

Docker must be running before executing the Makefile targets.

The project also requires permission to create and use:

```text
/home/ekeisler/data/mariadb
/home/ekeisler/data/wordpress
```

If the username or required host path is different on your machine, update `DATA_DIR` in the `Makefile` and the matching `device` paths in `srcs/docker-compose.yaml`.

## 3. Cloning the Repository

Clone the repository and enter its directory:

```bash
git clone REPOSITORY_URL
cd PROJECT_DIRECTORY
```

Replace:

- `REPOSITORY_URL` with the repository URL.
- `PROJECT_DIRECTORY` with the cloned directory name.

## 4. Environment Configuration

The non-secret configuration is stored in:

```text
srcs/.env
```

A typical file contains:

```env
DOMAIN_NAME=<login>.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
```

The exact variable names must match those referenced in `srcs/docker-compose.yaml`.

The domain name is used by:

- NGINX when generating the TLS certificate.
- NGINX when rendering the server configuration.
- WordPress when setting its site URL.

For local access, map the domain to the Docker host in `/etc/hosts`:

```text
127.0.0.1 <login>.42.fr
```

When using a virtual machine, use the VM's IP address instead of `127.0.0.1`.

The `.env` file contains configuration but should still be reviewed before committing. Never place passwords or private keys in it.

## 5. Docker Secrets

The project requires four secret files:

```text
secrets/mariadb/db_root_password.txt
secrets/mariadb/db_password.txt
secrets/wordpress/wp_admin_password.txt
secrets/wordpress/wp_user_password.txt
```

Each file must contain a deliberate password.

The files should not contain accidental placeholder values, unnecessary characters, or exposed credentials. Check them locally without committing their contents:

```bash
wc -c secrets/mariadb/db_root_password.txt
wc -c secrets/mariadb/db_password.txt
wc -c secrets/wordpress/wp_admin_password.txt
wc -c secrets/wordpress/wp_user_password.txt
```

The secret files are mounted by Docker Compose under `/run/secrets/`.

The services read them at runtime:

- MariaDB reads the root and application database passwords.
- WordPress reads the application database password and WordPress account passwords.

Secrets are intentionally not placed in:

- Dockerfiles.
- `srcs/docker-compose.yaml`.
- Git-tracked source files.
- Image build arguments.

Make sure the repository ignores them:

```bash
git status --short
git ls-files | grep -iE 'secret|\.env'
```

The second command should not list the secret files or the `.env` file.

## 6. Makefile Commands

The Makefile provides the main project commands.

Inspect all available targets:

```bash
make help
```

Common targets include:

```bash
make build
make up
make down
make clean
make re
```

### `make build`

Creates the required host directories and builds the Docker images:

```bash
make build
```

### `make up`

Creates the required directories, builds the images if necessary, and starts the stack:

```bash
make up
```

### `make down`

Stops and removes the containers and networks while keeping the named volumes:

```bash
make down
```

### `make clean`

The exact behavior depends on the Makefile. Read the target before using it because cleanup commands may remove containers, images, networks, or volumes.

### `make re`

If available, this target usually rebuilds and restarts the project. Check the Makefile to confirm its exact behavior.

## 7. Building with Docker Compose

The project uses:

```text
srcs/docker-compose.yaml
```

To build all services directly:

```bash
docker compose -p inception -f srcs/docker-compose.yaml build
```

Build without the cache:

```bash
docker compose -p inception -f srcs/docker-compose.yaml build --no-cache
```

Use `--no-cache` when a package installation or Dockerfile change is not being reflected. It should not be used for every build because it is slower.

Start the project after building:

```bash
docker compose -p inception -f srcs/docker-compose.yaml up -d
```

Build and start in one command:

```bash
docker compose -p inception -f srcs/docker-compose.yaml up -d --build
```

## 8. Compose Services

List the services defined by the Compose file:

```bash
docker compose -p inception -f srcs/docker-compose.yaml config --services
```

The expected services are:

```text
mariadb
wordpress
nginx
```

Display the fully resolved Compose configuration:

```bash
docker compose -p inception -f srcs/docker-compose.yaml config
```

This is useful for checking:

- Networks.
- Volumes.
- Secrets.
- Environment variables.
- Port mappings.
- Restart policies.
- Service dependencies.

## 9. Network Architecture

The stack uses two Docker networks.

### Backend network

The backend network is marked as internal:

```yaml
backend:
  internal: true
```

It is used for communication between:

- MariaDB.
- WordPress.
- NGINX.

The internal network prevents services from using it as a direct route to the outside network.

### Frontend network

The frontend network is used by NGINX to expose HTTPS traffic:

```yaml
frontend:
```

Only NGINX joins this network.

NGINX publishes:

```text
443:443
```

MariaDB and WordPress do not publish ports to the host. WordPress communicates with MariaDB through the service name and internal port:

```text
mariadb:3306
```

NGINX communicates with WordPress through PHP-FPM:

```text
wordpress:9000
```

## 10. NGINX Implementation

NGINX is built from:

```text
srcs/requirements/nginx/Dockerfile
```

The image installs:

- NGINX.
- OpenSSL.
- Gettext.

The default Alpine NGINX configuration is removed because it listens on port `80`, while this project must expose HTTPS on port `443` only.

The server configuration template is located at:

```text
srcs/requirements/nginx/conf/wordpress.conf.template
```

It contains:

- TLS configuration.
- TLSv1.2 and TLSv1.3 restrictions.
- The WordPress document root.
- PHP-FPM forwarding to `wordpress:9000`.
- WordPress permalink rewriting.
- Static file handling.

The configuration is a template because it contains:

```text
${DOMAIN_NAME}
```

The entrypoint renders the template when the container starts.

It must use:

```bash
envsubst '${DOMAIN_NAME}'
```

rather than a bare `envsubst`. A bare call could replace NGINX variables such as:

```text
$uri
$document_root
```

The NGINX entrypoint then starts NGINX in the foreground:

```bash
exec nginx -g "daemon off;"
```

This ensures that NGINX remains PID 1 and receives Docker signals correctly.

## 11. TLS Certificate

The NGINX entrypoint generates a self-signed certificate on the first boot.

The certificate is generated for the configured domain:

```text
${DOMAIN_NAME}
```

The private key should have restrictive permissions:

```text
chmod 600
```

The certificate is intended for local development and evaluation. It is not a replacement for a trusted production certificate.

Test HTTPS with:

```bash
curl -k -s -o /dev/null -w "%{http_code}\n" \
  --resolve <login>.42.fr:443:127.0.0.1 \
  https://<login>.42.fr/
```

Test TLSv1.2:

```bash
curl -k -s -o /dev/null -w "%{http_code}\n" \
  --tlsv1.2 --tls-max 1.2 \
  --resolve <login>.42.fr:443:127.0.0.1 \
  https://<login>.42.fr/
```

Test that TLSv1.1 is rejected:

```bash
curl -k -s -o /dev/null -w "%{http_code}\n" \
  --tlsv1.1 --tls-max 1.1 \
  --resolve <login>.42.fr:443:127.0.0.1 \
  https://<login>.42.fr/
```

## 12. WordPress Implementation

WordPress is built from:

```text
srcs/requirements/wordpress/Dockerfile
```

The image includes PHP-FPM and WP-CLI.

The `php-phar` package is required because WP-CLI is distributed as a `.phar` archive. Without the PHP Phar extension, WP-CLI cannot start correctly.

The WordPress entrypoint:

1. Reads the Docker secrets.
2. Waits for MariaDB to become available.
3. Generates `wp-config.php` if it does not exist.
4. Installs WordPress on the first run.
5. Creates the administrator and normal user.
6. Skips initialization if the existing WordPress data is already present.
7. Starts PHP-FPM in the foreground.

The WordPress URL must use HTTPS:

```bash
wp core install --url="https://$DOMAIN_NAME"
```

Using `http://` would create an incorrect site URL because NGINX serves the project only through HTTPS.

PHP-FPM must run in the foreground so Docker can track it as the main process:

```bash
exec php-fpm84 -F
```

The exact PHP-FPM binary name may depend on the Alpine PHP version used by the Dockerfile.

## 13. MariaDB Implementation

MariaDB is built from:

```text
srcs/requirements/mariadb/Dockerfile
```

The image uses an explicit version tag:

```text
mariadb:1.0
```

The project must not use the `latest` tag.

The MariaDB entrypoint:

1. Reads the root password from its Docker secret.
2. Reads the application password from its Docker secret.
3. Initializes the database only if `/var/lib/mysql/mysql` does not exist.
4. Creates the configured database and application user.
5. Starts MariaDB in the foreground.

The healthcheck verifies that MariaDB is ready and that authentication works.

The healthcheck must not contain accidental characters after the secret path. For example, this would be incorrect:

```text
/run/secrets/db_root_password)z
```

The MariaDB process must remain in the foreground:

```bash
exec mariadbd
```

## 14. Volumes and Persistent Data

The project uses two named Docker volumes:

```text
db_data
wp_data
```

They are defined in `srcs/docker-compose.yaml`.

The volumes are Docker named volumes with bind-backed driver options:

```yaml
driver_opts:
  type: none
  device: /home/ekeisler/data/mariadb
  o: bind
```

The database volume stores:

```text
/var/lib/mysql
```

The WordPress volume stores:

```text
/var/www/html
```

The host-backed locations are:

```text
/home/ekeisler/data/mariadb
/home/ekeisler/data/wordpress
```

The Makefile's `prepare-dirs` target creates these directories before Docker Compose starts:

```bash
mkdir -p /home/ekeisler/data/mariadb
mkdir -p /home/ekeisler/data/wordpress
```

The WordPress volume is mounted:

- Read-write in the WordPress container.
- Read-only in the NGINX container.

This is appropriate because NGINX serves the files but does not need to modify them.

Inspect the volumes:

```bash
docker volume ls
```

Inspect a specific volume:

```bash
docker volume inspect db_data
docker volume inspect wp_data
```

Do not remove the volumes during normal development:

```bash
docker compose -p inception -f srcs/docker-compose.yaml down -v
```

Removing them deletes the persistent database and WordPress data.

## 15. Container Management

Display the container status:

```bash
docker compose -p inception -f srcs/docker-compose.yaml ps
```

List all containers:

```bash
docker ps -a
```

Stop the project:

```bash
make down
```

Restart all services:

```bash
docker compose -p inception -f srcs/docker-compose.yaml restart
```

Restart one service:

```bash
docker compose -p inception -f srcs/docker-compose.yaml restart SERVICE_NAME
```

Recreate containers:

```bash
docker compose -p inception -f srcs/docker-compose.yaml up -d --force-recreate
```

Rebuild and recreate one service:

```bash
docker compose -p inception -f srcs/docker-compose.yaml up -d \
  --build --force-recreate SERVICE_NAME
```

Open a shell inside a container:

```bash
docker exec -it SERVICE_NAME sh
```

Examples:

```bash
docker exec -it nginx sh
docker exec -it wordpress sh
docker exec -it mariadb sh
```

Run a command inside a container:

```bash
docker exec SERVICE_NAME COMMAND
```

## 16. Logs and Debugging

View all Compose logs:

```bash
docker compose -p inception -f srcs/docker-compose.yaml logs -f
```

View one service's logs:

```bash
docker logs -f nginx
docker logs -f wordpress
docker logs -f mariadb
```

Show the last lines:

```bash
docker logs nginx --tail 50
docker logs wordpress --tail 50
docker logs mariadb --tail 50
```

Important checks include:

```bash
docker compose -p inception -f srcs/docker-compose.yaml ps
docker port nginx
docker logs nginx
docker logs wordpress
docker logs mariadb
```

Check that all required processes are running:

```bash
docker exec nginx ps
docker exec wordpress ps
docker exec mariadb ps
```

The main service process should remain in the foreground and be managed as PID 1.

## 17. Restart Policy Test

The project uses a restart policy to recover from unexpected container failures.

Simulate a crash by killing PID 1 from inside the container:

```bash
docker exec nginx sh -c 'kill -9 1'
```

Wait a few seconds:

```bash
sleep 3
```

Check the container:

```bash
docker inspect nginx --format '{{.State.Status}}'
```

Expected result:

```text
running
```

Do not use this command for the restart-policy test:

```bash
docker kill nginx
```

A signal sent externally is considered an intentional user action and may not trigger the restart policy.

## 18. Persistence Test

To verify that data persists:

```bash
make down
make up
```

Check the WordPress logs:

```bash
docker logs wordpress --tail 10
```

The expected message is similar to:

```text
wp-config.php already exists, skipping generation
```

Check the MariaDB logs:

```bash
docker logs mariadb --tail 30 | grep -i init
```

MariaDB should not perform its first-time initialization again.

If the services initialize from scratch, inspect:

- The named volumes.
- The `device` paths in `srcs/docker-compose.yaml`.
- The permissions on `/home/ekeisler/data`.
- The `prepare-dirs` target in the Makefile.

## 19. WordPress User Test

List the configured WordPress users:

```bash
docker exec wordpress \
  wp user list --allow-root --fields=user_login,roles
```

The output should contain:

- An administrator.
- A regular user.

Check that the administrator login does not contain:

```text
admin
Admin
administrator
Administrator
```

## 20. Checking Image Tags

The project must not use the `latest` tag.

List relevant images:

```bash
docker images --format '{{.Repository}}:{{.Tag}}' \
  | grep -E '^(mariadb|wordpress|nginx):'
```

Check for the forbidden tag:

```bash
docker images --format '{{.Repository}}:{{.Tag}}' \
  | grep ':latest'
```

The project configuration should use explicit version tags or locally built project tags.

## 21. Checking for Secret Leaks

Inspect the WordPress image history:

```bash
docker history wordpress:1.0 --no-trunc \
  | grep -iE "password|secret"
```

The command should produce no output.

Also inspect the Git working tree:

```bash
git status --short
git ls-files | grep -iE "secret|\.env"
```

The secret files and `.env` file must not be tracked.

Review Dockerfiles and Compose files manually to ensure they do not contain:

- Password values.
- Secret contents.
- Private keys.
- Authentication tokens.

## 22. Rebuilding After Changes

Rebuild after modifying:

- A Dockerfile.
- A package list.
- An entrypoint script.
- An NGINX configuration.
- A PHP configuration.
- A Compose service definition.

Use:

```bash
make build
make up
```

Or:

```bash
docker compose -p inception -f srcs/docker-compose.yaml up -d --build
```

If changes are not applied:

```bash
docker compose -p inception -f srcs/docker-compose.yaml up -d \
  --build --force-recreate
```

## 23. Data Backup

Before destructive operations, back up the MariaDB database.

For MariaDB:

```bash
docker exec mariadb mariadb-dump \
  -u root -p DATABASE_NAME > backup.sql
```

Replace `DATABASE_NAME` with the configured database name. The command prompts for the root password.

Restore the database with:

```bash
docker exec -i mariadb mariadb \
  -u root -p DATABASE_NAME < backup.sql
```

Do not commit `backup.sql` if it contains private or personal data.

## 24. Common Development Problems

### The host data directory does not exist

Run:

```bash
make prepare-dirs
```

If the target is unavailable, create the directories manually:

```bash
sudo mkdir -p /home/ekeisler/data/mariadb
sudo mkdir -p /home/ekeisler/data/wordpress
```

### A volume uses the wrong host path

Inspect the Compose configuration:

```bash
docker compose -p inception -f srcs/docker-compose.yaml config
```

Check the `device` value under `db_data` and `wp_data`.

Also inspect the volumes:

```bash
docker volume inspect db_data
docker volume inspect wp_data
```

### WordPress cannot connect to MariaDB

Inside Docker Compose, use the service name as the database host:

```text
mariadb
```

Do not use:

```text
localhost
127.0.0.1
```

Check the database-related variables in `srcs/.env` and verify the secret files.

### NGINX cannot connect to WordPress

Check that WordPress is running:

```bash
docker compose -p inception -f srcs/docker-compose.yaml ps
docker logs wordpress
```

The NGINX FastCGI configuration should target:

```text
wordpress:9000
```

### NGINX configuration variables disappear

The template must be rendered with a restricted variable list:

```bash
envsubst '${DOMAIN_NAME}'
```

Do not use bare `envsubst`, because it can replace NGINX variables such as `$uri` and `$document_root`.

### WP-CLI fails with a Phar error

Verify that the WordPress Dockerfile installs the PHP Phar package.

For Alpine-based PHP 8.4 images, this may be:

```text
php84-phar
```

The exact package name must match the PHP version used in the image.

### The WordPress URL uses HTTP

The WordPress installation command must use:

```bash
--url="https://$DOMAIN_NAME"
```

NGINX serves only HTTPS, so using `http://` can cause incorrect redirects and mixed-content problems.

## 25. Final Verification

Run the following checks before considering the project complete:

```bash
make build
make up
docker compose -p inception -f srcs/docker-compose.yaml ps
docker port nginx
curl -k -s -o /dev/null -w "%{http_code}\n" \
  --resolve <login>.42.fr:443:127.0.0.1 \
  https://<login>.42.fr/
docker exec wordpress \
  wp user list --allow-root --fields=user_login,roles
git status --short
git ls-files | grep -iE "secret|\.env"
```

Confirm that:

- All three services are running.
- MariaDB is healthy.
- Only NGINX publishes port `443`.
- The website returns HTTP status `200`.
- TLSv1.2 and TLSv1.3 are supported.
- TLSv1.1 is rejected.
- WordPress users are correctly configured.
- Data persists after `make down && make up`.
- No secrets are tracked by Git.
- No image uses the `latest` tag.