FROM alpine:3.23

RUN apk update && apk add --no-cache \
	mariadb \
	mariadb-client \
	su-exec \
	gettext

RUN mkdir -p /var/lib/mysql /run/mysqld \
	&& chown -R mysql:mysql /var/lib/mysql /run/mysqld

COPY tools/entrypoint.sh /entrypoint.sh

COPY conf/init.sql /init.sql

RUN chmod +x /entrypoint.sh && chmod +x /init.sql

ENTRYPOINT ["/entrypoint.sh"]
