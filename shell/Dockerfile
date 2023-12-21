FROM cgr.dev/chainguard/wolfi-base

RUN \
  apk add --no-cache \
    curl \
    bash \
    openssl

ENV XDG_CONFIG_HOME=/root/.config
COPY inputrc /root/.inputrc
ADD bashrc /root/.bashrc
ADD curlrc /root/config/.curlrc
CMD ["/bin/bash"]
