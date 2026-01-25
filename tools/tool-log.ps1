<#
.SYNOPSIS
    View and manage the tool execution log.

.DESCRIPTION
    Tracks tool executions for debugging and analysis.
    Stores log in _machine/tool-executions.log

.PARAMETER View
    View recent log entries

.PARAMETER Recent
    Number of recent entries to show (default: 20)

.PARAMETER Clear
    Clear the log file

.PARAMETER Stats
    Show execution statistics

.EXAMPLE
    .\tool-log.ps1 -View
    .\tool-log.ps1 -View -Recent 50
    .\tool-log.ps1 -Stats
    .\tool-log.ps1 -Clear
#>

param(
    [switch]$View,
    [int]$Recent = 20,
    [switch]$Clear,
    [switch]$Stats
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$LogPath = "C:\scripts\_machine\tool-executions.log"

function Get-LogEntries {
    if (-not (Test-Path $LogPath)) {
        return @()
    }
    return Get-Content $LogPath | Where-Object { $_ -match '\S' }
}

function Show-View {
    $entries = Get-LogEntries

    if ($entries.Count -eq 0) {
        Write-Host "No log entries found." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "=== TOOL EXECUTION LOG ===" -ForegroundColor Cyan
    Write-Host "Showing last $Recent entries" -ForegroundColor DarkGray
    Write-Host ""

    $entries | Select-Object -Last $Recent | ForEach-Object {
        if ($_ -match '^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \| (\w+) \| (.+)$') {
            $time = $matches[1]
            $status = $matches[2]
            $tool = $matches[3]

            $color = switch ($status) {
                "START" { "Cyan" }
                "END" { "Green" }
                "ERROR" { "Red" }
                default { "White" }
            }

            Write-Host "$time | " -NoNewline -ForegroundColor DarkGray
            Write-Host "$status" -NoNewline -ForegroundColor $color
            Write-Host " | $tool"
        } else {
            Write-Host $_ -ForegroundColor DarkGray
        }
    }

    Write-Host ""
}

function Show-Stats {
    $entries = Get-LogEntries

    if ($entries.Count -eq 0) {
        Write-Host "No log entries found." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "=== TOOL EXECUTION STATS ===" -ForegroundColor Cyan
    Write-Host ""

    # Count by tool
    $toolCounts = @{}
    foreach ($entry in $entries) {
        if ($entry -match '\| START \| (.+)$') {
            $tool = $matches[1]
            if (-not $toolCounts.ContainsKey($tool)) {
                $toolCounts[$tool] = 0
            }
            $toolCounts[$tool]++
        }
    }

    Write-Host "EXECUTIONS BY TOOL:" -ForegroundColor Yellow
    $toolCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor White
    }

    # Count by date
    Write-Host ""
    Write-Host "EXECUTIONS BY DATE (last 7 days):" -ForegroundColor Yellow
    $dateCounts = @{}
    foreach ($entry in $entries) {
        if ($entry -match '^(\d{4}-\d{2}-\d{2})') {
            $date = $matches[1]
            if (-not $dateCounts.ContainsKey($date)) {
                $dateCounts[$date] = 0
            }
            $dateCounts[$date]++
        }
    }
    $dateCounts.GetEnumerator() | Sort-Object Name -Descending | Select-Object -First 7 | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor White
    }

    Write-Host ""
    Write-Host "Total entries: $($entries.Count)" -ForegroundColor DarkGray
    Write-Host ""
}

function Clear-Log {
    if (Test-Path $LogPath) {
        Remove-Item $LogPath -Force
        Write-Host "Log cleared." -ForegroundColor Green
    } else {
        Write-Host "Log file doesn't exist." -ForegroundColor Yellow
    }
}

# Static function to add log entry (called by other tools)
function global:Add-ToolLogEntry {
    param(
        [string]$Tool,
        [ValidateSet("START", "END", "ERROR")]
        [string]$Status,
        [string]$Details = ""
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp | $Status | $Tool"
    if ($Details) { $entry += " | $Details" }

    $entry | Add-Content $LogPath
}

# Main execution
if ($View) {
    Show-View
} elseif ($Stats) {
    Show-Stats
} elseif ($Clear) {
    Clear-Log
} else {
    Show-View
}
