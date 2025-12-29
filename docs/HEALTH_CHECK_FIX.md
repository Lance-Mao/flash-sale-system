# Kubernetes 健康检查失败修复

## 🔴 问题描述

### 症状

Pod 一直重启，日志显示：

```
Liveness probe failed: HTTP probe failed with statuscode: 404
Readiness probe failed: HTTP probe failed with statuscode: 404
```

### 查看 Pod 状态

```bash
kubectl get pods -n flashsale-dev
NAME                              READY   STATUS             RESTARTS   AGE
usercenter-api-xxx                0/1     CrashLoopBackOff   5          5m
order-api-xxx                     0/1     CrashLoopBackOff   4          5m
```

### 查看 Pod 事件

```bash
kubectl describe pod usercenter-api-xxx -n flashsale-dev

Events:
  Warning  Unhealthy  3m   kubelet  Liveness probe failed: HTTP probe failed with statuscode: 404
  Warning  Unhealthy  3m   kubelet  Readiness probe failed: HTTP probe failed with statuscode: 404
  Warning  BackOff    2m   kubelet  Back-off restarting failed container
```

---

## 🔍 根本原因

### 问题 1: 应用代码缺少健康检查端点

**检查应用路由**（`app/usercenter/cmd/api/internal/handler/routes.go`）：

```go
func RegisterHandlers(server *rest.Server, serverCtx *svc.ServiceContext) {
    server.AddRoutes(
        []rest.Route{
            {
                Method:  http.MethodPost,
                Path:    "/user/register",
                Handler: user.RegisterHandler(serverCtx),
            },
            {
                Method:  http.MethodPost,
                Path:    "/user/login",
                Handler: user.LoginHandler(serverCtx),
            },
        },
        rest.WithPrefix("/usercenter/v1"),
    )
}
```

**结论**：
- ❌ 没有 `/healthz` 端点
- ❌ 没有 `/health` 端点
- ❌ 没有 `/ping` 端点

### 问题 2: Helm 配置了不存在的健康检查路径

**Helm deployment 模板**（`deploy/helm/templates/deployment.yaml:62-77`）：

```yaml
livenessProbe:
  httpGet:
    path: /healthz      # ❌ 这个路径不存在
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /healthz      # ❌ 这个路径不存在
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

**结果**：
1. Kubernetes 每 10 秒访问 `http://pod-ip:port/healthz`
2. 应用返回 404（路径不存在）
3. 连续失败 3 次后，Kubernetes 认为 Pod 不健康
4. 重启 Pod（Liveness）或从负载均衡移除（Readiness）
5. 循环往复 → CrashLoopBackOff

---

## ✅ 解决方案对比

| 方案 | 优点 | 缺点 | 适用场景 |
|------|------|------|---------|
| **1. TCP 检查** | 无需改代码，立即生效 | 只检查端口，无法检测应用逻辑 | ⭐ 快速修复 |
| **2. 添加健康检查端点** | 可检测数据库、依赖等 | 需要修改代码 | ⭐⭐ 生产环境 |
| **3. 禁用健康检查** | 最简单 | 无法自动恢复故障 | ❌ 不推荐 |

---

## 🔧 方案 1: TCP 检查（快速修复）

### 修改 Helm 模板

**deploy/helm/templates/deployment.yaml 第62-76行**：

```yaml
# 原配置（错误）
livenessProbe:
  httpGet:
    path: /healthz        # ❌ HTTP 检查，返回 404
    port: http

# 修改后（正确）
livenessProbe:
  tcpSocket:
    port: http            # ✅ TCP 检查，只检查端口是否监听
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  tcpSocket:
    port: http            # ✅ TCP 检查
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

### 应用修复

```bash
# 重新部署
helm upgrade flashsale ./deploy/helm \
  --namespace flashsale-dev \
  --reuse-values \
  --wait --timeout 5m

# 等待 Pod 就绪
kubectl get pods -n flashsale-dev -w

