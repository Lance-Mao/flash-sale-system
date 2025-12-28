# GitHub Secrets 配置指南

本文档说明如何配置 GitHub Actions 所需的密钥（Secrets）。

## 概述

项目的 CI/CD 流程需要以下 GitHub Secrets：

| Secret 名称 | 用途 | 是否必需 | 获取方式 |
|------------|------|---------|---------|
| `DOCKERHUB_USERNAME` | Docker Hub 用户名 | 是 | Docker Hub 账号 |
| `DOCKERHUB_TOKEN` | Docker Hub 访问令牌 | 是 | Docker Hub Settings -> Security |
| `KUBE_CONFIG_DEV` | 开发环境 K8s 配置 | 部署时必需 | 参见下方 |
| `DINGTALK_TOKEN` | 钉钉通知 Token | 可选 | 钉钉群机器人 |

## 配置步骤

### 1. 访问 GitHub Secrets 设置页面

1. 打开你的 GitHub 仓库
2. 点击 **Settings** 标签
3. 在左侧菜单选择 **Secrets and variables** -> **Actions**
4. 点击 **New repository secret** 按钮

### 2. 配置 Docker Hub 凭证

#### DOCKERHUB_USERNAME

- **Name**: `DOCKERHUB_USERNAME`
- **Secret**: 你的 Docker Hub 用户名（例如：`yourusername`）

#### DOCKERHUB_TOKEN

