<#
.SYNOPSIS
    Real-time API performance monitoring with endpoint tracking.

.DESCRIPTION
    Monitors API endpoints for response times, error rates, and usage patterns.
    Tracks performance trends and detects regressions.

    Features:
    - Response time tracking (min, max, avg, p50, p95, p99)
    - Error rate monitoring (4xx, 5xx)
    - Endpoint usage statistics
    - Performance regression detection
    - Real-time monitoring dashboard
    - Historical trend analysis
    - Alert thresholds

.PARAMETER BaseUrl
    Base URL of API to monitor

.PARAMETER Duration
    Monitoring duration in seconds (default: 60)

.PARAMETER Endpoints
    Specific endpoints to monitor (default: auto-discover from Swagger)

.PARAMETER Threshold
    Response time threshold in milliseconds (default: 500)

.PARAMETER SaveResults
    Save monitoring results to trends file

.PARAMETER CompareBaseline
    Compare against baseline and detect regressions

.EXAMPLE
    .\monitor-api-performance.ps1 -BaseUrl "https://localhost:7001" -Duration 60
    .\monitor-api-performance.ps1 -BaseUrl "https://localhost:7001" -Endpoints "/api/users,/api/projects"
    .\monitor-api-performance.ps1 -BaseUrl "https://localhost:7001" -SaveResults -CompareBaseline
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BaseUrl,

    [int]$Duration = 60,
    [string[]]$Endpoints,
    [int]$Threshold = 500,
    [switch]$SaveResults,
    [switch]$CompareBaseline
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$TrendFile = "C:/scripts/_machine/api-performance-trends.json"
$BaselineFile = "C:/scripts/_machine/api-performance-baseline.json"

$script:Metrics = @{}

function Get-SwaggerEndpoints {
    param([string]$BaseUrl)

    Write-Host "Auto-discovering endpoints from Swagger..." -ForegroundColor Cyan

    $swaggerUrls = @(
        "$BaseUrl/swagger/v1/swagger.json",
        "$BaseUrl/swagger/swagger.json"
    )

    foreach ($url in $swaggerUrls) {
        try {
            $response = Invoke-RestMethod -Uri $url -TimeoutSec 5 -ErrorAction Stop

            $endpoints = @()

            foreach ($path in $response.paths.PSObject.Properties) {
                foreach ($method in $path.Value.PSObject.Properties.Name) {
                    $endpoints += @{
                        "Method" = $method.ToUpper()
                        "Path" = $path.Name
                    }
                }
            }

            Write-Host "  Found $($endpoints.Count) endpoints" -ForegroundColor Green
            return $endpoints

        } catch {
            continue
        }
    }

    Write-Host "  Could not fetch Swagger spec" -ForegroundColor Yellow
    return @()
}

function Test-Endpoint {
    param([string]$BaseUrl, [string]$Method, [string]$Path)

    $url = "$BaseUrl$Path"

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $response = Invoke-WebRequest -Uri $url -Method $Method -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop

        $stopwatch.Stop()

        return @{
            "Success" = $true
            "StatusCode" = $response.StatusCode
            "ResponseTime" = $stopwatch.ElapsedMilliseconds
        }

    } catch {
        $stopwatch.Stop()

        $statusCode = if ($_.Exception.Response) {
            [int]$_.Exception.Response.StatusCode
        } else {
            0
        }

        return @{
            "Success" = $false
            "StatusCode" = $statusCode
            "ResponseTime" = $stopwatch.ElapsedMilliseconds
        }
    }
}

function Monitor-Endpoints {
    param([string]$BaseUrl, [array]$Endpoints, [int]$Duration)

    Write-Host ""
    Write-Host "=== Monitoring API Performance ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Duration: $Duration seconds" -ForegroundColor White
    Write-Host "Endpoints: $($Endpoints.Count)" -ForegroundColor White
    Write-Host ""

    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($Duration)

    # Initialize metrics
    foreach ($endpoint in $Endpoints) {
        $key = "$($endpoint.Method) $($endpoint.Path)"

        $script:Metrics[$key] = @{
            "Method" = $endpoint.Method
            "Path" = $endpoint.Path
            "Requests" = @()
            "Errors" = 0
            "Total" = 0
        }
    }

    # Monitor loop
    $iteration = 0

    while ((Get-Date) -lt $endTime) {
        $iteration++

        foreach ($endpoint in $Endpoints) {
            $key = "$($endpoint.Method) $($endpoint.Path)"

            $result = Test-Endpoint -BaseUrl $BaseUrl -Method $endpoint.Method -Path $endpoint.Path

            $script:Metrics[$key].Total++
            $script:Metrics[$key].Requests += $result.ResponseTime

            if (-not $result.Success -or $result.StatusCode -ge 400) {
                $script:Metrics[$key].Errors++
            }
        }

        # Progress update every 10 iterations
        if ($iteration % 10 -eq 0) {
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            $remaining = ($endTime - (Get-Date)).TotalSeconds

            Write-Host ("`rElapsed: {0:F0}s | Remaining: {1:F0}s" -f $elapsed, $remaining) -NoNewline -ForegroundColor DarkGray
        }

        Start-Sleep -Milliseconds 500
    }

    Write-Host ""
    Write-Host ""
}

