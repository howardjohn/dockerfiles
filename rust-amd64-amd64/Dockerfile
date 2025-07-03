ARG VERSIONNUM
FROM --platform=$BUILDPLATFORM rust:${VERSIONNUM}-slim

RUN cargo install cargo-chef --locked --version 0.1.72 \
    && rm -rf $CARGO_HOME/registry/

ENV CARGO_BUILD_TARGET=x86_64-unknown-linux-gnu
