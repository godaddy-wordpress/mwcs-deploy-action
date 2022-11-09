FROM alpine:3.16

RUN apk add --no-cache tar curl ca-certificates bash httpie py3-rich

COPY deploy.sh /

ENTRYPOINT ["/deploy.sh"]
