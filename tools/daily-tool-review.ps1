# Daily Tool Review - End of Session Routine
# MANDATORY 2-minute check for continuous improvement

param(
    [Parameter(Mandatory=$false)]
    [string]$WishlistPath = "C:\scripts\_machine\tool-wishlist.md"
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  DAILY TOOL REVIEW - End of Session Routine" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Check if wishlist exists
if (-not (Test-Path $WishlistPath)) {
    Write-Host "ERROR: Wishlist not found: $WishlistPath" -ForegroundColor Red
    exit 1
}

# Read wishlist
$wishlistContent = Get-Content $WishlistPath -Raw

# Count items in each priority
$criticalCount = ([regex]::Matches($wishlistContent, "Priority: CRITICAL")).Count
$highCount = ([regex]::Matches($wishlistContent, "Priority: HIGH")).Count
$mediumCount = ([regex]::Matches($wishlistContent, "Priority: MEDIUM")).Count
$lowCount = ([regex]::Matches($wishlistContent, "Priority: LOW")).Count

Write-Host "Current Wishlist Status:" -ForegroundColor Yellow
Write-Host "   CRITICAL: $criticalCount" -ForegroundColor Red
Write-Host "   HIGH: $highCount" -ForegroundColor Yellow
Write-Host "   MEDIUM: $mediumCount" -ForegroundColor Yellow
Write-Host "   LOW: $lowCount" -ForegroundColor Gray
Write-Host ""

# Check for urgent items
if ($criticalCount -gt 0) {
    Write-Host "ACTION REQUIRED: $criticalCount CRITICAL items in wishlist!" -ForegroundColor Red
    Write-Host "   Review and implement top item today." -ForegroundColor Yellow
    Write-Host ""
}

# Analyze PowerShell history for repeated patterns
$historyPath = (Get-PSReadlineOption).HistorySavePath
if (Test-Path $historyPath) {
    Write-Host "Analyzing session history for repeated patterns..." -ForegroundColor Gray

    $history = Get-Content $historyPath -Tail 100 -ErrorAction SilentlyContinue

    if ($history) {
        # Group by command (first word)
        $commandFrequency = $history | ForEach-Object {
            if ($_ -match '^(\S+)') {
                $Matches[1]
            }
        } | Group-Object | Where-Object { $_.Count -ge 3 } | Sort-Object Count -Descending | Select-Object -First 5

        if ($commandFrequency) {
            Write-Host ""
            Write-Host "Repeated Commands Today (3+ times):" -ForegroundColor Yellow
            $commandFrequency | ForEach-Object {
                $cmd = $_.Name
                $count = $_.Count
                Write-Host "   $cmd ($count times)" -ForegroundColor Cyan
            }
            Write-Host ""
        }
    }
}

# Quick wins
Write-Host "Quick Wins (10-minute high-value tools):" -ForegroundColor Green
Write-Host "   From META_OPTIMIZATION_100_TOOLS.md (ratio > 5.0, effort = 1):" -ForegroundColor Gray
Write-Host "   - git-bisect-automation.ps1 (ratio 5.3)" -ForegroundColor Cyan
Write-Host "   - stale-branch-auto-cleanup.ps1 (ratio 7.0)" -ForegroundColor Cyan
Write-Host "   - pr-review-checklist-generator.ps1 (ratio 7.0)" -ForegroundColor Cyan
Write-Host ""

# Recommendations
Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow

if ($criticalCount -eq 0 -and $highCount -eq 0) {
    Write-Host "   No urgent items - great job staying ahead!" -ForegroundColor Green
    Write-Host "   Consider implementing 1-2 MEDIUM priority tools this week" -ForegroundColor Gray
} elseif ($criticalCount -gt 0) {
    Write-Host "   Implement top CRITICAL item before end of day" -ForegroundColor Red
    Write-Host "   Estimated time: 10-30 minutes" -ForegroundColor Gray
} elseif ($highCount -gt 3) {
    Write-Host "   HIGH priority backlog building up ($highCount items)" -ForegroundColor Yellow
    Write-Host "   Consider dedicating 1 hour this week to clear top 3" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Action Items:" -ForegroundColor Cyan
Write-Host "   1. Review wishlist: code $WishlistPath" -ForegroundColor White
Write-Host "   2. Implement top 1 item if ratio > 8.0 or effort = 1" -ForegroundColor White
Write-Host "   3. Move any completed tools to IMPLEMENTED section" -ForegroundColor White
Write-Host "   4. Add any new tool ideas from today" -ForegroundColor White
Write-Host ""

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  Daily review complete - See you tomorrow!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Return summary
[PSCustomObject]@{
    CriticalItems = $criticalCount
    HighItems = $highCount
    MediumItems = $mediumCount
    LowItems = $lowCount
    TotalItems = $criticalCount + $highCount + $mediumCount + $lowCount
    RecommendedAction = if ($criticalCount -gt 0) { "IMPLEMENT_TOP_CRITICAL" }
                        elseif ($highCount -gt 3) { "CLEAR_HIGH_BACKLOG" }
                        else { "MAINTAIN_CURRENT_PACE" }
}
