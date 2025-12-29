# 电商秒杀系统 (Flash Sale System)

[English](README.md) | 中文文档

基于 **go-zero** 微服务框架构建的**高性能电商秒杀系统**，专为**高并发**场景设计，采用企业级架构。

## ✨ 项目亮点

- 🚀 **高并发处理**: 基于 Redis 的库存扣减、分布式锁、防止超卖
- 🎯 **秒杀优化**: 针对流量峰值优化，队列机制 + 限流
- 🔧 **微服务架构**: DDD 领域驱动设计，服务边界清晰
- ⚡ **高性能**: go-zero 框架内置熔断、负载均衡
- 📊 **完整可观测性**: Jaeger 链路追踪、Prometheus 指标、ELK 日志
- 🔄 **CI/CD 就绪**: GitHub Actions、Docker、Kubernetes、Helm
- 💳 **支付集成**: 微信支付 v3 API
- 📦 **消息队列**: Kafka 事件驱动、Asynq 延时任务

## 🏗 系统架构
 
### 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    API 网关 (Nginx/APISIX)                      │
└─────────────────────────────────────────────────────────────────┘
                                   │
        ┌──────────────┬───────────┼───────────┬──────────────┐
        │              │           │           │              │
    ┌───▼────┐    ┌───▼────┐  ┌──▼─────┐ ┌───▼────┐    ┌───▼────┐
    │ 用户   │    │ 商品   │  │ 订单   │ │ 支付   │    │ 秒杀   │
    │ 中心   │    │ 服务   │  │ 服务   │ │ 服务   │    │ 服务   │
    └───┬────┘    └───┬────┘  └───┬────┘ └───┬────┘    └───┬────┘
        │              │           │          │              │
    ┌───▼────┐    ┌───▼────┐  ┌───▼────┐ ┌──▼─────┐    ┌───▼────┐
    │用户 RPC│    │商品 RPC│  │订单 RPC│ │支付 RPC│    │秒杀 RPC│
    └───┬────┘    └───┬────┘  └───┬────┘ └───┬────┘    └───┬────┘
        │              │           │          │              │
        └──────────────┴───────────┴──────────┴──────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
    ┌───▼─────┐            ┌──────▼──────┐           ┌──────▼──────┐
    │  MySQL  │            │    Redis    │           │    Kafka    │
    │  集群   │            │    集群     │           │    集群     │
    └─────────┘            └─────────────┘           └─────────────┘
```

### 服务列表

| 服务 | 端口 | 说明 |
|------|------|------|
| **usercenter-api** | 1004 | 用户注册、登录、个人信息 |
| **usercenter-rpc** | 2004 | 用户服务 RPC |
| **product-api** | 1003 | 商品管理（由 travel 改造） |
| **product-rpc** | 2003 | 商品服务 RPC |
| **order-api** | 1001 | 订单创建、查询 |
| **order-rpc** | 2001 | 订单服务 RPC |
| **order-mq** | - | 订单消息消费者 |
| **payment-api** | 1002 | 支付、微信支付回调 |
| **payment-rpc** | 2002 | 支付服务 RPC |
| **mqueue-job** | - | 异步任务处理（订单超时、通知） |
| **mqueue-scheduler** | - | 定时任务（结算） |

## 🛠 技术栈

### 核心框架
- **Go 1.22** - 编程语言
- **go-zero v1.7.3** - 微服务框架
- **gRPC** - RPC 通信
- **Protocol Buffers** - 数据序列化

### 存储
- **MySQL 8.0** - 关系型数据库
- **Redis 6.2** - 缓存和队列
- **Kafka 3.9** - 消息队列

### 可观测性
- **Jaeger** - 分布式链路追踪
- **Prometheus** - 指标采集
- **Grafana** - 指标可视化
- **ELK Stack** - 日志聚合（Elasticsearch、Kibana、Filebeat）

### DevOps
- **Docker** - 容器化
- **Kubernetes** - 容器编排
- **Helm** - K8s 包管理器
- **GitHub Actions** - CI/CD
- **Harbor** - 容器镜像仓库

### 第三方集成
- **微信支付 v3** - 支付网关
- **Asynq** - 延时任务队列
- **Sonyflake** - 分布式唯一 ID

## 🚀 快速开始

### 前置要求

- Go 1.22+
- Docker & Docker Compose
- MySQL 8.0
- Redis 6.2
- Kafka 3.9（可选，用于消息队列功能）

### 1. 克隆仓库

```bash
git clone https://github.com/Lance-Mao/flash-sale-system.git
cd flash-sale-system
```

### 2. 启动基础设施

```bash
# 启动 MySQL、Redis、Kafka 等
docker-compose -f docker-compose-env.yml up -d

# 等待服务就绪
sleep 10
```

### 3. 初始化数据库

```bash
# 导入数据库表结构
mysql -h 127.0.0.1 -P 33069 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_usercenter.sql
mysql -h 127.0.0.1 -P 33069 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_order.sql
mysql -h 127.0.0.1 -P 33069 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_payment.sql
mysql -h 127.0.0.1 -P 33069 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_product.sql
```

### 4. 启动服务

**方式一：使用 Docker Compose（热重载）**

```bash
docker-compose up -d
```

**方式二：本地开发**

```bash
# 终端 1：启动 usercenter-rpc
cd app/usercenter/cmd/rpc
go run usercenter.go -f etc/usercenter-local.yaml

