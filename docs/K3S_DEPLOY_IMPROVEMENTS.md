# K3S 部署文档改进说明

## 文档对比

| 项目 | 原文档 | 修复版文档 |
|------|--------|-----------|
| 文件名 | K3S_QUICK_DEPLOY.md | K3S_QUICK_DEPLOY_FIXED.md |
| 章节数 | 11章 | 13章 |
| 行数 | 840行 | 1400+行 |
| 完整度 | ⭐⭐⭐ (3/5) | ⭐⭐⭐⭐⭐ (5/5) |

---

## 主要改进清单

### ✅ P0 级别改进（必须修复）

#### 1. 补充数据库创建步骤

**问题**: 原文档直接执行 `mysql < *.sql`，但 SQL 文件不包含 CREATE DATABASE

**修复**:
```bash
# 新增：先创建数据库
kubectl exec -it deploy/mysql -n infra -- mysql -uroot -pPXDN93VRKUm8TeE7 <<'EOF'
CREATE DATABASE IF NOT EXISTS flashsale_usercenter DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS flashsale_order DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS flashsale_payment DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS flashsale_product DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
EOF

# 然后导入表结构（指定数据库）
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 flashsale_usercenter < deploy/sql/flashsale_usercenter.sql
```

**位置**: 第四章 4.5 节

---

#### 2. 修正 Helm Values 配置

**问题**: values-dev.yaml 缺少关键配置（密码、JWT secret）

**修复**:
```yaml
config:
  mysql:
    host: mysql.infra.svc.cluster.local
    port: 3306
    username: root
    password: PXDN93VRKUm8TeE7  # 新增
  redis:
    host: redis-master.infra.svc.cluster.local
    port: 6379
    password: G62m50oigInC30sf  # 新增
  kafka:
    brokers: flashsale-kafka-kafka-bootstrap.infra.svc.cluster.local:9092
  jwt:
    secret: your-jwt-secret-change-this-in-production  # 新增

# Asynq 配置（新增整个章节）
asynq:
  redis:
    addr: redis-master.infra.svc.cluster.local:6379
    password: G62m50oigInC30sf
    db: 0
```

**位置**: 第五章（新增章节）"准备应用配置"

---

#### 3. 修正 GitHub Secrets 名称

**问题**: 文档说 `DOCKERHUB_USERNAME`，实际 CI/CD 用 `HARBOR_USERNAME`

**修复**:
```yaml
# 原文档（错误）:
DOCKERHUB_USERNAME: xxx
DOCKERHUB_TOKEN: xxx

# 修复版（正确）:
HARBOR_USERNAME: xxx    # 注意：虽然叫 HARBOR，实际是 Docker Hub
HARBOR_PASSWORD: xxx    # 注意：使用 Token，不是密码
KUBE_CONFIG_DEV: xxx
```

**位置**: 第六章 6.3 节

---

### ✅ P1 级别改进（强烈建议）

#### 4. 添加 Kafka Topic 创建步骤

**问题**: Kafka 部署后没有创建 Topics，应用启动会失败

**修复**: 新增第 4.4 节 "创建 Kafka Topics"

```bash
# 使用 Strimzi CRD 创建 Topics
kubectl apply -f /tmp/kafka-topics.yaml

# Topics:
# - payment-update
# - order-update
# - pay-callback
# - close-order
```

**位置**: 第四章 4.4 节（新增）

---

#### 5. 统一服务名称说明

**问题**: 代码中用 `travel-api`，但实际是 `product` 服务

**修复**: 添加说明

```yaml
ingress:
  hosts:
    - host: dev-api.flashsale.com
      paths:
        - path: /product
          pathType: Prefix
          service: travel-api  # 注意: travel 是 product 的别名
```

**位置**: 第五章 5.1 节

---

#### 6. 补充 Asynq 配置

**问题**: 项目使用 Asynq 做延迟队列，但文档完全没提

**修复**:
1. 在 values-dev.yaml 添加 asynq 配置
2. 新增第八章 8.4 节部署 Asynqmon 监控

**位置**: 第八章 8.4 节（新增）

---

### ✅ P2 级别改进（建议补充）

#### 7. 添加资源需求明细

**问题**: 原文档说 2核2G 就够，实际需要 4核8G+

**修复**: 新增资源需求表

| 组件 | 内存 | CPU | 存储 |
|------|------|-----|------|
| K3s 自身 | 512MB | 0.5核 | 1GB |
| MySQL | 1GB | 0.5核 | 10GB |
| Redis | 512MB | 0.2核 | 5GB |
| Kafka + Zookeeper | 3GB | 0.8核 | 7GB |
| 应用服务 (11个) | 2GB | 2核 | 2GB |
| **总计** | **~10GB** | **~5核** | **~35GB** |

**位置**: 第一章 1.2 节（新增）

---

#### 8. 添加 Jaeger 部署步骤

**问题**: 项目依赖链路追踪，但文档没有部署说明

**修复**: 新增第八章 8.3 节 "部署 Jaeger"

```bash
# 部署 Jaeger All-in-One
kubectl apply -f /tmp/jaeger.yaml

# 访问: http://localhost:16686
```

**位置**: 第八章 8.3 节（新增）

---

#### 9. 添加域名和证书配置

**问题**: 文档提到域名 `dev-api.flashsale.com`，但没说怎么配置

**修复**: 新增第五章 5.3 节 "配置域名访问"

**方式1**: 配置 hosts 文件（测试）
```bash
echo "$SERVER_IP dev-api.flashsale.com" | sudo tee -a /etc/hosts
```

