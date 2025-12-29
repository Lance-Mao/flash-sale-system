# CodeQL Action 权限错误修复

## 🔴 错误信息

```
Error: Resource not accessible by integration
Warning: This run of the CodeQL Action does not have permission to access the CodeQL Action API endpoints
Warning: CodeQL Action v3 will be deprecated in December 2026
```

---

## 🔍 问题分析

### 原因 1: 权限不足

**错误**：
```
Resource not accessible by integration
```

**原因**：
- GitHub Actions 的 `GITHUB_TOKEN` 默认权限不足
- 需要 `security-events: write` 权限才能上传 SARIF 文件到 Code Scanning
- 但原配置没有声明这个权限

**影响**：
- Trivy 安全扫描可以正常运行 ✅
- 但扫描结果无法上传到 GitHub Security ❌
- 无法在 GitHub UI 查看安全漏洞

### 原因 2: 版本过旧

**警告**：
```
CodeQL Action v3 will be deprecated in December 2026
```

**原因**：
- 使用了 `github/codeql-action/upload-sarif@v3`
- GitHub 建议升级到 v4

---

## ✅ 修复方案

### 修复 1: 添加权限配置

**.github/workflows/ci-cd.yml 第59-67行**：

```yaml
# 原配置（错误）
build-images:
  needs: lint-and-test
  runs-on: ubuntu-latest
  if: github.event_name == 'push'
  strategy:
    matrix:
      service: [...]

# 修复后（正确）
build-images:
  needs: lint-and-test
  runs-on: ubuntu-latest
  if: github.event_name == 'push'
  permissions:                     # ✅ 新增
    contents: read                 # 读取代码
    security-events: write         # 上传安全扫描结果
    packages: write                # 推送镜像（可选）
  strategy:
    matrix:
      service: [...]
```

### 修复 2: 升级 CodeQL Action 版本

**.github/workflows/ci-cd.yml 第128行**：

```yaml
# 原配置（旧版本）
- name: Upload Trivy results
  uses: github/codeql-action/upload-sarif@v3  # ❌ v3 将被废弃

# 修复后（新版本）
- name: Upload Trivy results
  uses: github/codeql-action/upload-sarif@v4  # ✅ v4 最新版本
```

---

## 📊 GitHub Token 权限说明

### 默认权限（不足）

```yaml
permissions:
  contents: read  # 只能读代码，不能写
```

### 所需权限

| 权限 | 用途 | 必需 |
|------|------|------|
| `contents: read` | 读取代码 | ✅ 是 |
| `security-events: write` | 上传 SARIF 到 Code Scanning | ✅ 是 |
| `packages: write` | 推送到 GitHub Packages | ⚪ 可选 |

### 权限作用域

```yaml
# 仅在 build-images job 中生效
build-images:
  permissions:
    contents: read
    security-events: write
    packages: write
  steps:
    - name: Upload Trivy results
      uses: github/codeql-action/upload-sarif@v4  # ✅ 有权限
```

---

## 🧪 验证修复

### 1. 检查 Workflow 权限

**在 GitHub UI 查看**：
```
Actions → 你的 Workflow Run → Job: build-images

应该看到：
✅ Set up job
   Permissions:
     contents: read
     security-events: write
     packages: write
```

### 2. 检查 SARIF 上传

**在日志中查看**：
```
Run github/codeql-action/upload-sarif@v4
Post-processing sarif files: ["trivy-results.sarif"]
Validating trivy-results.sarif
Uploading code scanning results
  ✅ Successfully uploaded results  # 应该成功
```

### 3. 在 GitHub Security 查看结果

**访问**：
```
GitHub Repository → Security → Code scanning

应该看到：
- Trivy 扫描结果
- 发现的漏洞列表
- 严重程度分级
```

---

## 🎯 Code Scanning 功能介绍

启用后可以获得：

### 功能 1: 安全漏洞可视化

**位置**：`Security → Code scanning alerts`

```
High severity vulnerabilities:
- CVE-2023-xxxxx in package@1.2.3
  Location: Dockerfile line 10
  Recommendation: Upgrade to package@1.2.4
```

### 功能 2: PR 自动检查

当创建 PR 时：
```
✅ All checks passed
❌ Code scanning / Trivy found 3 vulnerabilities

Details:
- High: CVE-2023-xxxxx
- Medium: CVE-2023-yyyyy
```

### 功能 3: 趋势分析

**Security Overview** 页面：
- 漏洞数量趋势
- 修复率统计
- 各镜像安全分数

