# CI/CD 增强方案文档

本文件夹包含完善项目 CI/CD 和架构升级的完整方案。

## 📁 文件说明

### 文档类
- **WEEKLY_PLAN.md**: 本周实施计划（Day 1-7 任务清单）
- **DEVELOPMENT.md**: 完整开发文档（开发规范、部署指南、故障排查）
- **FEATURE_ROADMAP.md**: 功能扩展路线图（业务功能、架构优化）
- **CI_CD_GUIDE.md**: CI/CD 实施指南（详细步骤、配置说明）

### 已部署的配置文件
以下配置文件已放置在项目相应位置（不在此文件夹）：

#### 项目根目录
- `.github/workflows/ci-cd.yml` - GitHub Actions 工作流
- `.golangci.yml` - 代码检查配置
- `Makefile` - 构建工具
- `sonar-project.properties` - SonarQube 配置

#### Helm Charts
- `deploy/helm/Chart.yaml` - Helm Chart 定义
- `deploy/helm/values.yaml` - 默认配置
- `deploy/helm/values-dev.yaml` - 开发环境配置
- `deploy/helm/values-prod.yaml` - 生产环境配置

#### Dockerfile
- `deploy/dockerfile/usercenter-api/Dockerfile` - 多阶段构建示例

## 🎯 快速开始

1. **阅读顺序**
   ```
   WEEKLY_PLAN.md → CI_CD_GUIDE.md → DEVELOPMENT.md → FEATURE_ROADMAP.md
   ```

2. **立即执行**
   ```bash
   # 安装开发工具
   make install-tools

   # 检查代码
   make lint

   # 运行测试
   make test
   ```

3. **本周目标**
   - 搭建 CI/CD Pipeline
   - 部署开发环境到 K8s
   - 完成第一次自动化部署

## 📊 实施优先级

### 第一阶段（本周）
✅ CI/CD 基础设施

### 第二阶段（下周）
- 配置中心（Nacos/Apollo）
- 服务注册发现（etcd）
- API 网关升级（APISIX）

### 第三阶段（1-2个月）
- 新增业务服务（消息通知、优惠券、搜索）
- 完善测试体系
- 监控告警优化

## 🔗 相关资源

- [go-zero 官方文档](https://go-zero.dev)
- [Kubernetes 文档](https://kubernetes.io/zh-cn/docs/)
- [APISIX 文档](https://apisix.apache.org/zh/)
- [Harbor 文档](https://goharbor.io/docs/)

## 📞 支持

如有问题，请查看 DEVELOPMENT.md 中的故障排查章节。
