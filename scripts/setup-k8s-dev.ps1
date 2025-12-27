# Kubernetes 开发环境设置脚本（Windows）
# 用途：检测并配置本地 Kubernetes 环境

Write-Host "===== Kubernetes 开发环境检测 =====" -ForegroundColor Cyan

# 1. 检查 Docker
Write-Host "`n[1/6] 检查 Docker..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "✅ Docker 已安装: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker 未安装或未运行" -ForegroundColor Red
    Write-Host "请先安装 Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# 2. 检查 kubectl
Write-Host "`n[2/6] 检查 kubectl..." -ForegroundColor Yellow
try {
    $kubectlVersion = kubectl version --client --short 2>$null
    Write-Host "✅ kubectl 已安装: $kubectlVersion" -ForegroundColor Green
} catch {
    Write-Host "⚠️  kubectl 未安装，正在安装..." -ForegroundColor Yellow

    # 安装 kubectl
    curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"

    # 移动到 PATH 目录
    $kubectlPath = "C:\Program Files\kubectl"
    New-Item -ItemType Directory -Force -Path $kubectlPath | Out-Null
    Move-Item -Path ".\kubectl.exe" -Destination "$kubectlPath\kubectl.exe" -Force

    # 添加到 PATH
    $env:Path += ";$kubectlPath"
    [Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)

    Write-Host "✅ kubectl 安装完成" -ForegroundColor Green
}

# 3. 检查 Kubernetes 集群
Write-Host "`n[3/6] 检查 Kubernetes 集群..." -ForegroundColor Yellow

$k8sAvailable = $false
$currentContext = ""

try {
    $nodes = kubectl get nodes 2>$null
    if ($LASTEXITCODE -eq 0) {
        $k8sAvailable = $true
        $currentContext = kubectl config current-context
        Write-Host "✅ Kubernetes 集群可用" -ForegroundColor Green
        Write-Host "   当前 Context: $currentContext" -ForegroundColor Cyan
        Write-Host "`n$nodes"
    }
} catch {
    Write-Host "⚠️  未检测到可用的 Kubernetes 集群" -ForegroundColor Yellow
}

# 4. 提供配置建议
Write-Host "`n[4/6] 配置建议..." -ForegroundColor Yellow

if (-not $k8sAvailable) {
    Write-Host "未找到运行中的 Kubernetes 集群，请选择以下方案之一：`n" -ForegroundColor Yellow

    Write-Host "方案 1（推荐）：启用 Docker Desktop 内置 Kubernetes" -ForegroundColor Cyan
    Write-Host "  1. 打开 Docker Desktop"
    Write-Host "  2. Settings -> Kubernetes -> Enable Kubernetes"
    Write-Host "  3. Apply & Restart"
    Write-Host "  4. 等待几分钟直到 Kubernetes 运行`n"

    Write-Host "方案 2：安装 Minikube" -ForegroundColor Cyan
    Write-Host "  # 使用 Chocolatey 安装"
    Write-Host "  choco install minikube"
    Write-Host "  # 启动"
    Write-Host "  minikube start --driver=docker --cpus=4 --memory=8192`n"

    $choice = Read-Host "是否要检查 Minikube？(y/n)"

    if ($choice -eq "y" -or $choice -eq "Y") {
        Write-Host "`n[5/6] 检查 Minikube..." -ForegroundColor Yellow

        try {
            $minikubeVersion = minikube version --short
            Write-Host "✅ Minikube 已安装: $minikubeVersion" -ForegroundColor Green

            $minikubeStatus = minikube status 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Minikube 正在运行" -ForegroundColor Green
            } else {
                Write-Host "⚠️  Minikube 未运行" -ForegroundColor Yellow
                $startMinikube = Read-Host "是否启动 Minikube？(y/n)"

                if ($startMinikube -eq "y" -or $startMinikube -eq "Y") {
                    Write-Host "正在启动 Minikube..." -ForegroundColor Yellow
                    minikube start --driver=docker --cpus=4 --memory=8192

                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "✅ Minikube 启动成功" -ForegroundColor Green
                        $k8sAvailable = $true
                    }
                }
            }
        } catch {
            Write-Host "❌ Minikube 未安装" -ForegroundColor Red
            Write-Host "安装命令: choco install minikube" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "✅ 已检测到运行中的 Kubernetes 集群" -ForegroundColor Green
}

