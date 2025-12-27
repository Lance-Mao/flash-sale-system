@echo off
chcp 65001 >nul
echo ========================================
echo   启动 Usercenter 本地开发环境
echo ========================================
echo.

REM 检查是否在项目根目录
if not exist "app\usercenter" (
    echo [错误] 请在项目根目录执行此脚本！
    pause
    exit /b 1
)

REM 检查Docker服务
echo [1/4] 检查Docker环境...
docker ps >nul 2>&1
if errorlevel 1 (
    echo [错误] Docker未运行，请先启动Docker！
    pause
    exit /b 1
)
echo ✓ Docker正常运行

REM 检查MySQL
echo [2/4] 检查MySQL容器...
docker ps | findstr mysql >nul
if errorlevel 1 (
    echo [警告] MySQL容器未运行，正在启动...
    docker-compose -f docker-compose-env.yml up -d mysql
    timeout /t 10 /nobreak >nul
)
echo ✓ MySQL已就绪

REM 检查Redis
echo [3/4] 检查Redis容器...
docker ps | findstr redis >nul
if errorlevel 1 (
    echo [警告] Redis容器未运行，正在启动...
    docker-compose -f docker-compose-env.yml up -d redis
    timeout /t 5 /nobreak >nul
)
echo ✓ Redis已就绪

REM 检查数据库
echo [4/4] 检查数据库表...
docker exec mysql mysql -uroot -pPXDN93VRKUm8TeE7 -e "use flashsale_usercenter; show tables;" >nul 2>&1
if errorlevel 1 (
    echo [警告] 数据库不存在，正在初始化...
    docker exec -i mysql mysql -uroot -pPXDN93VRKUm8TeE7 < deploy\sql\flashsale_usercenter.sql
    echo ✓ 数据库初始化完成
) else (
    echo ✓ 数据库已存在
)

echo.
echo ========================================
echo   环境检查完成，开始启动服务
echo ========================================
echo.

REM 启动RPC服务
echo [启动] usercenter-rpc (端口:2004)
start "usercenter-rpc" cmd /k "cd app\usercenter\cmd\rpc && go run usercenter.go -f etc\usercenter-local.yaml"
echo ✓ RPC服务启动中...
timeout /t 3 /nobreak >nul

REM 启动API服务
echo [启动] usercenter-api (端口:1004)
start "usercenter-api" cmd /k "cd app\usercenter\cmd\api && go run usercenter.go -f etc\usercenter-local.yaml"
echo ✓ API服务启动中...

echo.
echo ========================================
echo   启动完成！
echo ========================================
echo.
echo 📌 服务地址：
echo    - API: http://localhost:1004
echo    - RPC: localhost:2004
echo.
echo 📌 测试接口：
echo    curl -X POST http://localhost:1004/usercenter/v1/user/register \
echo      -H "Content-Type: application/json" \
echo      -d "{\"mobile\":\"13800138000\",\"password\":\"123456\"}"
echo.
echo 📌 查看详细文档：LOCAL_START_GUIDE.md
echo.
echo 按任意键关闭此窗口...
pause >nul
