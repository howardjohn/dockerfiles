FROM envoyproxy/nighthawk-dev:e9623db69db2236eccdaace5b22d4a65bfb940c1 as nighthawk
FROM fortio/fortio:1.30.0 as fortio
FROM howardjohn/wrk2 as wrk
FROM ubuntu:jammy

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    curl \
    openssl \
    bc \
    python3 \
    bsdmainutils \
    && apt-get clean -y \
    && rm -rf /var/cache/debconf/* /var/lib/apt/lists/* \
    /var/log/* /tmp/*  /var/tmp/*

COPY --from=nighthawk /usr/local/bin/nighthawk_client /usr/bin/nighthawk
COPY --from=fortio /usr/bin/fortio /usr/bin/fortio
COPY --from=wrk /usr/bin/wrk /usr/bin/wrk
ADD  https://gobinaries.com/binary/github.com/rakyll/hey?os=linux&arch=amd64&version=v0.1.4 /usr/bin/hey
RUN chmod +x /usr/bin/hey
ADD  https://github.com/hatoo/oha/releases/download/v0.5.2/oha-linux-amd64 /usr/bin/oha
RUN chmod +x /usr/bin/oha
ADD https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 /usr/bin/jq
RUN chmod +x /usr/bin/jq

ADD benchmark.sh /usr/bin/benchmark

ENTRYPOINT ["/usr/bin/benchmark"]
