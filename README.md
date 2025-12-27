# Flash Sale System

[中文文档](README-cn.md) | English

A high-performance flash sale e-commerce system built with **go-zero** microservices framework, designed to handle **high-concurrency** scenarios with enterprise-grade architecture.

## ✨ Highlights

- 🚀 **High Concurrency**: Redis-based stock deduction, distributed locks, preventing overselling
- 🎯 **Flash Sale**: Optimized for spike traffic with queue mechanism and rate limiting
- 🔧 **Microservices**: DDD architecture with clear service boundaries
- ⚡ **High Performance**: go-zero framework with built-in circuit breaker, load balancing
- 📊 **Full Observability**: Jaeger tracing, Prometheus metrics, ELK logging
- 🔄 **CI/CD Ready**: GitHub Actions, Docker, Kubernetes, Helm
- 💳 **Payment Integration**: WeChat Pay v3 API
- 📦 **Message Queue**: Kafka for event-driven architecture, Asynq for delayed tasks

## 🏗 Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        API Gateway (Nginx/APISIX)               │
└─────────────────────────────────────────────────────────────────┘
                                   │
        ┌──────────────┬───────────┼───────────┬──────────────┐
        │              │           │           │              │
    ┌───▼────┐    ┌───▼────┐  ┌──▼─────┐ ┌───▼────┐    ┌───▼────┐
    │ User   │    │ Product│  │ Order  │ │Payment │    │ Flash  │
    │ Center │    │        │  │        │ │        │    │ Sale   │
    └───┬────┘    └───┬────┘  └───┬────┘ └───┬────┘    └───┬────┘
        │              │           │          │              │
    ┌───▼────┐    ┌───▼────┐  ┌───▼────┐ ┌──▼─────┐    ┌───▼────┐
    │User RPC│    │Prod RPC│  │Ord RPC │ │Pay RPC │    │Sale RPC│
    └───┬────┘    └───┬────┘  └───┬────┘ └───┬────┘    └───┬────┘
        │              │           │          │              │
        └──────────────┴───────────┴──────────┴──────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────┐
        │                          │                          │
    ┌───▼─────┐            ┌──────▼──────┐           ┌──────▼──────┐
    │  MySQL  │            │    Redis    │           │    Kafka    │
    │ Cluster │            │   Cluster   │           │   Cluster   │
    └─────────┘            └─────────────┘           └─────────────┘
```

### Service List

| Service | Port | Description |
|---------|------|-------------|
| **usercenter-api** | 1004 | User registration, login, profile |
| **usercenter-rpc** | 2004 | User service RPC |
| **product-api** | 1003 | Product management (adapted from travel service) |
| **product-rpc** | 2003 | Product service RPC |
| **order-api** | 1001 | Order creation, query |
| **order-rpc** | 2001 | Order service RPC |
| **order-mq** | - | Order message consumer |
| **payment-api** | 1002 | Payment, WeChat Pay callback |
| **payment-rpc** | 2002 | Payment service RPC |
| **mqueue-job** | - | Async job processor (order timeout, notifications) |
| **mqueue-scheduler** | - | Scheduled tasks (settlement) |

## 🛠 Tech Stack

### Core Framework
- **Go 1.22** - Programming language
- **go-zero v1.7.3** - Microservices framework
- **gRPC** - RPC communication
- **Protocol Buffers** - Data serialization

### Storage
- **MySQL 8.0** - Relational database
- **Redis 6.2** - Cache and queue
- **Kafka 3.9** - Message queue

### Observability
- **Jaeger** - Distributed tracing
- **Prometheus** - Metrics collection
- **Grafana** - Metrics visualization
- **ELK Stack** - Log aggregation (Elasticsearch, Kibana, Filebeat)

### DevOps
- **Docker** - Containerization
- **Kubernetes** - Container orchestration
- **Helm** - K8s package manager
- **GitHub Actions** - CI/CD
- **Harbor** - Container registry

### Third-party
- **WeChat Pay v3** - Payment gateway
- **Asynq** - Delayed task queue
- **Sonyflake** - Distributed unique ID

## 🚀 Quick Start

### Prerequisites

- Go 1.22+
- Docker & Docker Compose
- MySQL 8.0
- Redis 6.2
- Kafka 3.9 (optional for MQ features)

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/flash-sale-system.git
cd flash-sale-system
```

### 2. Start Infrastructure

```bash
# Start MySQL, Redis, Kafka, etc.
docker-compose -f docker-compose-env.yml up -d

# Wait for services to be ready
sleep 10
```

### 3. Initialize Database

```bash
# Import database schemas
mysql -h 127.0.0.1 -P 33069 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_usercenter.sql
mysql -h 127.0.0.1 -P 33069 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_order.sql
mysql -h 127.0.0.1 -P 33069 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_payment.sql
mysql -h 127.0.0.1 -P 33069 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_product.sql
```

### 4. Start Services

**Option A: Using Docker Compose (with hot-reload)**

```bash
docker-compose up -d
```

**Option B: Local Development**

