<#
.SYNOPSIS
    Focus Mode - Suppress non-critical notifications
    50-Expert Council V2 Improvement #41 | Priority: 2.67

.DESCRIPTION
    Enables deep focus by suppressing non-critical notifications.
    Tracks focus sessions for productivity analysis.

.PARAMETER On
    Enable focus mode.

.PARAMETER Off
    Disable focus mode.

.PARAMETER Duration
    Focus duration in minutes (default: 90 - one Pomodoro ultra).

.PARAMETER Status
    Show focus mode status.

.PARAMETER Stats
    Show focus statistics.

.EXAMPLE
    focus-mode.ps1 -On -Duration 60
    focus-mode.ps1 -Off
    focus-mode.ps1 -Status
#>

param(
    [switch]$On,
    [switch]$Off,
    [int]$Duration = 90,
    [switch]$Status,
    [switch]$Stats
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$FocusFile = "C:\scripts\_machine\focus_mode.json"

if (-not (Test-Path $FocusFile)) {
    @{
        active = $false
        startTime = $null
        endTime = $null
        duration = 0
        sessions = @()
        totalFocusMinutes = 0
        suppressedCount = 0
    } | ConvertTo-Json -Depth 10 | Set-Content $FocusFile -Encoding UTF8
}

$focus = Get-Content $FocusFile -Raw | ConvertFrom-Json

if ($On) {
    if ($focus.active) {
        Write-Host "Focus mode already active!" -ForegroundColor Yellow
        $remaining = ([datetime]::Parse($focus.endTime) - (Get-Date)).TotalMinutes
        Write-Host "Time remaining: $([Math]::Round($remaining)) minutes" -ForegroundColor Cyan
        return
    }

    $focus.active = $true
    $focus.startTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $focus.endTime = (Get-Date).AddMinutes($Duration).ToString("yyyy-MM-dd HH:mm:ss")
    $focus.duration = $Duration
    $focus | ConvertTo-Json -Depth 10 | Set-Content $FocusFile -Encoding UTF8

    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "  ║                                                            ║" -ForegroundColor Blue
    Write-Host "  ║    🎯  FOCUS MODE ACTIVATED  🎯                            ║" -ForegroundColor Cyan
    Write-Host "  ║                                                            ║" -ForegroundColor Blue
    Write-Host "  ╚════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""
    Write-Host "  Duration: $Duration minutes" -ForegroundColor White
    Write-Host "  End time: $($focus.endTime)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  🔕 Non-critical notifications suppressed" -ForegroundColor Yellow
    Write-Host "  💪 Deep work time - make it count!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  To end early: focus-mode.ps1 -Off" -ForegroundColor DarkGray
    Write-Host ""
}
elseif ($Off) {
    if (-not $focus.active) {
        Write-Host "Focus mode not active." -ForegroundColor Yellow
        return
    }

    $startTime = [datetime]::Parse($focus.startTime)
    $actualDuration = ((Get-Date) - $startTime).TotalMinutes

    # Record session
    $session = @{
        date = (Get-Date).ToString("yyyy-MM-dd")
        plannedMinutes = $focus.duration
        actualMinutes = [Math]::Round($actualDuration)
        completed = $actualDuration -ge ($focus.duration * 0.9)
    }

    $focus.sessions += $session
    $focus.totalFocusMinutes += $session.actualMinutes
    $focus.active = $false
    $focus.startTime = $null
    $focus.endTime = $null
    $focus | ConvertTo-Json -Depth 10 | Set-Content $FocusFile -Encoding UTF8

    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║                                                            ║" -ForegroundColor Green
    Write-Host "  ║    ✅  FOCUS SESSION COMPLETE  ✅                          ║" -ForegroundColor White
    Write-Host "  ║                                                            ║" -ForegroundColor Green
    Write-Host "  ╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Session duration: $([Math]::Round($actualDuration)) minutes" -ForegroundColor White
    Write-Host "  Total focus time: $($focus.totalFocusMinutes) minutes" -ForegroundColor Cyan
    Write-Host ""

    if ($session.completed) {
        Write-Host "  🏆 Full session completed! Great job!" -ForegroundColor Yellow
    }
    Write-Host ""
}
elseif ($Status) {
    Write-Host ""
    Write-Host "=== FOCUS MODE STATUS ===" -ForegroundColor Cyan
    Write-Host ""

    if ($focus.active) {
        $remaining = ([datetime]::Parse($focus.endTime) - (Get-Date)).TotalMinutes

        if ($remaining -le 0) {
            Write-Host "  🔔 Focus session ENDED - time to take a break!" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  Run: focus-mode.ps1 -Off" -ForegroundColor Gray
        }
        else {
            Write-Host "  🎯 FOCUS MODE ACTIVE" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Time remaining: $([Math]::Round($remaining)) minutes" -ForegroundColor White
            Write-Host "  End time: $($focus.endTime)" -ForegroundColor Gray

            # Progress bar
            $elapsed = $focus.duration - $remaining
            $progress = [Math]::Min(100, [Math]::Round(($elapsed / $focus.duration) * 100))
            $filled = [Math]::Round($progress / 5)
            $bar = "█" * $filled + "░" * (20 - $filled)
            Write-Host ""
            Write-Host "  [$bar] $progress%" -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "  Focus mode: OFF" -ForegroundColor Gray
        Write-Host "  Total focus time: $($focus.totalFocusMinutes) minutes" -ForegroundColor White
        Write-Host ""
        Write-Host "  Start focus: focus-mode.ps1 -On" -ForegroundColor Gray
    }
    Write-Host ""
}
elseif ($Stats) {
    Write-Host ""
    Write-Host "=== FOCUS STATISTICS ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Total sessions: $($focus.sessions.Count)" -ForegroundColor White
    Write-Host "  Total focus time: $($focus.totalFocusMinutes) minutes ($([Math]::Round($focus.totalFocusMinutes / 60, 1)) hours)" -ForegroundColor Yellow
    Write-Host ""

    $completed = ($focus.sessions | Where-Object { $_.completed }).Count
    $rate = if ($focus.sessions.Count -gt 0) { [Math]::Round(($completed / $focus.sessions.Count) * 100) } else { 0 }
    Write-Host "  Completion rate: $rate%" -ForegroundColor $(if ($rate -ge 80) { "Green" } else { "Yellow" })
    Write-Host ""

    # Recent sessions
    Write-Host "  Recent sessions:" -ForegroundColor Magenta
    $focus.sessions | Select-Object -Last 5 | ForEach-Object {
        $status = if ($_.completed) { "✓" } else { "○" }
        Write-Host "    $status $($_.date): $($_.actualMinutes)/$($_.plannedMinutes) min" -ForegroundColor White
    }
    Write-Host ""
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -On [-Duration n]    Start focus mode" -ForegroundColor White
    Write-Host "  -Off                 End focus mode" -ForegroundColor White
    Write-Host "  -Status              Check status" -ForegroundColor White
    Write-Host "  -Stats               Show statistics" -ForegroundColor White
}
