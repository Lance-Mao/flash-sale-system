# Generate Dockerfiles for all services
# Usage: .\generate-dockerfiles.ps1

$ErrorActionPreference = "Stop"

$projectRoot = "D:\project\go\flash-sale\flash-sale-system"
$dockerfileDir = "$projectRoot\deploy\dockerfile"

# Define all services with their configurations
# Format: service_name = "main_file:http_port:grpc_port:config_file"
$services = @{
    "usercenter-rpc" = "app/usercenter/cmd/rpc/usercenter.go:1005:4009:etc/usercenter.yaml"
    "travel-api" = "app/travel/cmd/api/travel.go:1006:4010:etc/travel.yaml"
    "travel-rpc" = "app/travel/cmd/rpc/travel.go:1007:4011:etc/travel.yaml"
    "order-api" = "app/order/cmd/api/order.go:1008:4012:etc/order.yaml"
    "order-rpc" = "app/order/cmd/rpc/order.go:1009:4013:etc/order.yaml"
    "payment-api" = "app/payment/cmd/api/payment.go:1010:4014:etc/payment.yaml"
    "payment-rpc" = "app/payment/cmd/rpc/payment.go:1011:4015:etc/payment.yaml"
    "order-mq" = "app/order/cmd/mq/order.go:1012:4016:etc/order-mq.yaml"
    "mqueue-job" = "app/mqueue/cmd/job/mqueue.go:1013:4017:etc/job.yaml"
    "mqueue-scheduler" = "app/mqueue/cmd/scheduler/mqueue.go:1014:4018:etc/scheduler.yaml"
}

Write-Host "===== Generating Dockerfiles for all services =====" -ForegroundColor Cyan

$created = @()
$skipped = @()

foreach ($service in $services.Keys) {
    $config = $services[$service] -split ':'
    $mainFile = $config[0]
    $httpPort = $config[1]
    $grpcPort = $config[2]
    $configFile = $config[3]

    $serviceDir = Join-Path $dockerfileDir $service
    $dockerfile = Join-Path $serviceDir "Dockerfile"

    # Skip if Dockerfile already exists
    if (Test-Path $dockerfile) {
        Write-Host "Updating Dockerfile for $service..." -ForegroundColor Yellow
        # Don't skip, update to fix path issues
    } else {
        Write-Host "Creating Dockerfile for $service..." -ForegroundColor Green
    }

    # Create directory
    New-Item -ItemType Directory -Force -Path $serviceDir | Out-Null

    # Extract app path (convert to Unix-style path)
    $appPath = (Split-Path -Parent $mainFile) -replace '\\', '/'
    $binaryName = $service

    # Generate Dockerfile content
    $dockerfileContent = @"
# Multi-stage build for $service
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
    -o /app/bin/$binaryName \
    $mainFile

# Stage 2: Runtime stage
FROM alpine:3.19

# Install necessary runtime dependencies
RUN apk add --no-cache ca-certificates tzdata wget && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    apk del tzdata

# Create non-root user
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app

WORKDIR /app

# Copy binary and config from build stage
COPY --from=builder /app/bin/$binaryName ./
COPY --from=builder /app/$appPath/etc ./etc

# Change ownership
RUN chown -R app:app /app

# Switch to non-root user
USER app

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:$httpPort/healthz || exit 1

EXPOSE $httpPort $grpcPort

CMD ["./$binaryName", "-f", "$configFile"]
"@

    # Write Dockerfile
    $dockerfileContent | Out-File -FilePath $dockerfile -Encoding UTF8 -NoNewline

    Write-Host "OK: $service - Dockerfile updated/created" -ForegroundColor Green
    $created += $service
}

Write-Host ""
Write-Host "===== Summary =====" -ForegroundColor Cyan

Write-Host ""
Write-Host "Processed Dockerfiles for:" -ForegroundColor Green
foreach ($s in $created) {
    Write-Host "  - $s"
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the generated Dockerfiles in deploy/dockerfile/"
Write-Host "2. Test build a service:"
Write-Host "   docker build -f deploy/dockerfile/SERVICE_NAME/Dockerfile -t SERVICE_NAME:test ."
Write-Host "3. Verify paths use forward slashes (/) not backslashes (\)"
Write-Host "4. Push to GitHub to trigger CI/CD"

Write-Host ""
Write-Host "===== Done =====" -ForegroundColor Cyan
