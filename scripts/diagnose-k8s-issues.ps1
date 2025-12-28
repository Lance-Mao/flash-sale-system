# Docker Desktop Kubernetes 诊断和修复脚本
# 用于诊断 K8s 一直启动失败的问题

Write-Host "=== Docker Desktop Kubernetes 诊断工具 ===" -ForegroundColor Cyan
Write-Host ""

# 检查 Docker 是否运行
Write-Host "[1/7] 检查 Docker 运行状态..." -ForegroundColor Cyan
try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Docker 正在运行 (版本: $dockerVersion)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Docker 未运行" -ForegroundColor Red
        Write-Host "    请先启动 Docker Desktop" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "  ✗ 无法连接到 Docker" -ForegroundColor Red
    exit 1
}

# 检查 kubectl 是否可用
Write-Host ""
Write-Host "[2/7] 检查 kubectl..." -ForegroundColor Cyan
$kubectl = Get-Command kubectl -ErrorAction SilentlyContinue
if ($kubectl) {
    $kubectlVersion = kubectl version --client --short 2>&1 | Select-String "Client Version"
    Write-Host "  ✓ kubectl 已安装: $kubectlVersion" -ForegroundColor Green
} else {
    Write-Host "  ✗ kubectl 未安装" -ForegroundColor Red
    exit 1
}

# 检查当前 context
Write-Host ""
Write-Host "[3/7] 检查 Kubernetes context..." -ForegroundColor Cyan
$currentContext = kubectl config current-context 2>&1
if ($currentContext -eq "docker-desktop") {
    Write-Host "  ✓ 当前 context: $currentContext" -ForegroundColor Green
} else {
    Write-Host "  ⚠ 当前 context 不是 docker-desktop: $currentContext" -ForegroundColor Yellow
    Write-Host "    切换到 docker-desktop? (y/n)" -ForegroundColor Yellow
    $switch = Read-Host
    if ($switch -eq "y") {
        kubectl config use-context docker-desktop
        Write-Host "  ✓ 已切换到 docker-desktop" -ForegroundColor Green
    }
}

# 检查 K8s 核心组件
Write-Host ""
Write-Host "[4/7] 检查 Kubernetes 核心组件..." -ForegroundColor Cyan

$components = @(
    "kube-apiserver",
    "etcd",
    "kube-scheduler",
    "kube-controller-manager"
)

$componentStatus = @{}
foreach ($comp in $components) {
    $container = docker ps --filter "name=k8s_${comp}_" --format "{{.Names}}" 2>&1
    if ($container) {
        Write-Host "  ✓ $comp : 运行中" -ForegroundColor Green
        $componentStatus[$comp] = "running"
    } else {
        $podContainer = docker ps --filter "name=k8s_POD_${comp}" --format "{{.Names}}" 2>&1
        if ($podContainer) {
            Write-Host "  ✗ $comp : POD 存在但主容器未运行 ⚠️" -ForegroundColor Red
            $componentStatus[$comp] = "pod-only"
        } else {
            Write-Host "  ✗ $comp : 未运行" -ForegroundColor Red
            $componentStatus[$comp] = "not-running"
        }
    }
}

# 检查组件健康状态
Write-Host ""
Write-Host "[5/7] 检查组件健康状态..." -ForegroundColor Cyan
$componentHealth = kubectl get componentstatuses 2>&1
if ($componentHealth -match "Unhealthy") {
    Write-Host "  ⚠ 发现不健康的组件:" -ForegroundColor Yellow
    $componentHealth | Select-String "Unhealthy" | ForEach-Object {
        Write-Host "    $_" -ForegroundColor Red
    }
} else {
    Write-Host "  组件状态:" -ForegroundColor White
    Write-Host $componentHealth -ForegroundColor DarkGray
}

# 检查节点状态
Write-Host ""
Write-Host "[6/7] 检查节点状态..." -ForegroundColor Cyan
$nodes = kubectl get nodes 2>&1
if ($nodes -match "docker-desktop") {
    Write-Host "  ✓ 节点已注册" -ForegroundColor Green
    kubectl get nodes
} else {
    Write-Host "  ✗ 没有节点注册" -ForegroundColor Red
    Write-Host "    输出: $nodes" -ForegroundColor DarkGray
}

# 检查系统 pods
Write-Host ""
Write-Host "[7/7] 检查系统 Pods..." -ForegroundColor Cyan
$pods = kubectl get pods -n kube-system 2>&1
if ($pods -match "No resources found") {
    Write-Host "  ✗ kube-system namespace 中没有 pods" -ForegroundColor Red
} else {
    Write-Host "  kube-system pods:" -ForegroundColor White
    kubectl get pods -n kube-system
}

# 诊断总结
Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "诊断总结" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

$hasIssues = $false

