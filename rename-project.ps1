# Project Rename Script: flashsale -> flash-sale-system
# Usage: .\rename-project.ps1

$ErrorActionPreference = "Stop"

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Renaming Project to FlashSale System" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# Define replacement rules
$rules = @{
    "flash-sale-system" = "flash-sale-system"
    "flashsale_usercenter" = "flashsale_usercenter"
    "flashsale_order" = "flashsale_order"
    "flashsale_payment" = "flashsale_payment"
    "flashsale_product" = "flashsale_product"
    "flashsale-prod" = "flashsale-prod"
    "flashsale-dev" = "flashsale-dev"
    "flashsale-log" = "flashsale-log"
    "flashsale-gateway" = "flashsale-gateway"
    "flashsale" = "flashsale"
}

# Get all files except excluded
$files = Get-ChildItem -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\\.git\\' -and
    $_.FullName -notmatch '\\node_modules\\' -and
    $_.FullName -notmatch '\\bin\\' -and
    $_.FullName -notmatch '\\data\\' -and
    $_.Extension -notmatch '\.(exe|dll|so|png|jpg|jpeg|gif)$'
}

$count = 0
foreach ($file in $files) {
    $count++
    Write-Progress -Activity "Processing files" -Status "$count / $($files.Count)" -PercentComplete (($count / $files.Count) * 100)

    try {
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        $original = $content

        foreach ($old in $rules.Keys) {
            $new = $rules[$old]
            $content = $content -replace [regex]::Escape($old), $new
        }

        if ($content -ne $original) {
            $relativePath = $file.FullName.Substring((Get-Location).Path.Length + 1)
            Write-Host "  Updated: $relativePath" -ForegroundColor Green
            Set-Content -Path $file.FullName -Value $content -NoNewline -Encoding UTF8
        }
    }
    catch {
        # Skip binary files
    }
}

Write-Host ""
Write-Host "Renaming SQL files..." -ForegroundColor Yellow

$sqlFiles = @(
    @("deploy\sql\flashsale_order.sql", "deploy\sql\flashsale_order.sql"),
    @("deploy\sql\flashsale_payment.sql", "deploy\sql\flashsale_payment.sql"),
    @("deploy\sql\flashsale_product.sql", "deploy\sql\flashsale_product.sql"),
    @("deploy\sql\flashsale_usercenter.sql", "deploy\sql\flashsale_usercenter.sql")
)

foreach ($pair in $sqlFiles) {
    if (Test-Path $pair[0]) {
        Write-Host "  $($pair[0]) -> $($pair[1])" -ForegroundColor Cyan
        Move-Item -Path $pair[0] -Destination $pair[1] -Force
    }
}

if (Test-Path "deploy\nginx\conf.d\flashsale-gateway.conf") {
    Write-Host "  Renaming nginx config..." -ForegroundColor Cyan
    Move-Item -Path "deploy\nginx\conf.d\flashsale-gateway.conf" -Destination "deploy\nginx\conf.d\flashsale-gateway.conf" -Force
}

Write-Host ""
Write-Host "Updating go.mod..." -ForegroundColor Yellow

if (Test-Path "go.mod") {
    $goMod = Get-Content "go.mod" -Raw -Encoding UTF8
    $goMod = $goMod -replace "module\s+github\.com/[^/]+/flash-sale-system", "module github.com/yourusername/flash-sale-system"
    Set-Content -Path "go.mod" -Value $goMod -NoNewline -Encoding UTF8
    Write-Host "  Updated module path" -ForegroundColor Green
}

Write-Host ""
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Rename completed!" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run: go mod tidy" -ForegroundColor White
Write-Host "  2. Test build: .\build.ps1 build" -ForegroundColor White
Write-Host ""
