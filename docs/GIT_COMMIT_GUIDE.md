# Git 提交指南

## 🎯 当前状态

项目已重命名为 **flash-sale-system** (电商秒杀系统)，所有配置和文档已更新完成，现在可以提交到 GitHub 了。

## 📝 提交步骤

### 1. 查看当前状态

```bash
cd D:\project\go\flash-sale-system
git status
```

### 2. 添加所有更改

```bash
# 添加所有文件
git add .

# 查看将要提交的内容
git status
```

### 3. 提交更改

```bash
# 使用描述性的提交信息
git commit -m "refactor: rename project to flash-sale-system and add CI/CD

- Rename from go-zero-looklook to flash-sale-system
- Change business context from travel booking to flash sale e-commerce
- Add complete CI/CD configuration (GitHub Actions, Helm, Docker)
- Add comprehensive documentation (CI/CD guide, feature roadmap, dev guide)
- Update all references: looklook -> flashsale
- Rewrite README with flash sale focus

Major changes:
- .github/workflows/ci-cd.yml: Complete CI/CD pipeline
- deploy/helm/: Kubernetes deployment charts
- docs/ci-cd-enhancement/: Full documentation suite
- README.md/README-cn.md: New project documentation
- build.ps1/build.bat: Windows build scripts
- All service configurations updated"
```

### 4. 创建 GitHub 仓库并推送

#### 方式 A: 通过 GitHub 网站创建

1. 访问 https://github.com/new
2. 仓库名称: `flash-sale-system`
3. 描述: `High-performance flash sale e-commerce system built with go-zero microservices framework`
4. 设置为 **Public** (或 Private)
5. **不要** 初始化 README (我们已经有了)
6. 创建仓库

#### 方式 B: 使用 GitHub CLI (如果已安装)

```bash
# 安装 GitHub CLI: https://cli.github.com/
gh repo create flash-sale-system --public --source=. --remote=origin --push
```

### 5. 连接远程仓库并推送

```bash
# 添加远程仓库 (替换 yourusername 为你的 GitHub 用户名)
git remote add origin https://github.com/yourusername/flash-sale-system.git

# 查看远程仓库
git remote -v

# 推送到 main 分支
git branch -M main
git push -u origin main
```

### 6. 验证推送

```bash
# 查看远程分支
git branch -r

# 查看最近提交
git log --oneline -n 5
```

## 🔧 如果遇到问题

### 问题 1: 已经有旧的 remote

```bash
# 查看现有 remote
git remote -v

# 删除旧的 remote
git remote remove origin

# 添加新的 remote
git remote add origin https://github.com/yourusername/flash-sale-system.git
```

### 问题 2: 推送被拒绝

```bash
# 如果远程有内容，强制推送 (小心使用)
git push -u origin main --force

# 或者先拉取再推送
git pull origin main --rebase
git push -u origin main
```

### 问题 3: 文件太大

```bash
# 查看大文件
git ls-files -z | xargs -0 du -h | sort -h | tail -20

# 如果有不需要的大文件，添加到 .gitignore
echo "data/" >> .gitignore
echo "*.exe" >> .gitignore
git rm --cached -r data/
git commit -m "chore: remove large files from git"
```

## 📋 提交前检查清单

- [ ] 确认 `.gitignore` 正确配置（不提交 `data/`、`bin/`、`.idea/` 等）
- [ ] README.md 已更新为 flash-sale-system
- [ ] go.mod 中的 module 路径已更新
- [ ] 所有敏感信息（密码、密钥）已移除
- [ ] 文档中的 `yourusername` 已替换为实际用户名

## 🎉 推送后的操作

### 1. 更新 README 中的链接

在 GitHub 仓库页面，找到你的实际链接，然后更新：

```bash
# 替换 README.md 中的占位符
# yourusername → 你的实际用户名

# 重新提交
git add README.md README-cn.md
git commit -m "docs: update repository URLs"
git push
```

### 2. 配置 GitHub Actions Secrets

在 GitHub 仓库设置中添加 Secrets：
- Settings → Secrets and variables → Actions → New repository secret

需要添加的 Secrets：
```
HARBOR_USERNAME=your-harbor-username
HARBOR_PASSWORD=your-harbor-password
KUBE_CONFIG_DEV=<base64-encoded-kubeconfig>
KUBE_CONFIG_PROD=<base64-encoded-kubeconfig>
DINGTALK_TOKEN=your-dingtalk-webhook-token
SONAR_TOKEN=your-sonar-token (可选)
SONAR_HOST_URL=https://sonarcloud.io (可选)
```

### 3. 启用 GitHub Actions

- GitHub 仓库 → Actions 标签
- 如果看到提示，点击 "I understand my workflows, go ahead and enable them"

### 4. 添加项目描述和标签

在 GitHub 仓库页面：
- 点击右上角的 ⚙️ (设置图标)
- 添加描述: `High-performance flash sale e-commerce system built with go-zero microservices framework`
- 添加标签 (Topics):
  - `go-zero`
  - `microservices`
  - `flash-sale`
  - `e-commerce`
  - `high-concurrency`
  - `kubernetes`
  - `docker`
  - `ci-cd`
  - `golang`

## 🔗 有用的命令

```bash
# 查看提交历史
git log --oneline --graph --all

# 查看文件变更
git diff HEAD~1

# 查看仓库大小
git count-objects -vH

# 清理未跟踪文件（谨慎使用）
git clean -fd -n  # 预览
git clean -fd     # 实际执行
```

## ✨ 下一步

提交成功后，你可以：

1. 在 README 中添加徽章 (Badges):
   - Build status
   - Go version
   - License
   - Stars

2. 创建第一个 Release:
   ```bash
   git tag -a v0.1.0 -m "Initial release"
   git push origin v0.1.0
   ```

3. 邀请协作者或公开项目

4. 开始开发新功能！

---

**准备好了吗？执行上面的命令开始提交吧！**