1. 登录 [Docker Hub](https://hub.docker.com/)
2. 点击右上角头像 -> **Account Settings**
3. 选择 **Security** 标签
4. 点击 **New Access Token**
5. 填写：
   - **Access Token Description**: `GitHub Actions CI/CD`
   - **Access permissions**: 选择 **Read, Write, Delete**
6. 点击 **Generate**
7. 复制生成的 Token（只显示一次！）
8. 在 GitHub Secrets 中添加：
   - **Name**: `DOCKERHUB_TOKEN`
   - **Secret**: 粘贴刚才复制的 Token

### 3. 配置 Kubernetes 访问凭证（开发环境）

#### KUBE_CONFIG_DEV

**前置条件**: 已按照 `docs/K8S_DEPLOYMENT_TUNNEL.md` 配置 Cloudflare Tunnel

##### 方式 1: 使用脚本自动生成（推荐）

```powershell
# 1. 启动 Cloudflare Tunnel（快速模式）
.\scripts\start-cloudflare-tunnel.ps1 -Quick

# 记录输出的 Tunnel URL，例如:
# https://random-words-1234.trycloudflare.com

# 2. 生成远程 kubeconfig（在新的 PowerShell 窗口）
.\scripts\generate-remote-kubeconfig.ps1 `
  -TunnelUrl "https://random-words-1234.trycloudflare.com" `
  -Base64Output

# 脚本会自动:
# - 导出并修改 kubeconfig
# - 生成 base64 编码
# - 复制到剪贴板
```

##### 方式 2: 手动生成

```powershell
# 1. 导出当前 kubeconfig
kubectl config view --raw > kubeconfig-local.yaml

# 2. 编辑 kubeconfig-local.yaml
# 将 server 地址替换为 Cloudflare Tunnel URL:
#   原地址: https://kubernetes.docker.internal:6443
#   新地址: https://your-tunnel-url.trycloudflare.com

# 3. Base64 编码
$kubeconfig = Get-Content kubeconfig-local.yaml -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($kubeconfig)
$base64 = [Convert]::ToBase64String($bytes)
$base64 | Set-Clipboard
```

##### 添加到 GitHub Secrets

1. 在 GitHub Secrets 页面点击 **New repository secret**
2. **Name**: `KUBE_CONFIG_DEV`
3. **Secret**: 粘贴 base64 编码的 kubeconfig
4. 点击 **Add secret**

##### 验证配置

```bash
# 在本地测试（使用远程 kubeconfig）
export KUBECONFIG=./kubeconfig-remote.yaml
kubectl get nodes

# 应该能看到你的本地节点
# NAME             STATUS   ROLES           AGE   VERSION
# docker-desktop   Ready    control-plane   ...   v1.xx.x
```

### 4. 配置钉钉通知（可选）

如果不需要钉钉通知，可以在 workflow 中删除或注释掉相关步骤。

#### DINGTALK_TOKEN

1. 在钉钉群中添加自定义机器人
2. 选择 **自定义** -> **添加**
3. 配置机器人：
   - 名称: `GitHub CI/CD`
   - 安全设置: 选择 **加签** 或 **自定义关键词**
4. 复制 Webhook URL 中的 access_token 参数值
   ```
   https://oapi.dingtalk.com/robot/send?access_token=<这里是token>
   ```
5. 在 GitHub Secrets 中添加：
   - **Name**: `DINGTALK_TOKEN`
   - **Secret**: 粘贴 access_token 值

## 验证配置

配置完成后，可以通过以下方式验证：

### 查看 Secrets 列表

在 GitHub Secrets 页面应该能看到：
- ✅ DOCKERHUB_USERNAME
- ✅ DOCKERHUB_TOKEN
- ✅ KUBE_CONFIG_DEV
- ✅ DINGTALK_TOKEN (可选)

### 触发 GitHub Actions

```bash
# 推送代码到 main 分支触发 CI/CD
git add .
git commit -m "test: trigger ci/cd pipeline"
git push origin main
```

### 检查 Actions 日志

1. 在 GitHub 仓库页面点击 **Actions** 标签
2. 查看最新的 workflow 运行
3. 检查每个步骤的日志输出

常见错误：
- `Error: unauthorized`: DOCKERHUB_TOKEN 无效或过期
- `Error: unable to connect to server`: KUBE_CONFIG_DEV 配置错误或 Tunnel 未运行
- `Error: 403 Forbidden`: kubeconfig 中的证书过期或无效

## 安全最佳实践

1. **定期轮换密钥**
   - Docker Hub Token: 每 90 天
   - Kubeconfig 证书: 根据集群配置

2. **最小权限原则**
   - Docker Hub Token: 只授予必要的权限
   - Kubeconfig: 使用专门的服务账号，不要使用管理员账号

3. **监控访问**
   - 定期检查 Docker Hub 访问日志
   - 启用 Kubernetes 审计日志
   - 检查 GitHub Actions 运行历史

4. **立即撤销泄露的密钥**
   如果密钥意外泄露：
   1. 立即在 GitHub Secrets 中删除
   2. 在服务提供商处撤销对应的 Token/证书
   3. 生成新的密钥并重新配置

## 故障排查

### Docker Hub 认证失败

```bash
# 本地测试 Docker Hub Token
echo $DOCKERHUB_TOKEN | docker login -u $DOCKERHUB_USERNAME --password-stdin

# 如果失败，重新生成 Token
```

### Kubernetes 连接失败

```bash
# 测试 Cloudflare Tunnel 是否可访问
curl -k https://your-tunnel-url.trycloudflare.com

# 测试 kubeconfig
export KUBECONFIG=./kubeconfig-remote.yaml
kubectl cluster-info

# 查看详细错误
kubectl get nodes -v=9
```

### Base64 解码测试

```bash
# 验证 KUBE_CONFIG_DEV 是否正确编码
echo "$KUBE_CONFIG_DEV" | base64 -d | kubectl --kubeconfig=- get nodes
```

## 更新 Secrets

如需更新某个 Secret：

1. 在 GitHub Secrets 页面找到对应的 Secret
2. 点击右侧的 **Update** 按钮
3. 输入新的值
4. 点击 **Update secret**

**注意**:
- 更新 Secret 后，正在运行的 workflow 不会使用新值
- 需要重新触发 workflow 才能使用更新后的 Secret

## 本地开发 vs GitHub Actions

| 环境 | Docker 认证 | K8s 访问 | 通知 |
|-----|------------|----------|------|
| 本地开发 | 本地 Docker CLI | 直接访问 localhost:6443 | 无 |
| GitHub Actions | DOCKERHUB_TOKEN | 通过 Cloudflare Tunnel | DINGTALK_TOKEN |

## 参考资料

- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Docker Hub Access Tokens](https://docs.docker.com/docker-hub/access-tokens/)
- [Kubernetes kubeconfig](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
