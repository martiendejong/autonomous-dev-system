<#
.SYNOPSIS
    Build Time Tracker
    50-Expert Council V2 Improvement #38 | Priority: 2.33

.DESCRIPTION
    Tracks build times and alerts on regressions.

.PARAMETER Track
    Track a build.

.PARAMETER Project
    Project name.

.PARAMETER Duration
    Build duration in seconds.

.PARAMETER Stats
    Show build statistics.

.PARAMETER Alert
    Alert threshold in seconds.

.EXAMPLE
    build-tracker.ps1 -Track -Project "client-manager" -Duration 45
    build-tracker.ps1 -Stats
#>

param(
    [switch]$Track,
    [string]$Project = "",
    [int]$Duration = 0,
    [switch]$Stats,
    [int]$Alert = 60,
    [switch]$Trends
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$BuildFile = "C:\scripts\_machine\build_times.json"

if (-not (Test-Path $BuildFile)) {
    @{
        builds = @()
        averages = @{}
        alerts = @()
    } | ConvertTo-Json -Depth 10 | Set-Content $BuildFile -Encoding UTF8
}

$data = Get-Content $BuildFile -Raw | ConvertFrom-Json

if ($Track -and $Project -and $Duration -gt 0) {
    # Record build
    $build = @{
        project = $Project
        duration = $Duration
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        date = (Get-Date).ToString("yyyy-MM-dd")
    }

    $data.builds += $build

    # Update average
    $projectBuilds = $data.builds | Where-Object { $_.project -eq $Project }
    $avg = ($projectBuilds | Measure-Object -Property duration -Average).Average

    if (-not $data.averages) { $data.averages = @{} }
    $data.averages | Add-Member -NotePropertyName $Project -NotePropertyValue ([Math]::Round($avg, 1)) -Force

    # Check for regression
    $isRegression = $Duration -gt ($avg * 1.5) -and $Duration -gt $Alert

    $data | ConvertTo-Json -Depth 10 | Set-Content $BuildFile -Encoding UTF8

    Write-Host "✓ Build tracked: $Project = ${Duration}s" -ForegroundColor Green
    Write-Host "  Average: $([Math]::Round($avg, 1))s" -ForegroundColor Gray

    if ($isRegression) {
        Write-Host ""
        Write-Host "⚠️  BUILD REGRESSION DETECTED!" -ForegroundColor Red
        Write-Host "   Duration: ${Duration}s (avg: $([Math]::Round($avg, 1))s)" -ForegroundColor Yellow

        $data.alerts += @{
            project = $Project
            duration = $Duration
            average = $avg
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        $data | ConvertTo-Json -Depth 10 | Set-Content $BuildFile -Encoding UTF8
    }
}
elseif ($Stats) {
    Write-Host "=== BUILD TIME STATISTICS ===" -ForegroundColor Cyan
    Write-Host ""

    if ($data.averages) {
        Write-Host "AVERAGES BY PROJECT:" -ForegroundColor Yellow
        foreach ($p in $data.averages.PSObject.Properties) {
            $color = if ($p.Value -gt $Alert) { "Yellow" } else { "Green" }
            Write-Host "  $($p.Name): $($p.Value)s" -ForegroundColor $color
        }
    }

    Write-Host ""
    Write-Host "RECENT BUILDS:" -ForegroundColor Yellow
    $data.builds | Select-Object -Last 10 | ForEach-Object {
        Write-Host "  $($_.project): $($_.duration)s ($($_.timestamp))" -ForegroundColor Gray
    }

    if ($data.alerts.Count -gt 0) {
        Write-Host ""
        Write-Host "RECENT ALERTS:" -ForegroundColor Red
        $data.alerts | Select-Object -Last 5 | ForEach-Object {
            Write-Host "  ⚠ $($_.project): $($_.duration)s (avg: $($_.average)s)" -ForegroundColor Yellow
        }
    }
}
elseif ($Trends) {
    Write-Host "=== BUILD TIME TRENDS ===" -ForegroundColor Cyan
    Write-Host ""

    $byProject = $data.builds | Group-Object project

    foreach ($group in $byProject) {
        Write-Host "$($group.Name):" -ForegroundColor Yellow

        $recent = $group.Group | Select-Object -Last 7
        foreach ($b in $recent) {
            $bar = "█" * [Math]::Min(30, [Math]::Round($b.duration / 2))
            Write-Host "  $($b.date) [$bar] $($b.duration)s" -ForegroundColor Gray
        }
        Write-Host ""
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Track -Project x -Duration n   Track build" -ForegroundColor White
    Write-Host "  -Stats                          Show statistics" -ForegroundColor White
    Write-Host "  -Trends                         Show trends" -ForegroundColor White
    Write-Host "  -Alert n                        Alert threshold" -ForegroundColor White
}
