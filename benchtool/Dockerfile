FROM envoyproxy/nighthawk-dev@sha256:4f0085b98117fc1c505b0c993e1b8cfa32c52874153b10a76af904e4fcd60a38 as nighthawk
FROM fortio/fortio:1.63.7 as fortio
FROM howardjohn/wrk2 as wrk
FROM howardjohn/nettools

RUN apk add --no-cache \
  python3 \
  iperf3 \
  util-linux-misc

ARG TARGETARCH

COPY --from=nighthawk /usr/local/bin/nighthawk_client /usr/bin/nighthawk
COPY --from=fortio /usr/bin/fortio /usr/bin/fortio
COPY --from=wrk /usr/bin/wrk /usr/bin/wrk
ADD https://gobinaries.com/binary/github.com/rakyll/hey?os=linux&arch=${TARGETARCH}&version=v0.1.4 /usr/bin/hey
RUN chmod +x /usr/bin/hey

ADD https://github.com/hatoo/oha/releases/download/v1.4.4/oha-linux-${TARGETARCH} /usr/bin/oha
RUN chmod +x /usr/bin/oha

ADD benchmark.sh /usr/bin/benchmark

ENTRYPOINT ["/usr/bin/benchmark"]