# 预期输出（所有 Running）
NAME                              READY   STATUS    RESTARTS   AGE
usercenter-api-xxx                1/1     Running   0          2m
order-api-xxx                     1/1     Running   0          2m
```

### 验证修复

```bash
# 查看 Pod 事件（应该没有 Unhealthy 警告）
kubectl describe pod usercenter-api-xxx -n flashsale-dev

Events:
  Normal  Scheduled   2m   default-scheduler  Successfully assigned flashsale-dev/usercenter-api-xxx to node1
  Normal  Pulled      2m   kubelet            Container image pulled
  Normal  Created     2m   kubelet            Created container usercenter-api
  Normal  Started     2m   kubelet            Started container usercenter-api
```

### TCP 检查工作原理

```
Kubernetes → TCP 连接 pod-ip:1004 → 连接成功 → Pod 健康 ✅
             ↓ 如果端口未监听
             TCP 连接失败 → Pod 不健康 ❌ → 重启或移除
```

**优点**：
- ✅ 立即生效，无需修改代码
- ✅ 检查应用是否启动（端口监听）
- ✅ 简单可靠

**缺点**：
- ❌ 无法检测应用逻辑错误（如数据库断开）
- ❌ 即使应用 panic，只要端口监听就认为健康

---

## 🚀 方案 2: 添加健康检查端点（最佳实践）

### 2.1 添加健康检查路由

**app/usercenter/cmd/api/desc/usercenter.api**：

```api
syntax = "v1"

info(
    title: "用户中心服务"
    desc: "用户中心服务"
    author: "Mikael"
    email: "13247629622@163.com"
    version: "v1"
)

import (
    "user/user.api"
)

//============================> health check <============================
@server(
    prefix: /
)
service usercenter {
    @doc "health check"
    @handler healthCheck
    get /healthz returns (HealthCheckResp)
}

//============================> usercenter v1 <============================
//no need login
@server(
    prefix: usercenter/v1
    group: user
)
service usercenter {
    // ... 原有路由
}
```

**app/usercenter/cmd/api/desc/user/user.api** 添加响应类型：

```api
type HealthCheckResp {
    Status string `json:"status"`
    Message string `json:"message"`
    Timestamp int64 `json:"timestamp"`
}
```

### 2.2 实现健康检查逻辑

**创建 handler**：`app/usercenter/cmd/api/internal/handler/healthCheckHandler.go`

```go
package handler

import (
    "net/http"
    "time"

    "github.com/zeromicro/go-zero/rest/httpx"
    "github.com/Lance-Mao/flash-sale-system/app/usercenter/cmd/api/internal/logic"
    "github.com/Lance-Mao/flash-sale-system/app/usercenter/cmd/api/internal/svc"
)

func HealthCheckHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        l := logic.NewHealthCheckLogic(r.Context(), svcCtx)
        resp, err := l.HealthCheck()
        if err != nil {
            httpx.ErrorCtx(r.Context(), w, err)
        } else {
            httpx.OkJsonCtx(r.Context(), w, resp)
        }
    }
}
```

**创建 logic**：`app/usercenter/cmd/api/internal/logic/healthCheckLogic.go`

```go
package logic

import (
    "context"
    "time"

    "github.com/Lance-Mao/flash-sale-system/app/usercenter/cmd/api/internal/svc"
    "github.com/Lance-Mao/flash-sale-system/app/usercenter/cmd/api/internal/types"
    "github.com/zeromicro/go-zero/core/logx"
)

type HealthCheckLogic struct {
    logx.Logger
    ctx    context.Context
    svcCtx *svc.ServiceContext
}

func NewHealthCheckLogic(ctx context.Context, svcCtx *svc.ServiceContext) *HealthCheckLogic {
    return &HealthCheckLogic{
        Logger: logx.WithContext(ctx),
        ctx:    ctx,
        svcCtx: svcCtx,
    }
}

