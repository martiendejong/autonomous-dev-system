<#
.SYNOPSIS
    Goal Alignment Verification - Ensure current work matches stated goals.
    Expert: Jordan Peterson + Ray Dalio

.DESCRIPTION
    Implements 50-Expert Council Improvement #46.
    Regularly verify current work aligns with stated goals.
    Prevents drift and rabbit holes.

.PARAMETER CurrentTask
    What you're currently doing.

.PARAMETER SessionGoal
    The session's stated goal.

.PARAMETER Check
    Quick alignment check (returns true/false).

.EXAMPLE
    align.ps1 -CurrentTask "Writing tests" -SessionGoal "Add auth feature"

.EXAMPLE
    align.ps1 -Check
#>

param(
    [string]$CurrentTask = "",
    [string]$SessionGoal = "",
    [switch]$Check
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║           GOAL ALIGNMENT VERIFICATION                        ║" -ForegroundColor Green
Write-Host "║           (50-Expert Council #46)                            ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

if ($Check) {
    Write-Host "QUICK ALIGNMENT CHECK:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Ask yourself:" -ForegroundColor White
    Write-Host "    → What was I asked to do?" -ForegroundColor Cyan
    Write-Host "    → What am I actually doing?" -ForegroundColor Cyan
    Write-Host "    → Are these the same thing?" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  If different: STOP and realign." -ForegroundColor Red
    Write-Host ""
    return
}

# Alignment matrix
Write-Host "ALIGNMENT ANALYSIS:" -ForegroundColor Yellow
Write-Host ""

if ($CurrentTask -and $SessionGoal) {
    Write-Host "  SESSION GOAL:   $SessionGoal" -ForegroundColor Cyan
    Write-Host "  CURRENT TASK:   $CurrentTask" -ForegroundColor Cyan
    Write-Host ""

    # Simple alignment check
    $goalWords = $SessionGoal.ToLower() -split '\s+'
    $taskWords = $CurrentTask.ToLower() -split '\s+'
    $overlap = ($goalWords | Where-Object { $taskWords -contains $_ }).Count
    $alignmentScore = [math]::Round(($overlap / $goalWords.Count) * 100)

    Write-Host "  ALIGNMENT SCORE: $alignmentScore%" -ForegroundColor $(if ($alignmentScore -ge 50) { "Green" } else { "Red" })
    Write-Host ""

    if ($alignmentScore -lt 50) {
        Write-Host "  ⚠️  LOW ALIGNMENT DETECTED" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Consider:" -ForegroundColor Yellow
        Write-Host "    1. Is this task necessary for the goal?" -ForegroundColor White
        Write-Host "    2. Am I in a rabbit hole?" -ForegroundColor White
        Write-Host "    3. Should I stop and refocus?" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host "  ✓ Alignment looks good. Continue." -ForegroundColor Green
        Write-Host ""
    }
}

# Show alignment principles
Write-Host "ALIGNMENT PRINCIPLES (Ray Dalio):" -ForegroundColor Magenta
Write-Host ""
Write-Host "  1. Goals determine tasks, not the reverse" -ForegroundColor White
Write-Host "  2. If you can't explain how task serves goal, stop" -ForegroundColor White
Write-Host "  3. Interesting ≠ Important" -ForegroundColor White
Write-Host "  4. Check alignment every 15 minutes of work" -ForegroundColor White
Write-Host ""

# Show HP's preferences
Write-Host "HP'S ALIGNMENT PREFERENCES:" -ForegroundColor Magenta
Write-Host ""
Write-Host "  ✓ Direct path to goal (no scenic routes)" -ForegroundColor White
Write-Host "  ✓ Pragmatic solutions (not elegant over-engineering)" -ForegroundColor White
Write-Host "  ✓ Working software > perfect architecture" -ForegroundColor White
Write-Host "  ✓ Ask if unsure, don't assume" -ForegroundColor White
Write-Host ""
