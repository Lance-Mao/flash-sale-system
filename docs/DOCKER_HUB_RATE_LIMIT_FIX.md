# Docker Hub 限流问题解决方案

## 🔴 错误信息

```
429 Too Many Requests
toomanyrequests: You have reached your pull rate limit
Error: You may increase the limit by upgrading.
https://www.docker.com/increase-rate-limit
```

---

## 🔍 问题分析

### Docker Hub 限流策略

| 账户类型 | 拉取限制 | 时间窗口 |
|---------|---------|---------|
| **匿名用户** | 100次 | 6小时 |
| **免费账户** | 200次 | 6小时 |
| **Pro账户** | 无限制 | - |
| **Team账户** | 无限制 | - |

### 项目情况

```
构建服务数量: 11个
每个服务拉取: golang:1.22-alpine + alpine:3.19 = 2个镜像
总拉取次数: 11 × 2 = 22次（单次构建）

如果频繁触发CI/CD:
- 1小时内触发5次 = 110次拉取
- 很容易达到200次限制
```

### 为什么会触发限流？

1. ✅ **已配置登录**（第89-94行）
   ```yaml
   - name: Login to Harbor
     uses: docker/login-action@v3
     with:
       registry: docker.io
       username: ${{ secrets.HARBOR_USERNAME }}
       password: ${{ secrets.HARBOR_PASSWORD }}
   ```

2. ❌ **但拉取基础镜像仍计入限额**
   - 即使认证，免费账户仍有200次/6小时限制
   - 11个服务并发构建，快速消耗限额

3. ❌ **GitHub Actions 共享 IP**
   - 多个用户共享同一个 runner IP
   - 匿名限额按IP计算（100次/6小时）

---

## ✅ 解决方案

### 方案1：限制并发构建（已实施 ⭐）

**修改内容**（ci-cd.yml 第67-69行）：

```yaml
strategy:
  max-parallel: 3      # 限制同时构建3个服务
  fail-fast: false     # 一个失败不影响其他
  matrix:
    service: [...]
```

**效果**：
- ✅ 降低瞬时拉取频率
- ✅ 减少触发限流概率
- ⚠️ 构建时间增加（原11并发 → 现3并发）

**构建时间估算**：
```
原来: 11个服务并发 = ~10分钟
现在: 3个并发，分4批 = ~15-20分钟
```

---

### 方案2：使用镜像缓存（已配置）

**现有配置**（ci-cd.yml 第116-117行）：

```yaml
- name: Build and push
  uses: docker/build-push-action@v5
  with:
    cache-from: type=gha        # 从 GitHub Actions 缓存读取
    cache-to: type=gha,mode=max # 写入缓存（最大化缓存层）
```

**工作原理**：
```
第一次构建:
├─ 拉取 golang:1.22-alpine ❌ 计入限额
├─ 拉取 alpine:3.19 ❌ 计入限额
└─ 缓存所有层 ✅

后续构建:
├─ 从缓存读取 ✅ 不拉取镜像
└─ 只拉取变更的层 ✅ 减少拉取
```

**限制**：
- ⚠️ 首次构建仍需拉取
- ⚠️ 缓存过期（通常7天）后需重新拉取

---

### 方案3：使用阿里云镜像加速（推荐长期方案）

#### 3.1 修改 Dockerfile

**原 Dockerfile**（所有服务）：
```dockerfile
FROM golang:1.22-alpine AS builder
...
FROM alpine:3.19
```

**修改为使用阿里云镜像**：
```dockerfile
# 使用阿里云镜像
FROM registry.cn-hangzhou.aliyuncs.com/google_containers/golang:1.22-alpine AS builder

# 配置 Alpine 镜像源
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

...

FROM registry.cn-hangzhou.aliyuncs.com/google_containers/alpine:3.19
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
```

**优点**：
- ✅ 不受 Docker Hub 限流影响
- ✅ 国内访问速度快
- ✅ 免费无限制

**缺点**：
- ❌ 需要修改所有 Dockerfile
- ❌ 镜像可能不是最新版本

---

### 方案4：等待限流窗口过期（临时方案）

**限流时间窗口**：6小时

**操作步骤**：

