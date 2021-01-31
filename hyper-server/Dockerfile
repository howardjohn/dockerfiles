FROM rust:1.49 as builder

ADD ./ /hyper
WORKDIR /hyper

RUN cargo clean
RUN RUSTFLAGS="-C target-cpu=native" cargo build --release

FROM gcr.io/distroless/cc-debian10:nonroot

COPY --from=builder /hyper/target/release/hyper-techempower /usr/bin/hyper

CMD ["/usr/bin/hyper"]
