# Fix Go import paths
# Replace flashsale/ with github.com/Lance-Mao/flash-sale-system/

$ErrorActionPreference = "Stop"

Write-Host "Fixing Go import paths..." -ForegroundColor Cyan
Write-Host ""

# Get all .go files
$goFiles = Get-ChildItem -Path app,pkg,deploy -Recurse -Filter *.go -File -ErrorAction SilentlyContinue

if (-not $goFiles) {
    Write-Host "No Go files found!" -ForegroundColor Red
    exit 1
}

$count = 0
$updated = 0

foreach ($file in $goFiles) {
    $count++
    $percentComplete = ($count / $goFiles.Count) * 100
    Write-Progress -Activity "Fixing imports" -Status "$count / $($goFiles.Count)" -PercentComplete $percentComplete

    try {
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        $original = $content

        # Replace flashsale/ with full module path
        $content = $content -replace '"flashsale/', '"github.com/Lance-Mao/flash-sale-system/'

        if ($content -ne $original) {
            Set-Content -Path $file.FullName -Value $content -NoNewline -Encoding UTF8
            $relativePath = $file.FullName.Substring((Get-Location).Path.Length + 1)
            Write-Host "  Updated: $relativePath" -ForegroundColor Green
            $updated++
        }
    }
    catch {
        $relativePath = $file.FullName.Substring((Get-Location).Path.Length + 1)
        Write-Host "  Error processing: $relativePath" -ForegroundColor Red
        Write-Host "    $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Progress -Activity "Fixing imports" -Completed

Write-Host ""
Write-Host "Updated $updated files" -ForegroundColor Green
Write-Host ""

if ($updated -gt 0) {
    Write-Host "Running go mod tidy..." -ForegroundColor Cyan
    go mod tidy

    if ($LASTEXITCODE -eq 0) {
        Write-Host "go mod tidy completed successfully" -ForegroundColor Green
    } else {
        Write-Host "go mod tidy failed" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