1. **查看当前限额**（在本地执行）：
   ```bash
   # 匿名查询
   curl -s -D - -o /dev/null https://auth.docker.io/token\?service\=registry.docker.io\?scope\=repository:library/golang:pull | grep -i ratelimit

   # 认证查询
   TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/golang:pull" \
     -u 你的用户名:你的密码 | jq -r .token)
   curl -s -D - -o /dev/null -H "Authorization: Bearer $TOKEN" \
     https://registry-1.docker.io/v2/library/golang/manifests/latest | grep -i ratelimit

   # 输出示例:
   # ratelimit-limit: 200;w=21600
   # ratelimit-remaining: 15  # 剩余15次
   ```

2. **等待重置**：
   - 限流窗口：6小时（21600秒）
   - 建议等待后再次触发 CI/CD

3. **临时禁用自动构建**：
   ```yaml
   # 临时修改 ci-cd.yml
   on:
     push:
       branches: [main]
     # 手动触发
     workflow_dispatch:
   ```

---

### 方案5：升级 Docker Hub 账户（付费方案）

**价格**：
- **Pro**: $5/月（个人）
  - 无限镜像拉取
  - 5个私有仓库

- **Team**: $7/用户/月（团队）
  - 无限镜像拉取
  - 无限私有仓库

**适用场景**：
- 频繁触发 CI/CD
- 多人团队开发
- 需要更多私有仓库

---

### 方案6：使用 GitHub Container Registry（最佳长期方案）

#### 6.1 修改基础镜像构建

**创建自己的基础镜像**：

```dockerfile
# .github/workflows/build-base-images.yml
name: Build Base Images

on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 0'  # 每周日构建

jobs:
  build-base:
    runs-on: ubuntu-latest
    steps:
      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Pull and push golang
        run: |
          docker pull golang:1.22-alpine
          docker tag golang:1.22-alpine ghcr.io/${{ github.repository }}/golang:1.22-alpine
          docker push ghcr.io/${{ github.repository }}/golang:1.22-alpine

      - name: Pull and push alpine
        run: |
          docker pull alpine:3.19
          docker tag alpine:3.19 ghcr.io/${{ github.repository }}/alpine:3.19
          docker push ghcr.io/${{ github.repository }}/alpine:3.19
```

#### 6.2 修改 Dockerfile

```dockerfile
# 使用 GHCR 镜像
FROM ghcr.io/lance-mao/flash-sale-system/golang:1.22-alpine AS builder
...
FROM ghcr.io/lance-mao/flash-sale-system/alpine:3.19
```

**优点**：
- ✅ 完全免费
- ✅ 无拉取限制
- ✅ 与 GitHub 集成
- ✅ 自动缓存

**缺点**：
- ❌ 需要初始设置
- ❌ 需要定期同步上游镜像

---

## 🎯 推荐方案组合

### 短期（立即生效）

1. ✅ **限制并发构建**（已实施）
   ```yaml
   max-parallel: 3
   ```

2. ✅ **利用现有缓存**（已配置）
   ```yaml
   cache-from: type=gha
   cache-to: type=gha,mode=max
   ```

3. ⏰ **等待6小时后再触发构建**

### 中期（1-2周内）

1. 🔄 **迁移到 GitHub Container Registry**
   - 创建基础镜像副本
   - 修改 Dockerfile

2. 🌏 **配置阿里云镜像加速**（国内环境）
   - 修改 Dockerfile
   - 使用阿里云镜像源

### 长期（可选）

1. 💰 **升级 Docker Hub 账户**（如预算充足）
   - Pro: $5/月
   - 无限拉取

2. 🏗️ **自建 Docker Registry**（企业方案）
   - Harbor 私有仓库
   - 完全自主控制

---

## 📊 方案对比

| 方案 | 成本 | 实施难度 | 效果 | 推荐指数 |
|------|------|---------|------|---------|
| 限制并发 | 免费 | ⭐ 简单 | 🟡 中等 | ⭐⭐⭐⭐ |
| 镜像缓存 | 免费 | ⭐ 简单 | 🟢 好 | ⭐⭐⭐⭐⭐ |
| 阿里云镜像 | 免费 | ⭐⭐ 中等 | 🟢 好 | ⭐⭐⭐⭐ |
| 等待过期 | 免费 | ⭐ 简单 | 🟡 临时 | ⭐⭐ |
| 升级账户 | $5/月 | ⭐ 简单 | 🟢 完美 | ⭐⭐⭐ |
| GHCR | 免费 | ⭐⭐⭐ 复杂 | 🟢 完美 | ⭐⭐⭐⭐⭐ |

