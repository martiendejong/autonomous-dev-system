<#
.SYNOPSIS
    Proactive Check-ins, Energy-Aware & Stress Detection
    50-Expert Council Improvements #44, #45, #48 | Priority: 2.67, 1.4, 2.25

.DESCRIPTION
    Monitors work patterns and proactively offers help:
    - Suggests breaks after long sessions
    - Detects stress patterns
    - Energy-aware task suggestions

.PARAMETER Check
    Run a proactive check based on current state.

.PARAMETER LogWork
    Log work duration for a task.

.PARAMETER Duration
    Duration in minutes.

.PARAMETER Stress
    Enable stress reduction mode.

.EXAMPLE
    proactive-check.ps1 -Check
    proactive-check.ps1 -LogWork -Duration 120
#>

param(
    [switch]$Check,
    [switch]$LogWork,
    [int]$Duration = 0,
    [switch]$Stress
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$WorkLogFile = "C:\scripts\_machine\work_log.json"

if (-not (Test-Path $WorkLogFile)) {
    @{
        sessions = @()
        currentSession = @{
            start = $null
            tasks = @()
        }
        totalMinutes = 0
        stressMode = $false
    } | ConvertTo-Json -Depth 10 | Set-Content $WorkLogFile -Encoding UTF8
}

$log = Get-Content $WorkLogFile -Raw | ConvertFrom-Json

if ($Check) {
    Write-Host "=== PROACTIVE CHECK-IN ===" -ForegroundColor Cyan
    Write-Host ""

    $sentiment = Get-Content "C:\scripts\_machine\sentiment_history.json" -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json

    # Check for signs of stress
    $stressIndicators = 0

    if ($sentiment -and $sentiment.patterns.frustrationCount -gt 3) {
        $stressIndicators++
        Write-Host "⚠ Multiple frustration signals detected" -ForegroundColor Yellow
    }

    if ($log.totalMinutes -gt 180) {
        $stressIndicators++
        Write-Host "⚠ Long work session ($($log.totalMinutes) minutes)" -ForegroundColor Yellow
    }

    Write-Host ""

    if ($stressIndicators -ge 2) {
        Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║  STRESS REDUCTION MODE RECOMMENDED     ║" -ForegroundColor Red
        Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Host "Suggestions:" -ForegroundColor Yellow
        Write-Host "  1. Take a 10-minute break" -ForegroundColor White
        Write-Host "  2. Switch to a simpler task" -ForegroundColor White
        Write-Host "  3. Let Claude handle routine work autonomously" -ForegroundColor White
        Write-Host ""
        Write-Host "Enable stress mode: proactive-check.ps1 -Stress" -ForegroundColor Gray
    } elseif ($log.totalMinutes -gt 60) {
        Write-Host "You've been working for $($log.totalMinutes) minutes." -ForegroundColor Yellow
        Write-Host "Consider a short break to maintain productivity." -ForegroundColor White
    } else {
        Write-Host "✓ Work patterns look healthy" -ForegroundColor Green
        Write-Host "  Session time: $($log.totalMinutes) minutes" -ForegroundColor Gray
    }

    # Task suggestions based on energy
    $hour = (Get-Date).Hour
    Write-Host ""
    Write-Host "ENERGY-AWARE SUGGESTIONS:" -ForegroundColor Magenta

    if ($hour -ge 9 -and $hour -le 11) {
        Write-Host "  Morning peak: Good time for complex/creative work" -ForegroundColor Green
    } elseif ($hour -ge 14 -and $hour -le 15) {
        Write-Host "  Post-lunch dip: Consider routine tasks or short break" -ForegroundColor Yellow
    } elseif ($hour -ge 16 -and $hour -le 18) {
        Write-Host "  Afternoon recovery: Good for reviews and planning" -ForegroundColor Green
    } elseif ($hour -ge 21) {
        Write-Host "  Late evening: Consider wrapping up soon" -ForegroundColor Yellow
    }
}
elseif ($LogWork -and $Duration -gt 0) {
    $log.totalMinutes += $Duration
    $log.currentSession.tasks += @{
        duration = $Duration
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    $log | ConvertTo-Json -Depth 10 | Set-Content $WorkLogFile -Encoding UTF8

    Write-Host "✓ Logged $Duration minutes of work" -ForegroundColor Green
    Write-Host "  Total session: $($log.totalMinutes) minutes" -ForegroundColor Gray
}
elseif ($Stress) {
    $log.stressMode = $true
    $log | ConvertTo-Json -Depth 10 | Set-Content $WorkLogFile -Encoding UTF8

    Write-Host "=== STRESS REDUCTION MODE ENABLED ===" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Claude will now:" -ForegroundColor Yellow
    Write-Host "  • Give shorter, simpler responses" -ForegroundColor White
    Write-Host "  • Handle more tasks autonomously" -ForegroundColor White
    Write-Host "  • Avoid asking unnecessary questions" -ForegroundColor White
    Write-Host "  • Suggest breaks more frequently" -ForegroundColor White
}
else {
    Write-Host "Usage: proactive-check.ps1 -Check" -ForegroundColor Yellow
}
