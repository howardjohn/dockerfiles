FROM alpine:latest as tailscale
ARG TARGETARCH
ARG VERSIONNUM
WORKDIR /app
RUN wget https://pkgs.tailscale.com/stable/tailscale_${VERSIONNUM}_${TARGETARCH}.tgz && \
  tar xzf tailscale_${VERSIONNUM}_${TARGETARCH:?}.tgz --strip-components=1
COPY start.sh ./start.sh
CMD ["/app/start.sh"]