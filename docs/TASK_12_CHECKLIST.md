# GitHub Secrets 配置清单 - 任务 12

**状态**: 进行中
**集群类型**: Docker Desktop Kubernetes ✅
**创建日期**: 2025-12-28

---

## ✅ 已完成

- [x] Kubernetes 集群运行正常 (docker-desktop)
- [x] kubectl 命令可用
- [x] 创建 flashsale-dev 命名空间
- [x] 生成 kubeconfig base64 脚本

---

## 📋 需要配置的 Secrets（3个必需，4个可选）

### 必需 Secrets（CI/CD 流程运行最少需要）

| # | Secret 名称 | 状态 | 用途 |
|---|------------|------|------|
| 1 | `HARBOR_USERNAME` | ⬜ 待配置 | 镜像仓库用户名 |
| 2 | `HARBOR_PASSWORD` | ⬜ 待配置 | 镜像仓库密码/Token |
| 3 | `KUBE_CONFIG_DEV` | ⬜ 待配置 | K8s 开发环境配置 |

### 可选 Secrets（增强功能）

| # | Secret 名称 | 状态 | 用途 |
|---|------------|------|------|
| 4 | `KUBE_CONFIG_PROD` | ⬜ 可选 | K8s 生产环境配置 |
| 5 | `DINGTALK_TOKEN` | ⬜ 可选 | 钉钉部署通知 |
| 6 | `SONAR_TOKEN` | ⬜ 可选 | SonarQube 代码扫描 |
| 7 | `SONAR_HOST_URL` | ⬜ 可选 | SonarQube 服务地址 |

---

## 🚀 配置步骤

### 步骤 1: 生成 KUBE_CONFIG_DEV ⭐

```powershell
# 在 PowerShell 中运行（项目根目录）
cd D:\project\go\flash-sale\flash-sale-system
.\scripts\generate-kubeconfig-base64.ps1
```

**脚本会自动**：
- ✅ 读取你的 kubeconfig 文件
- ✅ 转换为 base64 格式
- ✅ 复制到剪贴板
- ✅ 保存到 `scripts/kubeconfig-base64.txt`

**然后在 GitHub 添加**：
1. 打开: https://github.com/Lance-Mao/flash-sale-system/settings/secrets/actions
2. 点击 "New repository secret"
3. Name: `KUBE_CONFIG_DEV`
4. Secret: `Ctrl+V` 粘贴剪贴板内容
5. 点击 "Add secret"

✅ 完成后勾选上面清单中的 KUBE_CONFIG_DEV

---

### 步骤 2: 配置镜像仓库 Secrets ⭐

**推荐方案 A - Docker Hub（最简单，5分钟搞定）**

```
1. 注册/登录 Docker Hub: https://hub.docker.com/
2. 创建 Access Token:
   - 点击头像 -> Account Settings
   - Security -> New Access Token
   - Token 名称: flash-sale-ci
   - 权限: Read, Write, Delete
   - Generate 并保存 Token（只显示一次！）

3. 添加到 GitHub Secrets:
   HARBOR_USERNAME = 你的 Docker Hub 用户名
   HARBOR_PASSWORD = 上面生成的 Access Token

4. 修改 workflow 配置:
   打开 .github/workflows/ci-cd.yml
   找到 env 部分，修改：
     REGISTRY: docker.io
     IMAGE_PREFIX: 你的Docker Hub用户名
```

**推荐方案 B - 阿里云容器镜像服务（国内访问快）**

```
1. 开通服务: https://cr.console.aliyun.com/
2. 创建个人实例（免费）
3. 创建命名空间: flashsale
4. 设置固定密码:
   - 访问凭证 -> 设置固定密码
5. 记录信息:
   Registry: registry.cn-hangzhou.aliyuncs.com
   Username: 你的阿里云账号
   Password: 固定密码

6. 添加到 GitHub Secrets:
   HARBOR_USERNAME = 阿里云账号
   HARBOR_PASSWORD = 固定密码

7. 修改 workflow:
   REGISTRY: registry.cn-hangzhou.aliyuncs.com
   IMAGE_PREFIX: flashsale
```

**方案 C - 自建 Harbor（企业推荐，需要服务器）**

参考文档: `docs/ci-cd-enhancement/GITHUB_SECRETS_GUIDE.md`

✅ 完成后勾选上面清单中的 HARBOR_USERNAME 和 HARBOR_PASSWORD

---

### 步骤 3: 配置钉钉通知（可选但推荐）⭐