---

## 🛠️ 当前状态

### 已实施的优化

✅ **限制并发构建**：
```yaml
strategy:
  max-parallel: 3
  fail-fast: false
```

✅ **镜像缓存**：
```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

✅ **Docker Hub 认证**：
```yaml
- name: Login to Harbor
  uses: docker/login-action@v3
  with:
    username: ${{ secrets.HARBOR_USERNAME }}
    password: ${{ secrets.HARBOR_PASSWORD }}
```

### 待实施的优化

- [ ] 迁移到 GitHub Container Registry
- [ ] 配置阿里云镜像加速
- [ ] 创建自定义基础镜像

---

## 🚀 立即操作建议

### 1. 等待限流窗口过期（6小时）

```bash
# 查看当前时间
date

# 在 6 小时后再次触发 CI/CD
# 例如：现在是 16:22，下次触发应在 22:22 之后
```

### 2. 减少触发频率

```bash
# 合并多个提交后再 push
git add .
git commit -m "feat: add health check + fix image tags + fix permissions"
git push origin main

# 而不是每次修改都 push
```

### 3. 验证构建成功

```bash
# 第一次构建后，后续构建会使用缓存
# 构建时间会显著减少：
# - 第一次：~15-20分钟（3个并发）
# - 后续：~5-10分钟（大部分来自缓存）
```

---

## 📝 监控和预防

### 1. 监控 Docker Hub 限额

**在本地定期检查**：
```bash
#!/bin/bash
# check-docker-limit.sh

TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/golang:pull" \
  -u $DOCKER_USERNAME:$DOCKER_PASSWORD | jq -r .token)

LIMIT=$(curl -s -D - -o /dev/null -H "Authorization: Bearer $TOKEN" \
  https://registry-1.docker.io/v2/library/golang/manifests/latest 2>&1 | grep -i ratelimit)

echo "Docker Hub Rate Limit Status:"
echo "$LIMIT"
```

### 2. 避免频繁触发

**最佳实践**：
- ✅ 本地充分测试后再 push
- ✅ 使用 PR 合并多个修改
- ✅ 定时构建而非每次提交
- ❌ 避免短时间内多次 push

### 3. 设置通知

**在 GitHub Actions 中添加**：
```yaml
- name: Check if rate limited
  if: failure()
  run: |
    if grep -q "429 Too Many Requests" build.log; then
      echo "⚠️ Docker Hub rate limit reached!"
      echo "Wait 6 hours before next build."
    fi
```

---

## 📖 参考资料

- [Docker Hub Rate Limits](https://docs.docker.com/docker-hub/download-rate-limit/)
- [GitHub Actions Cache](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [GitHub Container Registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [阿里云容器镜像服务](https://help.aliyun.com/product/60716.html)

---

## 💡 总结

### 当前问题
- ❌ Docker Hub 免费账户限流：200次/6小时
- ❌ 11个服务并发构建，快速消耗限额
- ❌ 短时间内多次触发 CI/CD

### 已采取措施
- ✅ 限制并发构建（max-parallel: 3）
- ✅ 启用 GitHub Actions 缓存
- ✅ 配置 Docker Hub 认证

### 后续建议
1. ⏰ **立即**：等待6小时后再构建
2. 📦 **本周内**：考虑迁移到 GHCR
3. 🌏 **可选**：配置阿里云镜像加速

### 预期效果
- ✅ 单次构建限额消耗：22次 → 保持不变
- ✅ 构建频率控制：避免短时间多次触发
- ✅ 缓存命中率：首次0% → 后续80%+
- ✅ 触发限流概率：高 → 低

---

**修复状态**: ✅ 已添加并发限制
**下次构建**: 建议等待6小时（22:22之后）
**长期方案**: 迁移到 GitHub Container Registry
**修复时间**: 2025-12-29
