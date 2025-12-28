# 内网穿透实现 K8s CI/CD 快速上手指南

## 快速开始（5 分钟验证流程）

### 第 1 步: 安装 cloudflared

**Windows (推荐使用 winget)**:
```powershell
winget install --id Cloudflare.cloudflared
```

或从 https://github.com/cloudflare/cloudflared/releases 下载安装。

### 第 2 步: 启动 Docker Desktop Kubernetes

1. 打开 Docker Desktop
2. Settings -> Kubernetes -> ☑ Enable Kubernetes
3. 等待 Kubernetes 启动（右下角显示绿色）

验证:
```powershell
kubectl get nodes
# 应该看到 docker-desktop 节点
```

### 第 3 步: 启动 Cloudflare Tunnel（快速模式）

```powershell
# 进入项目目录
cd D:\project\go\flash-sale\flash-sale-system

# 启动 tunnel（会自动获得一个临时域名）
.\scripts\start-cloudflare-tunnel.ps1 -Quick
```

输出示例:
```
启动 Tunnel...
⚠ 临时域名仅在 cloudflared 进程运行时有效
⚠ 关闭此窗口将停止 Tunnel

Your quick Tunnel has been created! Visit it at:
https://random-words-1234.trycloudflare.com  ← 复制这个 URL
```

**重要**: 保持这个 PowerShell 窗口打开！

### 第 4 步: 生成远程 kubeconfig

**在新的 PowerShell 窗口** 执行:

```powershell
# 使用刚才复制的 Tunnel URL
.\scripts\generate-remote-kubeconfig.ps1 `
  -TunnelUrl "https://random-words-1234.trycloudflare.com" `
  -Base64Output
```

脚本会:
- ✅ 生成 `kubeconfig-remote.yaml`
- ✅ 生成 `kubeconfig-remote.base64.txt`
- ✅ 自动复制 base64 到剪贴板
- ✅ 显示 base64 内容

### 第 5 步: 配置 GitHub Secrets

1. 打开你的 GitHub 仓库
2. **Settings** -> **Secrets and variables** -> **Actions**
3. 点击 **New repository secret**
4. 添加以下 Secrets:

#### 必需的 Secrets:

**KUBE_CONFIG_DEV** (已在剪贴板):
- Name: `KUBE_CONFIG_DEV`
- Secret: Ctrl+V 粘贴

**DOCKERHUB_USERNAME**:
- Name: `DOCKERHUB_USERNAME`
- Secret: 你的 Docker Hub 用户名

**DOCKERHUB_TOKEN**:
- Name: `DOCKERHUB_TOKEN`
- Secret: [获取方式见下方](#获取-docker-hub-token)

#### 可选的 Secrets:

**DINGTALK_TOKEN** (钉钉通知，可跳过):
- 如不需要，可以在 `.github/workflows/ci-cd.yml` 中注释掉相关步骤

### 第 6 步: 触发 CI/CD

```powershell
# 推送代码到 main 分支
git add .
git commit -m "ci: enable k8s deployment via cloudflare tunnel"
git push origin main
```

### 第 7 步: 查看部署结果

1. GitHub 仓库 -> **Actions** 标签
2. 查看最新的 workflow 运行
3. 检查 `deploy-dev` job 的日志

## 获取 Docker Hub Token

1. 登录 https://hub.docker.com/
2. 右上角头像 -> **Account Settings**
3. **Security** 标签 -> **New Access Token**
4. 填写:
   - Description: `GitHub Actions CI/CD`
   - Permissions: **Read, Write, Delete**
5. 点击 **Generate** 并复制 Token（只显示一次！）

## 注意事项

### ⚠️ Tunnel 必须持续运行

在 GitHub Actions 部署时，本地的 Cloudflare Tunnel 必须保持运行:
- 快速模式: 不要关闭 PowerShell 窗口
- 持久模式: 配置为 Windows 服务（见完整文档）

### ⚠️ 临时域名会变化

快速模式使用的 `trycloudflare.com` 域名每次启动都会变化:
- 如果重启 Tunnel，需要重新生成 kubeconfig
- 如果需要固定域名，使用持久化配置（见完整文档）

### ⚠️ 仅用于学习和验证

这种方式不适合生产环境:
- API Server 暴露到公网（通过 Cloudflare 保护）
- 依赖本地机器和网络稳定性
- 生产环境请使用云端 K8s 集群

## 故障排查

### Tunnel 连接失败
```powershell
# 检查本地 K8s 是否运行
kubectl get nodes

# 测试本地 API Server
curl -k https://127.0.0.1:6443
```

### GitHub Actions 部署失败

**错误**: `unable to connect to server`
- 检查本地 Tunnel 是否还在运行
- 检查 KUBE_CONFIG_DEV 是否正确配置

**错误**: `unauthorized` 或 `401`
- kubeconfig 中的证书可能有问题
- 重新生成 kubeconfig 并更新 Secret

**错误**: `Docker Hub authentication failed`
- 检查 DOCKERHUB_TOKEN 是否有效
- 重新生成 Token 并更新 Secret

### 测试远程访问

```powershell
# 使用生成的 kubeconfig 测试
$env:KUBECONFIG = ".\kubeconfig-remote.yaml"
kubectl get nodes

# 应该能看到:
# NAME             STATUS   ROLES           AGE   VERSION
# docker-desktop   Ready    control-plane   ...   v1.xx.x
```

## 进阶配置

### 持久化 Tunnel（固定域名）

参考完整文档: `docs/K8S_DEPLOYMENT_TUNNEL.md`

好处:
- 固定的域名（使用你自己的域名或 Cloudflare 子域名）
- 可配置为 Windows 服务，开机自启
- 更稳定的连接

### 完整文档

- **详细配置**: `docs/K8S_DEPLOYMENT_TUNNEL.md`
- **Secrets 配置**: `docs/GITHUB_SECRETS_SETUP.md`
- **CI/CD Workflow**: `.github/workflows/ci-cd.yml`

## 清理

### 停止 Tunnel
- 快速模式: Ctrl+C 或关闭 PowerShell 窗口
- 服务模式: `sc stop cloudflared`

### 删除 GitHub Secrets
1. Settings -> Secrets and variables -> Actions
2. 点击 Secret 右侧的删除按钮

### 禁用部署
注释掉 `.github/workflows/ci-cd.yml` 中的 `deploy-dev` job。
