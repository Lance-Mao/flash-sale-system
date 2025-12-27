@echo off
REM Windows 批处理脚本 - 替代 Makefile
REM 使用方法: build.bat [command]

setlocal

set "REGISTRY=harbor.example.com/flashsale"
set "VERSION="
set "BUILD_TIME="

REM 获取 git commit sha
for /f %%i in ('git rev-parse --short HEAD') do set "COMMIT_SHA=%%i"

if "%1"=="" goto help
if "%1"=="help" goto help
if "%1"=="lint" goto lint
if "%1"=="test" goto test
if "%1"=="build" goto build
if "%1"=="clean" goto clean
if "%1"=="dev-up" goto dev-up
if "%1"=="dev-down" goto dev-down
if "%1"=="docker-build" goto docker-build
if "%1"=="install-tools" goto install-tools
goto help

:help
echo.
echo Available commands:
echo   build.bat help           - Show this help
echo   build.bat lint           - Run linter
echo   build.bat test           - Run tests
echo   build.bat build          - Build all services
echo   build.bat clean          - Clean build artifacts
echo   build.bat dev-up         - Start development environment
echo   build.bat dev-down       - Stop development environment
echo   build.bat docker-build   - Build Docker images
echo   build.bat install-tools  - Install development tools
echo.
goto end

:lint
echo Running linter...
golangci-lint run --timeout=5m
if %errorlevel% neq 0 (
    echo Lint failed!
    exit /b 1
)
echo Lint passed!
goto end

:test
echo Running tests...
go test -race -cover -coverprofile=coverage.out ./...
if %errorlevel% neq 0 (
    echo Tests failed!
    exit /b 1
)
echo Tests passed!
go tool cover -func=coverage.out
goto end

:build
echo Building all services...
if not exist bin mkdir bin

echo Building usercenter-api...
go build -o bin\usercenter-api.exe app\usercenter\cmd\api\usercenter.go

echo Building usercenter-rpc...
go build -o bin\usercenter-rpc.exe app\usercenter\cmd\rpc\usercenter.go

echo Building travel-api...
go build -o bin\travel-api.exe app\travel\cmd\api\travel.go

echo Building travel-rpc...
go build -o bin\travel-rpc.exe app\travel\cmd\rpc\travel.go

echo Building order-api...
go build -o bin\order-api.exe app\order\cmd\api\order.go

echo Building order-rpc...
go build -o bin\order-rpc.exe app\order\cmd\rpc\order.go

echo Building payment-api...
go build -o bin\payment-api.exe app\payment\cmd\api\payment.go

echo Building payment-rpc...
go build -o bin\payment-rpc.exe app\payment\cmd\rpc\payment.go

echo Building order-mq...
go build -o bin\order-mq.exe app\order\cmd\mq\order.go

echo Building mqueue-job...
go build -o bin\mqueue-job.exe app\mqueue\cmd\job\job.go

echo Building mqueue-scheduler...
go build -o bin\mqueue-scheduler.exe app\mqueue\cmd\scheduler\scheduler.go

echo Build completed!
goto end

:clean
echo Cleaning build artifacts...
if exist bin rmdir /s /q bin
if exist coverage.out del coverage.out
go clean -cache
echo Clean completed!
goto end

:dev-up
echo Starting development environment...
docker-compose -f docker-compose-env.yml up -d
echo Waiting for services to be ready...
timeout /t 10 /nobreak >nul
echo Development environment is ready!
goto end

:dev-down
echo Stopping development environment...
docker-compose -f docker-compose-env.yml down
echo Development environment stopped!
goto end

:docker-build
echo Building Docker images...
REM 这里需要根据实际情况修改
docker build -f deploy\dockerfile\usercenter-api\Dockerfile -t %REGISTRY%/usercenter-api:latest .
docker build -f deploy\dockerfile\usercenter-rpc\Dockerfile -t %REGISTRY%/usercenter-rpc:latest .
REM ... 其他服务
echo Docker images built!
goto end

:install-tools
echo Installing development tools...
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
go install github.com/zeromicro/go-zero/tools/goctl@latest
echo Tools installed!
goto end

:end
endlocal
