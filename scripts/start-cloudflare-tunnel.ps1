# 启动 Cloudflare Tunnel 用于本地 K8s 集群访问
# 用途: 将本地 Docker Desktop K8s API Server 暴露到公网，供 GitHub Actions 访问

param(
    [switch]$Quick,  # 使用快速模式（临时域名）
    [string]$TunnelName = "flashsale-k8s"
)

Write-Host "=== Cloudflare Tunnel 启动脚本 ===" -ForegroundColor Cyan
Write-Host ""

# 检查 cloudflared 是否安装
$cloudflared = Get-Command cloudflared -ErrorAction SilentlyContinue
if (-not $cloudflared) {
    Write-Host "❌ cloudflared 未安装" -ForegroundColor Red
    Write-Host ""
    Write-Host "请使用以下命令安装:" -ForegroundColor Yellow
    Write-Host "  winget install --id Cloudflare.cloudflared" -ForegroundColor White
    Write-Host ""
    Write-Host "或从此处下载: https://github.com/cloudflare/cloudflared/releases" -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ cloudflared 已安装: $($cloudflared.Version)" -ForegroundColor Green

# 检查 Docker Desktop K8s 是否运行
Write-Host ""
Write-Host "检查本地 Kubernetes 集群..." -ForegroundColor Cyan
$k8sRunning = $false
try {
    $clusterInfo = kubectl cluster-info 2>&1
    if ($LASTEXITCODE -eq 0) {
        $k8sRunning = $true
        Write-Host "✓ Kubernetes 集群运行中" -ForegroundColor Green
    }
} catch {
    # 忽略错误
}

if (-not $k8sRunning) {
    Write-Host "❌ Kubernetes 集群未运行" -ForegroundColor Red
    Write-Host ""
    Write-Host "请先启动 Docker Desktop 并启用 Kubernetes:" -ForegroundColor Yellow
    Write-Host "  1. 打开 Docker Desktop" -ForegroundColor White
    Write-Host "  2. Settings -> Kubernetes -> Enable Kubernetes" -ForegroundColor White
    Write-Host "  3. 等待 Kubernetes 启动完成" -ForegroundColor White
    exit 1
}

# 测试本地 K8s API Server 连接
Write-Host ""
Write-Host "测试本地 K8s API Server 连接..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "https://127.0.0.1:6443" -SkipCertificateCheck -ErrorAction Stop 2>&1
} catch {
    # 401/403 是正常的（需要认证），表示 API Server 可访问
    if ($_.Exception.Response.StatusCode -in @(401, 403)) {
        Write-Host "✓ K8s API Server 可访问 (https://127.0.0.1:6443)" -ForegroundColor Green
    } else {
        Write-Host "⚠ K8s API Server 响应异常，但继续尝试..." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# 快速模式：使用临时域名
if ($Quick) {
    Write-Host "使用快速模式（临时域名）..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "启动 Tunnel..." -ForegroundColor Cyan
    Write-Host "⚠ 临时域名仅在 cloudflared 进程运行时有效" -ForegroundColor Yellow
    Write-Host "⚠ 关闭此窗口将停止 Tunnel" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "按 Ctrl+C 停止..." -ForegroundColor DarkGray
    Write-Host ""

    # 启动临时 tunnel
    cloudflared tunnel --url https://127.0.0.1:6443 --no-tls-verify
    exit
}

# 完整模式：使用持久化 tunnel
Write-Host "检查 Tunnel 配置..." -ForegroundColor Cyan

# 检查是否已创建 tunnel
$tunnelExists = $false
try {
    $tunnelList = cloudflared tunnel list 2>&1
    if ($tunnelList -match $TunnelName) {
        $tunnelExists = $true
        Write-Host "✓ Tunnel '$TunnelName' 已存在" -ForegroundColor Green
    }
} catch {
    # 忽略错误
}

if (-not $tunnelExists) {
    Write-Host "⚠ Tunnel '$TunnelName' 不存在" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "请先创建 Tunnel:" -ForegroundColor Yellow
    Write-Host "  1. 登录 Cloudflare: cloudflared tunnel login" -ForegroundColor White
    Write-Host "  2. 创建 Tunnel: cloudflared tunnel create $TunnelName" -ForegroundColor White
    Write-Host "  3. 配置 Tunnel (参考 docs/K8S_DEPLOYMENT_TUNNEL.md)" -ForegroundColor White
    Write-Host ""
    Write-Host "或使用快速模式: .\start-cloudflare-tunnel.ps1 -Quick" -ForegroundColor Cyan
    exit 1
}

# 检查配置文件
$configPath = "$env:USERPROFILE\.cloudflared\config.yml"
if (-not (Test-Path $configPath)) {
    Write-Host "⚠ 配置文件不存在: $configPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "请参考 docs/K8S_DEPLOYMENT_TUNNEL.md 创建配置文件" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "或使用快速模式: .\start-cloudflare-tunnel.ps1 -Quick" -ForegroundColor Cyan
    exit 1
}

Write-Host "✓ 配置文件存在: $configPath" -ForegroundColor Green

# 启动 tunnel
Write-Host ""
Write-Host "启动 Tunnel '$TunnelName'..." -ForegroundColor Cyan
Write-Host "按 Ctrl+C 停止..." -ForegroundColor DarkGray
Write-Host ""

cloudflared tunnel run $TunnelName
