*This project has been created as part of the 42 curriculum by ekeisler.*

# Inception

## Description 📜

Inception is a system administration and Docker project from the 42 curriculum.

The goal of the project is to build a small infrastructure composed of several services running in separate Docker containers. The services are created from custom Dockerfiles and managed with Docker Compose.

This project contains:

- **NGINX**, configured as the HTTPS entry point and reverse proxy.
- **WordPress**, running with PHP-FPM.
- **MariaDB**, used as the WordPress database.
- Two Docker named volumes for persistent MariaDB and WordPress data.
- Docker secrets for storing passwords.
- Two Docker networks for separating public and internal communication.

The final architecture is:

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

NGINX is the only service exposed to the host. It listens on port `443` and serves the website through HTTPS.

WordPress and MariaDB are not directly accessible from outside the Docker networks:

- NGINX communicates with WordPress through PHP-FPM on port `9000`.
- WordPress communicates with MariaDB on port `3306`.
- MariaDB and WordPress do not publish ports on the host.

### Technical Choices

#### Virtual Machines and Docker

A virtual machine emulates an entire operating system, including its kernel and system resources. This provides strong isolation but usually requires more memory, storage, and startup time.

Docker containers share the host kernel while isolating application processes and their filesystems. Containers are lighter and start faster than virtual machines, making them suitable for running separate services such as NGINX, WordPress, and MariaDB.

For this project, Docker makes it possible to:

- Separate each service into its own container.
- Reproduce the same environment on different machines.
- Manage the complete stack with Docker Compose.
- Build custom images from Dockerfiles.
- Limit communication between services using Docker networks.

#### Secrets and Environment Variables

Environment variables are suitable for non-sensitive configuration such as:

```env
DOMAIN_NAME=<login>.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
```

These values are stored in:

```text
srcs/.env
```

Passwords and other sensitive values are handled separately with Docker secrets:

```text
secrets/mariadb/db_root_password.txt
secrets/mariadb/db_password.txt
secrets/wordpress/wp_admin_password.txt
secrets/wordpress/wp_user_password.txt
```

This prevents passwords from being written directly in Dockerfiles or in the Compose configuration.

The services access the secrets at runtime through:

```text
/run/secrets/
```

This is safer than placing passwords directly in source files, although the secret files must still be protected and excluded from Git.

#### Docker Networks and Host Network

The host network uses the network interfaces and ports of the host machine directly. Although it can provide good performance, it reduces network isolation and can create port conflicts.

Docker networks provide isolated virtual networks for containers. Services can communicate using their Compose service names without exposing every port to the host.

This project uses:

- A `frontend` network for NGINX and published HTTPS traffic.
- An internal `backend` network for communication between NGINX, WordPress, and MariaDB.

Only NGINX publishes port `443`.

#### Docker Volumes and Bind Mounts

A bind mount directly maps a host path into a container. It is simple and useful during development, but it strongly depends on the host filesystem structure.

A Docker volume is managed by Docker and can persist independently from the lifecycle of a container.

This project uses Docker named volumes:

```text
db_data
wp_data
```

They are backed by specific host directories using Docker volume driver options:

```text
/home/ekeisler/data/mariadb
/home/ekeisler/data/wordpress
```

This allows the project to use named Docker volumes while keeping the data in controlled host locations.

The volumes ensure that:

- Database data survives container restarts.
- WordPress files survive container recreation.
- `make down` does not delete application data.
- First-run initialization is not repeated every time the stack starts.

## Instructions 🤓

### Prerequisites

Install the following tools:

- Docker
- Docker Compose
- Make
- Git

Verify the installation:

```bash
docker --version
docker compose version
make --version
git --version
```

Docker must be running before starting the project.

### Configuration

The project uses a non-secret environment file:

```text
srcs/.env
```

It should contain values similar to:

```env
DOMAIN_NAME=<login>.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
```

Replace `<login>` with the 42 login used by the project.

The project also requires these secret files:

```text
secrets/mariadb/db_root_password.txt
secrets/mariadb/db_password.txt
secrets/wordpress/wp_admin_password.txt
secrets/wordpress/wp_user_password.txt
```

Each file must contain a real password. The secret files must not be committed to Git.

For local access, add the domain to `/etc/hosts`:

```text
127.0.0.1 <login>.42.fr
```

If Docker is running in a virtual machine, replace `127.0.0.1` with the virtual machine's IP address.

### How to Run

Run the project from the repository root:

```bash
make up
```

This command prepares the data directories, builds the images if necessary, and starts the services.

To build the images separately:

```bash
make build
```

To start the stack directly with Docker Compose:

```bash
docker compose -p inception -f srcs/docker-compose.yaml up -d
```

To build and start the services in one command:

```bash
docker compose -p inception -f srcs/docker-compose.yaml up -d --build
```

Check the service status:

```bash
docker compose -p inception -f srcs/docker-compose.yaml ps
```

The expected services are:

```text
mariadb
wordpress
nginx
```

MariaDB should be marked as healthy, and all three services should be running.

To stop the project:

```bash
make down
```

This stops and removes the containers and networks while preserving the named volumes.

Do not use the following command unless you intentionally want to delete all persistent data:

```bash
docker compose -p inception -f srcs/docker-compose.yaml down -v
```

### Usage

Once the project is running, access the website at:

```text
https://<login>.42.fr
```

The WordPress administration panel is available at:

```text
https://<login>.42.fr/wp-admin
```

The administrator password is stored in:

```text
secrets/wordpress/wp_admin_password.txt
```

