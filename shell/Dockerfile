FROM alpine

RUN \
  apk add --no-cache \
    curl \
    bash \
    openssl

COPY inputrc /root/.inputrc
ADD bashrc /root/.bashrc
