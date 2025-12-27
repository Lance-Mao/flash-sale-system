# Lint Auto-Fix Script
# This script automatically fixes common linting issues

Write-Host "===== Auto-fixing lint issues =====" -ForegroundColor Cyan

$projectRoot = "D:\project\go\flash-sale\flash-sale-system"
cd $projectRoot

Write-Host "`n[1/3] Running golangci-lint with auto-fix..." -ForegroundColor Yellow

# Run golangci-lint with --fix flag to automatically fix issues
golangci-lint run --fix --timeout=10m

if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: All auto-fixable issues have been resolved" -ForegroundColor Green
} else {
    Write-Host "WARNING: Some issues remain" -ForegroundColor Yellow
}

Write-Host "`n[2/3] Running gofmt to format all Go files..." -ForegroundColor Yellow

# Format all Go files
Get-ChildItem -Path . -Filter *.go -Recurse -File | ForEach-Object {
    gofmt -w $_.FullName
}

Write-Host "OK: All files formatted" -ForegroundColor Green

Write-Host "`n[3/3] Running go mod tidy..." -ForegroundColor Yellow

go mod tidy

Write-Host "OK: Dependencies tidied" -ForegroundColor Green

Write-Host "`n===== Auto-fix complete =====" -ForegroundColor Cyan
Write-Host "Run 'make lint' to verify remaining issues" -ForegroundColor Yellow
