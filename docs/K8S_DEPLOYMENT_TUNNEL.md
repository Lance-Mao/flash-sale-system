# 使用内网穿透访问本地 K8s 集群

## 概述

本文档说明如何使用 Cloudflare Tunnel 将本地 Docker Desktop K8s 集群暴露给 GitHub Actions 进行 CI/CD 部署。

**适用场景**: 学习、开发、验证 CI/CD 流程
**不适用**: 生产环境

## 前置条件

1. Docker Desktop 已安装并启动 Kubernetes
2. 有 Cloudflare 账号（免费）
3. kubectl 可以访问本地集群

## 步骤 1: 验证本地 K8s 集群

```bash
# 检查集群状态
kubectl cluster-info

# 应该看到类似输出:
# Kubernetes control plane is running at https://kubernetes.docker.internal:6443
```

## 步骤 2: 安装 Cloudflare Tunnel (cloudflared)

### Windows
```powershell
# 使用 winget 安装
winget install --id Cloudflare.cloudflared

# 或下载安装包
# https://github.com/cloudflare/cloudflared/releases
```

### macOS
```bash
brew install cloudflared
```

### Linux
```bash
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb
```

## 步骤 3: 认证 Cloudflare

```bash
# 登录到 Cloudflare 账号
cloudflared tunnel login
```

这会打开浏览器，选择你要使用的域名（或使用 trycloudflare.com 的临时域名）。

## 步骤 4: 创建 Tunnel

```bash
# 创建一个名为 flashsale-k8s 的 tunnel
cloudflared tunnel create flashsale-k8s

# 记录输出中的 Tunnel ID，例如:
# Created tunnel flashsale-k8s with id 12345678-1234-1234-1234-123456789abc
```

## 步骤 5: 配置 Tunnel

创建配置文件 `~/.cloudflared/config.yml` (或在 Windows 上 `%USERPROFILE%\.cloudflared\config.yml`):

```yaml
tunnel: flashsale-k8s
credentials-file: C:\Users\YourUsername\.cloudflared\12345678-1234-1234-1234-123456789abc.json

ingress:
  # 将所有流量转发到本地 K8s API Server
  - hostname: k8s.yourdomain.com  # 或使用 trycloudflare.com 的随机域名
    service: https://127.0.0.1:6443
    originRequest:
      noTLSVerify: true  # Docker Desktop 使用自签名证书
  # 默认规则（必须）
  - service: http_status:404
```

**注意**:
- 替换 `credentials-file` 路径为实际的凭证文件路径
- 如果没有自己的域名，可以使用 `--url` 参数使用临时域名（见下方）

## 步骤 6: 运行 Tunnel

### 方式 1: 使用配置文件（推荐）

```bash
# 启动 tunnel（前台运行，用于测试）
cloudflared tunnel run flashsale-k8s

# 或后台运行
cloudflared tunnel run flashsale-k8s &
```

### 方式 2: 使用临时域名（快速测试）

```bash
# 无需配置文件，获得一个临时的 trycloudflare.com 域名
cloudflared tunnel --url https://127.0.0.1:6443 --no-tls-verify
```

输出示例:
```
Your quick Tunnel has been created! Visit it at:
https://random-words-1234.trycloudflare.com
```

## 步骤 7: 生成可访问的 kubeconfig

需要创建一个新的 kubeconfig，将 API Server 地址替换为 Cloudflare Tunnel 的公网地址：

```bash
# 导出当前 kubeconfig
kubectl config view --raw > kubeconfig-local.yaml

# 编辑 kubeconfig-local.yaml，修改 server 地址:
# 原地址: https://kubernetes.docker.internal:6443
# 新地址: https://k8s.yourdomain.com (或 trycloudflare.com 的地址)
```

或者使用脚本自动生成（见 `scripts/generate-remote-kubeconfig.ps1`）。

## 步骤 8: 配置 GitHub Secrets

在 GitHub 仓库设置中添加以下 Secrets：

1. **KUBE_CONFIG_DEV**: Base64 编码的 kubeconfig

```bash
# Windows PowerShell
$kubeconfig = Get-Content kubeconfig-remote.yaml -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($kubeconfig)
$base64 = [Convert]::ToBase64String($bytes)
$base64 | Set-Clipboard
```

```bash
# Linux/macOS
cat kubeconfig-remote.yaml | base64 | pbcopy  # macOS
cat kubeconfig-remote.yaml | base64 | xclip   # Linux
```

## 步骤 9: 启用 CI/CD 部署

修改 `.github/workflows/ci-cd.yml`，取消注释 `deploy-dev` job。

## 测试验证

```bash
# 在另一台机器或使用远程 kubeconfig 测试
export KUBECONFIG=./kubeconfig-remote.yaml
kubectl get nodes

# 应该能看到你本地的节点
```

## 安全注意事项

⚠️ **仅用于学习和测试！**

1. K8s API Server 暴露到公网（通过 Cloudflare 保护）
2. 使用强认证（client certificates）
3. 定期检查 Cloudflare 访问日志
4. 不在 tunnel 时关闭 tunnel
5. 生产环境请使用云端 K8s 集群

## 故障排查

### Tunnel 连接失败
```bash
# 检查 cloudflared 日志
cloudflared tunnel info flashsale-k8s

# 测试本地 K8s API 连通性
curl -k https://127.0.0.1:6443
```

### kubectl 无法连接
```bash
# 验证 Tunnel 是否正常
curl -k https://k8s.yourdomain.com

# 检查 kubeconfig 中的证书是否正确
kubectl config view --raw
```

### GitHub Actions 部署失败
- 检查 KUBE_CONFIG_DEV secret 是否正确配置
- 检查 Tunnel 是否持续运行
- 查看 GitHub Actions 日志中的具体错误

## 进阶：作为 Windows 服务运行

```bash
# 安装为 Windows 服务（需要管理员权限）
cloudflared service install

# 启动服务
sc start cloudflared

# 查看服务状态
sc query cloudflared
```

## 清理

```bash
# 停止 tunnel
# Ctrl+C 或 kill 进程

# 删除 tunnel
cloudflared tunnel delete flashsale-k8s

# 卸载 Windows 服务
cloudflared service uninstall
```
