ARG VERSIONNUM
FROM --platform=$BUILDPLATFORM rust:${VERSIONNUM}-slim

RUN cargo install cargo-chef --locked --version 0.1.72 \
    && rm -rf $CARGO_HOME/registry/

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    g++-aarch64-linux-gnu \
    libc6-dev-arm64-cross \
    && apt-get clean \
    && rm -rf  /var/log/*log /var/lib/apt/lists/* /var/log/apt/* /var/lib/dpkg/*-old /var/cache/debconf/*-old

RUN rustup target add aarch64-unknown-linux-gnu
RUN rustup toolchain install stable-aarch64-unknown-linux-gnu --force-non-host

ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc \
    CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc \
    CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++ \
    CARGO_BUILD_TARGET=aarch64-unknown-linux-gnu