# 5. 生成 kubeconfig base64（用于 GitHub Secrets）
Write-Host "`n[5/6] 生成 kubeconfig base64..." -ForegroundColor Yellow

if ($k8sAvailable) {
    $kubeconfigPath = "$env:USERPROFILE\.kube\config"

    if (Test-Path $kubeconfigPath) {
        $content = Get-Content $kubeconfigPath -Raw
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
        $base64 = [Convert]::ToBase64String($bytes)

        # 保存到临时文件
        $outputFile = "$env:TEMP\kubeconfig-base64.txt"
        $base64 | Out-File -FilePath $outputFile -NoNewline

        # 复制到剪贴板
        $base64 | Set-Clipboard

        Write-Host "✅ kubeconfig base64 已生成" -ForegroundColor Green
        Write-Host "   已复制到剪贴板" -ForegroundColor Cyan
        Write-Host "   已保存到: $outputFile" -ForegroundColor Cyan
        Write-Host "`n   现在可以将此 base64 字符串添加到 GitHub Secrets:" -ForegroundColor Yellow
        Write-Host "   Settings -> Secrets -> Actions -> New secret" -ForegroundColor Yellow
        Write-Host "   Name: KUBE_CONFIG_DEV" -ForegroundColor Yellow
        Write-Host "   Value: [粘贴剪贴板内容]" -ForegroundColor Yellow
    } else {
        Write-Host "⚠️  未找到 kubeconfig 文件: $kubeconfigPath" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  无可用的 Kubernetes 集群，跳过" -ForegroundColor Yellow
}

# 6. 测试集群连接
Write-Host "`n[6/6] 测试集群连接..." -ForegroundColor Yellow

if ($k8sAvailable) {
    Write-Host "正在测试 kubectl 命令..." -ForegroundColor Cyan

    # 测试命令
    kubectl get nodes
    kubectl get namespaces

    Write-Host "`n✅ 集群连接正常！" -ForegroundColor Green

    # 创建测试命名空间
    Write-Host "`n是否创建 flashsale-dev 命名空间？" -ForegroundColor Yellow
    $createNs = Read-Host "(y/n)"

    if ($createNs -eq "y" -or $createNs -eq "Y") {
        kubectl create namespace flashsale-dev 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ 命名空间 flashsale-dev 已创建" -ForegroundColor Green
        } else {
            Write-Host "⚠️  命名空间可能已存在" -ForegroundColor Yellow
        }
    }
}

# 总结
Write-Host "`n===== 配置总结 =====" -ForegroundColor Cyan

if ($k8sAvailable) {
    Write-Host "✅ Kubernetes 开发环境已就绪！" -ForegroundColor Green
    Write-Host "`n下一步操作：" -ForegroundColor Yellow
    Write-Host "1. 将 kubeconfig base64 添加到 GitHub Secrets (KUBE_CONFIG_DEV)"
    Write-Host "2. 配置镜像仓库 Secrets (HARBOR_USERNAME, HARBOR_PASSWORD)"
    Write-Host "3. 运行 CI/CD 测试"
    Write-Host "`n参考文档: docs/ci-cd-enhancement/GITHUB_SECRETS_GUIDE.md" -ForegroundColor Cyan
} else {
    Write-Host "⚠️  Kubernetes 环境未就绪" -ForegroundColor Yellow
    Write-Host "`n请按照上述建议配置 Kubernetes 集群，然后重新运行此脚本。" -ForegroundColor Yellow
}

Write-Host "`n===== 完成 =====" -ForegroundColor Cyan
