# User Documentation

## 1. Project Overview

This project is an Inception stack running several services with Docker Compose.

The stack contains:

- **NGINX**: The only publicly accessible service. It receives HTTPS requests on port `443`, handles TLS encryption, and forwards PHP requests to WordPress.
- **WordPress**: Runs the website and the PHP-FPM application server.
- **MariaDB**: Stores WordPress users, posts, settings, and other application data.

The services communicate through Docker networks:

- The `frontend` network connects NGINX to the outside world.
- The `backend` network connects NGINX, WordPress, and MariaDB internally.
- MariaDB and WordPress are not directly exposed to the host.

The website is accessible only through HTTPS.

## 2. Project Requirements

The project uses:

- Docker Compose to manage the services.
- Alpine-based Docker images built from scratch.
- NGINX with TLSv1.2 and TLSv1.3.
- WordPress with PHP-FPM.
- MariaDB as the database server.
- Docker named volumes for persistent data.
- Docker secrets for passwords.
- A private backend network for internal communication.

Only NGINX publishes a port:

```text
443:443
```

MariaDB and WordPress do not publish ports on the host.

## 3. Prerequisites

Before starting the project, install:

- Docker
- Docker Compose
- Make
- Git, if the project is stored in a Git repository

Check the installed tools:

```bash
docker --version
docker compose version
make --version
```

Docker must be running before using the project.

## 4. Domain Name

The project uses a domain name configured in:

```text
srcs/.env
```

The file should contain a value similar to:

```env
DOMAIN_NAME=<login>.42.fr
```

Replace `<login>` with your 42 login.

For local testing, the domain must resolve to the machine running Docker. Add an entry to `/etc/hosts` if required:

```text
127.0.0.1 <login>.42.fr
```

If Docker is running inside a virtual machine, replace `127.0.0.1` with the IP address of the virtual machine.

## 5. Starting the Project

Run the following command from the repository root:

```bash
make up
```

The `make up` target:

1. Creates the required host data directories.
2. Builds the Docker images if necessary.
3. Creates the networks and volumes.
4. Starts MariaDB, WordPress, and NGINX.

You can also start the project directly with Docker Compose:

```bash
docker compose -p inception -f srcs/docker-compose.yaml up -d
```

To build the images before starting:

```bash
make build
make up
```

## 6. Stopping the Project

Stop the containers with:

```bash
make down
```

Or directly with Docker Compose:

```bash
docker compose -p inception -f srcs/docker-compose.yaml down
```

This stops and removes the containers and networks but keeps the persistent volumes.

Do not use the following command unless you intentionally want to delete the project data:

```bash
docker compose -p inception -f srcs/docker-compose.yaml down -v
```

The `-v` option removes Docker volumes and can delete the MariaDB and WordPress data.

## 7. Accessing the Website

Open the configured domain in a browser:

```text
https://<login>.42.fr
```

The website uses HTTPS on port `443`.

Because the project generates a self-signed certificate, the browser may display a security warning. This is expected for local development. Accept the certificate only when you know that you are accessing your own local project.

You can test the website from the terminal:

```bash
curl -k -s -o /dev/null -w "%{http_code}\n" \
  --resolve <login>.42.fr:443:127.0.0.1 \
  https://<login>.42.fr/
```

A successful response should return:

```text
200
```

If the project is running inside a virtual machine, replace `127.0.0.1` with the virtual machine's IP address.

## 8. Accessing the WordPress Administration Panel

The WordPress administration panel is available at:

```text
https://<login>.42.fr/wp-admin
```

Log in with the WordPress administrator account configured in:

```text
secrets/wordpress/wp_admin_password.txt
```

The administrator username is configured in the WordPress environment variables or entrypoint configuration.

The administrator username must not contain:

- `admin`
- `Admin`
- `administrator`
- `Administrator`

For security reasons, do not use a default administrator username.

## 9. Credentials and Secrets

The project uses Docker secrets for passwords.

The secret files are stored in:

```text
secrets/
├── mariadb/
│   ├── db_root_password.txt
│   └── db_password.txt
└── wordpress/
    ├── wp_admin_password.txt
    └── wp_user_password.txt
```

These files contain:

- `db_root_password.txt`: The MariaDB root password.
- `db_password.txt`: The password of the normal MariaDB application user.
- `wp_admin_password.txt`: The WordPress administrator password.
- `wp_user_password.txt`: The password of the additional WordPress user.

Inside the containers, Docker mounts the secrets at:

```text
/run/secrets/db_root_password
/run/secrets/db_password
/run/secrets/wp_admin_password
/run/secrets/wp_user_password
```

Passwords are read at runtime by the entrypoint scripts. They are not written directly in the Dockerfiles or in `srcs/docker-compose.yaml`.

Never:

- Commit files from `secrets/` to Git.
- Share the passwords publicly.
- Put passwords in Dockerfiles.
- Put passwords directly in `srcs/docker-compose.yaml`.
- Display passwords in screenshots or logs.

If a password is exposed, replace it and recreate the affected services.

## 10. Checking the Service Status

Display the status of the containers:

```bash
docker compose -p inception -f srcs/docker-compose.yaml ps
```

The expected result is:

- `mariadb`: running and healthy.
- `wordpress`: running.
- `nginx`: running.