Because the project uses a self-signed TLS certificate, the browser may display a certificate warning. This is expected for local development.

You can test the website from the terminal:

```bash
curl -k -s -o /dev/null -w "%{http_code}\n" \
  --resolve <login>.42.fr:443:127.0.0.1 \
  https://<login>.42.fr/
```

A successful request should return:

```text
200
```

View the logs of all services:

```bash
docker compose -p inception -f srcs/docker-compose.yaml logs -f
```

View the logs of a specific service:

```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

Check that only NGINX publishes a port:

```bash
for c in mariadb wordpress nginx; do
  echo "$c:"
  docker port "$c"
done
```

Expected result:

- MariaDB: no published port.
- WordPress: no published port.
- NGINX: port `443`.

Test the WordPress users:

```bash
docker exec wordpress \
  wp user list --allow-root --fields=user_login,roles
```

The administrator username must not contain `admin` or `administrator`.

### Persistence Test

The project data is stored in two named Docker volumes:

```text
db_data
wp_data
```

These volumes are backed by:

```text
/home/ekeisler/data/mariadb
/home/ekeisler/data/wordpress
```

Test persistence with:

```bash
make down
make up
```

Then inspect the logs:

```bash
docker logs wordpress --tail 10
docker logs mariadb --tail 30
```

WordPress should detect its existing configuration instead of reinstalling the website. MariaDB should not initialize its database again.

### Submission Requirements

Before submitting the project, verify the following requirements:

- All services are built from custom Dockerfiles.
- The Dockerfiles do not use the `latest` tag.
- NGINX is the only service exposing a host port.
- NGINX listens on port `443`.
- TLSv1.2 and TLSv1.3 are supported.
- TLSv1.1 is rejected.
- WordPress uses HTTPS as its configured site URL.
- MariaDB is configured with a healthcheck.
- WordPress and MariaDB data persist in named Docker volumes.
- The volumes are backed by the required host data directories.
- Passwords are stored as Docker secrets.
- Secrets are not committed to Git.
- No passwords appear in Dockerfiles or image layers.
- Containers use their real service process as PID 1.
- No `tail -f`, `sleep infinity`, or similar process-holding workaround is used.
- The WordPress administrator username does not contain `admin` or `administrator`.
- The services restart after an unexpected internal process crash.
- The project starts correctly from a fresh environment.

Useful verification commands:

```bash
# Check container status
docker compose -p inception -f srcs/docker-compose.yaml ps

# Check published ports
docker port nginx

# Check for latest tags
docker images --format '{{.Repository}}:{{.Tag}}' | grep ':latest'

# Check tracked secrets
git ls-files | grep -iE 'secret|\.env'

# Check WordPress users
docker exec wordpress wp user list --allow-root

# Test HTTPS
curl -k -s -o /dev/null -w "%{http_code}\n" \
  --resolve <login>.42.fr:443:127.0.0.1 \
  https://<login>.42.fr/
```

The commands checking for `latest` tags and tracked secrets should not return any unexpected result.

## Resources 💻

### Networking Concepts Studied

During this project, the following networking concepts were studied:

- Docker bridge networks.
- Internal Docker networks.
- Communication between containers using service names.
- Host ports and container ports.
- Port publishing.
- Reverse proxies.
- FastCGI communication.
- HTTPS and TLS certificates.
- TLS protocol version restrictions.
- DNS and `/etc/hosts`.
- Network isolation.
- The difference between internal and externally accessible services.

The stack uses the following internal connections:

```text
NGINX -> WordPress:9000
WordPress -> MariaDB:3306
```

Only the following host mapping is published:

```text
443:443
```

### Useful References

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
- [Docker Volumes Documentation](https://docs.docker.com/engine/storage/volumes/)
- [Docker Networking Documentation](https://docs.docker.com/engine/network/)
- [Docker Secrets Documentation](https://docs.docker.com/engine/swarm/secrets/)
- [NGINX Documentation](https://nginx.org/en/docs/)
- [NGINX Beginner's Guide](https://nginx.org/en/docs/beginners_guide.html)
- [PHP-FPM Documentation](https://www.php.net/manual/en/install.fpm.php)
- [MariaDB Documentation](https://mariadb.com/kb/en/documentation/)
- [WordPress Documentation](https://wordpress.org/documentation/)
- [WP-CLI Documentation](https://developer.wordpress.org/cli/commands/)
- [OpenSSL Documentation](https://docs.openssl.org/)
- [42 Inception Subject](https://cdn.intra.42.fr/pdf/pdf/413368/en.subject.pdf)

### AI Usage 🤖

Generative AI, including ChatGPT and Perplexity, was used for the following specific tasks:

- **Documentation creation:** Drafting and organizing this README, `USER_DOC.md`, and `DEV_DOC.md`.
- **Docker and Compose learning:** Explaining Docker networks, named volumes, bind-backed volumes, secrets, healthchecks, restart policies, and container process management.
- **Troubleshooting:** Helping identify configuration problems involving MariaDB, NGINX, WordPress, PHP-FPM, WP-CLI, and Docker Compose.
- **Verification planning:** Suggesting commands to check service status, HTTPS access, TLS versions, volume persistence, user configuration, image tags, and secret exposure.
- **Learning support:** Explaining the differences between virtual machines and Docker, environment variables and secrets, Docker networks and host networking, and Docker volumes and bind mounts.

AI-generated suggestions were reviewed, adapted, and tested against the project's actual files and behavior. The final implementation and validation remain of my responsibility.

#networking
#42school