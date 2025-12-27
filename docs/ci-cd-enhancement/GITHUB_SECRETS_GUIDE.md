# GitHub Secrets 配置详细指南

本指南帮助你完成任务 12：配置 GitHub Secrets，确保 CI/CD 流程可以正常运行。

## 📋 需要配置的 Secrets 清单

根据 `.github/workflows/ci-cd.yml` 分析，需要配置以下 Secrets：

| Secret 名称 | 必需/可选 | 用途 | 使用阶段 |
|------------|----------|------|---------|
| `HARBOR_USERNAME` | 必需 | Harbor 镜像仓库用户名 | 构建和推送镜像 |
| `HARBOR_PASSWORD` | 必需 | Harbor 镜像仓库密码 | 构建和推送镜像 |
| `KUBE_CONFIG_DEV` | 必需 | 开发环境 K8s 配置（base64） | 部署到 dev 环境 |
| `KUBE_CONFIG_PROD` | 可选 | 生产环境 K8s 配置（base64） | 部署到生产环境 |
| `DINGTALK_TOKEN` | 可选 | 钉钉机器人 Webhook Token | 部署通知 |
| `SONAR_TOKEN` | 可选 | SonarQube 认证 Token | 代码质量扫描 |
| `SONAR_HOST_URL` | 可选 | SonarQube 服务器地址 | 代码质量扫描 |

## 🔧 分步配置指南

### 步骤 1: 进入 GitHub Secrets 配置页面

1. 打开你的 GitHub 仓库页面：`https://github.com/Lance-Mao/flash-sale-system`
2. 点击顶部菜单的 **Settings** 标签
3. 在左侧菜单中找到 **Secrets and variables** → 点击 **Actions**
4. 点击右上角的 **New repository secret** 按钮

### 步骤 2: 配置 Harbor 镜像仓库 Secrets（必需）

#### 2.1 获取 Harbor 凭证

**选项 A - 使用 Docker Hub（简单，适合测试）**

如果暂时没有 Harbor，可以先使用 Docker Hub：

```bash
# 1. 注册 Docker Hub 账号：https://hub.docker.com/
# 2. 创建 Access Token：
#    - 登录 Docker Hub
#    - Account Settings → Security → New Access Token
#    - 输入 Token 名称（如：flash-sale-ci）
#    - 权限选择 Read, Write, Delete
#    - 保存 Token（只显示一次，请妥善保存）
```

然后修改 workflow 配置：
```yaml
# 在 .github/workflows/ci-cd.yml 中修改
env:
  REGISTRY: docker.io  # 改为 docker.io
  IMAGE_PREFIX: your-dockerhub-username  # 改为你的 Docker Hub 用户名
```

**选项 B - 部署 Harbor（推荐生产环境）**

```bash
# 使用 Docker Compose 快速部署 Harbor
# 1. 下载 Harbor 离线安装包
wget https://github.com/goharbor/harbor/releases/download/v2.10.0/harbor-offline-installer-v2.10.0.tgz
tar xvf harbor-offline-installer-v2.10.0.tgz
cd harbor

# 2. 配置 Harbor
cp harbor.yml.tmpl harbor.yml
# 编辑 harbor.yml，修改以下配置：
# hostname: harbor.yourdomain.com  # 或者使用 IP 地址
# harbor_admin_password: Harbor12345  # 管理员密码

# 3. 安装并启动 Harbor
sudo ./install.sh

# 4. 创建项目
# 浏览器访问 http://harbor.yourdomain.com
# 用户名：admin
# 密码：Harbor12345（或你设置的密码）
# 创建项目：flashsale（设为公开或私有）

# 5. 创建 Robot Account（推荐）
# Project flashsale → Robot Accounts → New Robot Account
# 名称：ci-robot
# 权限：Push, Pull
# 保存后会生成用户名和 Token
```

**选项 C - 使用阿里云容器镜像服务（推荐国内用户）**

```bash
# 1. 开通阿里云容器镜像服务：https://cr.console.aliyun.com/
# 2. 创建命名空间：flashsale
# 3. 创建镜像仓库（每个服务一个）
# 4. 设置访问凭证（固定密码）
#    - 进入"访问凭证"页面
#    - 设置固定密码
# 5. 记录：
#    - Registry: registry.cn-hangzhou.aliyuncs.com
#    - Username: 你的阿里云账号
#    - Password: 固定密码
```

#### 2.2 在 GitHub 添加 Harbor Secrets

1. 添加 `HARBOR_USERNAME`：
   - Name: `HARBOR_USERNAME`
   - Secret: 输入镜像仓库用户名
     - Docker Hub: 你的 Docker Hub 用户名
     - Harbor: `robot$ci-robot` 或 `admin`
     - 阿里云: 你的阿里云账号全名（通常是邮箱或手机号）
   - 点击 **Add secret**

2. 添加 `HARBOR_PASSWORD`：
   - Name: `HARBOR_PASSWORD`
   - Secret: 输入镜像仓库密码或 Token
   - 点击 **Add secret**

### 步骤 3: 配置 Kubernetes Secrets（必需）

