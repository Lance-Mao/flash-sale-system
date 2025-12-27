#!/bin/bash

echo "========================================"
echo "  启动 Usercenter 本地开发环境"
echo "========================================"
echo ""

# 检查是否在项目根目录
if [ ! -d "app/usercenter" ]; then
    echo "[错误] 请在项目根目录执行此脚本！"
    exit 1
fi

# 检查Docker服务
echo "[1/4] 检查Docker环境..."
if ! docker ps >/dev/null 2>&1; then
    echo "[错误] Docker未运行，请先启动Docker！"
    exit 1
fi
echo "✓ Docker正常运行"

# 检查MySQL
echo "[2/4] 检查MySQL容器..."
if ! docker ps | grep -q mysql; then
    echo "[警告] MySQL容器未运行，正在启动..."
    docker-compose -f docker-compose-env.yml up -d mysql
    sleep 10
fi
echo "✓ MySQL已就绪"

# 检查Redis
echo "[3/4] 检查Redis容器..."
if ! docker ps | grep -q redis; then
    echo "[警告] Redis容器未运行，正在启动..."
    docker-compose -f docker-compose-env.yml up -d redis
    sleep 5
fi
echo "✓ Redis已就绪"

# 检查数据库
echo "[4/4] 检查数据库表..."
if ! docker exec mysql mysql -uroot -pPXDN93VRKUm8TeE7 -e "use flashsale_usercenter; show tables;" >/dev/null 2>&1; then
    echo "[警告] 数据库不存在，正在初始化..."
    docker exec -i mysql mysql -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_usercenter.sql
    echo "✓ 数据库初始化完成"
else
    echo "✓ 数据库已存在"
fi

echo ""
echo "========================================"
echo "  环境检查完成，开始启动服务"
echo "========================================"
echo ""

# 启动RPC服务（后台运行）
echo "[启动] usercenter-rpc (端口:2004)"
cd app/usercenter/cmd/rpc
nohup go run usercenter.go -f etc/usercenter-local.yaml > ../../../../logs/usercenter-rpc.log 2>&1 &
RPC_PID=$!
echo "✓ RPC服务已启动 (PID: $RPC_PID)"
cd ../../../../

sleep 3

# 启动API服务（后台运行）
echo "[启动] usercenter-api (端口:1004)"
cd app/usercenter/cmd/api
nohup go run usercenter.go -f etc/usercenter-local.yaml > ../../../../logs/usercenter-api.log 2>&1 &
API_PID=$!
echo "✓ API服务已启动 (PID: $API_PID)"
cd ../../../../

echo ""
echo "========================================"
echo "  启动完成！"
echo "========================================"
echo ""
echo "📌 服务地址："
echo "   - API: http://localhost:1004"
echo "   - RPC: localhost:2004"
echo ""
echo "📌 进程ID："
echo "   - RPC PID: $RPC_PID"
echo "   - API PID: $API_PID"
echo ""
echo "📌 查看日志："
echo "   - tail -f logs/usercenter-rpc.log"
echo "   - tail -f logs/usercenter-api.log"
echo ""
echo "📌 停止服务："
echo "   - kill $RPC_PID $API_PID"
echo ""
echo "📌 测试接口："
echo '   curl -X POST http://localhost:1004/usercenter/v1/user/register \'
echo '     -H "Content-Type: application/json" \'
echo '     -d '"'"'{"mobile":"13800138000","password":"123456"}'"'"''
echo ""
echo "📌 查看详细文档：LOCAL_START_GUIDE.md"
