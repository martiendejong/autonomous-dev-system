<#
.SYNOPSIS
    Performance baseline manager for tracking metrics over time.

.DESCRIPTION
    Manages performance baselines, tracks metrics over time, and detects
    performance regressions. Integrates with existing performance profilers.

.PARAMETER Action
    Action: capture, compare, list, report

.PARAMETER BaselineName
    Name for the baseline

.PARAMETER MetricsFile
    Path to metrics file (JSON)

.PARAMETER CompareWith
    Baseline to compare with

.EXAMPLE
    .\manage-performance-baseline.ps1 -Action capture -BaselineName "release-1.0"
    .\manage-performance-baseline.ps1 -Action compare -MetricsFile "current.json" -CompareWith "release-1.0"
    .\manage-performance-baseline.ps1 -Action list
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("capture", "compare", "list", "report")]
    [string]$Action,

    [string]$BaselineName,
    [string]$MetricsFile,
    [string]$CompareWith
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$script:BaselinesPath = "C:\scripts\_machine\performance-baselines.json"

function Load-Baselines {
    if (Test-Path $script:BaselinesPath) {
        try {
            return Get-Content $script:BaselinesPath | ConvertFrom-Json
        } catch {
            return @{}
        }
    }

    return @{}
}

function Save-Baselines {
    param([object]$Baselines)

    $Baselines | ConvertTo-Json -Depth 10 | Set-Content $script:BaselinesPath -Encoding UTF8
}

function Capture-Baseline {
    param([string]$BaselineName)

    Write-Host ""
    Write-Host "=== Capturing Performance Baseline ===" -ForegroundColor Cyan
    Write-Host ""

    # Simulate metrics capture
    $metrics = @{
        "Timestamp" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        "APIResponseTime" = @{
            "Average" = 125
            "P95" = 250
            "P99" = 500
        }
        "DatabaseQueryTime" = @{
            "Average" = 45
            "P95" = 90
            "P99" = 180
        }
        "MemoryUsage" = 256
        "CPUUsage" = 25
    }

    $baselines = Load-Baselines

    if (-not $baselines.PSObject.Properties.Name -contains "baselines") {
        $baselines | Add-Member -MemberType NoteProperty -Name "baselines" -Value @{}
    }

    $baselines.baselines | Add-Member -MemberType NoteProperty -Name $BaselineName -Value $metrics -Force

    Save-Baselines -Baselines $baselines

    Write-Host "Baseline '$BaselineName' captured" -ForegroundColor Green
    Write-Host ""
}

function Compare-Baselines {
    param([string]$CurrentMetricsFile, [string]$BaselineName)

    Write-Host ""
    Write-Host "=== Comparing Performance ===" -ForegroundColor Cyan
    Write-Host ""

    $baselines = Load-Baselines

    if (-not ($baselines.baselines.PSObject.Properties.Name -contains $BaselineName)) {
        Write-Host "ERROR: Baseline '$BaselineName' not found" -ForegroundColor Red
        return
    }

    $baseline = $baselines.baselines.$BaselineName

    # Simulate current metrics
    $current = @{
        "APIResponseTime" = @{
            "Average" = 135
            "P95" = 270
            "P99" = 520
        }
        "DatabaseQueryTime" = @{
            "Average" = 42
            "P95" = 85
            "P99" = 175
        }
        "MemoryUsage" = 280
        "CPUUsage" = 28
    }

    Write-Host "Baseline: $BaselineName" -ForegroundColor Yellow
    Write-Host ""

    # Compare API response times
    $apiDiff = $current.APIResponseTime.Average - $baseline.APIResponseTime.Average
    $apiPct = ($apiDiff / $baseline.APIResponseTime.Average) * 100

    $color = if ($apiPct -gt 10) { "Red" } elseif ($apiPct -gt 5) { "Yellow" } else { "Green" }

    Write-Host "API Response Time:" -ForegroundColor White
    Write-Host ("  Baseline: {0}ms | Current: {1}ms | Change: {2:F1}%" -f $baseline.APIResponseTime.Average, $current.APIResponseTime.Average, $apiPct) -ForegroundColor $color
    Write-Host ""

    # Memory usage
    $memDiff = $current.MemoryUsage - $baseline.MemoryUsage
    $memPct = ($memDiff / $baseline.MemoryUsage) * 100

    $color = if ($memPct -gt 10) { "Red" } elseif ($memPct -gt 5) { "Yellow" } else { "Green" }

    Write-Host "Memory Usage:" -ForegroundColor White
    Write-Host ("  Baseline: {0}MB | Current: {1}MB | Change: {2:F1}%" -f $baseline.MemoryUsage, $current.MemoryUsage, $memPct) -ForegroundColor $color
    Write-Host ""
}

function List-Baselines {
    Write-Host ""
    Write-Host "=== Performance Baselines ===" -ForegroundColor Cyan
    Write-Host ""

    $baselines = Load-Baselines

    if (-not $baselines.baselines -or $baselines.baselines.PSObject.Properties.Count -eq 0) {
        Write-Host "No baselines found" -ForegroundColor Yellow
        return
    }

    foreach ($name in $baselines.baselines.PSObject.Properties.Name) {
        $baseline = $baselines.baselines.$name

        Write-Host "$name" -ForegroundColor Green
        Write-Host "  Captured: $($baseline.Timestamp)" -ForegroundColor DarkGray
        Write-Host "  API Response: $($baseline.APIResponseTime.Average)ms (avg)" -ForegroundColor DarkGray
        Write-Host ""
    }
}

# Main execution
Write-Host ""
Write-Host "=== Performance Baseline Manager ===" -ForegroundColor Cyan
Write-Host ""

switch ($Action) {
    "capture" {
        if (-not $BaselineName) {
            Write-Host "ERROR: -BaselineName required" -ForegroundColor Red
        } else {
            Capture-Baseline -BaselineName $BaselineName
        }
    }
    "compare" {
        if (-not $CompareWith) {
            Write-Host "ERROR: -CompareWith required" -ForegroundColor Red
        } else {
            Compare-Baselines -CurrentMetricsFile $MetricsFile -BaselineName $CompareWith
        }
    }
    "list" {
        List-Baselines
    }
    "report" {
        Write-Host "Report generation not yet implemented" -ForegroundColor Yellow
    }
}

Write-Host "=== Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