#### 3.1 准备 Kubernetes 集群

**选项 A - 本地开发（Minikube）**

```bash
# 1. 安装 Minikube
# Windows:
choco install minikube

# Mac:
brew install minikube

# Linux:
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# 2. 启动 Minikube
minikube start --cpus=4 --memory=8192 --driver=docker

# 3. 验证
kubectl get nodes
```

**选项 B - 云服务 Kubernetes（推荐）**

- **阿里云 ACK**：https://cs.console.aliyun.com/
- **腾讯云 TKE**：https://console.cloud.tencent.com/tke2
- **华为云 CCE**：https://console.huaweicloud.com/cce2.0/

创建一个最小规格集群（2核4G * 2节点）用于开发环境。

#### 3.2 获取 kubeconfig 并转换为 base64

**Windows（PowerShell）**：

```powershell
# 1. 获取 kubeconfig 文件
# 如果使用 Minikube:
minikube update-context

# 如果使用云服务，从云控制台下载 kubeconfig 到 ~/.kube/config

# 2. 查看 kubeconfig 内容（确保正确）
cat $env:USERPROFILE\.kube\config

# 3. 转换为 base64（一行，无换行）
$content = Get-Content $env:USERPROFILE\.kube\config -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
$base64 = [Convert]::ToBase64String($bytes)
$base64 | Set-Clipboard
Write-Host "kubeconfig base64 已复制到剪贴板"
Write-Host $base64
```

**Linux/Mac**：

```bash
# 1. 获取 kubeconfig
# 如果使用 Minikube:
minikube update-context

# 2. 查看 kubeconfig 内容
cat ~/.kube/config

# 3. 转换为 base64（一行，无换行）
cat ~/.kube/config | base64 -w 0
# Mac 使用：
cat ~/.kube/config | base64

# 4. 复制输出的 base64 字符串
```

#### 3.3 在 GitHub 添加 Kubernetes Secrets

1. 添加 `KUBE_CONFIG_DEV`：
   - Name: `KUBE_CONFIG_DEV`
   - Secret: 粘贴上一步复制的 base64 字符串
   - 点击 **Add secret**

2. **可选** - 添加 `KUBE_CONFIG_PROD`（如果有生产环境）：
   - Name: `KUBE_CONFIG_PROD`
   - Secret: 生产环境 kubeconfig 的 base64
   - 点击 **Add secret**

### 步骤 4: 配置钉钉通知（可选但推荐）

#### 4.1 创建钉钉群机器人

1. 在钉钉中创建一个群（如："Flash Sale 部署通知"）
2. 点击群设置 → 智能群助手 → 添加机器人 → 自定义
3. 机器人名称：`Flash Sale CI/CD`
4. 安全设置选择：**加签**（记录签名密钥）或**自定义关键词**（输入"部署"）
5. 完成后会得到 Webhook URL：
   ```
   https://oapi.dingtalk.com/robot/send?access_token=XXXXXXXXXXXXXX
   ```
6. 复制 `access_token` 后面的部分（`XXXXXXXXXXXXXX`）

#### 4.2 在 GitHub 添加钉钉 Secret

1. 添加 `DINGTALK_TOKEN`：
   - Name: `DINGTALK_TOKEN`
   - Secret: 粘贴上一步的 access_token
   - 点击 **Add secret**

### 步骤 5: 配置 SonarQube（可选，用于代码质量）

如果暂时不需要代码质量扫描，可以跳过此步骤，或者注释掉 workflow 中的 SonarQube 步骤。

#### 5.1 部署 SonarQube（可选）

```bash
# 使用 Docker 快速部署
docker run -d --name sonarqube \
  -p 9000:9000 \
  -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
  sonarqube:community

# 访问 http://localhost:9000
# 默认账号：admin / admin（首次登录需要修改密码）
```

#### 5.2 获取 SonarQube Token

1. 登录 SonarQube → My Account → Security → Generate Tokens
2. 名称：`github-actions`
3. 类型：`Global Analysis Token`
4. 过期时间：选择较长时间
5. 生成并复制 Token

#### 5.3 在 GitHub 添加 SonarQube Secrets

1. 添加 `SONAR_TOKEN`：
   - Name: `SONAR_TOKEN`
   - Secret: 粘贴 SonarQube Token
   - 点击 **Add secret**

2. 添加 `SONAR_HOST_URL`：
   - Name: `SONAR_HOST_URL`
   - Secret: `http://your-sonarqube-server:9000`
   - 点击 **Add secret**

## ✅ 验证配置

### 检查 Secrets 列表

配置完成后，在 GitHub Secrets 页面应该看到以下 Secrets：

**必需的 Secrets（最少配置）**：
- ✅ `HARBOR_USERNAME`
- ✅ `HARBOR_PASSWORD`
- ✅ `KUBE_CONFIG_DEV`

**可选的 Secrets**：
- ⬜ `KUBE_CONFIG_PROD`（有生产环境时添加）
- ⬜ `DINGTALK_TOKEN`（需要钉钉通知时添加）
- ⬜ `SONAR_TOKEN`（需要代码质量扫描时添加）
- ⬜ `SONAR_HOST_URL`（需要代码质量扫描时添加）

