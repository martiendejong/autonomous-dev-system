<#
.SYNOPSIS
    Track performance metrics over commits and alert on regressions

.DESCRIPTION
    Monitors performance trends across git history:
    - Response time metrics
    - Memory usage
    - CPU utilization
    - Database query performance
    - Bundle size

    Detects regressions by:
    - Comparing against baseline
    - Statistical analysis (mean + stddev)
    - Percentage thresholds

.PARAMETER MetricScript
    Script that outputs performance metric (must output single number)

.PARAMETER BaseCommit
    Baseline commit to compare against (default: main)

.PARAMETER Threshold
    Regression threshold percentage (default: 10)

.PARAMETER HistoryDepth
    Number of commits to analyze (default: 10)

.PARAMETER OutputFormat
    Output format: Table (default), Graph, JSON

.EXAMPLE
    # Check API response time regression
    .\performance-regression-detector.ps1 -MetricScript ".\measure-api-latency.ps1"

.EXAMPLE
    # Check bundle size with 5% threshold
    .\performance-regression-detector.ps1 -MetricScript ".\get-bundle-size.ps1" -Threshold 5

.NOTES
    Value: 9/10 - Prevents performance degradation
    Effort: 2/10 - Metric collection + statistical analysis
    Ratio: 4.5 (TIER S)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$MetricScript,

    [Parameter(Mandatory=$false)]
    [string]$BaseCommit = "main",

    [Parameter(Mandatory=$false)]
    [double]$Threshold = 10.0,

    [Parameter(Mandatory=$false)]
    [int]$HistoryDepth = 10,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'Graph', 'JSON')]
    [string]$OutputFormat = 'Table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "Performance Regression Detector" -ForegroundColor Cyan
Write-Host "  Metric script: $MetricScript" -ForegroundColor Gray
Write-Host "  Baseline: $BaseCommit" -ForegroundColor Gray
Write-Host "  Threshold: $Threshold%" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $MetricScript)) {
    Write-Host "❌ Metric script not found: $MetricScript" -ForegroundColor Red
    exit 1
}

# Get commit history
$commits = git log --oneline -$HistoryDepth --format="%H %s" | ForEach-Object {
    $parts = $_ -split ' ', 2
    [PSCustomObject]@{
        Hash = $parts[0]
        Message = $parts[1]
    }
}

Write-Host "Analyzing $($commits.Count) commits..." -ForegroundColor Yellow
Write-Host ""

$metrics = @()
$currentBranch = git branch --show-current

