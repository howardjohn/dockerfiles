FROM golang:1.20

RUN go install -ldflags="-s -w" github.com/golangci/golangci-lint/cmd/golangci-lint@v1.52.2
RUN go install -ldflags="-s -w" golang.org/x/tools/cmd/goimports@v0.9.1
RUN go install -ldflags="-s -w" mvdan.cc/gofumpt@v0.4.0
RUN go install -ldflags="-s -w" github.com/daixiang0/gci@v0.10.1

ENTRYPOINT []
