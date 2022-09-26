FROM alpine

RUN \
  apk add --no-cache \
    curl \
    bash \
    openssl

ARG VERSION
COPY inputrc /root/.inputrc
ADD bashrc /root/.bashrc
ADD https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubectl /usr/bin/kubectl
RUN chmod +x /usr/bin/kubectl
CMD ["/bin/bash"]