# 分析问题
if ($componentStatus["kube-controller-manager"] -eq "pod-only") {
    Write-Host "⚠️ 主要问题: kube-controller-manager 无法启动" -ForegroundColor Red
    Write-Host ""
    Write-Host "kube-controller-manager 是 Kubernetes 的核心组件，负责:" -ForegroundColor Yellow
    Write-Host "  - 节点管理" -ForegroundColor White
    Write-Host "  - Pod 副本控制" -ForegroundColor White
    Write-Host "  - 服务端点控制" -ForegroundColor White
    Write-Host "  - 等等..." -ForegroundColor White
    Write-Host ""
    Write-Host "这就是为什么 kubectl get nodes 和 get pods 都返回空的原因。" -ForegroundColor Yellow
    $hasIssues = $true
}

if ($componentStatus["kube-apiserver"] -ne "running") {
    Write-Host "⚠️ 严重: API Server 未运行" -ForegroundColor Red
    $hasIssues = $true
}

if ($componentStatus["etcd"] -ne "running") {
    Write-Host "⚠️ 严重: etcd 未运行" -ForegroundColor Red
    $hasIssues = $true
}

# 提供解决方案
if ($hasIssues) {
    Write-Host ""
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host "推荐解决方案" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "方案 1: 重置 Kubernetes (推荐)" -ForegroundColor Yellow
    Write-Host "  1. 打开 Docker Desktop" -ForegroundColor White
    Write-Host "  2. Settings -> Kubernetes" -ForegroundColor White
    Write-Host "  3. 点击 'Reset Kubernetes Cluster'" -ForegroundColor White
    Write-Host "  4. 确认重置" -ForegroundColor White
    Write-Host "  5. 等待重新初始化完成（可能需要几分钟）" -ForegroundColor White
    Write-Host ""

    Write-Host "方案 2: 重启 Docker Desktop" -ForegroundColor Yellow
    Write-Host "  1. 退出 Docker Desktop（右键托盘图标 -> Quit）" -ForegroundColor White
    Write-Host "  2. 等待完全退出" -ForegroundColor White
    Write-Host "  3. 重新启动 Docker Desktop" -ForegroundColor White
    Write-Host "  4. 等待 Kubernetes 启动（查看托盘图标）" -ForegroundColor White
    Write-Host ""

    Write-Host "方案 3: 增加资源配置" -ForegroundColor Yellow
    Write-Host "  如果机器资源不足，Kubernetes 组件可能无法启动:" -ForegroundColor White
    Write-Host "  1. Docker Desktop -> Settings -> Resources" -ForegroundColor White
    Write-Host "  2. 增加 CPU 和内存:" -ForegroundColor White
    Write-Host "     - 推荐 CPU: 至少 2 核" -ForegroundColor White
    Write-Host "     - 推荐内存: 至少 4GB" -ForegroundColor White
    Write-Host "  3. 点击 Apply & Restart" -ForegroundColor White
    Write-Host ""

    Write-Host "方案 4: 检查日志（高级）" -ForegroundColor Yellow
    Write-Host "  如果以上方案都无效，可以查看详细日志:" -ForegroundColor White
    Write-Host "  1. Docker Desktop -> Troubleshoot -> View logs" -ForegroundColor White
    Write-Host "  2. 搜索 'kube-controller-manager' 相关错误" -ForegroundColor White
    Write-Host ""

    Write-Host "方案 5: 完全重新安装 Docker Desktop" -ForegroundColor Yellow
    Write-Host "  最后的手段，如果其他方案都无效:" -ForegroundColor White
    Write-Host "  1. 卸载 Docker Desktop" -ForegroundColor White
    Write-Host "  2. 删除数据目录:" -ForegroundColor White
    Write-Host "     %APPDATA%\Docker" -ForegroundColor DarkGray
    Write-Host "     %LOCALAPPDATA%\Docker" -ForegroundColor DarkGray
    Write-Host "  3. 重新安装 Docker Desktop" -ForegroundColor White
    Write-Host ""

} else {
    Write-Host "✓ Kubernetes 看起来运行正常！" -ForegroundColor Green
    Write-Host ""
    Write-Host "如果你仍然遇到问题，请尝试:" -ForegroundColor Yellow
    Write-Host "  kubectl get all -A" -ForegroundColor White
    Write-Host "  查看所有资源的详细状态" -ForegroundColor White
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

# 提供快速重置选项
if ($hasIssues) {
    Write-Host "是否立即执行方案 2（重启 Docker Desktop）? (y/n)" -ForegroundColor Yellow
    $restart = Read-Host
    if ($restart -eq "y") {
        Write-Host ""
        Write-Host "正在关闭 Docker Desktop..." -ForegroundColor Cyan
        Stop-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 5

        Write-Host "正在启动 Docker Desktop..." -ForegroundColor Cyan
        Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

        Write-Host ""
        Write-Host "✓ Docker Desktop 正在重启" -ForegroundColor Green
        Write-Host "  请等待几分钟，直到托盘图标显示 Kubernetes 启动完成" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  然后再次运行此脚本验证:" -ForegroundColor Yellow
        Write-Host "  .\scripts\diagnose-k8s-issues.ps1" -ForegroundColor White
    }
}
