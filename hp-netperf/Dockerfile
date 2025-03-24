FROM cgr.dev/chainguard/wolfi-base AS builder

RUN apk add build-base curl
RUN curl -L https://github.com/HewlettPackard/netperf/archive/netperf-2.7.0.tar.gz | tar zx
WORKDIR /netperf-netperf-2.7.0
RUN ./configure --build=$(uname -m)-unknown-linux-gnu
RUN ls && make CFLAGS=-fcommon

FROM howardjohn/shell

WORKDIR /

COPY --from=builder /netperf-netperf-2.7.0/src/netserver /usr/bin/
COPY --from=builder /netperf-netperf-2.7.0/src/netperf /usr/bin/

CMD ["netserver", "-D", "-v", "1"]