function Calculate-Statistics {
    param([array]$ResponseTimes)

    if ($ResponseTimes.Count -eq 0) {
        return @{
            "Min" = 0
            "Max" = 0
            "Avg" = 0
            "P50" = 0
            "P95" = 0
            "P99" = 0
        }
    }

    $sorted = $ResponseTimes | Sort-Object

    $p50Index = [math]::Floor($sorted.Count * 0.50)
    $p95Index = [math]::Floor($sorted.Count * 0.95)
    $p99Index = [math]::Floor($sorted.Count * 0.99)

    return @{
        "Min" = $sorted[0]
        "Max" = $sorted[-1]
        "Avg" = [math]::Round(($ResponseTimes | Measure-Object -Average).Average, 2)
        "P50" = $sorted[$p50Index]
        "P95" = $sorted[$p95Index]
        "P99" = $sorted[$p99Index]
    }
}

function Show-Results {
    param([hashtable]$Metrics, [int]$Threshold)

    Write-Host "=== Performance Results ===" -ForegroundColor Cyan
    Write-Host ""

    foreach ($key in $Metrics.Keys | Sort-Object) {
        $metric = $Metrics[$key]
        $stats = Calculate-Statistics -ResponseTimes $metric.Requests

        $errorRate = if ($metric.Total -gt 0) {
            [math]::Round(($metric.Errors / $metric.Total) * 100, 2)
        } else {
            0
        }

        # Color based on performance
        $color = if ($stats.Avg -le $Threshold -and $errorRate -eq 0) {
            "Green"
        } elseif ($stats.Avg -le ($Threshold * 2) -and $errorRate -lt 5) {
            "Yellow"
        } else {
            "Red"
        }

        Write-Host "$key" -ForegroundColor White
        Write-Host ("  Requests: {0}" -f $metric.Total) -ForegroundColor DarkGray
        Write-Host ("  Errors:   {0} ({1}%)" -f $metric.Errors, $errorRate) -ForegroundColor $(if ($errorRate -eq 0) { "Green" } else { "Red" })
        Write-Host ("  Avg:      {0} ms" -f $stats.Avg) -ForegroundColor $color
        Write-Host ("  Min:      {0} ms" -f $stats.Min) -ForegroundColor DarkGray
        Write-Host ("  Max:      {0} ms" -f $stats.Max) -ForegroundColor DarkGray
        Write-Host ("  P50:      {0} ms" -f $stats.P50) -ForegroundColor DarkGray
        Write-Host ("  P95:      {0} ms" -f $stats.P95) -ForegroundColor DarkGray
        Write-Host ("  P99:      {0} ms" -f $stats.P99) -ForegroundColor DarkGray
        Write-Host ""
    }

    # Overall summary
    $allRequests = ($Metrics.Values | ForEach-Object { $_.Total }) | Measure-Object -Sum
    $allErrors = ($Metrics.Values | ForEach-Object { $_.Errors }) | Measure-Object -Sum
    $overallErrorRate = if ($allRequests.Sum -gt 0) {
        [math]::Round(($allErrors.Sum / $allRequests.Sum) * 100, 2)
    } else {
        0
    }

    Write-Host "=== Overall Summary ===" -ForegroundColor Cyan
    Write-Host ("  Total Requests: {0}" -f $allRequests.Sum) -ForegroundColor White
    Write-Host ("  Total Errors:   {0} ({1}%)" -f $allErrors.Sum, $overallErrorRate) -ForegroundColor $(if ($overallErrorRate -eq 0) { "Green" } else { "Red" })
    Write-Host ""
}

