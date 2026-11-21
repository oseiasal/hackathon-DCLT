FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY go.mod ./
COPY main.go ./
RUN go mod tidy && \
    CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/donation-service .

FROM alpine:3.20

RUN apk add --no-cache ca-certificates && \
    addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

WORKDIR /app
COPY --from=builder --chown=1000:1000 /app/donation-service /app/donation-service

ENV PORT=8082

USER 1000:1000
EXPOSE 8082

ENTRYPOINT ["/app/donation-service"]
