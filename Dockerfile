FROM traffmonetizer/cli_v2:latest AS source

FROM alpine:latest

WORKDIR /app

RUN apk update \
    && apk upgrade --no-cache \
    && apk add --no-cache ca-certificates ca-certificates-bundle bash curl dos2unix tzdata iptables redsocks zlib libgcc libstdc++ musl icu-libs \
    && update-ca-certificates

COPY --from=source /app/Cli /app/traffmonetizerCLI

COPY entrypoint.sh /entrypoint.sh

RUN dos2unix /entrypoint.sh

RUN chmod +x /entrypoint.sh /app/traffmonetizerCLI

ENTRYPOINT ["/entrypoint.sh"]