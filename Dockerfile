FROM alpine:latest

WORKDIR /usr/src/app

RUN apk --no-cache add openssl curl jq gettext bash

COPY entrypoint.sh /usr/src/app

CMD ["/usr/src/app/entrypoint.sh"]
