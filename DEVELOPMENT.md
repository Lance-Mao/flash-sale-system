# flash-sale-system 开发文档

## 快速开始

### 前置要求
- Go 1.22+
- Docker & Docker Compose
- Make
- goctl (`go install github.com/zeromicro/go-zero/tools/goctl@latest`)

### 本地开发

1. **启动基础设施**
```bash
docker-compose -f docker-compose-env.yml up -d
```

2. **初始化数据库**
```bash
# 导入 SQL schema
mysql -h 127.0.0.1 -P 33069 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_usercenter.sql
mysql -h 127.0.0.1 -P 33069 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_order.sql
mysql -h 127.0.0.1 -P 33069 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_payment.sql
mysql -h 127.0.0.1 -P 33069 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_product.sql
```

3. **启动服务（二选一）**

**方式一：热重载（推荐开发时使用）**
```bash
docker-compose up -d
# 服务会自动监听代码变化并重启
```

**方式二：本地运行**
```bash
# 启动 usercenter-api
cd app/usercenter/cmd/api
go run usercenter.go -f etc/usercenter-local.yaml

# 启动 usercenter-rpc（新终端）
cd app/usercenter/cmd/rpc
go run usercenter.go -f etc/usercenter-local.yaml
```

4. **访问服务**
- API Gateway: http://localhost:8888
- Jaeger UI: http://localhost:16686
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3001 (admin/admin)
- Kibana: http://localhost:5601
- Asynqmon: http://localhost:8980

### 代码生成

**生成 API 代码**
```bash
cd app/usercenter/cmd/api
goctl api go -api desc/usercenter.api -dir . --style=goZero
```

**生成 RPC 代码**
```bash
cd app/usercenter/cmd/rpc
goctl rpc protoc desc/usercenter.proto --go_out=. --go-grpc_out=. --zrpc_out=. --style=goZero
```

**生成 Model 代码**
```bash
cd deploy/script/mysql
./genModel.sh usercenter user
```

### 测试

```bash
# 运行所有测试
make test

# 运行特定服务测试
go test -v ./app/usercenter/...

# 测试覆盖率
go test -cover ./...
```

### 代码检查

```bash
# 运行 linter
make lint

# 自动修复部分问题
golangci-lint run --fix
```

## 项目结构

```
flash-sale-system/
├── app/                        # 业务服务
│   ├── usercenter/            # 用户中心
│   │   ├── cmd/
│   │   │   ├── api/           # HTTP API 服务
│   │   │   │   ├── desc/      # API 定义文件
│   │   │   │   ├── etc/       # 配置文件
│   │   │   │   ├── internal/  # 内部实现
│   │   │   │   │   ├── config/
│   │   │   │   │   ├── handler/
│   │   │   │   │   ├── logic/
│   │   │   │   │   ├── svc/
│   │   │   │   │   └── types/
│   │   │   │   └── usercenter.go
│   │   │   └── rpc/           # gRPC 服务
│   │   │       ├── desc/      # proto 文件
│   │   │       ├── etc/
│   │   │       ├── internal/
│   │   │       ├── pb/        # 生成的 pb 文件
│   │   │       └── usercenter.go
│   │   └── model/             # 数据模型
│   ├── travel/                # 旅游服务（结构同上）
│   ├── order/                 # 订单服务
│   ├── payment/               # 支付服务
│   └── mqueue/                # 消息队列服务
├── pkg/                        # 共享包
│   ├── ctxdata/               # Context 数据工具
│   ├── middleware/            # 中间件
│   ├── result/                # 响应格式
│   ├── xerr/                  # 错误定义
│   └── ...
├── deploy/                     # 部署相关
│   ├── dockerfile/            # Dockerfile
│   ├── helm/                  # Helm Charts
│   ├── nginx/                 # Nginx 配置
│   ├── script/                # 脚本
│   └── sql/                   # SQL Schema
├── .github/                    # GitHub Actions
│   └── workflows/
│       └── ci-cd.yml
├── docker-compose-env.yml      # 基础设施
├── docker-compose.yml          # 应用服务
├── Makefile                    # 构建脚本
└── README.md

```

