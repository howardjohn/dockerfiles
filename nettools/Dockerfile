FROM alpine

RUN \
  apk add --no-cache \
    curl \
    bash \
    openssl \
    socat \
    iproute2 \
    iputils \
    jq \
    tcpdump \
    iptables

COPY inputrc /root/.inputrc
ADD bashrc /root/.bashrc

CMD ["/bin/bash"]
