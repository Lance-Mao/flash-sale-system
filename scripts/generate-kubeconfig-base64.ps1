# Generate kubeconfig base64 for GitHub Secrets
# Purpose: Convert kubeconfig to base64 format for KUBE_CONFIG_DEV secret

Write-Host ""
Write-Host "===== Generate kubeconfig base64 for GitHub Secrets =====" -ForegroundColor Cyan
Write-Host ""

# 1. Check kubeconfig file
$kubeconfigPath = "$env:USERPROFILE\.kube\config"

if (-not (Test-Path $kubeconfigPath)) {
    Write-Host "ERROR: kubeconfig file not found: $kubeconfigPath" -ForegroundColor Red
    exit 1
}

Write-Host "OK: Found kubeconfig file: $kubeconfigPath" -ForegroundColor Green

# 2. Convert to base64
Write-Host ""
Write-Host "Converting to base64..." -ForegroundColor Yellow

try {
    $content = Get-Content $kubeconfigPath -Raw
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
    $base64 = [Convert]::ToBase64String($bytes)

    # 3. Save to file
    $outputFile = "$PSScriptRoot\kubeconfig-base64.txt"
    $base64 | Out-File -FilePath $outputFile -NoNewline -Encoding UTF8

    Write-Host "OK: base64 conversion successful!" -ForegroundColor Green
    Write-Host "   Saved to: $outputFile" -ForegroundColor Cyan

    # 4. Copy to clipboard
    $base64 | Set-Clipboard
    Write-Host "OK: Copied to clipboard!" -ForegroundColor Green

    # 5. Show preview (first and last 50 characters)
    $preview = if ($base64.Length -gt 100) {
        $base64.Substring(0, 50) + "..." + $base64.Substring($base64.Length - 50)
    } else {
        $base64
    }

    Write-Host ""
    Write-Host "Preview (first and last 50 chars):" -ForegroundColor Yellow
    Write-Host $preview -ForegroundColor Gray

    Write-Host ""
    Write-Host "String length: $($base64.Length) characters" -ForegroundColor Cyan

    # 6. Usage instructions
    Write-Host ""
    Write-Host "===== Next Steps =====" -ForegroundColor Cyan
    Write-Host "1. Open GitHub repo: https://github.com/Lance-Mao/flash-sale-system" -ForegroundColor White
    Write-Host "2. Go to: Settings -> Secrets and variables -> Actions" -ForegroundColor White
    Write-Host "3. Click: New repository secret" -ForegroundColor White
    Write-Host "4. Fill in:" -ForegroundColor White
    Write-Host "   Name:   KUBE_CONFIG_DEV" -ForegroundColor Yellow
    Write-Host "   Secret: [Press Ctrl+V to paste from clipboard]" -ForegroundColor Green
    Write-Host "5. Click: Add secret" -ForegroundColor White

    Write-Host ""
    Write-Host "OK: Configuration is ready!" -ForegroundColor Green

} catch {
    Write-Host "ERROR: Conversion failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 7. Verify cluster connection
Write-Host ""
Write-Host "===== Verify Cluster Connection =====" -ForegroundColor Cyan

try {
    $nodes = kubectl get nodes --no-headers 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK: Cluster connection is working" -ForegroundColor Green
        Write-Host ""
        Write-Host "Current nodes:" -ForegroundColor Yellow
        kubectl get nodes

        $currentContext = kubectl config current-context
        Write-Host ""
        Write-Host "Current Context: $currentContext" -ForegroundColor Cyan
    } else {
        Write-Host "WARNING: Cluster connection test failed" -ForegroundColor Yellow
        Write-Host "Output: $nodes" -ForegroundColor Gray
    }
} catch {
    Write-Host "WARNING: Could not verify cluster connection, but base64 is generated" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "===== Done =====" -ForegroundColor Cyan
Write-Host ""