func (l *HealthCheckLogic) HealthCheck() (resp *types.HealthCheckResp, err error) {
    // 检查数据库连接（可选）
    // if err := l.svcCtx.UserModel.Ping(); err != nil {
    //     return &types.HealthCheckResp{
    //         Status:    "unhealthy",
    //         Message:   "database connection failed",
    //         Timestamp: time.Now().Unix(),
    //     }, nil
    // }

    // 检查 RPC 连接（可选）
    // if err := l.svcCtx.UserrenterRpc.Ping(); err != nil {
    //     return &types.HealthCheckResp{
    //         Status:    "unhealthy",
    //         Message:   "rpc connection failed",
    //         Timestamp: time.Now().Unix(),
    //     }, nil
    // }

    // 所有检查通过
    return &types.HealthCheckResp{
        Status:    "healthy",
        Message:   "service is running",
        Timestamp: time.Now().Unix(),
    }, nil
}
```

### 2.3 重新生成代码

```bash
cd app/usercenter/cmd/api
goctl api go -api desc/usercenter.api -dir .
```

### 2.4 恢复 HTTP 健康检查

**deploy/helm/templates/deployment.yaml**：

```yaml
livenessProbe:
  httpGet:
    path: /healthz          # ✅ 现在有这个端点了
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
```

### 2.5 测试健康检查端点

```bash
# 端口转发
kubectl port-forward -n flashsale-dev svc/usercenter-api 8080:1004

# 测试健康检查
curl http://localhost:8080/healthz

# 预期输出:
{
  "status": "healthy",
  "message": "service is running",
  "timestamp": 1735490000
}
```

### 高级健康检查示例

**完整的健康检查逻辑**：

```go
func (l *HealthCheckLogic) HealthCheck() (resp *types.HealthCheckResp, err error) {
    checks := make(map[string]string)
    healthy := true

    // 1. 检查数据库连接
    if err := l.checkDatabase(); err != nil {
        checks["database"] = "failed: " + err.Error()
        healthy = false
    } else {
        checks["database"] = "ok"
    }

    // 2. 检查 Redis 连接
    if err := l.checkRedis(); err != nil {
        checks["redis"] = "failed: " + err.Error()
        healthy = false
    } else {
        checks["redis"] = "ok"
    }

    // 3. 检查 RPC 依赖
    if err := l.checkRPC(); err != nil {
        checks["rpc"] = "failed: " + err.Error()
        healthy = false
    } else {
        checks["rpc"] = "ok"
    }

    // 4. 检查磁盘空间
    if usage, err := l.checkDiskSpace(); err != nil || usage > 90 {
        checks["disk"] = fmt.Sprintf("warning: %.2f%% used", usage)
    } else {
        checks["disk"] = "ok"
    }

    status := "healthy"
    message := "all checks passed"
    if !healthy {
        status = "unhealthy"
        message = fmt.Sprintf("checks failed: %v", checks)
    }

    return &types.HealthCheckResp{
        Status:    status,
        Message:   message,
        Timestamp: time.Now().Unix(),
        Checks:    checks,
    }, nil
}
```

---

## 📊 两种方案对比

### TCP 检查

**工作原理**：
```
K8s → TCP 连接端口 → 成功/失败
```

**检测内容**：
- ✅ 应用是否启动
- ✅ 端口是否监听
- ❌ 应用逻辑是否正常
- ❌ 依赖服务是否可用

**适用场景**：
- 开发环境快速验证
- 无状态服务
- 简单应用

### HTTP 健康检查

**工作原理**：
```
K8s → HTTP GET /healthz → 检查响应码和内容
```

**检测内容**：
- ✅ 应用是否启动
- ✅ 端口是否监听
- ✅ 应用逻辑是否正常
- ✅ 依赖服务是否可用
- ✅ 数据库连接状态
- ✅ Redis 连接状态
- ✅ RPC 服务状态

**适用场景**：
- ⭐ 生产环境（强烈推荐）
- 有状态服务
- 依赖外部服务的应用

---

## 🔍 调试健康检查

### 查看健康检查日志

```bash
# 查看 kubelet 日志
kubectl logs -n kube-system -l component=kubelet

