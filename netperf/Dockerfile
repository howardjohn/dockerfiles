FROM rust:1.70 as builder

RUN cargo install netperf

FROM ubuntu:jammy

COPY --from=builder /usr/local/cargo/bin/netperf /usr/local/bin/netperf

CMD ["/usr/local/bin/netperf"]