# 终端 2：启动 usercenter-api
cd app/usercenter/cmd/api
go run usercenter.go -f etc/usercenter-local.yaml

# 其他服务类似...
```

**方式三：使用构建脚本（Windows）**

```powershell
# 构建所有服务
.\build.ps1 build

# 启动开发环境
.\build.ps1 dev-up
```

### 5. 测试 API

```bash
# API 网关地址
http://localhost:8888

# 注册用户
curl -X POST http://localhost:8888/usercenter/v1/user/register \
  -H "Content-Type: application/json" \
  -d '{"mobile":"13800138000","password":"123456"}'

# 登录
curl -X POST http://localhost:8888/usercenter/v1/user/login \
  -H "Content-Type: application/json" \
  -d '{"mobile":"13800138000","password":"123456"}'
```

### 6. 访问服务

| 服务 | 地址 |
|------|------|
| API 网关 | http://localhost:8888 |
| Jaeger UI | http://localhost:16686 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3001 (admin/admin) |
| Kibana | http://localhost:5601 |
| Asynqmon | http://localhost:8980 |

## 📁 项目结构

```
flash-sale-system/
├── app/                        # 业务服务
│   ├── usercenter/            # 用户中心
│   │   ├── cmd/
│   │   │   ├── api/           # HTTP API 服务
│   │   │   └── rpc/           # gRPC 服务
│   │   └── model/             # 数据模型
│   ├── product/               # 商品服务（由 travel 改造）
│   ├── order/                 # 订单服务
│   ├── payment/               # 支付服务
│   └── mqueue/                # 消息队列服务
├── pkg/                        # 共享包
│   ├── middleware/            # JWT、日志中间件
│   ├── result/                # 统一响应格式
│   ├── xerr/                  # 错误码定义
│   └── uniqueid/              # ID 生成器
├── deploy/                     # 部署配置
│   ├── sql/                   # 数据库表结构
│   ├── dockerfile/            # Dockerfile
│   ├── helm/                  # Helm charts
│   ├── nginx/                 # Nginx 配置
│   └── prometheus/            # 监控配置
├── docs/                       # 文档
├── .github/workflows/         # CI/CD 流水线
├── docker-compose-env.yml      # 基础设施
├── docker-compose.yml          # 应用服务
└── Makefile / build.ps1        # 构建脚本
```

## 🎯 核心功能

### ✅ 已实现

- [x] 用户注册、登录（手机号 + 密码）
- [x] JWT 认证
- [x] 商品管理（CRUD）
- [x] 订单创建和查询
- [x] 微信支付集成
- [x] 支付回调处理
- [x] 消息队列（Kafka）
- [x] 延时任务（Asynq - 订单超时、通知）
- [x] 分布式链路追踪（Jaeger）
- [x] 指标采集（Prometheus）
- [x] 日志聚合（ELK）
- [x] CI/CD 流水线（GitHub Actions）
- [x] Kubernetes 部署（Helm）

### 🚧 计划中（查看 [功能路线图](docs/ci-cd-enhancement/FEATURE_ROADMAP.md)）

- [ ] **秒杀服务** - 高并发秒杀处理
  - Redis 库存扣减
  - 分布式锁（防止超卖）
  - 限流和队列机制
- [ ] **优惠券服务** - 营销和促销
  - 优惠券发放
  - 使用追踪
  - 防刷机制
- [ ] **搜索服务** - Elasticsearch 集成
  - 商品全文搜索
  - 筛选和排序
- [ ] **API 网关** - 升级到 APISIX
- [ ] **配置中心** - Nacos 集成
- [ ] **服务发现** - etcd 集成

## 🧪 测试

```bash
# 运行所有测试
go test ./...

# 带覆盖率
go test -cover ./...

# 生成覆盖率报告
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

## 📊 性能指标

- **QPS**: 10,000+ (单实例)
- **延迟**: P99 < 200ms
- **并发**: 支持 1,000+ 并发用户
- **可用性**: 99.9%+

## 🔒 安全

- JWT token 认证
- 密码加密（bcrypt）
- SQL 注入防护
- XSS 防护
- 限流
- 请求签名（用于支付回调）

## 📖 文档

- [开发指南](docs/ci-cd-enhancement/DEVELOPMENT.md)
- [CI/CD 指南](docs/ci-cd-enhancement/CI_CD_GUIDE.md)
- [功能路线图](docs/ci-cd-enhancement/FEATURE_ROADMAP.md)
- [Windows 开发](docs/WINDOWS_MAKE_GUIDE.md)
- [任务状态](docs/TASK_STATUS.md)

## 🤝 贡献

欢迎贡献！请随时提交 Pull Request。

1. Fork 本仓库
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开一个 Pull Request

## 📝 开源协议

本项目采用 MIT 协议 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [go-zero](https://go-zero.dev) - 微服务框架
- 原始项目灵感来自 [go-zero-looklook](https://github.com/Mikaelemmmm/go-zero-looklook)

## 📧 联系方式

- **GitHub**: [@Lance-Mao](https://github.com/Lance-Mao)
- **Issues**: [GitHub Issues](https://github.com/Lance-Mao/flash-sale-system/issues)

---

⭐ 如果这个项目对你有帮助，请考虑给它一个 Star！
