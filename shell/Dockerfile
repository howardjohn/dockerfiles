FROM cgr.dev/chainguard/wolfi-base

RUN \
  apk add --no-cache \
    curl \
    bash \
    openssl

COPY inputrc /root/.inputrc
ADD bashrc /root/.bashrc
CMD ["/bin/bash"]
