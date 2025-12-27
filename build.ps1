# PowerShell 脚本 - 替代 Makefile
# 使用方法: .\build.ps1 [command]

param(
    [Parameter(Position=0)]
    [string]$Command = "help"
)

$ErrorActionPreference = "Stop"
$REGISTRY = "harbor.example.com/flashsale"

function Show-Help {
    Write-Host ""
    Write-Host "Available commands:" -ForegroundColor Cyan
    Write-Host "  .\build.ps1 help           - Show this help" -ForegroundColor White
    Write-Host "  .\build.ps1 lint           - Run linter" -ForegroundColor White
    Write-Host "  .\build.ps1 test           - Run tests" -ForegroundColor White
    Write-Host "  .\build.ps1 build          - Build all services" -ForegroundColor White
    Write-Host "  .\build.ps1 clean          - Clean build artifacts" -ForegroundColor White
    Write-Host "  .\build.ps1 dev-up         - Start development environment" -ForegroundColor White
    Write-Host "  .\build.ps1 dev-down       - Stop development environment" -ForegroundColor White
    Write-Host "  .\build.ps1 docker-build   - Build Docker images" -ForegroundColor White
    Write-Host "  .\build.ps1 install-tools  - Install development tools" -ForegroundColor White
    Write-Host ""
}

function Invoke-Lint {
    Write-Host "Running linter..." -ForegroundColor Cyan
    golangci-lint run --timeout=5m
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Lint failed!" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Lint passed!" -ForegroundColor Green
}

function Invoke-Test {
    Write-Host "Running tests..." -ForegroundColor Cyan
    go test -race -cover -coverprofile=coverage.out ./...
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Tests failed!" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Tests passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Coverage report:" -ForegroundColor Cyan
    go tool cover -func=coverage.out
}

function Invoke-Build {
    Write-Host "Building all services..." -ForegroundColor Cyan

    if (!(Test-Path "bin")) {
        New-Item -ItemType Directory -Path "bin" | Out-Null
    }

    $services = @{
        "usercenter-api" = "app\usercenter\cmd\api\usercenter.go"
        "usercenter-rpc" = "app\usercenter\cmd\rpc\usercenter.go"
        "travel-api" = "app\travel\cmd\api\travel.go"
        "travel-rpc" = "app\travel\cmd\rpc\travel.go"
        "order-api" = "app\order\cmd\api\order.go"
        "order-rpc" = "app\order\cmd\rpc\order.go"
        "payment-api" = "app\payment\cmd\api\payment.go"
        "payment-rpc" = "app\payment\cmd\rpc\payment.go"
        "order-mq" = "app\order\cmd\mq\order.go"
        "mqueue-job" = "app\mqueue\cmd\job\job.go"
        "mqueue-scheduler" = "app\mqueue\cmd\scheduler\scheduler.go"
    }

    foreach ($service in $services.Keys) {
        Write-Host "Building $service..." -ForegroundColor Yellow
        $outputPath = "bin\$service.exe"
        $sourcePath = $services[$service]

        go build -o $outputPath $sourcePath

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ $service built successfully" -ForegroundColor Green
        } else {
            Write-Host "  ❌ Failed to build $service" -ForegroundColor Red
            exit 1
        }
    }

    Write-Host ""
    Write-Host "✅ All services built successfully!" -ForegroundColor Green
}

function Invoke-Clean {
    Write-Host "Cleaning build artifacts..." -ForegroundColor Cyan

    if (Test-Path "bin") {
        Remove-Item -Recurse -Force "bin"
        Write-Host "  Removed bin directory" -ForegroundColor Gray
    }

    if (Test-Path "coverage.out") {
        Remove-Item -Force "coverage.out"
        Write-Host "  Removed coverage.out" -ForegroundColor Gray
    }

    go clean -cache
    Write-Host "✅ Clean completed!" -ForegroundColor Green
}

function Invoke-DevUp {
    Write-Host "Starting development environment..." -ForegroundColor Cyan
    docker-compose -f docker-compose-env.yml up -d

    Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10

    Write-Host "✅ Development environment is ready!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Services:" -ForegroundColor Cyan
    Write-Host "  MySQL:          localhost:33069" -ForegroundColor White
    Write-Host "  Redis:          localhost:36379" -ForegroundColor White
    Write-Host "  Kafka:          localhost:9092" -ForegroundColor White
    Write-Host "  Jaeger:         http://localhost:16686" -ForegroundColor White
    Write-Host "  Prometheus:     http://localhost:9090" -ForegroundColor White
    Write-Host "  Grafana:        http://localhost:3001" -ForegroundColor White
}

function Invoke-DevDown {
    Write-Host "Stopping development environment..." -ForegroundColor Cyan
    docker-compose -f docker-compose-env.yml down
    Write-Host "✅ Development environment stopped!" -ForegroundColor Green
}

function Invoke-DockerBuild {
    Write-Host "Building Docker images..." -ForegroundColor Cyan

    $services = @(
        "usercenter-api", "usercenter-rpc",
        "travel-api", "travel-rpc",
        "order-api", "order-rpc",
        "payment-api", "payment-rpc",
        "order-mq", "mqueue-job", "mqueue-scheduler"
    )

    foreach ($service in $services) {
        Write-Host "Building $service..." -ForegroundColor Yellow
        $dockerfilePath = "deploy\dockerfile\$service\Dockerfile"
        $imageName = "$REGISTRY/${service}:latest"

        if (Test-Path $dockerfilePath) {
            docker build -f $dockerfilePath -t $imageName .
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✅ $service image built" -ForegroundColor Green
            } else {
                Write-Host "  ❌ Failed to build $service" -ForegroundColor Red
            }
        } else {
            Write-Host "  ⚠️  Dockerfile not found for $service" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "✅ Docker images built!" -ForegroundColor Green
}

function Install-Tools {
    Write-Host "Installing development tools..." -ForegroundColor Cyan

    Write-Host "Installing golangci-lint..." -ForegroundColor Yellow
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

    Write-Host "Installing goctl..." -ForegroundColor Yellow
    go install github.com/zeromicro/go-zero/tools/goctl@latest

    Write-Host ""
    Write-Host "✅ Tools installed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Verify installation:" -ForegroundColor Cyan

    try {
        $golangciVersion = golangci-lint --version
        Write-Host "  ✅ golangci-lint: $golangciVersion" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ golangci-lint not found" -ForegroundColor Red
    }

    try {
        $goctlVersion = goctl --version
        Write-Host "  ✅ goctl: $goctlVersion" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ goctl not found" -ForegroundColor Red
    }
}

# Main
switch ($Command.ToLower()) {
    "help" { Show-Help }
    "lint" { Invoke-Lint }
    "test" { Invoke-Test }
    "build" { Invoke-Build }
    "clean" { Invoke-Clean }
    "dev-up" { Invoke-DevUp }
    "dev-down" { Invoke-DevDown }
    "docker-build" { Invoke-DockerBuild }
    "install-tools" { Install-Tools }
    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Show-Help
        exit 1
    }
}
