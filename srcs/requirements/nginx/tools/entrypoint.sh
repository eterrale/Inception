#!/bin/sh
set -e

CERT_DIR=/etc/nginx/ssl
CERT_FILE="$CERT_DIR/nginx.crt"
KEY_FILE="$CERT_DIR/nginx.key"

mkdir -p "$CERT_DIR"

if [ ! -f "$CERT_FILE" ]; then
    echo "Generating self-signed TLS certificate for ${DOMAIN_NAME}..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -subj "/CN=${DOMAIN_NAME}"
    chmod 600 "$KEY_FILE"
fi

envsubst '${DOMAIN_NAME}' < /etc/nginx/http.d/wordpress.conf.template > /etc/nginx/http.d/default.conf

exec nginx -g "daemon off;"