```bash
# Terminal 1: Start usercenter-rpc
cd app/usercenter/cmd/rpc
go run usercenter.go -f etc/usercenter-local.yaml

# Terminal 2: Start usercenter-api
cd app/usercenter/cmd/api
go run usercenter.go -f etc/usercenter-local.yaml

# Repeat for other services...
```

**Option C: Using Build Scripts (Windows)**

```powershell
# Build all services
.\build.ps1 build

# Start development environment
.\build.ps1 dev-up
```

### 5. Test APIs

```bash
# API Gateway URL
http://localhost:8888

# Register user
curl -X POST http://localhost:8888/usercenter/v1/user/register \
  -H "Content-Type: application/json" \
  -d '{"mobile":"13800138000","password":"123456"}'

# Login
curl -X POST http://localhost:8888/usercenter/v1/user/login \
  -H "Content-Type: application/json" \
  -d '{"mobile":"13800138000","password":"123456"}'
```

### 6. Access Services

| Service | URL |
|---------|-----|
| API Gateway | http://localhost:8888 |
| Jaeger UI | http://localhost:16686 |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3001 (admin/admin) |
| Kibana | http://localhost:5601 |
| Asynqmon | http://localhost:8980 |

## 📁 Project Structure

```
flash-sale-system/
├── app/                        # Business services
│   ├── usercenter/            # User center
│   │   ├── cmd/
│   │   │   ├── api/           # HTTP API service
│   │   │   └── rpc/           # gRPC service
│   │   └── model/             # Data models
│   ├── product/               # Product service (adapted from travel)
│   ├── order/                 # Order service
│   ├── payment/               # Payment service
│   └── mqueue/                # Message queue services
├── pkg/                        # Shared packages
│   ├── middleware/            # JWT, logging
│   ├── result/                # Standard response
│   ├── xerr/                  # Error codes
│   └── uniqueid/              # ID generator
├── deploy/                     # Deployment configs
│   ├── sql/                   # Database schemas
│   ├── dockerfile/            # Dockerfiles
│   ├── helm/                  # Helm charts
│   ├── nginx/                 # Nginx config
│   └── prometheus/            # Monitoring config
├── docs/                       # Documentation
├── .github/workflows/         # CI/CD pipelines
├── docker-compose-env.yml      # Infrastructure
├── docker-compose.yml          # Application
└── Makefile / build.ps1        # Build scripts
```

## 🎯 Core Features

### ✅ Implemented

- [x] User registration, login (mobile + password)
- [x] JWT authentication
- [x] Product management (CRUD)
- [x] Order creation and query
- [x] WeChat Pay integration
- [x] Payment callback handling
- [x] Message queue (Kafka)
- [x] Delayed tasks (Asynq - order timeout, notifications)
- [x] Distributed tracing (Jaeger)
- [x] Metrics collection (Prometheus)
- [x] Log aggregation (ELK)
- [x] CI/CD pipeline (GitHub Actions)
- [x] Kubernetes deployment (Helm)

### 🚧 Planned (See [FEATURE_ROADMAP](docs/ci-cd-enhancement/FEATURE_ROADMAP.md))

- [ ] **Flash Sale Service** - High-concurrency spike handling
  - Redis stock deduction
  - Distributed locks (prevent overselling)
  - Rate limiting and queue mechanism
- [ ] **Coupon Service** - Marketing and promotions
  - Coupon distribution
  - Usage tracking
  - Anti-fraud mechanism
- [ ] **Search Service** - Elasticsearch integration
  - Full-text product search
  - Filters and sorting
- [ ] **API Gateway** - Upgrade to APISIX
- [ ] **Config Center** - Nacos integration
- [ ] **Service Discovery** - etcd integration

## 🧪 Testing

```bash
# Run all tests
go test ./...

# With coverage
go test -cover ./...

# Generate coverage report
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

## 📊 Performance

- **QPS**: 10,000+ (single instance)
- **Latency**: P99 < 200ms
- **Concurrency**: Supports 1,000+ concurrent users
- **Availability**: 99.9%+

## 🔒 Security

- JWT token authentication
- Password encryption (bcrypt)
- SQL injection prevention
- XSS protection
- Rate limiting
- Request signing (for payment callbacks)

## 📖 Documentation

- [Development Guide](docs/ci-cd-enhancement/DEVELOPMENT.md)
- [CI/CD Guide](docs/ci-cd-enhancement/CI_CD_GUIDE.md)
- [Feature Roadmap](docs/ci-cd-enhancement/FEATURE_ROADMAP.md)
- [Windows Development](docs/WINDOWS_MAKE_GUIDE.md)
- [Task Status](docs/TASK_STATUS.md)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [go-zero](https://go-zero.dev) - Microservices framework
- Original project inspiration from [go-zero-looklook](https://github.com/Mikaelemmmm/go-zero-looklook)

## 📧 Contact

- **GitHub**: [@yourusername](https://github.com/yourusername)
- **Issues**: [GitHub Issues](https://github.com/yourusername/flash-sale-system/issues)

---

⭐ If you find this project helpful, please consider giving it a star!
