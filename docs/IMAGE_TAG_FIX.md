# 镜像标签不匹配问题修复

## 🔴 问题描述

### 症状
部署到 K8s 后，所有 Pod 处于 `ImagePullBackOff` 状态：

```bash
kubectl get pods -n flashsale-dev
NAME                              READY   STATUS             RESTARTS   AGE
usercenter-api-xxx                0/1     ImagePullBackOff   0          2m
order-api-xxx                     0/1     ImagePullBackOff   0          2m
```

### 错误日志
```
Failed to pull image "docker.io/mzlone/usercenter-api:5ece3df1023c70a61f74f3a6290d92307a56bf16"
Error: manifest for docker.io/mzlone/usercenter-api:5ece3df1023c70a61f74f3a6290d92307a56bf16 not found
```

---

## 🔍 根本原因

### 镜像构建阶段

**.github/workflows/ci-cd.yml 第92-102行**：

```yaml
- name: Extract metadata
  id: meta
  uses: docker/metadata-action@v5
  with:
    images: ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/${{ matrix.service }}
    tags: |
      type=ref,event=branch          # 生成: main
      type=ref,event=pr
      type=semver,pattern={{version}}
      type=semver,pattern={{major}}.{{minor}}
      type=sha,prefix={{branch}}-    # 生成: main-5ece3df
```

**实际推送的镜像标签**：
- ✅ `docker.io/mzlone/usercenter-api:main`
- ✅ `docker.io/mzlone/usercenter-api:main-5ece3df` （短SHA，7位）

### Helm 部署阶段

**原配置（错误）**：

```yaml
- name: Deploy with Helm
  run: |
    helm upgrade --install flashsale ./deploy/helm \
      --set image.tag=${{ github.sha }}    # ❌ 完整 SHA (40位)
```

**尝试拉取的镜像**：
- ❌ `docker.io/mzlone/usercenter-api:5ece3df1023c70a61f74f3a6290d92307a56bf16`

### 问题总结

| 阶段 | 标签格式 | 示例 | 状态 |
|------|---------|------|------|
| 镜像构建 | `{branch}-{短SHA}` | `main-5ece3df` | ✅ 存在 |
| Helm 部署 | `{完整SHA}` | `5ece3df1023c...` | ❌ 不存在 |

**标签不匹配 → 镜像拉取失败！**

---

## ✅ 解决方案

### 方案对比

| 方案 | 标签格式 | 优点 | 缺点 | 推荐场景 |
|------|---------|------|------|---------|
| 1. 固定标签 | `main` | 简单 | 无法回滚 | 开发环境 |
| 2. 短SHA | `main-5ece3df` | 可追溯，匹配构建 | 需要截取SHA | ⭐ 所有环境 |
| 3. 完整SHA | `5ece3df...` | 唯一性强 | 需修改构建配置 | 严格追溯需求 |

### 采用方案：方案2（短SHA）

**修复后的配置**：

```yaml
- name: Deploy with Helm
  run: |
    # Extract short SHA (first 7 chars) to match image tag
    SHORT_SHA=$(echo ${{ github.sha }} | cut -c1-7)
    IMAGE_TAG="${{ github.ref_name }}-${SHORT_SHA}"

    echo "Deploying with image tag: $IMAGE_TAG"

    helm upgrade --install flashsale ./deploy/helm \
      --namespace flashsale-dev \
      --create-namespace \
      --set image.tag=$IMAGE_TAG \           # ✅ 使用短SHA
      --set env=dev \
      --values ./deploy/helm/values-dev.yaml \
      --wait --timeout 10m \
      --debug
```

**关键改动**：

```bash
# 原来（错误）
--set image.tag=${{ github.sha }}
# 结果: 5ece3df1023c70a61f74f3a6290d92307a56bf16

# 修改后（正确）
SHORT_SHA=$(echo ${{ github.sha }} | cut -c1-7)
IMAGE_TAG="${{ github.ref_name }}-${SHORT_SHA}"
--set image.tag=$IMAGE_TAG
# 结果: main-5ece3df
```

---

## 🧪 验证修复

### 1. 检查镜像标签

**在 Docker Hub 查看**：
```bash
# 浏览器访问
https://hub.docker.com/r/mzlone/usercenter-api/tags

# 应该看到：
# - main
# - main-5ece3df
```

**本地拉取测试**：
```bash
docker pull docker.io/mzlone/usercenter-api:main-5ece3df
# 应该成功
```

### 2. 检查 Helm 部署

**查看部署日志**：
```
Deploying with image tag: main-5ece3df
```

**验证 Pod 使用的镜像**：
```bash
kubectl get deployment usercenter-api -n flashsale-dev \
  -o jsonpath='{.spec.template.spec.containers[0].image}'

# 预期输出:
# docker.io/mzlone/usercenter-api:main-5ece3df
```

### 3. 检查 Pod 状态

```bash
kubectl get pods -n flashsale-dev

# 预期输出（所有 Running）:
# NAME                              READY   STATUS    RESTARTS   AGE
# usercenter-api-xxx                1/1     Running   0          2m
# order-api-xxx                     1/1     Running   0          2m
```

---

## 📊 影响范围

### 影响的服务（11个）

