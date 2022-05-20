FROM alpine:latest as tailscale
ARG TARGETARCH
WORKDIR /app
RUN wget https://pkgs.tailscale.com/stable/tailscale_1.24.2_${TARGETARCH}.tgz && \
  tar xzf tailscale_1.24.2_${TARGETARCH:?}.tgz --strip-components=1
COPY start.sh ./start.sh
CMD ["/app/start.sh"]