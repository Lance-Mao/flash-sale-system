# 生成用于远程访问的 kubeconfig
# 将本地 K8s API Server 地址替换为 Cloudflare Tunnel 的公网地址

param(
    [Parameter(Mandatory=$true)]
    [string]$TunnelUrl,  # 例如: https://k8s.yourdomain.com 或 https://random-words-1234.trycloudflare.com

    [string]$OutputPath = ".\kubeconfig-remote.yaml",
    [switch]$Base64Output  # 输出 base64 编码（用于 GitHub Secrets）
)

Write-Host "=== 生成远程访问 kubeconfig ===" -ForegroundColor Cyan
Write-Host ""

# 检查 kubectl 是否可用
$kubectl = Get-Command kubectl -ErrorAction SilentlyContinue
if (-not $kubectl) {
    Write-Host "❌ kubectl 未安装" -ForegroundColor Red
    exit 1
}

# 验证 Tunnel URL 格式
if ($TunnelUrl -notmatch '^https?://') {
    Write-Host "❌ Tunnel URL 必须以 http:// 或 https:// 开头" -ForegroundColor Red
    Write-Host "示例: https://random-words-1234.trycloudflare.com" -ForegroundColor Yellow
    exit 1
}

$TunnelUrl = $TunnelUrl.TrimEnd('/')

Write-Host "Tunnel URL: $TunnelUrl" -ForegroundColor Cyan
Write-Host ""

# 导出当前 kubeconfig
Write-Host "导出当前 kubeconfig..." -ForegroundColor Cyan
$currentKubeconfig = kubectl config view --raw 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 无法导出 kubeconfig" -ForegroundColor Red
    Write-Host $currentKubeconfig
    exit 1
}

Write-Host "✓ 已导出当前 kubeconfig" -ForegroundColor Green

# 替换 server 地址
Write-Host ""
Write-Host "替换 API Server 地址..." -ForegroundColor Cyan

# 查找所有可能的本地地址
$localAddresses = @(
    'https://kubernetes.docker.internal:6443',
    'https://127.0.0.1:6443',
    'https://localhost:6443'
)

$remoteKubeconfig = $currentKubeconfig
$replaced = $false

foreach ($localAddr in $localAddresses) {
    if ($remoteKubeconfig -match [regex]::Escape($localAddr)) {
        Write-Host "  替换: $localAddr -> $TunnelUrl" -ForegroundColor Yellow
        $remoteKubeconfig = $remoteKubeconfig -replace [regex]::Escape($localAddr), $TunnelUrl
        $replaced = $true
    }
}

if (-not $replaced) {
    Write-Host "⚠ 未找到本地 API Server 地址，请手动检查" -ForegroundColor Yellow
    Write-Host "当前 server 地址:" -ForegroundColor Yellow
    $currentKubeconfig | Select-String "server:" | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
}

# 添加注释说明
$header = @"
# Remote kubeconfig for Cloudflare Tunnel access
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# Tunnel URL: $TunnelUrl
#
# ⚠️ 仅用于学习和开发环境
# ⚠️ 确保 Cloudflare Tunnel 正在运行
#
"@

$remoteKubeconfig = $header + "`n" + $remoteKubeconfig

# 保存到文件
Write-Host ""
Write-Host "保存到文件: $OutputPath" -ForegroundColor Cyan
$remoteKubeconfig | Out-File -FilePath $OutputPath -Encoding UTF8 -NoNewline
Write-Host "✓ 已保存" -ForegroundColor Green

# 如果需要 base64 编码
if ($Base64Output) {
    Write-Host ""
    Write-Host "生成 Base64 编码（用于 GitHub Secrets）..." -ForegroundColor Cyan

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($remoteKubeconfig)
    $base64 = [Convert]::ToBase64String($bytes)

    $base64OutputPath = $OutputPath -replace '\.yaml$', '.base64.txt'
    $base64 | Out-File -FilePath $base64OutputPath -Encoding UTF8 -NoNewline

    Write-Host "✓ Base64 已保存到: $base64OutputPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "复制以下内容到 GitHub Secrets (KUBE_CONFIG_DEV):" -ForegroundColor Yellow
    Write-Host "---" -ForegroundColor DarkGray
    Write-Host $base64 -ForegroundColor White
    Write-Host "---" -ForegroundColor DarkGray

    # 复制到剪贴板（如果可用）
    try {
        $base64 | Set-Clipboard
        Write-Host ""
        Write-Host "✓ 已复制到剪贴板" -ForegroundColor Green
    } catch {
        # 忽略剪贴板错误
    }
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步:" -ForegroundColor Yellow
Write-Host "  1. 测试 kubeconfig: kubectl --kubeconfig=$OutputPath get nodes" -ForegroundColor White
Write-Host "  2. 如果测试成功，将 base64 内容添加到 GitHub Secrets" -ForegroundColor White
Write-Host "     Repository Settings -> Secrets and variables -> Actions" -ForegroundColor White
Write-Host "     Secret Name: KUBE_CONFIG_DEV" -ForegroundColor White
Write-Host ""