```
1. 创建钉钉群: "Flash Sale 部署通知"

2. 添加机器人:
   - 群设置 -> 智能群助手 -> 添加机器人 -> 自定义
   - 机器人名称: Flash Sale CI/CD
   - 安全设置: 自定义关键词 -> 输入 "部署"
   - 完成后复制 Webhook URL 中的 access_token

3. 添加到 GitHub Secrets:
   DINGTALK_TOKEN = access_token 的值
```

✅ 完成后勾选上面清单中的 DINGTALK_TOKEN

---

### 步骤 4: SonarQube 配置（可选，暂时可跳过）

如果暂时不需要代码质量扫描，可以：

**选项 1 - 跳过（推荐）**
```yaml
# 在 .github/workflows/ci-cd.yml 中注释掉：
# - name: SonarQube Scan
#   uses: sonarsource/sonarqube-scan-action@master
#   env:
#     SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
#     SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}
```

**选项 2 - 配置 SonarQube**

参考文档: `docs/ci-cd-enhancement/GITHUB_SECRETS_GUIDE.md`

---

## ✅ 验证配置

### 检查清单

完成后，在 GitHub Secrets 页面应该看到（最少配置）：

- [x] `HARBOR_USERNAME`
- [x] `HARBOR_PASSWORD`
- [x] `KUBE_CONFIG_DEV`
- [ ] `DINGTALK_TOKEN`（可选）

### 测试 CI/CD

```bash
# 1. 创建测试分支
git checkout -b test/ci-secrets

# 2. 修改一个文件
echo "# CI/CD Test" >> README.md

# 3. 提交并推送
git add README.md
git commit -m "test: verify CI/CD secrets configuration"
git push -u origin test/ci-secrets

# 4. 在 GitHub 创建 Pull Request

# 5. 观察 Actions 运行
# 访问: https://github.com/Lance-Mao/flash-sale-system/actions
```

**预期结果**：
- ✅ lint-and-test job 成功
- ✅ build-images job 成功（如果配置了镜像仓库）
- ✅ deploy-dev job 成功（如果推送到 main 分支）
- ✅ 钉钉收到通知（如果配置了）

---

## 🔧 当前环境信息

```
Kubernetes 集群: docker-desktop
K8s 版本: v1.34.1
节点状态: Ready
命名空间: flashsale-dev (已创建)
Context: docker-desktop

集群地址: https://kubernetes.docker.internal:6443
```

---

## 📝 注意事项

### workflow 需要调整的地方

1. **镜像仓库地址**（必须修改）
```yaml
# .github/workflows/ci-cd.yml
env:
  REGISTRY: docker.io  # 或 registry.cn-hangzhou.aliyuncs.com
  IMAGE_PREFIX: your-username  # 你的用户名或命名空间
```

2. **部署域名**（根据实际情况修改）
```yaml
# deploy-dev job
environment:
  url: https://dev-api.flashsale.com  # 改为你的实际域名或 IP
```

3. **健康检查 URL**（根据实际情况修改）
```yaml
# Run smoke tests
curl -f https://dev-api.flashsale.com/health || exit 1
```

### 安全建议

- ⚠️ 不要将 base64 字符串提交到代码仓库
- ⚠️ scripts/kubeconfig-base64.txt 已添加到 .gitignore
- ⚠️ 定期更新 Secrets（建议 3-6 个月）
- ⚠️ 使用 Robot Account 而非个人账号

---

## 📚 相关文档

- 详细指南: `docs/ci-cd-enhancement/GITHUB_SECRETS_GUIDE.md`
- CI/CD 配置: `docs/ci-cd-enhancement/CI_CD_GUIDE.md`
- 任务清单: `docs/TASK_STATUS.md`

---

## 🆘 遇到问题？

### Q1: base64 生成失败？

```powershell
# 手动生成（PowerShell）
$content = Get-Content $env:USERPROFILE\.kube\config -Raw
$bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
$base64 = [Convert]::ToBase64String($bytes)
$base64 | Set-Clipboard
Write-Host "已复制到剪贴板"
```

### Q2: GitHub Actions 报错 "Invalid kubeconfig"？

- 检查 base64 是否完整（没有换行）
- 确认 context 是 docker-desktop
- 确保 Docker Desktop K8s 正在运行

### Q3: 镜像推送失败？

- 确认 HARBOR_USERNAME 和 HARBOR_PASSWORD 正确
- 检查 REGISTRY 地址是否匹配
- 登录测试: `docker login registry-address`

---

**更新时间**: 2025-12-28
**下次检查**: 配置完成后运行测试 CI/CD

---

## ✅ 完成标记

配置完成后，更新 `docs/TASK_STATUS.md`:
- 任务 12: 配置 GitHub Secrets → ✅ 已完成
