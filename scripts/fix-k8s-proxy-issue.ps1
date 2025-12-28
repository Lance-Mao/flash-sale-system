# Fix Kubernetes Proxy Issue
# Remove proxy settings that prevent K8s from starting

Write-Host "=== Kubernetes Proxy Fix Tool ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Issue: kube-controller-manager cannot connect to API Server due to proxy" -ForegroundColor Yellow
Write-Host ""

# Check current proxy settings
Write-Host "[1/3] Checking proxy environment variables..." -ForegroundColor Cyan

$proxyVars = @("HTTP_PROXY", "HTTPS_PROXY", "http_proxy", "https_proxy", "NO_PROXY", "no_proxy")
$foundProxy = $false

foreach ($var in $proxyVars) {
    $value = [Environment]::GetEnvironmentVariable($var, "Process")
    if ($value) {
        Write-Host "  Found: $var = $value" -ForegroundColor Yellow
        $foundProxy = $true
    }
}

if (-not $foundProxy) {
    Write-Host "  No proxy variables found" -ForegroundColor Green
}

Write-Host ""
Write-Host "[2/3] Fix Options:" -ForegroundColor Cyan
Write-Host "  1. Clear proxy and restart Docker Desktop (Recommended)" -ForegroundColor White
Write-Host "  2. Configure NO_PROXY to exclude Kubernetes" -ForegroundColor White
Write-Host "  3. Manual fix (show instructions)" -ForegroundColor White
Write-Host "  4. Skip" -ForegroundColor DarkGray
Write-Host ""

$choice = Read-Host "Enter option (1-4)"

switch ($choice) {
    "1" {
        Write-Host ""
        Write-Host "[3/3] Clearing proxy..." -ForegroundColor Cyan

        # Clear proxy variables
        $env:HTTP_PROXY = ""
        $env:HTTPS_PROXY = ""
        $env:http_proxy = ""
        $env:https_proxy = ""

        Write-Host "  Proxy cleared" -ForegroundColor Green
        Write-Host ""

        $restart = Read-Host "Restart Docker Desktop now? (y/n)"
        if ($restart -eq "y") {
            Write-Host ""
            Write-Host "  Stopping Docker Desktop..." -ForegroundColor Yellow
            Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
            Stop-Process -Name "com.docker.backend" -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5

            Write-Host "  Starting Docker Desktop..." -ForegroundColor Yellow
            $dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
            if (Test-Path $dockerPath) {
                Start-Process $dockerPath
                Write-Host ""
                Write-Host "  Docker Desktop is restarting..." -ForegroundColor Green
                Write-Host ""
                Write-Host "  Wait 2-3 minutes, then verify:" -ForegroundColor Yellow
                Write-Host "    kubectl get nodes" -ForegroundColor White
                Write-Host "    kubectl get componentstatuses" -ForegroundColor White
            } else {
                Write-Host "  Docker Desktop not found at default location" -ForegroundColor Red
                Write-Host "  Please restart manually" -ForegroundColor Yellow
            }
        }
    }

    "2" {
        Write-Host ""
        Write-Host "[3/3] Configuring NO_PROXY..." -ForegroundColor Cyan

        $noProxy = "127.0.0.1,localhost,192.168.65.0/24,kubernetes.docker.internal,.cluster.local"

        [Environment]::SetEnvironmentVariable("NO_PROXY", $noProxy, "User")
        [Environment]::SetEnvironmentVariable("no_proxy", $noProxy, "User")

        Write-Host "  NO_PROXY set to: $noProxy" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Restart Docker Desktop for changes to take effect" -ForegroundColor Yellow
    }

    "3" {
        Write-Host ""
        Write-Host "[3/3] Manual Fix Instructions" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Step 1: Docker Desktop Settings" -ForegroundColor Yellow
        Write-Host "  1. Open Docker Desktop" -ForegroundColor White
        Write-Host "  2. Settings -> Resources -> Proxies" -ForegroundColor White
        Write-Host "  3. Select 'System proxy' or 'No proxy'" -ForegroundColor White
        Write-Host "  4. Or add to bypass: 127.0.0.1,localhost,192.168.65.0/24" -ForegroundColor White
        Write-Host "  5. Click Apply & Restart" -ForegroundColor White
        Write-Host ""

        Write-Host "Step 2: Configure Proxy Software" -ForegroundColor Yellow
        Write-Host "  Clash: Settings -> Bypass -> Add 192.168.65.0/24" -ForegroundColor White
        Write-Host "  V2Ray: Routing -> Add direct rule for 192.168.65.0/24" -ForegroundColor White
        Write-Host ""

        Write-Host "See docs/K8S_PROXY_FIX.md for details" -ForegroundColor Cyan
    }

    "4" {
        Write-Host ""
        Write-Host "Skipped" -ForegroundColor DarkGray
        exit 0
    }

    default {
        Write-Host ""
        Write-Host "Invalid option" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($choice -in @("1", "2")) {
    Write-Host "Fix complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Verify:" -ForegroundColor Yellow
    Write-Host "  1. Wait for Docker Desktop and Kubernetes to start" -ForegroundColor White
    Write-Host "  2. Run: kubectl get componentstatuses" -ForegroundColor White
    Write-Host "     Expected: controller-manager is Healthy" -ForegroundColor DarkGray
    Write-Host "  3. Run: kubectl get nodes" -ForegroundColor White
    Write-Host "     Expected: see docker-desktop node" -ForegroundColor DarkGray
    Write-Host ""
}
