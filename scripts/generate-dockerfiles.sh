#!/bin/bash
# Generate Dockerfiles for all services
# Usage: ./generate-dockerfiles.sh

set -e

PROJECT_ROOT="D:/project/go/flash-sale/flash-sale-system"
DOCKERFILE_DIR="${PROJECT_ROOT}/deploy/dockerfile"

# Define all services with their configurations
declare -A SERVICES=(
    ["usercenter-rpc"]="app/usercenter/cmd/rpc/usercenter.go:1005:4009:etc/usercenter.yaml"
    ["travel-api"]="app/travel/cmd/api/travel.go:1006:4010:etc/travel.yaml"
    ["travel-rpc"]="app/travel/cmd/rpc/travel.go:1007:4011:etc/travel.yaml"
    ["order-api"]="app/order/cmd/api/order.go:1008:4012:etc/order.yaml"
    ["order-rpc"]="app/order/cmd/rpc/order.go:1009:4013:etc/order.yaml"
    ["payment-api"]="app/payment/cmd/api/payment.go:1010:4014:etc/payment.yaml"
    ["payment-rpc"]="app/payment/cmd/rpc/payment.go:1011:4015:etc/payment.yaml"
    ["order-mq"]="app/order/cmd/mq/order.go:1012:4016:etc/order-mq.yaml"
    ["mqueue-job"]="app/mqueue/cmd/job/mqueue.go:1013:4017:etc/job.yaml"
    ["mqueue-scheduler"]="app/mqueue/cmd/scheduler/mqueue.go:1014:4018:etc/scheduler.yaml"
)

echo "===== Generating Dockerfiles for all services ====="

for service in "${!SERVICES[@]}"; do
    IFS=':' read -r main_file http_port grpc_port config_file <<< "${SERVICES[$service]}"

    service_dir="${DOCKERFILE_DIR}/${service}"
    dockerfile="${service_dir}/Dockerfile"

    # Skip if Dockerfile already exists
    if [ -f "$dockerfile" ]; then
        echo "✓ ${service}: Dockerfile already exists, skipping"
        continue
    fi

    echo "Creating Dockerfile for ${service}..."
    mkdir -p "$service_dir"

    # Extract app path and binary name
    app_path=$(dirname "$main_file")
    binary_name="${service}"

    # Generate Dockerfile
    cat > "$dockerfile" << 'EOF'
# Multi-stage build
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
    -ldflags="-w -s -X main.version=$(git describe --tags --always) -X main.buildTime=$(date -u '+%Y-%m-%d_%H:%M:%S')" \
    -o /app/bin/SERVICE_NAME \
    MAIN_FILE

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
COPY --from=builder /app/bin/SERVICE_NAME ./
COPY --from=builder /app/APP_PATH/etc ./etc

# Change ownership
RUN chown -R app:app /app

# Switch to non-root user
USER app

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:HTTP_PORT/healthz || exit 1

EXPOSE HTTP_PORT GRPC_PORT

CMD ["./SERVICE_NAME", "-f", "CONFIG_FILE"]
EOF

    # Replace placeholders
    sed -i "s|SERVICE_NAME|${binary_name}|g" "$dockerfile"
    sed -i "s|MAIN_FILE|${main_file}|g" "$dockerfile"
    sed -i "s|APP_PATH|${app_path}|g" "$dockerfile"
    sed -i "s|HTTP_PORT|${http_port}|g" "$dockerfile"
    sed -i "s|GRPC_PORT|${grpc_port}|g" "$dockerfile"
    sed -i "s|CONFIG_FILE|${config_file}|g" "$dockerfile"

    echo "✓ ${service}: Dockerfile created at ${dockerfile}"
done

echo ""
echo "===== Summary ====="
echo "Generated Dockerfiles for:"
for service in "${!SERVICES[@]}"; do
    echo "  - ${service}"
done

echo ""
echo "Next steps:"
echo "1. Review the generated Dockerfiles"
echo "2. Adjust ports and config paths if needed"
echo "3. Uncomment services in .github/workflows/ci-cd.yml"
echo "4. Test build: docker build -f deploy/dockerfile/SERVICE_NAME/Dockerfile ."

echo ""
echo "===== Done ====="