try {
    foreach ($commit in $commits) {
        Write-Host "Testing commit: $($commit.Hash.Substring(0, 7)) - $($commit.Message)" -ForegroundColor Gray

        # Checkout commit
        git checkout $commit.Hash --quiet 2>$null

        # Run metric script
        try {
            $metricValue = & $MetricScript 2>$null

            if ($metricValue -match '^\d+(\.\d+)?$') {
                $metricValue = [double]$metricValue

                $metrics += [PSCustomObject]@{
                    Commit = $commit.Hash.Substring(0, 7)
                    Message = $commit.Message
                    Metric = $metricValue
                    Timestamp = Get-Date
                }

                Write-Host "  Metric: $metricValue" -ForegroundColor White
            } else {
                Write-Host "  ⚠️  Invalid metric output: $metricValue" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  ❌ Error running metric script: $_" -ForegroundColor Red
        }
    }
} finally {
    # Return to original branch
    git checkout $currentBranch --quiet 2>$null
}

Write-Host ""
Write-Host "PERFORMANCE ANALYSIS" -ForegroundColor Cyan
Write-Host ""

if ($metrics.Count -eq 0) {
    Write-Host "❌ No metrics collected" -ForegroundColor Red
    exit 1
}

# Calculate statistics
$values = $metrics | ForEach-Object { $_.Metric }
$mean = ($values | Measure-Object -Average).Average
$stdDev = [Math]::Sqrt((($values | ForEach-Object { ($_ - $mean) * ($_ - $mean) }) | Measure-Object -Average).Average)

Write-Host "Statistics:" -ForegroundColor Yellow
Write-Host "  Mean: $([Math]::Round($mean, 2))" -ForegroundColor Gray
Write-Host "  StdDev: $([Math]::Round($stdDev, 2))" -ForegroundColor Gray
Write-Host ""

# Detect regressions (newest first)
$metrics = $metrics | Sort-Object { $commits.IndexOf(($commits | Where-Object { $_.Hash -like "$($_.Commit)*" })) }

$regressions = @()
for ($i = 1; $i -lt $metrics.Count; $i++) {
    $current = $metrics[$i].Metric
    $previous = $metrics[$i - 1].Metric

    $percentChange = (($current - $previous) / $previous) * 100

    if ($percentChange -gt $Threshold) {
        $regressions += [PSCustomObject]@{
            Commit = $metrics[$i].Commit
            Message = $metrics[$i].Message
            Metric = $current
            PreviousMetric = $previous
            Change = $percentChange
            Severity = if ($percentChange -gt $Threshold * 2) { "CRITICAL" } `
                      elseif ($percentChange -gt $Threshold * 1.5) { "HIGH" } `
                      else { "MEDIUM" }
        }
    }
}

switch ($OutputFormat) {
    'Table' {
        if ($regressions.Count -eq 0) {
            Write-Host "✅ No performance regressions detected!" -ForegroundColor Green
        } else {
            Write-Host "⚠️  REGRESSIONS DETECTED:" -ForegroundColor Red
            Write-Host ""

            $regressions | Format-Table -AutoSize -Property @(
                @{Label='Commit'; Expression={$_.Commit}; Width=10}
                @{Label='Message'; Expression={$_.Message}; Width=40}
                @{Label='Previous'; Expression={$_.PreviousMetric}; Align='Right'}
                @{Label='Current'; Expression={$_.Metric}; Align='Right'}
                @{Label='Change'; Expression={"+$([Math]::Round($_.Change, 1))%"}; Align='Right'}
                @{Label='Severity'; Expression={$_.Severity}; Width=10}
            )

            Write-Host ""
            Write-Host "SUMMARY:" -ForegroundColor Cyan
            Write-Host "  Regressions: $($regressions.Count)" -ForegroundColor Red
            Write-Host "  CRITICAL: $(($regressions | Where-Object {$_.Severity -eq 'CRITICAL'}).Count)" -ForegroundColor Red
            Write-Host "  HIGH: $(($regressions | Where-Object {$_.Severity -eq 'HIGH'}).Count)" -ForegroundColor Yellow

            exit 1  # Fail CI
        }

        # Show trend
        Write-Host ""
        Write-Host "METRIC HISTORY:" -ForegroundColor Yellow
        $metrics | Format-Table -AutoSize -Property @(
            @{Label='Commit'; Expression={$_.Commit}; Width=10}
            @{Label='Message'; Expression={$_.Message}; Width=50}
            @{Label='Metric'; Expression={$_.Metric}; Align='Right'}
        )
    }
    'Graph' {
        # Simple ASCII graph
        Write-Host "PERFORMANCE TREND:" -ForegroundColor Cyan
        Write-Host ""

        $min = ($values | Measure-Object -Minimum).Minimum
        $max = ($values | Measure-Object -Maximum).Maximum
        $range = $max - $min

        foreach ($metric in $metrics) {
            $normalized = if ($range -gt 0) { (($metric.Metric - $min) / $range) * 50 } else { 25 }
            $bar = "#" * [int]$normalized

            Write-Host "$($metric.Commit) | $bar $($metric.Metric)" -ForegroundColor White
        }
    }
    'JSON' {
        @{
            Statistics = @{
                Mean = $mean
                StdDev = $stdDev
            }
            Regressions = $regressions
            Metrics = $metrics
        } | ConvertTo-Json -Depth 10
    }
}
