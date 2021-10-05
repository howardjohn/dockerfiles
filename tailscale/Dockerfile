FROM alpine:latest as tailscale
WORKDIR /app
RUN wget https://pkgs.tailscale.com/stable/tailscale_1.14.6_amd64.tgz && \
  tar xzf tailscale_1.14.6_amd64.tgz --strip-components=1
COPY start.sh ./start.sh
CMD ["/app/start.sh"]