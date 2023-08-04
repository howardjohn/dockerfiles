FROM --platform=$BUILDPLATFORM golang:1.20 AS build

ARG TARGETOS
ARG TARGETARCH

RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    GOOS=$TARGETOS GOARCH=$TARGETARCH go install -ldflags="-s -w" github.com/golangci/golangci-lint/cmd/golangci-lint@v1.52.2
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    GOOS=$TARGETOS GOARCH=$TARGETARCH go install -ldflags="-s -w" golang.org/x/tools/cmd/goimports@v0.9.1
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    GOOS=$TARGETOS GOARCH=$TARGETARCH go install -ldflags="-s -w" mvdan.cc/gofumpt@v0.4.0
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg \
    GOOS=$TARGETOS GOARCH=$TARGETARCH go install -ldflags="-s -w" github.com/daixiang0/gci@v0.10.1

FROM howardjohn/shell

COPY --from=build /go/bin/* /usr/local/bin

ENTRYPOINT []