# 查看 Pod 事件
kubectl get events -n flashsale-dev --field-selector involvedObject.name=usercenter-api-xxx

# 查看探针失败详情
kubectl describe pod usercenter-api-xxx -n flashsale-dev | grep -A 10 "Liveness\|Readiness"
```

### 手动测试健康检查

```bash
# 进入 Pod
kubectl exec -it usercenter-api-xxx -n flashsale-dev -- sh

# 测试 HTTP 健康检查
wget -O- http://localhost:1004/healthz

# 测试 TCP 连接
nc -zv localhost 1004
```

### 临时禁用健康检查（调试用）

```bash
# 编辑 Deployment
kubectl edit deployment usercenter-api -n flashsale-dev

# 注释掉 livenessProbe 和 readinessProbe
# 保存后 Pod 会重启，但不会再健康检查
```

---

## ⚙️ 健康检查最佳实践

### 1. 合理设置超时和阈值

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: 30    # 启动后等待 30 秒再检查（给应用启动时间）
  periodSeconds: 10          # 每 10 秒检查一次
  timeoutSeconds: 5          # 单次检查超时 5 秒
  failureThreshold: 3        # 连续失败 3 次才认为不健康

readinessProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: 10    # Readiness 可以更快（10 秒）
  periodSeconds: 5           # 更频繁检查（5 秒）
  timeoutSeconds: 3          # 更短超时（3 秒）
  failureThreshold: 3        # 失败 3 次就从负载均衡移除
```

### 2. Liveness vs Readiness

| 探针 | 用途 | 失败后果 | 使用场景 |
|------|------|---------|---------|
| **Liveness** | 检测应用是否存活 | 重启 Pod | 检测死锁、OOM等致命错误 |
| **Readiness** | 检测应用是否就绪 | 从负载均衡移除 | 检测依赖服务、启动过程 |

### 3. 健康检查应该轻量

```go
// ✅ 好的做法：快速检查
func (l *HealthCheckLogic) HealthCheck() {
    // 简单的 SELECT 1 查询
    if err := l.svcCtx.DB.Ping(); err != nil {
        return unhealthy
    }
    return healthy
}

// ❌ 不好的做法：复杂查询
func (l *HealthCheckLogic) HealthCheck() {
    // 复杂查询，可能超时
    if _, err := l.svcCtx.DB.Query("SELECT COUNT(*) FROM large_table"); err != nil {
        return unhealthy
    }
    return healthy
}
```

### 4. 避免健康检查影响性能

```yaml
# ❌ 不好的配置：检查太频繁
livenessProbe:
  periodSeconds: 1    # 每秒检查，压力太大

# ✅ 好的配置：合理间隔
livenessProbe:
  periodSeconds: 10   # 10 秒足够了
```

---

## 📝 总结

### 问题

- **原因**：应用没有 `/healthz` 端点，但 Helm 配置了 HTTP 健康检查
- **结果**：404 错误 → 健康检查失败 → Pod 重启循环

### 快速修复（方案1）

```yaml
# 改用 TCP 检查
livenessProbe:
  tcpSocket:
    port: http
readinessProbe:
  tcpSocket:
    port: http
```

**优点**：立即生效，无需改代码
**缺点**：只检查端口，无法检测应用逻辑

### 最佳实践（方案2）

1. 在应用代码中添加 `/healthz` 端点
2. 实现完整的健康检查逻辑（数据库、Redis、RPC）
3. 恢复 HTTP 健康检查
4. 合理配置超时和阈值

**优点**：可检测应用逻辑、依赖服务
**缺点**：需要修改代码

---

## 🔗 参考资料

- [Kubernetes Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [go-zero 健康检查实践](https://go-zero.dev/docs/tutorials)
- [12-Factor App: Health Checks](https://12factor.net/)

---

**修复状态**: ✅ 快速修复已完成（TCP 检查）
**长期方案**: 📝 添加健康检查端点（见方案2）
**修复文件**: `deploy/helm/templates/deployment.yaml`
**修复时间**: 2025-12-29
