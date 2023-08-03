FROM debian as builder

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    ca-certificates \
    build-essential libssl-dev git zlib1g-dev \
    && update-ca-certificates \
    && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf  /var/log/*log /var/lib/apt/lists/* /var/log/apt/* /var/lib/dpkg/*-old /var/cache/debconf/*-old

RUN git clone https://github.com/giltene/wrk2.git && cd wrk2 && make && cp wrk /usr/bin/wrk && cd .. && rm -rf wrk2

FROM cgr.dev/chainguard/cc-dynamic:latest

COPY --from=builder /usr/bin/wrk /usr/bin/wrk

ENTRYPOINT ["/usr/bin/wrk"]
