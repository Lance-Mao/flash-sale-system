# 项目文件组织说明

本文档说明新增文件的位置和组织结构。

## 📁 文件结构

```
flash-sale-system/
├── .github/
│   └── workflows/
│       └── ci-cd.yml                    ✅ GitHub Actions CI/CD 工作流
│
├── deploy/
│   ├── dockerfile/
│   │   └── usercenter-api/
│   │       └── Dockerfile               ✅ 多阶段构建示例
│   └── helm/
│       ├── Chart.yaml                   ✅ Helm Chart 定义
│       ├── values.yaml                  ✅ 默认配置
│       ├── values-dev.yaml              ✅ 开发环境配置
│       └── values-prod.yaml             ✅ 生产环境配置
│
├── docs/
│   └── ci-cd-enhancement/               📚 增强方案文档目录
│       ├── README.md                    ✅ 文档总览
│       ├── WEEKLY_PLAN.md               ✅ 本周实施计划
│       ├── DEVELOPMENT.md               ✅ 完整开发文档
│       ├── CI_CD_GUIDE.md               ✅ CI/CD 实施指南
│       └── FEATURE_ROADMAP.md           ✅ 功能扩展路线图
│
├── .golangci.yml                        ✅ 代码检查配置
├── Makefile                             ✅ 构建工具
├── sonar-project.properties             ✅ SonarQube 配置
└── THIS_FILE.md                         ✅ 本文件

```

## 🎯 文件分类说明

### 一、配置文件（项目根目录和特定位置）

这些文件必须放在特定位置，因为工具会从这些位置读取：

#### 1. CI/CD 配置
- **位置**: `.github/workflows/ci-cd.yml`
- **作用**: GitHub Actions 自动化流程
- **功能**:
  - 代码检查（golangci-lint）
  - 单元测试 + 覆盖率
  - Docker 镜像构建
  - 多环境部署
  - 钉钉通知

#### 2. 代码质量配置
- **位置**: `.golangci.yml`
- **作用**: Go 代码检查规则
- **使用**: `make lint` 或 `golangci-lint run`

- **位置**: `sonar-project.properties`
- **作用**: SonarQube 代码质量分析配置
- **使用**: SonarScanner 自动读取

#### 3. 构建工具
- **位置**: `Makefile`
- **作用**: 统一的构建命令
- **常用命令**:
  ```bash
  make lint          # 代码检查
  make test          # 运行测试
  make build         # 构建所有服务
  make docker-build  # 构建 Docker 镜像
  make dev-up        # 启动开发环境
  ```

#### 4. Kubernetes 部署
- **位置**: `deploy/helm/`
- **文件**:
  - `Chart.yaml` - Helm Chart 元数据
  - `values.yaml` - 默认配置
  - `values-dev.yaml` - 开发环境覆盖配置
  - `values-prod.yaml` - 生产环境覆盖配置
- **使用**:
  ```bash
  helm install flashsale ./deploy/helm \
    --namespace flashsale-dev \
    --values ./deploy/helm/values-dev.yaml
  ```

#### 5. Docker 镜像
- **位置**: `deploy/dockerfile/*/Dockerfile`
- **示例**: `deploy/dockerfile/usercenter-api/Dockerfile`
- **特点**: 多阶段构建，最小化镜像体积

### 二、文档（docs/ci-cd-enhancement/）

这些是规划和指南文档，集中在文档目录：

#### 1. README.md
- **作用**: 文档目录总览
- **内容**: 快速导航、阅读顺序、资源链接

#### 2. WEEKLY_PLAN.md
- **作用**: 本周实施计划
- **内容**: Day 1-7 具体任务清单
- **适合**: 立即开始执行

#### 3. CI_CD_GUIDE.md（⭐ 重点）
- **作用**: CI/CD 从零到一的详细指南
- **内容**:
  - 前置条件检查
  - Git 仓库配置
  - Harbor 镜像仓库部署
  - Kubernetes 集群准备
  - 基础设施部署（MySQL/Redis/Kafka）
  - 首次部署应用
  - 触发 CI/CD
  - 故障排查
- **适合**: 按步骤执行

#### 4. DEVELOPMENT.md
- **作用**: 完整的开发文档
- **内容**:
  - 快速开始
  - 项目结构
  - 开发规范
  - 部署指南
  - 故障排查
  - 监控指标
- **适合**: 开发团队日常参考

