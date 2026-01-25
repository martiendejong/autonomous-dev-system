# Fix Broken Param Blocks - Remove malformed usage tracking code from inside param blocks
# This fixes the specific error where tracking code was inserted INSIDE param block decorators

param(
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false
)

$ToolsDir = "C:\scripts\tools"

Write-Host "Fixing broken param blocks..." -ForegroundColor Cyan
Write-Host "  Dry Run: $DryRun" -ForegroundColor Gray
Write-Host ""

$tools = Get-ChildItem $ToolsDir -Filter "*.ps1" | Where-Object {
    $_.Name -notmatch '^_' -and
    $_.Name -ne 'integrate-usage-tracking.ps1' -and
    $_.Name -ne 'integrate-usage-tracking-v2.ps1' -and
    $_.Name -ne 'rollback-usage-tracking.ps1' -and
    $_.Name -ne 'fix-broken-param-blocks.ps1'
}

$fixed = 0
$skipped = 0
$errors = 0

foreach ($tool in $tools) {
    $content = Get-Content $tool.FullName -Raw -Encoding UTF8

    # Check for the specific broken pattern: tracking code inside param block
    # Pattern: [Parameter(...)\n\n# AUTO-USAGE TRACKING\n...\n]
    $brokenPattern = '(\[Parameter\([^\]]*\))\s*# AUTO-USAGE TRACKING[^\n]*\n[^\]]*_usage-logger\.ps1[^\n]*\n\s*(\])'

    if ($content -match $brokenPattern) {
        # Fix by removing the tracking code between [Parameter(...) and ]
        $newContent = $content -replace $brokenPattern, '$1$2'

        if ($DryRun) {
            Write-Host "[DRY-RUN] Would fix: $($tool.Name)" -ForegroundColor Cyan
        } else {
            try {
                $newContent | Set-Content $tool.FullName -Encoding UTF8 -NoNewline
                Write-Host "[FIXED] $($tool.Name)" -ForegroundColor Green
                $fixed++
            } catch {
                Write-Host "[ERROR] $($tool.Name): $_" -ForegroundColor Red
                $errors++
            }
        }
    } else {
        Write-Host "[SKIP] $($tool.Name) - No broken pattern found" -ForegroundColor Yellow
        $skipped++
    }
}

Write-Host ""
Write-Host "SUMMARY:" -ForegroundColor Yellow
Write-Host "  Total tools: $($tools.Count)" -ForegroundColor Gray
Write-Host "  Fixed: $fixed" -ForegroundColor Green
Write-Host "  Skipped: $skipped" -ForegroundColor Yellow
Write-Host "  Errors: $errors" -ForegroundColor Red
Write-Host ""

if ($DryRun) {
    Write-Host "Run without -DryRun to apply fixes" -ForegroundColor Cyan
} else {
    Write-Host "Param blocks fixed!" -ForegroundColor Green
    Write-Host "Now run: .\integrate-usage-tracking-v2.ps1" -ForegroundColor Cyan
}
