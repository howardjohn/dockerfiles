FROM --platform=$BUILDPLATFORM golang:1.20 as builder

ARG TARGETOS
ARG TARGETARCH

RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go install github.com/stormcat24/protodep@0.1.8

RUN find /go/bin -type f -exec cp {} /go/bin/protodep \;

FROM cgr.dev/chainguard/static

COPY --from=builder /go/bin/protodep /usr/bin/protodep

ENTRYPOINT ["/usr/bin/protodep"]