#### 5. FEATURE_ROADMAP.md
- **作用**: 功能扩展路线图
- **内容**:
  - 业务功能规划（消息通知、优惠券、搜索等）
  - 架构优化方案（API网关、配置中心、服务发现）
  - 详细技术方案
  - 实施时间表
  - 成本估算
- **适合**: 中长期规划

## 🚀 快速开始指引

### 如果你是第一次接触本项目：

1. **先读**: `docs/ci-cd-enhancement/README.md`
   - 了解整体规划

2. **再读**: `docs/ci-cd-enhancement/WEEKLY_PLAN.md`
   - 了解本周任务

3. **开始执行**: `docs/ci-cd-enhancement/CI_CD_GUIDE.md`
   - 按步骤搭建 CI/CD

4. **日常开发**: `docs/ci-cd-enhancement/DEVELOPMENT.md`
   - 开发规范、故障排查

5. **长期规划**: `docs/ci-cd-enhancement/FEATURE_ROADMAP.md`
   - 了解未来方向

### 立即可执行的命令：

```bash
# 1. 安装开发工具
make install-tools

# 2. 检查代码
make lint

# 3. 运行测试
make test

# 4. 本地构建
make build

# 5. 启动开发环境
make dev-up
```

## 📝 使用建议

### 对于开发人员
- 日常开发参考：`DEVELOPMENT.md`
- 提交代码前：运行 `make lint && make test`
- 遇到问题：查看 `DEVELOPMENT.md` 故障排查章节

### 对于运维人员
- 部署参考：`CI_CD_GUIDE.md`
- 监控配置：`DEVELOPMENT.md` 监控章节
- 故障处理：`CI_CD_GUIDE.md` 常见问题章节

### 对于架构师/Tech Lead
- 整体规划：`FEATURE_ROADMAP.md`
- 技术决策：`FEATURE_ROADMAP.md` 各功能技术方案
- 成本评估：`FEATURE_ROADMAP.md` 成本估算章节

### 对于项目经理
- 时间规划：`WEEKLY_PLAN.md` + `FEATURE_ROADMAP.md` 时间表
- 资源分配：`FEATURE_ROADMAP.md` 成本估算
- 验收标准：`FEATURE_ROADMAP.md` 验收标准章节

## 🔄 后续维护

### 需要更新的场景

当添加新服务时：
1. 更新 `Makefile` - 添加构建目标
2. 创建 `deploy/dockerfile/新服务/Dockerfile`
3. 更新 `.github/workflows/ci-cd.yml` - 添加到构建矩阵
4. 更新 `deploy/helm/values.yaml` - 添加服务配置

当修改架构时：
1. 更新 `DEVELOPMENT.md` - 项目结构章节
2. 更新 `FEATURE_ROADMAP.md` - 架构图

当添加新功能时：
1. 在 `FEATURE_ROADMAP.md` 中记录规划
2. 完成后更新 `DEVELOPMENT.md` 使用说明

## ❓ 常见问题

**Q: 为什么配置文件不在 docs 文件夹？**
A: 这些配置文件需要被工具读取，必须放在特定位置。例如 GitHub Actions 只会读取 `.github/workflows/` 下的文件。

**Q: 我应该先看哪个文档？**
A: 按顺序：README.md → WEEKLY_PLAN.md → CI_CD_GUIDE.md

**Q: 配置文件需要修改吗？**
A: 需要。主要修改：
- `.github/workflows/ci-cd.yml` - 镜像仓库地址、域名
- `deploy/helm/values-*.yaml` - 镜像仓库、数据库地址、域名
- `Makefile` - 镜像仓库地址

**Q: 文档太多，记不住怎么办？**
A: 收藏这个文件（THIS_FILE.md），它是总索引。

## 📞 获取帮助

- 文档问题：查看 `docs/ci-cd-enhancement/README.md`
- 技术问题：查看 `DEVELOPMENT.md` 故障排查章节
- CI/CD 问题：查看 `CI_CD_GUIDE.md` 常见问题章节

## 🎯 下一步行动

1. ✅ 阅读完本文件
2. ⬜ 阅读 `docs/ci-cd-enhancement/README.md`
3. ⬜ 执行 `WEEKLY_PLAN.md` 中的任务
4. ⬜ 按照 `CI_CD_GUIDE.md` 搭建环境
5. ⬜ 开始开发！

---

**最后更新**: 2025-12-28
**维护者**: Claude Code
**版本**: 1.0.0