### 测试 Secrets 是否正确

#### 测试 1: 验证 Harbor 凭证

```bash
# 使用配置的凭证登录镜像仓库
docker login harbor.example.com -u YOUR_USERNAME -p YOUR_PASSWORD
# 或 Docker Hub:
docker login -u YOUR_USERNAME -p YOUR_PASSWORD

# 成功显示：Login Succeeded
```

#### 测试 2: 验证 Kubernetes 配置

```bash
# 从 base64 恢复配置
echo "YOUR_BASE64_STRING" | base64 -d > /tmp/test-kubeconfig

# 使用恢复的配置测试连接
export KUBECONFIG=/tmp/test-kubeconfig
kubectl get nodes

# 成功显示节点列表
# 清理测试文件
rm /tmp/test-kubeconfig
```

#### 测试 3: 验证钉钉 Webhook

```bash
# 使用 curl 发送测试消息
curl -X POST "https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "msgtype": "text",
    "text": {
      "content": "GitHub Secrets 配置测试成功！"
    }
  }'

# 成功后钉钉群会收到测试消息
```

## 🚀 触发 CI/CD 测试

配置完成后，可以触发一次 CI/CD 测试验证所有 Secrets 是否正确：

```bash
# 1. 创建测试分支
git checkout -b test/ci-secrets

# 2. 做一个小修改（如修改 README）
echo "# CI/CD Test" >> README.md

# 3. 提交并推送
git add README.md
git commit -m "test: verify CI/CD secrets configuration"
git push -u origin test/ci-secrets

# 4. 在 GitHub 创建 Pull Request
# 观察 Actions 页面的运行结果
```

查看 CI/CD 执行情况：
- 访问：`https://github.com/Lance-Mao/flash-sale-system/actions`
- 点击最新的 workflow 运行
- 检查每个 job 是否成功

## 🔒 安全建议

1. **定期更新 Secrets**
   - 每 3-6 个月更换一次敏感凭证
   - 离职人员时立即更换相关凭证

2. **最小权限原则**
   - Harbor/Docker Hub 使用专门的 Robot Account，不要用管理员账号
   - Kubernetes 使用专门的 ServiceAccount，限制 namespace 权限

3. **备份 Secrets**
   - 将 Secrets 列表（不含值）记录在安全的地方
   - 使用密码管理器（如 1Password、Bitwarden）存储真实值

4. **监控使用**
   - 定期检查 Actions 日志，确认 Secrets 没有泄露
   - 避免在日志中打印 Secrets

## 📝 快速配置清单

完成后请检查：

- [ ] Harbor/Docker Hub 凭证已配置并测试成功
- [ ] Kubernetes 配置已转换为 base64 并添加
- [ ] 钉钉机器人 Token 已配置（可选）
- [ ] 所有 Secrets 在 GitHub 页面可见（但值已加密）
- [ ] 已触发一次 PR 测试 CI 流程
- [ ] 已在钉钉群收到测试通知（如果配置了）

## 🆘 常见问题

### Q1: base64 转换后的字符串太长，无法复制？

**A**: 直接在终端输出，然后保存到临时文件：

```bash
# Linux/Mac
cat ~/.kube/config | base64 -w 0 > /tmp/kubeconfig-base64.txt
cat /tmp/kubeconfig-base64.txt

# Windows PowerShell
$content = Get-Content $env:USERPROFILE\.kube\config -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
$base64 = [Convert]::ToBase64String($bytes)
$base64 | Out-File -FilePath $env:TEMP\kubeconfig-base64.txt
Get-Content $env:TEMP\kubeconfig-base64.txt
```

### Q2: CI/CD 报错 "Invalid kubeconfig"？

**A**: 检查以下几点：
- base64 转换时是否包含换行符（应该是一行）
- kubeconfig 中的 server 地址是否可从 GitHub Actions 访问
- 如果是本地 Minikube，需要暴露到公网或使用云服务

### Q3: 没有钉钉怎么办？

**A**: 有以下选项：
1. 不配置钉钉，workflow 会跳过通知步骤
2. 注释掉 workflow 中的钉钉通知步骤
3. 使用其他通知方式（Slack、企业微信、邮件）

### Q4: 暂时没有 Kubernetes 环境怎么办？

**A**: 可以：
1. 先完成 lint 和 test 阶段（不需要 K8s）
2. 注释掉 workflow 中的 deploy 阶段
3. 使用 Minikube 在本地快速搭建测试环境
4. 使用云服务的免费试用（阿里云、腾讯云）

## 📚 相关文档

- [GitHub Actions Secrets 官方文档](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Harbor 官方文档](https://goharbor.io/docs/)
- [Kubernetes 官方文档](https://kubernetes.io/docs/)
- [钉钉机器人文档](https://open.dingtalk.com/document/robots/custom-robot-access)

---

**完成时间预估**：1-2 小时（取决于是否需要部署 Harbor 和 K8s）

**下一步**：完成后即可进入任务 13-17（基础设施部署）
