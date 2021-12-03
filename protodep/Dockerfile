FROM --platform=$BUILDPLATFORM golang:1.17 as builder

ARG TARGETOS TARGETARCH
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go install github.com/stormcat24/protodep@0.1.5

RUN find /go/bin -type f -exec cp {} /go/bin/protodep \;

FROM gcr.io/distroless/base-debian10:nonroot

COPY --from=builder /go/bin/protodep /usr/bin/protodep

ENTRYPOINT ["/usr/bin/protodep"]
