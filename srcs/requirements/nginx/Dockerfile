FROM alpine:3.23

RUN apk update && apk add --no-cache \
    nginx \
    openssl \
    gettext

RUN rm -f /etc/nginx/http.d/default.conf

COPY conf/wordpress.conf.template /etc/nginx/http.d/wordpress.conf.template
COPY tools/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 443

ENTRYPOINT ["/entrypoint.sh"]
