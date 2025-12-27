# CI/CD Dockerfile 问题修复总结

**修复时间**: 2025-12-28
**问题**: CI/CD 流水线找不到服务的 Dockerfile 文件

---

## 🔴 原始错误

```
ERROR: failed to build: resolve : lstat deploy/dockerfile/mqueue-scheduler: no such file or directory
```

**原因**: workflow 配置了 11 个服务，但只有 `usercenter-api` 有 Dockerfile

---

## ✅ 已完成的修复

### 1. 生成所有服务的 Dockerfile

使用自动化脚本为以下服务生成了 Dockerfile：

- ✅ usercenter-api（已存在）
- ✅ usercenter-rpc
- ✅ travel-api
- ✅ travel-rpc
- ✅ order-api
- ✅ order-rpc
- ✅ payment-api
- ✅ payment-rpc
- ✅ order-mq
- ✅ mqueue-job
- ✅ mqueue-scheduler

**位置**: `deploy/dockerfile/*/Dockerfile`

### 2. 更新 CI/CD Workflow

**文件**: `.github/workflows/ci-cd.yml`

**修改**:
- ✅ 启用所有 11 个服务的构建
- ✅ 移除注释，正式启用

### 3. 创建自动化工具

**脚本**:
- `scripts/generate-dockerfiles.sh` (Linux/Mac)
- `scripts/generate-dockerfiles.ps1` (Windows)

**用途**: 快速为新服务生成 Dockerfile

### 4. 添加 .dockerignore

**文件**: `.dockerignore`

**作用**:
- 减小 Docker 构建上下文
- 加快构建速度
- 排除不必要的文件

### 5. 创建文档

**文档**:
- `docs/DOCKERFILE_GUIDE.md` - Dockerfile 配置详细指南
- `docs/CI_LINT_DISABLED.md` - Lint 禁用说明（之前创建）
- `docs/LINT_FIX_REPORT.md` - Lint 问题修复报告（之前创建）

---

## 📋 Dockerfile 特性

所有生成的 Dockerfile 都包含：

✅ **多阶段构建** - 减小最终镜像大小
✅ **非 root 用户** - 增强安全性
✅ **健康检查** - 支持 K8s liveness/readiness probe
✅ **时区设置** - 默认 Asia/Shanghai
✅ **最小化依赖** - 只包含必要的运行时依赖
✅ **优化缓存** - 先复制 go.mod，利用 Docker 层缓存

---

## 🏗️ Dockerfile 结构

```dockerfile
# Stage 1: Build
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /app/bin/SERVICE app/path/to/main.go

# Stage 2: Runtime
FROM alpine:3.19
RUN apk add --no-cache ca-certificates tzdata wget
RUN addgroup -g 1000 app && adduser -D -u 1000 -G app app
WORKDIR /app
COPY --from=builder /app/bin/SERVICE ./
COPY --from=builder /app/etc ./etc
USER app
HEALTHCHECK CMD wget --quiet --tries=1 --spider http://localhost:PORT/healthz
EXPOSE HTTP_PORT GRPC_PORT
CMD ["./SERVICE", "-f", "etc/config.yaml"]
```

---

## 🧪 本地测试命令

```bash
# 测试构建单个服务
docker build -f deploy/dockerfile/usercenter-api/Dockerfile -t usercenter-api:test .

# 查看镜像大小
docker images usercenter-api:test

# 测试运行（需要配置文件）
docker run --rm -p 1004:1004 usercenter-api:test

# 测试健康检查
docker inspect --format='{{.State.Health.Status}}' CONTAINER_ID
```

---

## 📊 镜像大小预估

| 服务类型 | 预估大小 | 说明 |
|---------|---------|------|
| API 服务 | ~20-30 MB | Alpine + Go 二进制 |
| RPC 服务 | ~15-25 MB | 更精简，无 HTTP 依赖 |
| MQ 消费者 | ~20-30 MB | 包含消息队列客户端 |

---

## 🔄 下一步（CI/CD 流程）

当代码推送到 GitHub 时，CI/CD 将：

```
1. lint-and-test
   ✅ 运行测试
   ✅ 生成覆盖率报告

2. build-images（11 个服务并行构建）
   ✅ 构建 Docker 镜像
   ✅ 推送到 docker.io/mzlone/SERVICE_NAME
   ✅ Trivy 安全扫描
   ✅ 生成 SBOM (Software Bill of Materials)

3. deploy-dev（如果推送到 main）
   ✅ 部署到 Kubernetes 开发环境
   ✅ 健康检查
   ✅ 钉钉通知

4. deploy-prod（如果打 tag）
   ✅ 部署到生产环境
   ✅ 创建 GitHub Release
```

---

## ⚠️ 注意事项

### 1. 首次推送镜像需要登录

**GitHub Secrets 配置**:
```
HARBOR_USERNAME = mzlone  # Docker Hub 用户名
HARBOR_PASSWORD = [Token] # Docker Hub Access Token
```

参考：`docs/TASK_12_CHECKLIST.md`

### 2. 端口冲突检查

确保本地没有服务占用以下端口：
- HTTP: 1004-1014
- gRPC: 4009-4018

### 3. 配置文件路径

每个服务的配置文件路径：
```
app/SERVICE/cmd/TYPE/etc/config.yaml
```

确保这些文件存在且配置正确。

---

## 📚 相关文档

| 文档 | 说明 |
|------|------|
| `docs/DOCKERFILE_GUIDE.md` | Dockerfile 配置详细指南 |
| `docs/TASK_12_CHECKLIST.md` | GitHub Secrets 配置 |
| `docs/CI_LINT_DISABLED.md` | Lint 检查说明 |
| `.dockerignore` | Docker 构建排除文件 |

---

## ✅ 验证清单

推送代码前检查：

- [x] 所有 Dockerfile 已生成（11 个）
- [x] workflow 已更新启用所有服务
- [x] .dockerignore 已创建
- [ ] 本地测试构建至少一个服务
- [ ] GitHub Secrets 已配置（HARBOR_USERNAME, HARBOR_PASSWORD）
- [ ] 配置文件路径正确

---

## 🚀 立即测试

```bash
# 1. 提交所有修改
git add deploy/dockerfile/ .github/workflows/ci-cd.yml .dockerignore docs/
git commit -m "ci: add Dockerfiles for all services

- Generate Dockerfiles for 11 services
- Update workflow to build all services
- Add .dockerignore for optimized builds
- Add documentation

Fixes Docker build errors in CI/CD pipeline"

# 2. 推送到 GitHub
git push origin main

# 3. 查看 CI/CD 运行
# 访问: https://github.com/Lance-Mao/flash-sale-system/actions
```

---

**修复完成！** 🎉

现在 CI/CD 流水线应该可以成功构建所有服务的 Docker 镜像了。