所有微服务都受影响：
- ✅ usercenter-api
- ✅ usercenter-rpc
- ✅ travel-api (product)
- ✅ travel-rpc
- ✅ order-api
- ✅ order-rpc
- ✅ order-mq
- ✅ payment-api
- ✅ payment-rpc
- ✅ mqueue-job
- ✅ mqueue-scheduler

### 一次性修复

只需修改 CI/CD 配置中的 Helm 部署步骤，所有服务自动修复。

---

## 🔄 如何应用修复

### 方式1: 重新触发 CI/CD

```bash
# 提交代码（可以是空提交）
git commit --allow-empty -m "fix: correct image tag format in deployment"
git push origin main

# GitHub Actions 会自动：
# 1. 构建镜像（标签: main-xxxxx）
# 2. 部署应用（使用匹配的标签）
```

### 方式2: 手动更新现有部署

如果镜像已存在，只是标签不对：

```bash
# 获取当前 commit 的短 SHA
SHORT_SHA=$(git rev-parse --short HEAD)
IMAGE_TAG="main-$SHORT_SHA"

# 更新部署
helm upgrade flashsale ./deploy/helm \
  --namespace flashsale-dev \
  --reuse-values \
  --set image.tag=$IMAGE_TAG

# 等待 Pod 重启
kubectl rollout status deployment/usercenter-api -n flashsale-dev
```

---

## 📝 最佳实践

### 1. 标签命名规范

推荐格式：`{分支名}-{短SHA}`

**示例**：
- `main-a1b2c3d` (main 分支)
- `develop-e4f5g6h` (develop 分支)
- `v1.0.0` (tag 版本)

### 2. 不同环境的标签策略

| 环境 | 标签策略 | 示例 | 原因 |
|------|---------|------|------|
| **开发环境** | `{branch}-{短SHA}` | `main-5ece3df` | 可追溯每次提交 |
| **测试环境** | `{branch}-latest` | `develop-latest` | 总是最新代码 |
| **生产环境** | `{version}` | `v1.2.3` | 语义化版本，稳定 |

### 3. metadata-action 配置模板

```yaml
- name: Extract metadata
  id: meta
  uses: docker/metadata-action@v5
  with:
    images: ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/${{ matrix.service }}
    tags: |
      # 分支名（如 main, develop）
      type=ref,event=branch

      # PR 编号（如 pr-123）
      type=ref,event=pr

      # Git 标签（如 v1.0.0）
      type=semver,pattern={{version}}
      type=semver,pattern={{major}}.{{minor}}

      # SHA 标签（带分支前缀）
      type=sha,prefix={{branch}}-

      # 【可选】完整 SHA（如需要）
      # type=sha
```

### 4. Helm 部署命令模板

```bash
# 开发环境
SHORT_SHA=$(echo ${{ github.sha }} | cut -c1-7)
IMAGE_TAG="${{ github.ref_name }}-${SHORT_SHA}"
helm upgrade --install app ./helm \
  --set image.tag=$IMAGE_TAG

# 生产环境（使用 Git Tag）
IMAGE_TAG="${{ github.ref_name }}"  # 如 v1.0.0
helm upgrade --install app ./helm \
  --set image.tag=$IMAGE_TAG
```

---

## ⚠️ 常见错误

### 错误1: 使用完整 SHA

```yaml
# ❌ 错误
--set image.tag=${{ github.sha }}
# 结果: 5ece3df1023c70a61f74f3a6290d92307a56bf16

# ✅ 正确
SHORT_SHA=$(echo ${{ github.sha }} | cut -c1-7)
--set image.tag=main-$SHORT_SHA
# 结果: main-5ece3df
```

### 错误2: 标签不包含分支名

```yaml
# ❌ 错误
tags: |
  type=sha
# 结果: 5ece3df (无法区分分支)

# ✅ 正确
tags: |
  type=sha,prefix={{branch}}-
# 结果: main-5ece3df (清晰明了)
```

### 错误3: 构建和部署标签格式不一致

```yaml
# ❌ 构建时
tags: type=sha,prefix={{branch}}-  # main-5ece3df

# ❌ 部署时
--set image.tag=latest  # latest (不匹配)

# ✅ 两者必须一致
```

---

## 🔗 相关文档

- [Docker metadata-action](https://github.com/docker/metadata-action)
- [Helm 镜像管理](https://helm.sh/docs/)
- [K8s ImagePullBackOff 排查](https://kubernetes.io/docs/concepts/containers/images/)

---

## 📌 总结

### 问题
- 镜像构建标签: `main-5ece3df`
- Helm 部署标签: `5ece3df1023c...`
- 结果: 标签不匹配，拉取失败

### 修复
```bash
# 截取短 SHA，保持一致
SHORT_SHA=$(echo ${{ github.sha }} | cut -c1-7)
IMAGE_TAG="${{ github.ref_name }}-${SHORT_SHA}"
--set image.tag=$IMAGE_TAG
```

### 验证
```bash
# 镜像存在
docker pull docker.io/mzlone/usercenter-api:main-5ece3df

# Pod 运行
kubectl get pods -n flashsale-dev
# 所有 Running ✅
```

---

**修复状态**: ✅ 已完成
**影响服务**: 11个微服务
**修复文件**: `.github/workflows/ci-cd.yml`
**修复时间**: 2025-12-29
