FROM lukemathwalker/cargo-chef:latest-rust-1.56.1-slim AS chef
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

RUN cargo chef prepare --recipe-path recipe.json

FROM gcr.io/distroless/cc-debian10:nonroot

COPY --from=builder /app/target/release/hyper-server /usr/bin/hyper

ENTRYPOINT ["/usr/bin/hyper"]
