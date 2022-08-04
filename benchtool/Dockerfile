FROM envoyproxy/nighthawk-dev@sha256:95751e0c2c042a5a52d4a84912654fa1d21f1df1a3ab925f3985dc3832fdf29c as nighthawk
FROM fortio/fortio:1.34.1 as fortio
FROM howardjohn/wrk2 as wrk
FROM ubuntu:jammy

ARG TARGETARCH

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    curl \
    openssl \
    bc \
    python3 \
    bsdmainutils \
    jq \
    && apt-get clean -y \
    && rm -rf /var/cache/debconf/* /var/lib/apt/lists/* \
    /var/log/* /tmp/*  /var/tmp/*

COPY --from=nighthawk /usr/local/bin/nighthawk_client /usr/bin/nighthawk
COPY --from=fortio /usr/bin/fortio /usr/bin/fortio
COPY --from=wrk /usr/bin/wrk /usr/bin/wrk
ADD  https://gobinaries.com/binary/github.com/rakyll/hey?os=linux&arch=${TARGETARCH}&version=v0.1.4 /usr/bin/hey
RUN chmod +x /usr/bin/hey
# TODO https://github.com/hatoo/oha/issues/174
ADD  https://github.com/hatoo/oha/releases/download/v0.5.2/oha-linux-amd64 /usr/bin/oha
RUN chmod +x /usr/bin/oha

ADD benchmark.sh /usr/bin/benchmark

ENTRYPOINT ["/usr/bin/benchmark"]
