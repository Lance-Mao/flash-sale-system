# Usercenter 本地启动指南

## 📋 前置条件

1. ✅ Go 1.25.4 已安装
2. ✅ Docker 环境已启动
3. ✅ MySQL、Redis等依赖服务已在Docker中运行

## 🚀 快速启动

### 方式一：使用启动脚本（推荐）

**Windows:**
```bash
# 在项目根目录执行
.\start-usercenter-local.bat
```

**Linux/Mac:**
```bash
# 在项目根目录执行
./start-usercenter-local.sh
```

### 方式二：手动启动

#### 1. 启动 usercenter-rpc（必须先启动）

```bash
# 进入RPC目录
cd app/usercenter/cmd/rpc

# 启动RPC服务
go run usercenter.go -f etc/usercenter-local.yaml
```

**启动成功日志：**
```
Starting rpc server at 0.0.0.0:2004...
```

#### 2. 启动 usercenter-api（新开终端）

```bash
# 进入API目录
cd app/usercenter/cmd/api

# 启动API服务
go run usercenter.go -f etc/usercenter-local.yaml
```

**启动成功日志：**
```
Starting server at 0.0.0.0:1004...
```

## 🔧 配置说明

### 本地配置文件

- **RPC配置**: `app/usercenter/cmd/rpc/etc/usercenter-local.yaml`
- **API配置**: `app/usercenter/cmd/api/etc/usercenter-local.yaml`

### 关键配置项

| 服务 | 配置项 | 本地地址 | 说明 |
|------|--------|----------|------|
| MySQL | DB.DataSource | `localhost:33069` | Docker映射端口 |
| Redis | Redis.Host | `localhost:36379` | Docker映射端口 |
| usercenter-rpc | ListenOn | `0.0.0.0:2004` | RPC服务端口 |
| usercenter-api | Port | `1004` | API服务端口 |

### 可选配置

**如果不需要链路追踪（Jaeger）**，可以注释掉配置文件中的 `Telemetry` 部分：

```yaml
# Telemetry:
#   Name: usercenter-api
#   Endpoint: http://localhost:14268/api/traces
#   Sampler: 1.0
#   Batcher: jaeger
```

## 🧪 测试接口

### 1. 用户注册

```bash
curl -X POST http://localhost:1004/usercenter/v1/user/register \
  -H "Content-Type: application/json" \
  -d '{
    "mobile": "13800138000",
    "password": "123456",
    "nickname": "测试用户"
  }'
```

**预期响应：**
```json
{
  "code": 0,
  "msg": "success",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIs...",
    "accessExpire": 1735123456,
    "refreshAfter": 1735115656
  }
}
```

### 2. 用户登录

```bash
curl -X POST http://localhost:1004/usercenter/v1/user/login \
  -H "Content-Type: application/json" \
  -d '{
    "mobile": "13800138000",
    "password": "123456"
  }'
```

### 3. 获取用户信息（需要JWT）

```bash
curl -X POST http://localhost:1004/usercenter/v1/user/detail \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your_token>" \
  -d '{}'
```

## 📊 服务端口

| 服务 | 端口 | 说明 |
|------|------|------|
| usercenter-api | 1004 | HTTP API服务 |
| usercenter-rpc | 2004 | gRPC服务 |
| Prometheus监控(API) | 4008 | 监控指标 |
| Prometheus监控(RPC) | 4009 | 监控指标 |

## ⚠️ 常见问题

### 1. 数据库连接失败

**错误信息：** `dial tcp 127.0.0.1:33069: connect: connection refused`

**解决方法：**
```bash
# 检查MySQL容器是否运行
docker ps | grep mysql

# 如果没有运行，启动依赖环境
docker-compose -f docker-compose-env.yml up -d mysql redis
```

### 2. 数据库不存在

**错误信息：** `Error 1049: Unknown database 'flashsale_usercenter'`

**解决方法：**
```bash
# 连接MySQL并导入SQL
docker exec -i mysql mysql -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_usercenter.sql

# 或者使用本地MySQL客户端
mysql -h 127.0.0.1 -P 33069 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_usercenter.sql
```

### 3. RPC连接失败

**错误信息：** API日志显示无法连接到RPC

**解决方法：**
- 确保先启动 `usercenter-rpc`
- 检查RPC是否在 `2004` 端口监听

### 4. Redis连接失败

**错误信息：** `dial tcp 127.0.0.1:36379: connect: connection refused`

**解决方法：**
```bash
# 检查Redis容器是否运行
docker ps | grep redis

# 启动Redis
docker-compose -f docker-compose-env.yml up -d redis
```

## 🔍 日志调试

**查看详细日志**，将配置文件中的日志级别改为 `debug`：

```yaml
Log:
  ServiceName: usercenter-api
  Level: debug  # 改为debug
```

## 🛑 停止服务

- **Ctrl + C** 停止正在运行的服务
- 或者查找并终止进程：

```bash
# Windows
tasklist | findstr "usercenter"
taskkill /F /PID <进程ID>

# Linux/Mac
ps aux | grep usercenter
kill -9 <进程ID>
```

## 📝 下一步

- 启动其他服务（travel、order、payment）参考相同方式
- 配置Nginx网关统一入口
- 使用Postman导入API文档进行测试
