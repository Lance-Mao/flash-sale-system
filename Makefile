# Makefile for flash-sale-system

.PHONY: all build test lint clean docker-build docker-push help

# 变量定义
SERVICES := usercenter-api usercenter-rpc travel-api travel-rpc order-api order-rpc payment-api payment-rpc order-mq mqueue-job mqueue-scheduler
REGISTRY := harbor.example.com/flashsale
VERSION := $(shell git describe --tags --always --dirty)
BUILD_TIME := $(shell date -u '+%Y-%m-%d_%H:%M:%S')
COMMIT_SHA := $(shell git rev-parse --short HEAD)
LDFLAGS := -w -s -X main.version=$(VERSION) -X main.buildTime=$(BUILD_TIME) -X main.commitSha=$(COMMIT_SHA)

# 默认目标
all: lint test build

# 帮助信息
help:
	@echo "Available targets:"
	@echo "  make build              - Build all services"
	@echo "  make test               - Run tests"
	@echo "  make lint               - Run linter"
	@echo "  make clean              - Clean build artifacts"
	@echo "  make docker-build       - Build all Docker images"
	@echo "  make docker-push        - Push all Docker images"
	@echo "  make gen-api            - Generate API code"
	@echo "  make gen-rpc            - Generate RPC code"
	@echo "  make gen-model          - Generate model code"

# 构建所有服务
build:
	@echo "Building all services..."
	@mkdir -p bin
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/usercenter-api app/usercenter/cmd/api/usercenter.go
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/usercenter-rpc app/usercenter/cmd/rpc/usercenter.go
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/travel-api app/travel/cmd/api/travel.go
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/travel-rpc app/travel/cmd/rpc/travel.go
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/order-api app/order/cmd/api/order.go
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/order-rpc app/order/cmd/rpc/order.go
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/payment-api app/payment/cmd/api/payment.go
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/payment-rpc app/payment/cmd/rpc/payment.go
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/order-mq app/order/cmd/mq/order.go
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/mqueue-job app/mqueue/cmd/job/job.go
	@CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="$(LDFLAGS)" -o bin/mqueue-scheduler app/mqueue/cmd/scheduler/scheduler.go
	@echo "Build completed!"

# 运行测试
test:
	@echo "Running tests..."
	@go test -cover -coverprofile=coverage.out ./...
	@go tool cover -func=coverage.out

# 运行 linter
lint:
	@echo "Running linter..."
	@golangci-lint run --timeout=5m

# 清理构建产物
clean:
	@echo "Cleaning..."
	@rm -rf bin/
	@rm -f coverage.out
	@go clean -cache

# 构建 Docker 镜像
docker-build:
	@echo "Building Docker images..."
	@for service in $(SERVICES); do \
		echo "Building $$service..."; \
		docker build -f deploy/dockerfile/$$service/Dockerfile \
			-t $(REGISTRY)/$$service:$(VERSION) \
			-t $(REGISTRY)/$$service:latest .; \
	done

# 推送 Docker 镜像
docker-push:
	@echo "Pushing Docker images..."
	@for service in $(SERVICES); do \
		echo "Pushing $$service..."; \
		docker push $(REGISTRY)/$$service:$(VERSION); \
		docker push $(REGISTRY)/$$service:latest; \
	done

# 代码生成
gen-api:
	@echo "Generating API code..."
	@cd deploy/script/gencode && ./gen.sh api

gen-rpc:
	@echo "Generating RPC code..."
	@cd deploy/script/gencode && ./gen.sh rpc

gen-model:
	@echo "Generating model code..."
	@cd deploy/script/mysql && ./genModel.sh usercenter user
	@cd deploy/script/mysql && ./genModel.sh usercenter user_auth

# 启动本地开发环境
dev-up:
	@echo "Starting development environment..."
	@docker-compose -f docker-compose-env.yml up -d
	@echo "Waiting for services to be ready..."
	@sleep 10
	@echo "Development environment is ready!"

# 停止本地开发环境
dev-down:
	@echo "Stopping development environment..."
	@docker-compose -f docker-compose-env.yml down

# 查看日志
logs:
	@docker-compose -f docker-compose-env.yml logs -f

# 数据库迁移
migrate-up:
	@echo "Running database migrations..."
	# 这里可以集成数据库迁移工具，如 golang-migrate

migrate-down:
	@echo "Rolling back database migrations..."
	# 这里可以集成数据库迁移工具

# 安装开发工具
install-tools:
	@echo "Installing development tools..."
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@go install github.com/zeromicro/go-zero/tools/goctl@latest
	@echo "Tools installed!"
