# Update Go import paths
# Usage: .\update-imports.ps1

$ErrorActionPreference = "Stop"

Write-Host "Updating Go import paths..." -ForegroundColor Cyan

# Find the old module path from git
$oldModule = ""
try {
    $gitRemote = git config --get remote.origin.url 2>$null
    if ($gitRemote -match '([^/:]+)/([^/]+)\.git$') {
        $oldModule = "$($Matches[1])/$($Matches[2])"
    }
} catch {
    # Fallback: search in files for old import pattern
    $sampleFile = Get-ChildItem -Path app -Recurse -Filter "*.go" | Select-Object -First 1
    if ($sampleFile) {
        $content = Get-Content $sampleFile.FullName -Raw
        if ($content -match 'github\.com/[^/]+/go-zero-looklook') {
            $oldModule = $Matches[0]
        }
    }
}

# If still not found, use default
if (-not $oldModule) {
    $oldModule = "github.com/Mikaelemmmm/go-zero-looklook"
}

$newModule = "github.com/yourusername/flash-sale-system"

Write-Host "  Old module: $oldModule" -ForegroundColor Yellow
Write-Host "  New module: $newModule" -ForegroundColor Green
Write-Host ""

# Get all .go files
$goFiles = Get-ChildItem -Path app,pkg -Recurse -Filter *.go -File

$count = 0
$updated = 0

foreach ($file in $goFiles) {
    $count++
    Write-Progress -Activity "Updating imports" -Status "$count / $($goFiles.Count)" -PercentComplete (($count / $goFiles.Count) * 100)

    try {
        $content = Get-Content -Path $file.FullName -Raw
        $original = $content

        # Replace import paths
        $content = $content -replace [regex]::Escape($oldModule), $newModule

        if ($content -ne $original) {
            Set-Content -Path $file.FullName -Value $content -NoNewline
            $relativePath = $file.FullName.Substring((Get-Location).Path.Length + 1)
            Write-Host "  Updated: $relativePath" -ForegroundColor Green
            $updated++
        }
    }
    catch {
        Write-Host "  Error processing: $($file.FullName)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Updated $updated files" -ForegroundColor Green
Write-Host ""
Write-Host "Running go mod tidy..." -ForegroundColor Cyan
go mod tidy

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