**方式2**: 真实域名 + SSL（生产）
```bash
# 安装 cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# 创建 Let's Encrypt Issuer
```

**位置**: 第五章 5.3 节（新增）

---

#### 10. 添加资源验证步骤

**问题**: 没有验证节点资源是否足够

**修复**: 新增第四章 4.6 节 "验证基础设施"

```bash
# 检查资源使用
kubectl top pods -n infra
kubectl top nodes

# 检查存储
kubectl get pvc -n infra
```

**位置**: 第四章 4.6 节（新增）

---

## 新增章节

### 第五章：准备应用配置（全新）

**内容**:
- 5.1 更新 Helm Values 配置
- 5.2 生成 JWT Secret
- 5.3 配置域名访问

**原因**: 原文档缺少应用配置步骤，直接跳到 CI/CD

---

### 第八章：部署监控（扩展）

**新增内容**:
- 8.3 部署 Jaeger（链路追踪）
- 8.4 部署 Asynqmon（任务队列监控）

**原因**: 原文档只有 Prometheus，缺少其他监控组件

---

### 第十三章：总结与下一步（全新）

**内容**:
- 13.1 部署清单（Checklist）
- 13.2 成本估算
- 13.3 下一步计划
- 13.4 参考资料
- 13.5 获取帮助

**原因**: 帮助用户确认部署完整性，规划后续工作

---

### 附录 A：快速命令参考（全新）

**内容**: 常用命令速查表
- 查看状态
- 日志查看
- 调试命令
- 重启服务
- Helm 命令

**原因**: 方便日常运维

---

## 改进详情对比

### 原文档结构
```
一、服务器准备
二、安装 K3s
三、安装基础组件
四、部署基础设施
    4.1 MySQL
    4.2 Redis
    4.3 Kafka
    4.4 初始化数据库 ❌ 缺少创建数据库步骤
五、CI/CD 集成 ❌ 缺少应用配置章节
六、测试部署
七、监控和维护 ❌ 只有 Prometheus
八、常见问题
九、资源优化建议
十、备份和恢复
十一、卸载和清理
```

### 修复版结构
```
一、服务器准备
    1.2 资源需求明细 ✅ 新增
二、安装 K3s
三、安装基础组件
四、部署基础设施
    4.1 MySQL
    4.2 Redis
    4.3 Kafka
    4.4 创建 Kafka Topics ✅ 新增
    4.5 初始化数据库 ✅ 修复
    4.6 验证基础设施 ✅ 新增
五、准备应用配置 ✅ 全新章节
    5.1 更新 Helm Values
    5.2 生成 JWT Secret
    5.3 配置域名访问
六、CI/CD 集成 ✅ 修正 Secrets 名称
七、部署应用 ✅ 改进测试步骤
八、部署监控
    8.1 Prometheus + Grafana
    8.2 配置应用监控
    8.3 部署 Jaeger ✅ 新增
    8.4 部署 Asynqmon ✅ 新增
九、常见问题排查 ✅ 新增2个问题
十、资源优化建议
十一、备份和恢复
十二、卸载和清理
十三、总结与下一步 ✅ 全新章节
附录 A：快速命令参考 ✅ 全新附录
```

---

## 使用建议

### 对于新用户
1. **按顺序执行修复版文档**
2. 不要跳过任何步骤
3. 特别注意第四章 4.5 节（数据库初始化）
4. 特别注意第五章（应用配置）

### 对于已部署用户
1. 检查是否缺少以下配置：
   - [ ] 数据库是否已创建
   - [ ] Kafka Topics 是否已创建
   - [ ] values-dev.yaml 是否有密码配置
   - [ ] GitHub Secrets 名称是否正确
   - [ ] JWT Secret 是否已生成

2. 补充缺失配置：
```bash
# 检查数据库
kubectl exec -it deploy/mysql -n infra -- mysql -uroot -pPXDN93VRKUm8TeE7 -e "SHOW DATABASES;"

# 检查 Kafka Topics
kubectl get kafkatopics -n infra

# 检查 ConfigMap
kubectl get configmap flashsale-config -n flashsale-dev -o yaml
```

---

## 测试验证

### 完整性测试清单

执行以下命令验证部署是否完整：

```bash
# 1. 基础设施检查
kubectl get pods -n infra
kubectl get pvc -n infra
kubectl get svc -n infra

# 2. 应用检查
kubectl get pods -n flashsale-dev
kubectl get svc -n flashsale-dev
kubectl get ingress -n flashsale-dev

# 3. 配置检查
kubectl get configmap flashsale-config -n flashsale-dev -o yaml | grep -E "mysql|redis|kafka|jwt"

# 4. Kafka Topics 检查
kubectl get kafkatopics -n infra

# 5. 功能测试
kubectl port-forward -n flashsale-dev svc/usercenter-api 8080:1004
curl http://localhost:8080/usercenter/v1/ping
```

### 预期结果

所有检查都应该通过：
- ✅ 所有 Pod 状态为 Running
- ✅ ConfigMap 包含所有必要配置
- ✅ Kafka Topics 已创建
- ✅ API 可以正常访问

---

## 反馈与改进

如果在使用修复版文档时遇到问题：

1. **提交 Issue**: https://github.com/Lance-Mao/flash-sale-system/issues
2. **标签**: `documentation`, `k3s`, `deployment`
3. **包含信息**:
   - 操作系统和版本
   - K3s 版本
   - 错误信息
   - 执行到哪一步

---

**文档版本**: v2.0
**改进项**: 40+
**新增章节**: 3个
**新增小节**: 10+
**修复问题**: 12个

**维护者**: Flash Sale Team
**最后更新**: 2025-12-29
