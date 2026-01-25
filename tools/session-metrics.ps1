<#
.SYNOPSIS
    Track and display session metrics for Claude Agent.

.DESCRIPTION
    Tracks session duration, actions taken, and estimates costs.
    Stores metrics in _machine/session-metrics.json.

.PARAMETER Start
    Start a new session timer

.PARAMETER End
    End current session and calculate metrics

.PARAMETER Show
    Show current session or historical metrics

.PARAMETER History
    Show last N sessions

.EXAMPLE
    .\session-metrics.ps1 -Start
    .\session-metrics.ps1 -End
    .\session-metrics.ps1 -Show
    .\session-metrics.ps1 -History 10
#>

param(
    [switch]$Start,
    [switch]$End,
    [switch]$Show,
    [int]$History = 0
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$MetricsPath = "C:\scripts\_machine\session-metrics.json"
$CurrentSessionPath = "C:\scripts\_machine\current-session.json"

function Get-Metrics {
    if (Test-Path $MetricsPath) {
        return Get-Content $MetricsPath -Raw | ConvertFrom-Json
    }
    return @{
        sessions = @()
        totals = @{
            sessionCount = 0
            totalDuration = 0
            totalToolsCreated = 0
            totalDocsCreated = 0
        }
    }
}

function Save-Metrics {
    param($Metrics)
    $Metrics | ConvertTo-Json -Depth 5 | Set-Content $MetricsPath -Encoding UTF8
}

function Start-Session {
    $session = @{
        id = (Get-Date).ToString("yyyyMMddHHmmss")
        startTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        endTime = $null
        duration = $null
        toolsCreated = 0
        docsCreated = 0
        commitsCreated = 0
        notes = ""
    }

    $session | ConvertTo-Json | Set-Content $CurrentSessionPath -Encoding UTF8

    Write-Host ""
    Write-Host "=== SESSION STARTED ===" -ForegroundColor Green
    Write-Host "ID: $($session.id)"
    Write-Host "Start: $($session.startTime)"
    Write-Host ""
    Write-Host "Remember to run: .\session-metrics.ps1 -End" -ForegroundColor Yellow
    Write-Host ""
}

function End-Session {
    if (-not (Test-Path $CurrentSessionPath)) {
        Write-Host "ERROR: No active session found. Start with -Start first." -ForegroundColor Red
        return
    }

    $session = Get-Content $CurrentSessionPath -Raw | ConvertFrom-Json
    $session.endTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")

    $start = [DateTime]::Parse($session.startTime)
    $end = [DateTime]::Parse($session.endTime)
    $duration = ($end - $start).TotalMinutes
    $session.duration = [Math]::Round($duration, 1)

    # Try to count what was created (simplified)
    $recentCommits = git -C "C:\scripts" log --since="$($session.startTime)" --oneline 2>$null
    if ($recentCommits) {
        $session.commitsCreated = ($recentCommits -split "`n").Count
    }

    # Add to metrics
    $metrics = Get-Metrics
    $metrics.sessions += $session
    $metrics.totals.sessionCount++
    $metrics.totals.totalDuration += $session.duration

    Save-Metrics -Metrics $metrics
    Remove-Item $CurrentSessionPath -Force

    Write-Host ""
    Write-Host "=== SESSION ENDED ===" -ForegroundColor Green
    Write-Host "ID: $($session.id)"
    Write-Host "Duration: $($session.duration) minutes"
    Write-Host "Commits: $($session.commitsCreated)"
    Write-Host ""
}

function Show-Current {
    Write-Host ""
    Write-Host "=== SESSION METRICS ===" -ForegroundColor Cyan

    if (Test-Path $CurrentSessionPath) {
        $session = Get-Content $CurrentSessionPath -Raw | ConvertFrom-Json
        $start = [DateTime]::Parse($session.startTime)
        $elapsed = ((Get-Date) - $start).TotalMinutes

        Write-Host ""
        Write-Host "CURRENT SESSION:" -ForegroundColor Yellow
        Write-Host "  ID: $($session.id)"
        Write-Host "  Started: $($session.startTime)"
        Write-Host "  Elapsed: $([Math]::Round($elapsed, 1)) minutes"
    } else {
        Write-Host ""
        Write-Host "No active session." -ForegroundColor DarkGray
    }

    $metrics = Get-Metrics
    Write-Host ""
    Write-Host "TOTALS:" -ForegroundColor Yellow
    Write-Host "  Sessions: $($metrics.totals.sessionCount)"
    Write-Host "  Total Duration: $([Math]::Round($metrics.totals.totalDuration, 1)) minutes"

    if ($metrics.totals.sessionCount -gt 0) {
        $avgDuration = $metrics.totals.totalDuration / $metrics.totals.sessionCount
        Write-Host "  Average Duration: $([Math]::Round($avgDuration, 1)) minutes"
    }

    Write-Host ""
}

function Show-History {
    param([int]$Count)

    $metrics = Get-Metrics

    if ($metrics.sessions.Count -eq 0) {
        Write-Host "No session history." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "=== SESSION HISTORY (last $Count) ===" -ForegroundColor Cyan
    Write-Host ""

    $recent = $metrics.sessions | Select-Object -Last $Count

    foreach ($session in $recent) {
        Write-Host "$($session.id) | $($session.startTime) | $($session.duration) min | $($session.commitsCreated) commits" -ForegroundColor DarkGray
    }

    Write-Host ""
}

# Main execution
if ($Start) {
    Start-Session
} elseif ($End) {
    End-Session
} elseif ($History -gt 0) {
    Show-History -Count $History
} else {
    Show-Current
}
