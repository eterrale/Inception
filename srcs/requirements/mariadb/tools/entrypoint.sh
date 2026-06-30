#!/bin/sh
set -e

MARIADB_DATABASE=$MYSQL_DATABASE
MARIADB_USER=$MYSQL_USER
MARIADB_PASSWORD=$(cat run/secrets/db_password)
MARIADB_ROOT_PASSWORD=$(cat run/secrets/db_root_password)

export MARIADB_DATABASE
export MARIADB_USER
export MARIADB_PASSWORD
export MARIADB_ROOT_PASSWORD


mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

# Initialization
if [ ! -d "/var/lib/mysql/mysql" ]; then
  echo "Initializing MariaDB..."
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql
  mariadbd --user=mysql --datadir=/var/lib/mysql --skip-networking &
  pid="$!"
  # Wait for MariaDB to be ready by checking the socket
  i=0
  while [ ! -S /run/mysqld/mysqld.sock ]; do
      sleep 1
      i=$((i + 1))
      if [ $i -gt 30 ]; then
          echo "[ERROR] MariaDB did not start in time"
          exit 1
      fi
  done
  # Init the DB
  envsubst </init.sql | mariadb -u root
  kill "$pid"
  wait "$pid" || true
  echo "MariaDB initialization complete."
fi

exec su-exec mysql mariadbd \
  --skip-networking=0 \
  --bind-address=0.0.0.0 \
  --port=3306 \
  --datadir=/var/lib/mysql