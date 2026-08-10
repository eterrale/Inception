#!/bin/sh
set -e

cd /var/www/html

export WP_DB_HOST=mariadb
export WP_DB_NAME=$MYSQL_DATABASE
export WP_DB_USER=$MYSQL_USER
export WP_DB_PASSWORD=$(cat /run/secrets/db_password.txt)
export WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password.txt)
export WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password.txt)

# CHECK
echo "Waiting for MariaDB to be ready..."
i=0
until mariadb -h "$WP_DB_HOST" -u "$WP_DB_USER" -p"$WP_DB_PASSWORD" -e "SELECT 1" >/dev/null 2>&1; do
    sleep 1
    i=$((i + 1))
    if [ $i -gt 30 ]; then
        echo "[ERROR] Could not connect to MariaDB in time"
        exit 1
    fi
done
echo "MariaDB is reachable."

# CONF
WP_REPO=/var/www/html
WP_CONFIG=$WP_REPO/wp-config.php
WP_SAMPLE=$WP_REPO/wp-config-sample.php

if [ ! -f "$WP_CONFIG" ]; then
  cp "$WP_SAMPLE" "$WP_CONFIG"
  echo "Start setup wp-config.php"
  sed -i "s/database_name_here/$WP_DB_NAME/" "$WP_CONFIG"
  sed -i "s/username_here/$WP_DB_USER/" "$WP_CONFIG"
  sed -i "s/password_here/$WP_DB_PASSWORD/" "$WP_CONFIG"
  sed -i "s/localhost/$WP_DB_HOST/" "$WP_CONFIG"
  echo "Setup done"
else
  echo "wp-config.php already exists, skipping generation"
fi

# INSTALL
if ! wp core is-installed --allow-root; then
    echo "Installing WordPress..."
    wp core install \
        --url="https://$DOMAIN_NAME" \
        --title="My WordPress Site" \
        --admin_user="siteowner" \
        --admin_password="$WP_ADMIN_PASSWORD" \
        --admin_email="admin@example.com" \
        --allow-root

    echo "Creating second non-admin user..."
    wp user create \
        editor_user \
        editor@example.com \
        --role=editor \
        --user_pass="$WP_USER_PASSWORD" \
        --allow-root
fi

# EXEC
chown -R nobody:nobody /var/www/html
exec php-fpm84 -F