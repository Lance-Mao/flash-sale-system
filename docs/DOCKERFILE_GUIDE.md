# Dockerfile 配置说明

**更新时间**: 2025-12-28
**当前状态**: 只有 usercenter-api 配置完成

---

## 📊 当前状态

### 已完成的服务（1个）

| 服务 | Dockerfile 路径 | 状态 | CI/CD |
|------|----------------|------|-------|
| usercenter-api | `deploy/dockerfile/usercenter-api/Dockerfile` | ✅ 完成 | ✅ 已启用 |

### 待创建的服务（10个）

| 服务 | 主文件 | HTTP端口 | gRPC端口 | 状态 |
|------|--------|---------|---------|------|
| usercenter-rpc | app/usercenter/cmd/rpc/usercenter.go | 1005 | 4009 | ⬜ 待创建 |
| travel-api | app/travel/cmd/api/travel.go | 1006 | 4010 | ⬜ 待创建 |
| travel-rpc | app/travel/cmd/rpc/travel.go | 1007 | 4011 | ⬜ 待创建 |
| order-api | app/order/cmd/api/order.go | 1008 | 4012 | ⬜ 待创建 |
| order-rpc | app/order/cmd/rpc/order.go | 1009 | 4013 | ⬜ 待创建 |
| payment-api | app/payment/cmd/api/payment.go | 1010 | 4014 | ⬜ 待创建 |
| payment-rpc | app/payment/cmd/rpc/payment.go | 1011 | 4015 | ⬜ 待创建 |
| order-mq | app/order/cmd/mq/order.go | 1012 | 4016 | ⬜ 待创建 |
| mqueue-job | app/mqueue/cmd/job/mqueue.go | 1013 | 4017 | ⬜ 待创建 |
| mqueue-scheduler | app/mqueue/cmd/scheduler/mqueue.go | 1014 | 4018 | ⬜ 待创建 |

---

## 🚀 快速生成所有 Dockerfile

### 方案 1：使用自动化脚本（推荐）

**Windows (PowerShell)**:
```powershell
cd D:\project\go\flash-sale\flash-sale-system
.\scripts\generate-dockerfiles.ps1
```

**Linux/Mac (Bash)**:
```bash
cd /path/to/flash-sale-system
chmod +x scripts/generate-dockerfiles.sh
./scripts/generate-dockerfiles.sh
```

### 方案 2：手动创建单个服务

复制 `usercenter-api` 的 Dockerfile 并修改：

```bash
# 1. 复制模板
cp deploy/dockerfile/usercenter-api/Dockerfile deploy/dockerfile/usercenter-rpc/Dockerfile

# 2. 修改以下内容
# - 构建命令中的主文件路径
# - 配置文件路径
# - HTTP/gRPC 端口
# - 二进制文件名
```

---

## 📝 Dockerfile 结构说明

每个 Dockerfile 使用多阶段构建：

### Stage 1: Builder（构建阶段）

```dockerfile
FROM golang:1.22-alpine AS builder

# 安装工具
RUN apk add --no-cache git make

# 复制依赖
COPY go.mod go.sum ./
RUN go mod download

# 复制源码
COPY . .

# 构建二进制（关键：修改这里的路径）
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -o /app/bin/SERVICE_NAME \
    app/SERVICE/cmd/TYPE/main.go
```

### Stage 2: Runtime（运行阶段）

```dockerfile
FROM alpine:3.19

# 安装运行时依赖
RUN apk add --no-cache ca-certificates tzdata wget

# 创建非 root 用户
RUN addgroup -g 1000 app && adduser -D -u 1000 -G app app

# 复制二进制和配置
COPY --from=builder /app/bin/SERVICE_NAME ./
COPY --from=builder /app/app/SERVICE/cmd/TYPE/etc ./etc

# 健康检查（关键：修改端口）
HEALTHCHECK --interval=30s --timeout=3s \
    CMD wget --quiet --tries=1 --spider http://localhost:PORT/healthz || exit 1

# 暴露端口（关键：修改端口）
EXPOSE HTTP_PORT GRPC_PORT

# 启动命令
CMD ["./SERVICE_NAME", "-f", "etc/config.yaml"]
```

