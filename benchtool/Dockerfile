FROM envoyproxy/nighthawk-dev@sha256:510fd9b95f7bd56223f46cae9edbd58d8780c00c8852485908d88f476635923e as nighthawk
FROM fortio/fortio:1.57.5 as fortio
FROM howardjohn/wrk2 as wrk
FROM howardjohn/nettools

ARG TARGETARCH

COPY --from=nighthawk /usr/local/bin/nighthawk_client /usr/bin/nighthawk
COPY --from=fortio /usr/bin/fortio /usr/bin/fortio
COPY --from=wrk /usr/bin/wrk /usr/bin/wrk
ADD https://gobinaries.com/binary/github.com/rakyll/hey?os=linux&arch=${TARGETARCH}&version=v0.1.4 /usr/bin/hey
RUN chmod +x /usr/bin/hey

ADD https://github.com/hatoo/oha/releases/download/v0.6.1/oha-linux-${TARGETARCH} /usr/bin/oha
RUN chmod +x /usr/bin/oha

ADD benchmark.sh /usr/bin/benchmark

ENTRYPOINT ["/usr/bin/benchmark"]
