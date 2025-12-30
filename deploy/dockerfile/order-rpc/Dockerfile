# Multi-stage build for order-rpc
# Stage 1: Build stage
FROM golang:1.22-alpine AS builder

# Set working directory
WORKDIR /app

# Install necessary tools
RUN apk add --no-cache git make curl

# Download grpc_health_probe
RUN GRPC_HEALTH_PROBE_VERSION=v0.4.24 && \
    curl -L https://github.com/grpc-ecosystem/grpc-health-probe/releases/download/${GRPC_HEALTH_PROBE_VERSION}/grpc_health_probe-linux-amd64 \
    -o /bin/grpc_health_probe && \
    chmod +x /bin/grpc_health_probe

# Copy dependency files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -o /app/bin/order-rpc \
    app/order/cmd/rpc/order.go

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

# Copy binary, config and grpc_health_probe from build stage
COPY --from=builder /app/bin/order-rpc ./
COPY --from=builder /app/app/order/cmd/rpc/etc ./etc
COPY --from=builder /bin/grpc_health_probe /bin/grpc_health_probe

# Change ownership
RUN chown -R app:app /app

# Switch to non-root user
USER app

# Health check using gRPC health check protocol
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD /bin/grpc_health_probe -addr=:2001 || exit 1

EXPOSE 2001 4013

CMD ["./order-rpc", "-f", "etc/order.yaml"]