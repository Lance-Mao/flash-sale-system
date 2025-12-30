# Multi-stage build for order-mq
# Stage 1: Build stage
FROM golang:1.22-alpine AS builder

# Set working directory
WORKDIR /app

# Install necessary tools
RUN apk add --no-cache git make

# Copy dependency files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -o /app/bin/order-mq \
    app/order/cmd/mq/order.go

# Stage 2: Runtime stage
FROM alpine:3.19

# Install necessary runtime dependencies
RUN apk add --no-cache ca-certificates tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    apk del tzdata

# Create non-root user
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app

WORKDIR /app

# Copy binary and config from build stage
COPY --from=builder /app/bin/order-mq ./
COPY --from=builder /app/app/order/cmd/mq/etc ./etc

# Change ownership
RUN chown -R app:app /app

# Switch to non-root user
USER app

# Health check for background service - check if process is running
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD pgrep order-mq || exit 1

EXPOSE 4003

CMD ["./order-mq", "-f", "etc/order.yaml"]