## 开发规范

### 分支策略
- `main`: 主分支，对应生产环境
- `develop`: 开发分支
- `feature/*`: 功能分支
- `bugfix/*`: 修复分支
- `hotfix/*`: 紧急修复
- `release/*`: 发布分支

### 提交规范（Conventional Commits）
```
feat: 新功能
fix: 修复 bug
docs: 文档更新
style: 代码格式（不影响代码运行）
refactor: 重构
perf: 性能优化
test: 测试相关
chore: 构建过程或辅助工具的变动
```

### API 设计规范
- 使用 RESTful 风格
- 统一响应格式（pkg/result）
- 统一错误码（pkg/xerr）
- 接口版本控制 `/v1/`

### RPC 设计规范
- 使用 Protocol Buffers v3
- 服务命名：{Domain}Service
- 方法命名：动词+名词（GetUser, CreateOrder）

### 数据库规范
- 表名：小写+下划线
- 主键：id (bigint unsigned)
- 时间字段：create_time, update_time (datetime)
- 软删除：del_state (tinyint)
- 版本号：version (bigint) - 乐观锁

## 部署指南

### Docker Compose（开发环境）
```bash
# 启动所有服务
docker-compose -f docker-compose-env.yml up -d
docker-compose up -d

# 查看日志
docker-compose logs -f usercenter-api

# 停止服务
docker-compose down
```

### Kubernetes（生产环境）
```bash
# 创建命名空间
kubectl create namespace flashsale-prod

# 创建 Secret
kubectl create secret docker-registry harbor-secret \
  --docker-server=harbor.example.com \
  --docker-username=admin \
  --docker-password=xxx \
  -n flashsale-prod

# 部署
helm upgrade --install flashsale ./deploy/helm \
  --namespace flashsale-prod \
  --values ./deploy/helm/values-prod.yaml

# 查看状态
kubectl get pods -n flashsale-prod
kubectl logs -f deployment/usercenter-api -n flashsale-prod

# 回滚
helm rollback flashsale -n flashsale-prod
```

## 故障排查

### 常见问题

**Q: 服务启动失败，提示数据库连接错误**
```bash
# 检查 MySQL 是否启动
docker-compose -f docker-compose-env.yml ps mysql

# 检查数据库密码
# 默认密码在 docker-compose-env.yml 中
```

**Q: RPC 调用失败**
```bash
# 检查 RPC 服务是否启动
curl http://localhost:2004/healthz

# 检查 API 配置中的 RPC 地址
cat app/usercenter/cmd/api/etc/usercenter-local.yaml
```

**Q: Kafka 消息未消费**
```bash
# 查看消费者组
docker exec -it kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --list

# 查看 lag
docker exec -it kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --group order-mq --describe
```

## 监控指标

### 核心指标
- **QPS**: Prometheus 查询 `rate(http_requests_total[1m])`
- **延迟**: `histogram_quantile(0.99, http_request_duration_seconds)`
- **错误率**: `rate(http_requests_total{code!="200"}[1m])`

### Grafana 仪表盘
导入 ID:
- go-zero API: 待补充
- go-zero RPC: 待补充
- MySQL: 7362
- Redis: 11835
- Kafka: 721

## 性能优化建议

1. **缓存策略**
   - 热点数据预加载
   - 缓存穿透使用 BloomFilter
   - 缓存雪崩加随机过期时间

2. **数据库优化**
   - 合理使用索引
   - 避免 N+1 查询
   - 读写分离

3. **RPC 调用优化**
   - 批量查询减少 RPC 次数
   - 使用连接池
   - 合理设置超时时间

## 联系方式

- 问题反馈: GitHub Issues
- 技术交流: 待建立
- 文档贡献: Pull Request

## License

MIT License
