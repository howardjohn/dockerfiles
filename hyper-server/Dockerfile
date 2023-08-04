FROM --platform=$BUILDPLATFORM howardjohn/rust-${BUILDARCH}-${TARGETARCH} AS chef
WORKDIR app

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder 
COPY --from=planner /app/recipe.json recipe.json
# Build dependencies - this is the caching Docker layer!
RUN cargo chef cook --release --recipe-path recipe.json
# Build application
COPY . .
RUN cargo build --release
RUN mv target/${CARGO_BUILD_TARGET}/release/hyper-server target/release/hyper-server

FROM cgr.dev/chainguard/cc-dynamic:latest

COPY --from=builder /app/target/release/hyper-server /usr/bin/hyper

ENTRYPOINT ["/usr/bin/hyper"]
