FROM alpine:latest

RUN    apk update \
    && apk add bash \
    && apk add gettext \
    && apk add apache2-utils \
    && apk add postfix \
    && rm -rf /var/cache/apk/*

COPY ./scripts/bash/split-to-lines.sh /root/
COPY ./scripts/bash/envsubst-files.sh /root/

COPY ./entrypoint.sh /root/

RUN chmod 755 /root/*.sh

ENTRYPOINT ["/root/entrypoint.sh"]
