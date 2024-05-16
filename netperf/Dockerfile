FROM --platform=$BUILDPLATFORM howardjohn/rust-${BUILDARCH}-${TARGETARCH} as builder

RUN cargo install netperf

FROM howardjohn/shell
RUN \
  apk add --no-cache \
  libgcc

COPY --from=builder /usr/local/cargo/bin/netperf /usr/local/bin/netperf

CMD ["/usr/local/bin/netperf"]