---

## 🔧 修改 CI/CD Workflow

生成 Dockerfile 后，在 `.github/workflows/ci-cd.yml` 中启用对应服务：

```yaml
strategy:
  matrix:
    service:
      - usercenter-api
      - usercenter-rpc  # 取消注释
      - travel-api      # 取消注释
      # ... 其他服务
```

---

## ✅ 验证 Dockerfile

### 本地测试构建

```bash
# 构建单个服务
docker build -f deploy/dockerfile/SERVICE_NAME/Dockerfile -t SERVICE_NAME:test .

# 查看镜像大小
docker images SERVICE_NAME:test

# 运行测试
docker run --rm SERVICE_NAME:test ./SERVICE_NAME --version
```

### 常见问题检查

1. **构建失败 - 找不到主文件**
   ```bash
   # 检查主文件路径是否正确
   ls app/SERVICE/cmd/TYPE/main.go
   ```

2. **运行失败 - 找不到配置文件**
   ```bash
   # 检查配置文件路径
   ls app/SERVICE/cmd/TYPE/etc/config.yaml
   ```

3. **健康检查失败**
   ```bash
   # 检查端口是否正确
   grep -r "Port:" app/SERVICE/cmd/TYPE/etc/
   ```

---

## 📐 服务端口规划

| 服务类型 | HTTP 端口范围 | gRPC 端口范围 |
|---------|--------------|--------------|
| API 服务 | 1000-1099 | - |
| RPC 服务 | - | 4000-4099 |
| MQ 消费者 | 1100-1199 | - |

**当前分配**:
```
usercenter-api:  1004  (HTTP)
usercenter-rpc:  4009  (gRPC)
travel-api:      1006  (HTTP)
travel-rpc:      4011  (gRPC)
order-api:       1008  (HTTP)
order-rpc:       4013  (gRPC)
payment-api:     1010  (HTTP)
payment-rpc:     4015  (gRPC)
order-mq:        1012  (HTTP - 健康检查)
mqueue-job:      1013  (HTTP - 健康检查)
mqueue-scheduler: 1014 (HTTP - 健康检查)
```

---

## 🎯 优化建议

### 1. 创建通用基础镜像

为了减少构建时间，可以创建一个包含 Go 和常用工具的基础镜像：

```dockerfile
# deploy/dockerfile/base/Dockerfile
FROM golang:1.22-alpine
RUN apk add --no-cache git make ca-certificates tzdata
```

### 2. 使用 .dockerignore

创建 `.dockerignore` 减少构建上下文：

```
.git
.github
.idea
.vscode
*.md
data/
bin/
*.log
```

### 3. 优化构建缓存

在 Dockerfile 中先复制 go.mod，利用 Docker 缓存：

```dockerfile
COPY go.mod go.sum ./
RUN go mod download  # 这层会被缓存

COPY . .            # 源码改变不影响上层缓存
```

---

## 📚 参考资源

- [Docker 最佳实践](https://docs.docker.com/develop/dev-best-practices/)
- [Go Docker 多阶段构建](https://docs.docker.com/build/building/multi-stage/)
- [Alpine Linux](https://alpinelinux.org/)

---

## 🔄 后续计划

1. ✅ 创建 usercenter-api Dockerfile
2. ⬜ 生成其他服务的 Dockerfile
3. ⬜ 测试所有服务的 Docker 构建
4. ⬜ 在 CI/CD 中启用所有服务
5. ⬜ 优化镜像大小和构建时间
6. ⬜ 配置镜像扫描（Trivy）
7. ⬜ 配置镜像签名（Cosign）

---

**最后更新**: 2025-12-28
**下次检查**: 生成所有 Dockerfile 后