---

## 🔄 替代方案

如果不需要 Code Scanning 功能：

### 方案 1: 移除 SARIF 上传步骤

```yaml
# 删除这个步骤
- name: Upload Trivy results
  uses: github/codeql-action/upload-sarif@v4
  with:
    sarif_file: 'trivy-results.sarif'
  continue-on-error: true
```

**保留**：
```yaml
# 仍然执行扫描，但不上传
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/${{ matrix.service }}:main
    format: 'table'  # 改为表格输出到日志
  continue-on-error: true
```

### 方案 2: 输出到 Artifact

```yaml
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/${{ matrix.service }}:main
    format: 'json'
    output: 'trivy-results.json'

- name: Upload scan results
  uses: actions/upload-artifact@v4
  with:
    name: trivy-results-${{ matrix.service }}
    path: trivy-results.json
```

**优点**：
- 不需要额外权限
- 结果保存为 Artifact，可下载查看
- 适合私有仓库或不想公开漏洞信息的场景

---

## 📝 最佳实践

### 1. 权限最小化原则

```yaml
# ✅ 好的做法：只授予必要权限
permissions:
  contents: read
  security-events: write

# ❌ 不好的做法：授予过多权限
permissions: write-all  # 危险！
```

### 2. 不同环境的权限策略

| 环境 | 权限配置 | 原因 |
|------|---------|------|
| **开发环境** | `security-events: write` | 启用 Code Scanning |
| **生产环境** | 同上 | 监控生产镜像安全 |
| **Fork PR** | 自动降级为只读 | 安全考虑 |

### 3. Trivy 扫描配置

```yaml
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_PREFIX }}/${{ matrix.service }}:main
    format: 'sarif'
    output: 'trivy-results.sarif'
    severity: 'CRITICAL,HIGH'      # 只报告高危漏洞
    ignore-unfixed: true           # 忽略无修复方案的漏洞
  continue-on-error: true
```

### 4. 扫描结果处理策略

```yaml
# 开发环境：允许失败
continue-on-error: true

# 生产环境：严格检查
- name: Scan image with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    severity: 'CRITICAL'
    exit-code: '1'  # 发现 CRITICAL 漏洞则失败
  # 不使用 continue-on-error
```

---

## ⚠️ 常见问题

### Q1: 为什么还是报错 403 Forbidden？

**原因**：仓库可能禁用了 Code Scanning

**解决**：
```
Repository Settings
→ Security & analysis
→ Code scanning
→ Enable
```

### Q2: Fork 的 PR 报权限错误？

**原因**：Fork PR 默认只有只读权限（安全考虑）

**解决**：
- Fork PR 无法上传 SARIF（正常现象）
- 使用 `continue-on-error: true` 允许失败
- 或者在合并后再扫描

### Q3: 私有仓库是否支持 Code Scanning？

**答案**：支持，但需要：
- GitHub Pro/Team/Enterprise 订阅
- 或者使用 GitHub Actions 免费额度

---

## 🔗 相关资源

- [GitHub Actions Permissions](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)
- [Code Scanning 文档](https://docs.github.com/en/code-security/code-scanning)
- [Trivy Action](https://github.com/aquasecurity/trivy-action)
- [CodeQL Action](https://github.com/github/codeql-action)

---

## 📌 总结

### 修复前

```yaml
build-images:
  runs-on: ubuntu-latest
  # ❌ 没有 permissions 配置

  - name: Upload Trivy results
    uses: github/codeql-action/upload-sarif@v3  # ❌ v3 将废弃

结果：
- ❌ 权限不足，上传失败
- ⚠️ 使用旧版本
```

### 修复后

```yaml
build-images:
  runs-on: ubuntu-latest
  permissions:                      # ✅ 添加权限
    contents: read
    security-events: write
    packages: write

  - name: Upload Trivy results
    uses: github/codeql-action/upload-sarif@v4  # ✅ 升级到 v4

结果：
- ✅ 权限充足，上传成功
- ✅ 使用最新版本
- ✅ Security 页面可查看漏洞
```

### 额外收益

启用 Code Scanning 后：
- ✅ 自动发现镜像漏洞
- ✅ PR 自动安全检查
- ✅ 漏洞趋势分析
- ✅ 符合安全合规要求

---

**修复状态**: ✅ 已完成
**修复文件**: `.github/workflows/ci-cd.yml`
**修复行**: 第63-66行, 第128行
**修复时间**: 2025-12-29
