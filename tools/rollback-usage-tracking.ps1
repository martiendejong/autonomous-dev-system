# Rollback Usage Tracking - Remove auto-logging from all tools
# Run to undo the broken integration

param(
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false
)

$ToolsDir = "C:\scripts\tools"

Write-Host "Rolling back usage tracking integration..." -ForegroundColor Cyan
Write-Host "  Dry Run: $DryRun" -ForegroundColor Gray
Write-Host ""

$tools = Get-ChildItem $ToolsDir -Filter "*.ps1" | Where-Object {
    $_.Name -notmatch '^_' -and
    $_.Name -ne 'integrate-usage-tracking.ps1' -and
    $_.Name -ne 'rollback-usage-tracking.ps1'
}

$rolledBack = 0
$skipped = 0
$errors = 0

foreach ($tool in $tools) {
    $content = Get-Content $tool.FullName -Raw -Encoding UTF8

    # Check if has tracking code
    if ($content -notmatch 'AUTO-USAGE TRACKING') {
        Write-Host "[SKIP] $($tool.Name) - No tracking found" -ForegroundColor Yellow
        $skipped++
        continue
    }

    # Remove the tracking snippet (including surrounding newlines)
    $pattern = '(?s)\s*# AUTO-USAGE TRACKING[^\n]*\n[^\n]*_usage-logger\.ps1[^\n]*\n\s*'
    $newContent = $content -replace $pattern, "`n"

    if ($DryRun) {
        Write-Host "[DRY-RUN] Would rollback: $($tool.Name)" -ForegroundColor Cyan
    } else {
        try {
            $newContent | Set-Content $tool.FullName -Encoding UTF8 -NoNewline
            Write-Host "[ROLLED BACK] $($tool.Name)" -ForegroundColor Green
            $rolledBack++
        } catch {
            Write-Host "[ERROR] $($tool.Name): $_" -ForegroundColor Red
            $errors++
        }
    }
}

Write-Host ""
Write-Host "SUMMARY:" -ForegroundColor Yellow
Write-Host "  Total tools: $($tools.Count)" -ForegroundColor Gray
Write-Host "  Rolled back: $rolledBack" -ForegroundColor Green
Write-Host "  Skipped: $skipped" -ForegroundColor Yellow
Write-Host "  Errors: $errors" -ForegroundColor Red
Write-Host ""

if ($DryRun) {
    Write-Host "Run without -DryRun to apply rollback" -ForegroundColor Cyan
} else {
    Write-Host "Usage tracking removed!" -ForegroundColor Green
}
