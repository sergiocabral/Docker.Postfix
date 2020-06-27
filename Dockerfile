FROM alpine:latest

RUN apk add --no-cache \
	bash \
	gettext \
	apache2-utils \
	rsyslog \
	postfix

COPY ./scripts/bash/split-to-lines.sh /root/
COPY ./scripts/bash/envsubst-files.sh /root/

COPY ./entrypoint.sh /root/

RUN chmod 755 /root/*.sh

ENTRYPOINT ["/root/entrypoint.sh"]