function Save-Trends {
    param([hashtable]$Metrics, [string]$BaseUrl)

    $trends = if (Test-Path $TrendFile) {
        Get-Content $TrendFile | ConvertFrom-Json
    } else {
        @()
    }

    $entry = @{
        "Timestamp" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        "BaseUrl" = $BaseUrl
        "Endpoints" = @{}
    }

    foreach ($key in $Metrics.Keys) {
        $metric = $Metrics[$key]
        $stats = Calculate-Statistics -ResponseTimes $metric.Requests

        $entry.Endpoints[$key] = @{
            "Total" = $metric.Total
            "Errors" = $metric.Errors
            "Avg" = $stats.Avg
            "P95" = $stats.P95
        }
    }

    $trends += $entry

    # Keep last 100 entries
    $trends = $trends | Select-Object -Last 100

    $trends | ConvertTo-Json -Depth 10 | Set-Content $TrendFile -Encoding UTF8

    Write-Host "Performance trends saved" -ForegroundColor Green
    Write-Host ""
}

function Compare-ToBaseline {
    param([hashtable]$Metrics)

    if (-not (Test-Path $BaselineFile)) {
        Write-Host ""
        Write-Host "No baseline found. Run with -SaveResults to set one." -ForegroundColor Yellow
        Write-Host ""
        return
    }

    $baseline = Get-Content $BaselineFile | ConvertFrom-Json

    Write-Host ""
    Write-Host "=== Regression Analysis ===" -ForegroundColor Cyan
    Write-Host ""

    $regressions = @()

    foreach ($key in $Metrics.Keys) {
        if ($baseline.Endpoints.$key) {
            $current = Calculate-Statistics -ResponseTimes $Metrics[$key].Requests
            $baselineAvg = $baseline.Endpoints.$key.Avg

            $diff = $current.Avg - $baselineAvg
            $pctChange = if ($baselineAvg -gt 0) {
                [math]::Round(($diff / $baselineAvg) * 100, 1)
            } else {
                0
            }

            if ($pctChange -gt 20) {
                $regressions += "$key is $pctChange% slower (was $($baselineAvg)ms, now $($current.Avg)ms)"
            }
        }
    }

    if ($regressions.Count -gt 0) {
        Write-Host "REGRESSIONS DETECTED:" -ForegroundColor Red
        Write-Host ""

        foreach ($regression in $regressions) {
            Write-Host "  - $regression" -ForegroundColor Yellow
        }

        Write-Host ""
    } else {
        Write-Host "No significant regressions detected!" -ForegroundColor Green
        Write-Host ""
    }
}

function Save-Baseline {
    param([hashtable]$Metrics, [string]$BaseUrl)

    $baseline = @{
        "Timestamp" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        "BaseUrl" = $BaseUrl
        "Endpoints" = @{}
    }

    foreach ($key in $Metrics.Keys) {
        $metric = $Metrics[$key]
        $stats = Calculate-Statistics -ResponseTimes $metric.Requests

        $baseline.Endpoints[$key] = @{
            "Avg" = $stats.Avg
            "P95" = $stats.P95
        }
    }

    $baseline | ConvertTo-Json -Depth 10 | Set-Content $BaselineFile -Encoding UTF8

    Write-Host "Baseline saved!" -ForegroundColor Green
    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== API Performance Monitor ===" -ForegroundColor Cyan
Write-Host ""

# Determine endpoints to monitor
$endpointsToMonitor = if ($Endpoints) {
    $Endpoints | ForEach-Object {
        @{
            "Method" = "GET"
            "Path" = $_
        }
    }
} else {
    Get-SwaggerEndpoints -BaseUrl $BaseUrl
}

if ($endpointsToMonitor.Count -eq 0) {
    Write-Host "ERROR: No endpoints to monitor" -ForegroundColor Red
    Write-Host "Specify -Endpoints or ensure Swagger is available" -ForegroundColor Yellow
    exit 1
}

# Monitor endpoints
Monitor-Endpoints -BaseUrl $BaseUrl -Endpoints $endpointsToMonitor -Duration $Duration

# Show results
Show-Results -Metrics $script:Metrics -Threshold $Threshold

# Save results if requested
if ($SaveResults) {
    Save-Trends -Metrics $script:Metrics -BaseUrl $BaseUrl
    Save-Baseline -Metrics $script:Metrics -BaseUrl $BaseUrl
}

# Compare to baseline if requested
if ($CompareBaseline) {
    Compare-ToBaseline -Metrics $script:Metrics
}

Write-Host "=== Monitoring Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
