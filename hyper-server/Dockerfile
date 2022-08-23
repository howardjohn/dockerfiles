FROM lukemathwalker/cargo-chef:latest-rust-1.63.0-slim AS chef
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

FROM gcr.io/distroless/cc-debian11:nonroot

COPY --from=builder /app/target/release/hyper-server /usr/bin/hyper

ENTRYPOINT ["/usr/bin/hyper"]
