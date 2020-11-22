FROM golang as builder

RUN go get github.com/stormcat24/protodep

FROM gcr.io/distroless/base-debian10:nonroot

COPY --from=builder /go/bin/protodep /usr/bin/protodep

ENTRYPOINT ["/usr/bin/protodep"]
