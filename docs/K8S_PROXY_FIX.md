# 修复 Kubernetes 代理问题

本文档说明如何解决因代理配置导致的 Kubernetes 启动失败问题。

## 问题症状

- Kubernetes 一直显示"启动中"
- `kubectl get nodes` 返回空或连接失败
- `kube-controller-manager` 反复重启

## 根本原因

错误日志：
```
Error: Get "https://192.168.65.3:6443/healthz":
proxyconnect tcp: dial tcp 127.0.0.1:7897: connect: connection refused
```

**Kubernetes 内部组件（controller-manager）尝试通过系统代理访问 API Server，导致连接失败。**

Kubernetes 内部组件之间的通信应该是直连，不应该走代理。

## 解决方案

### 方案 1: 清除 Docker Desktop 代理配置（推荐）

1. 打开 **Docker Desktop**
2. 点击右上角 **设置图标** → **Resources** → **Proxies**
3. 检查以下设置：

   **如果启用了 "Manual proxy configuration":**
   - 方式 A: 完全禁用代理（推荐）
     - 选择 **System proxy** 或 **No proxy**

   - 方式 B: 添加 Kubernetes 内部地址到排除列表
     - 在 **Bypass proxy settings for these hosts & domains** 中添加：
       ```
       127.0.0.1
       localhost
       192.168.65.0/24
       kubernetes.docker.internal
       .cluster.local
       ```

4. 点击 **Apply & Restart**

### 方案 2: 完全重置 Kubernetes（如果方案 1 无效）

1. Docker Desktop → **Settings** → **Kubernetes**
2. 点击 **Reset Kubernetes Cluster**
3. 确认重置
4. 等待重新初始化（3-5 分钟）

### 方案 3: 检查系统代理设置

#### Windows

**检查并清理系统环境变量:**

1. 按 `Win + R`，输入 `sysdm.cpl`，回车
2. 点击 **高级** → **环境变量**
3. 检查以下变量（在用户变量和系统变量中）：
   - `HTTP_PROXY`
   - `HTTPS_PROXY`
   - `NO_PROXY`
   - `http_proxy`
   - `https_proxy`
   - `no_proxy`

4. **推荐操作**:
   - 删除这些变量（如果不需要全局代理）
   - 或者在 `NO_PROXY` 中添加：
     ```
     127.0.0.1,localhost,192.168.65.0/24,kubernetes.docker.internal,.cluster.local
     ```

5. 点击 **确定** 保存
6. **重启电脑**（或至少重启 Docker Desktop）

**使用 PowerShell 临时清除:**

```powershell
# 临时清除当前会话的代理
$env:HTTP_PROXY = ""
$env:HTTPS_PROXY = ""
$env:NO_PROXY = ""

# 重启 Docker Desktop
Restart-Service docker  # 或通过托盘图标重启
```

#### 检查代理软件

如果你使用以下代理软件，需要配置排除规则：
- **Clash**: 在 Settings → Bypass 中添加 `192.168.65.0/24`, `kubernetes.docker.internal`
- **V2Ray**: 在路由设置中添加直连规则
- **Shadowsocks**: 配置 PAC 或添加直连规则
- **其他代理软件**: 添加 Kubernetes 内部 IP 段到直连/绕过列表

### 方案 4: 使用脚本一键修复

运行以下 PowerShell 脚本：

```powershell
.\scripts\fix-k8s-proxy-issue.ps1
```

## 验证修复

### 1. 检查 controller-manager 日志

```bash
# 等待 30 秒后检查
docker logs $(docker ps --filter "name=kube-controller-manager" --format "{{.Names}}" | head -1) 2>&1 | tail -20
```

**应该看到**:
- 没有 "connection refused" 错误
- 没有 "proxyconnect" 错误
- 看到 "Started controller" 等成功信息

### 2. 检查组件健康状态

```bash
kubectl get componentstatuses
```

**期望输出** (全部 Healthy):
```
NAME                 STATUS    MESSAGE   ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   ok
```

### 3. 检查节点状态

```bash
kubectl get nodes
```

**期望输出**:
```
NAME             STATUS   ROLES           AGE   VERSION
docker-desktop   Ready    control-plane   ...   v1.xx.x
```

### 4. 检查系统 Pods

```bash
kubectl get pods -n kube-system
```

**应该看到多个 pods 都在运行**:
```
NAME                                     READY   STATUS    RESTARTS   AGE
coredns-xxx                              1/1     Running   0          1m
etcd-docker-desktop                      1/1     Running   0          1m
kube-apiserver-docker-desktop            1/1     Running   0          1m
kube-controller-manager-docker-desktop   1/1     Running   0          1m
kube-proxy-xxx                           1/1     Running   0          1m
kube-scheduler-docker-desktop            1/1     Running   0          1m
storage-provisioner                      1/1     Running   0          1m
vpnkit-controller                        1/1     Running   0          1m
```

## 常见问题

### Q: 我需要代理访问外网，删除后怎么办？

A: 两种方式：
1. **推荐**: 只在 Docker Desktop 中禁用，保留系统代理
2. 使用 `NO_PROXY` 环境变量排除 Kubernetes 内部地址

### Q: 重启后问题又出现了？

A: 可能是某个软件或脚本在启动时自动设置了代理。检查：
- 开机启动项
- PowerShell/Bash 配置文件 (profile.ps1, .bashrc)
- 代理软件的自动配置

### Q: 端口 7897 是什么？

A: 常见于：
- Clash for Windows 默认 HTTP 代理端口
- V2Ray/V2RayN 的 HTTP 代理端口
- 其他代理工具的本地代理端口

### Q: 修复后 Docker 拉取镜像很慢？

A: 两种解决方案：
1. 配置 Docker 镜像加速器（阿里云、DaoCloud 等）
2. 只在拉取镜像时启用代理，Kubernetes 运行时禁用

## 预防措施

1. **使用镜像加速器**代替全局代理（针对 Docker）
2. **配置精确的代理规则**，排除本地和内网地址
3. **使用 PAC 模式**而不是全局代理
4. 定期检查 `NO_PROXY` 环境变量

## 相关资源

- Docker Desktop 代理配置: https://docs.docker.com/desktop/networking/
- Kubernetes 网络故障排查: https://kubernetes.io/docs/tasks/debug/
- 国内 Docker 镜像加速: https://gist.github.com/y0ngb1n/7e8f16af3242c7815e7ca2f0833d3ea6