You can also use:

```bash
docker ps
```

Only NGINX should show a published host port:

```text
0.0.0.0:443->443/tcp
```

MariaDB and WordPress should not publish ports to the host.

Check the published ports:

```bash
for c in mariadb wordpress nginx; do
  echo "$c:"
  docker port "$c"
done
```

Expected result:

- MariaDB: no output.
- WordPress: no output.
- NGINX: port `443`.

## 11. Viewing Logs

Display the logs of all services:

```bash
docker compose -p inception -f srcs/docker-compose.yaml logs
```

Follow the logs in real time:

```bash
docker compose -p inception -f srcs/docker-compose.yaml logs -f
```

View the logs of one service:

```bash
docker logs mariadb
docker logs wordpress
docker logs nginx
```

Show only the latest lines:

```bash
docker logs wordpress --tail 20
docker logs mariadb --tail 30
docker logs nginx --tail 20
```

Useful messages include:

```text
wp-config.php already exists, skipping generation
```

This indicates that WordPress data already exists and was not initialized again.

MariaDB should not display its first-time initialization messages after a normal stop and restart.

## 12. Testing HTTPS

Test a supported TLS version:

```bash
curl -k -s -o /dev/null -w "%{http_code}\n" \
  --tlsv1.2 --tls-max 1.2 \
  --resolve <login>.42.fr:443:127.0.0.1 \
  https://<login>.42.fr/
```

The expected result is:

```text
200
```

TLSv1.1 should not be accepted:

```bash
curl -k -s -o /dev/null -w "%{http_code}\n" \
  --tlsv1.1 --tls-max 1.1 \
  --resolve <login>.42.fr:443:127.0.0.1 \
  https://<login>.42.fr/
```

This command should fail to establish a connection.

The NGINX configuration allows only:

- TLSv1.2
- TLSv1.3

## 13. Checking WordPress Users

List the WordPress users:

```bash
docker exec wordpress \
  wp user list --allow-root --fields=user_login,roles
```

The output should contain:

- One administrator user.
- One additional normal user.

The administrator username should not contain `admin` or `administrator`.

## 14. Data Persistence

The project uses two named Docker volumes:

```text
db_data
wp_data
```

They store:

- MariaDB data in `db_data`.
- WordPress files in `wp_data`.

The volumes are backed by these host directories:

```text
/home/ekeisler/data/mariadb
/home/ekeisler/data/wordpress
```

The exact paths are configured in `srcs/docker-compose.yaml`.

To verify persistence:

```bash
make down
make up
```

Then check the logs:

```bash
docker logs wordpress --tail 10
docker logs mariadb --tail 30
```

WordPress should report that the existing configuration is being reused. MariaDB should not initialize its database again.

## 15. Restarting After a Crash

The services use a restart policy for unexpected failures.

To simulate a process crash inside the NGINX container:

```bash
docker exec nginx sh -c 'kill -9 1'
```

Wait a few seconds:

```bash
sleep 3
```

Check the status:

```bash
docker inspect nginx --format '{{.State.Status}}'
```

The expected result is:

```text
running
```

Do not use `docker kill nginx` for this test. A kill issued from outside the container is treated as an intentional user action and may not trigger the restart policy.

## 16. Common Problems

### The website does not load

Check the containers:

```bash
docker compose -p inception -f srcs/docker-compose.yaml ps
```

Then inspect the logs:

```bash
docker logs nginx
docker logs wordpress
docker logs mariadb
```

Verify that:

- NGINX is running.
- Port `443` is available.
- The domain name is correct.
- The domain resolves to the Docker host.
- The `/etc/hosts` entry is correct.

### The browser reports a certificate warning

The certificate is self-signed and generated locally by NGINX. A browser warning is expected unless the certificate has been manually trusted.

### MariaDB is unhealthy

Check the MariaDB logs:

```bash
docker logs mariadb
```

Verify that:

- `db_root_password.txt` contains the intended root password.
- `db_password.txt` contains the intended application password.
- The stray characters or extra content have not been added to the secret files.
- The MariaDB volume is writable.

### WordPress keeps restarting

Check the WordPress logs:

```bash
docker logs wordpress
```

Common causes include:

- Missing PHP packages.
- Incorrect database credentials.
- Missing WordPress secrets.
- An incorrect `DOMAIN_NAME`.
- A database that has not finished starting.

### Data has disappeared

Do not run cleanup commands. Check that the volumes still exist:

```bash
docker volume ls
```

Also inspect the data directories:

```bash
ls -la /home/ekeisler/data/mariadb
ls -la /home/ekeisler/data/wordpress
```

## 17. Useful Commands

```bash
# Start the project
make up

# Build the project
make build

# Stop the project without deleting volumes
make down

# Display container status
docker compose -p inception -f srcs/docker-compose.yaml ps

# Follow all logs
docker compose -p inception -f srcs/docker-compose.yaml logs -f

# Display only the configured services
docker compose -p inception -f srcs/docker-compose.yaml config --services

# Check published ports
docker port nginx

# List Docker volumes
docker volume ls

# List WordPress users
docker exec wordpress wp user list --allow-root

# Test the HTTPS website
curl -k https://<login>.42.fr
```