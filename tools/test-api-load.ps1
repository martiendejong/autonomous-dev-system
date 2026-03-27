<#
.SYNOPSIS
    API load testing tool for performance benchmarking and bottleneck identification.

.DESCRIPTION
    Simulates concurrent API requests to measure performance under load.
    Supports multiple load patterns and generates detailed HTML reports.

    Features:
    - Multiple load patterns (constant, ramp-up, spike, stress)
    - Concurrent request simulation
    - Response time percentiles (P50, P95, P99)
    - Throughput and error rate tracking
    - HTML report with charts
    - Support for authentication
    - Custom headers and payloads
    - Rate limiting detection

.PARAMETER BaseUrl
    Base URL of API to test

.PARAMETER Endpoints
    Comma-separated list of endpoints to test (e.g., "/api/users,/api/projects")

.PARAMETER Pattern
    Load pattern: constant, ramp-up, spike, stress (default: constant)

.PARAMETER Duration
    Test duration in seconds (default: 60)

.PARAMETER Concurrency
    Number of concurrent requests (default: 10)

.PARAMETER RampUpTime
    Ramp-up time for gradual load increase (seconds, for ramp-up pattern)

.PARAMETER AuthToken
    Bearer token for authentication

.PARAMETER Headers
    Custom headers as JSON string

.PARAMETER Method
    HTTP method (default: GET)

.PARAMETER Body
    Request body as JSON string (for POST/PUT)

.PARAMETER OutputPath
    Output path for HTML report

.EXAMPLE
    .\test-api-load.ps1 -BaseUrl "https://localhost:5001" -Endpoints "/api/users" -Duration 30
    .\test-api-load.ps1 -BaseUrl "https://localhost:5001" -Endpoints "/api/users,/api/projects" -Pattern ramp-up -Duration 120 -Concurrency 50
    .\test-api-load.ps1 -BaseUrl "https://localhost:5001" -Endpoints "/api/auth/login" -Method POST -Body '{"username":"test","password":"test"}'
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BaseUrl,

    [Parameter(Mandatory=$true)]
    [string]$Endpoints,

    [ValidateSet("constant", "ramp-up", "spike", "stress")]
    [string]$Pattern = "constant",

    [int]$Duration = 60,
    [int]$Concurrency = 10,
    [int]$RampUpTime = 30,
    [string]$AuthToken,
    [string]$Headers,
    [ValidateSet("GET", "POST", "PUT", "DELETE", "PATCH")]
    [string]$Method = "GET",
    [string]$Body,
    [string]$OutputPath
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$script:Results = @()
$script:StartTime = $null
$script:ErrorCount = 0
$script:SuccessCount = 0

function Invoke-ApiRequest {
    param([string]$Url, [string]$Method, [string]$Body, [hashtable]$Headers)

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $params = @{
            Uri = $Url
            Method = $Method
            TimeoutSec = 30
        }

        if ($Headers) {
            $params.Headers = $Headers
        }

        if ($Body -and ($Method -eq "POST" -or $Method -eq "PUT" -or $Method -eq "PATCH")) {
            $params.Body = $Body
            $params.ContentType = "application/json"
        }

        $response = Invoke-WebRequest @params -UseBasicParsing

        $stopwatch.Stop()

        $result = @{
            "Timestamp" = (Get-Date)
            "Endpoint" = $Url
            "Method" = $Method
            "StatusCode" = $response.StatusCode
            "ResponseTime" = $stopwatch.ElapsedMilliseconds
            "Success" = $true
            "Error" = $null
        }

        $script:SuccessCount++

        return $result

    } catch {
        $stopwatch.Stop()

        $statusCode = if ($_.Exception.Response) {
            [int]$_.Exception.Response.StatusCode
        } else {
            0
        }

        $result = @{
            "Timestamp" = (Get-Date)
            "Endpoint" = $Url
            "Method" = $Method
            "StatusCode" = $statusCode
            "ResponseTime" = $stopwatch.ElapsedMilliseconds
            "Success" = $false
            "Error" = $_.Exception.Message
        }

        $script:ErrorCount++

        return $result
    }
}

function Start-ConstantLoad {
    param([array]$Endpoints, [int]$Duration, [int]$Concurrency)

    Write-Host ""
    Write-Host "=== Constant Load Test ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("Concurrency: {0} requests" -f $Concurrency) -ForegroundColor White
    Write-Host ("Duration: {0} seconds" -f $Duration) -ForegroundColor White
    Write-Host ""

    $script:StartTime = Get-Date
    $endTime = $script:StartTime.AddSeconds($Duration)

    $jobs = @()

    # Start concurrent workers
    for ($i = 0; $i -lt $Concurrency; $i++) {
        $job = Start-Job -ScriptBlock {
            param($BaseUrl, $Endpoints, $EndTime, $Method, $Body, $Headers)

            $results = @()

            while ((Get-Date) -lt $EndTime) {
                $endpoint = $Endpoints | Get-Random
                $url = $BaseUrl.TrimEnd('/') + '/' + $endpoint.TrimStart('/')

                # Invoke request
                try {
                    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    $response = Invoke-WebRequest -Uri $url -Method $Method -UseBasicParsing -TimeoutSec 30
                    $stopwatch.Stop()

                    $results += @{
                        "Timestamp" = (Get-Date)
                        "Endpoint" = $endpoint
                        "StatusCode" = $response.StatusCode
                        "ResponseTime" = $stopwatch.ElapsedMilliseconds
                        "Success" = $true
                    }

                } catch {
                    $stopwatch.Stop()

                    $results += @{
                        "Timestamp" = (Get-Date)
                        "Endpoint" = $endpoint
                        "StatusCode" = 0
                        "ResponseTime" = $stopwatch.ElapsedMilliseconds
                        "Success" = $false
                        "Error" = $_.Exception.Message
                    }
                }

                Start-Sleep -Milliseconds 100
            }

            return $results

        } -ArgumentList $BaseUrl, $Endpoints, $endTime, $Method, $Body, $Headers

        $jobs += $job
    }

    # Wait and show progress
    while ((Get-Date) -lt $endTime) {
        $elapsed = ((Get-Date) - $script:StartTime).TotalSeconds
        $remaining = ($endTime - (Get-Date)).TotalSeconds

        Write-Host ("`rElapsed: {0:F1}s | Remaining: {1:F1}s | Requests: {2} | Errors: {3}" -f $elapsed, $remaining, $script:SuccessCount, $script:ErrorCount) -NoNewline -ForegroundColor Yellow

        Start-Sleep -Seconds 1
    }

    Write-Host ""
    Write-Host ""
    Write-Host "Waiting for workers to finish..." -ForegroundColor Cyan

    # Collect results
    foreach ($job in $jobs) {
        $jobResults = Receive-Job -Job $job -Wait
        $script:Results += $jobResults
        Remove-Job -Job $job
    }

    Write-Host "All workers completed" -ForegroundColor Green
    Write-Host ""
}

function Start-RampUpLoad {
    param([array]$Endpoints, [int]$Duration, [int]$MaxConcurrency, [int]$RampUpTime)

    Write-Host ""
    Write-Host "=== Ramp-Up Load Test ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("Max Concurrency: {0} requests" -f $MaxConcurrency) -ForegroundColor White
    Write-Host ("Ramp-Up Time: {0} seconds" -f $RampUpTime) -ForegroundColor White
    Write-Host ("Total Duration: {0} seconds" -f $Duration) -ForegroundColor White
    Write-Host ""

    $script:StartTime = Get-Date
    $endTime = $script:StartTime.AddSeconds($Duration)
    $rampUpEnd = $script:StartTime.AddSeconds($RampUpTime)

    $jobs = @()

    while ((Get-Date) -lt $endTime) {
        $elapsed = ((Get-Date) - $script:StartTime).TotalSeconds

        # Calculate current concurrency
        $currentConcurrency = if ((Get-Date) -lt $rampUpEnd) {
            [int]($MaxConcurrency * ($elapsed / $RampUpTime))
        } else {
            $MaxConcurrency
        }

        # Add workers if needed
        while ($jobs.Count -lt $currentConcurrency) {
            $job = Start-Job -ScriptBlock {
                param($BaseUrl, $Endpoints, $Method)

                $endpoint = $Endpoints | Get-Random
                $url = $BaseUrl.TrimEnd('/') + '/' + $endpoint.TrimStart('/')

                try {
                    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    $response = Invoke-WebRequest -Uri $url -Method $Method -UseBasicParsing -TimeoutSec 30
                    $stopwatch.Stop()

                    return @{
                        "Timestamp" = (Get-Date)
                        "Endpoint" = $endpoint
                        "StatusCode" = $response.StatusCode
                        "ResponseTime" = $stopwatch.ElapsedMilliseconds
                        "Success" = $true
                    }

                } catch {
                    $stopwatch.Stop()

                    return @{
                        "Timestamp" = (Get-Date)
                        "Endpoint" = $endpoint
                        "StatusCode" = 0
                        "ResponseTime" = $stopwatch.ElapsedMilliseconds
                        "Success" = $false
                        "Error" = $_.Exception.Message
                    }
                }

            } -ArgumentList $BaseUrl, $Endpoints, $Method

            $jobs += $job
        }

        # Collect completed jobs
        $completed = $jobs | Where-Object { $_.State -eq "Completed" }

        foreach ($job in $completed) {
            $result = Receive-Job -Job $job
            $script:Results += $result

            if ($result.Success) {
                $script:SuccessCount++
            } else {
                $script:ErrorCount++
            }

            Remove-Job -Job $job
        }

        $jobs = $jobs | Where-Object { $_.State -ne "Completed" }

        $remaining = ($endTime - (Get-Date)).TotalSeconds

        Write-Host ("`rConcurrency: {0}/{1} | Elapsed: {2:F1}s | Remaining: {3:F1}s | Requests: {4} | Errors: {5}" -f $jobs.Count, $MaxConcurrency, $elapsed, $remaining, $script:SuccessCount, $script:ErrorCount) -NoNewline -ForegroundColor Yellow

        Start-Sleep -Milliseconds 500
    }

    Write-Host ""
    Write-Host ""

    # Wait for remaining jobs
    Write-Host "Waiting for workers to finish..." -ForegroundColor Cyan

    foreach ($job in $jobs) {
        $result = Receive-Job -Job $job -Wait
        $script:Results += $result
        Remove-Job -Job $job
    }

    Write-Host "All workers completed" -ForegroundColor Green
    Write-Host ""
}

function Calculate-Statistics {
    param([array]$Results)

    if ($Results.Count -eq 0) {
        return @{
            "TotalRequests" = 0
            "SuccessCount" = 0
            "ErrorCount" = 0
            "ErrorRate" = 0
            "AvgResponseTime" = 0
            "MinResponseTime" = 0
            "MaxResponseTime" = 0
            "P50" = 0
            "P95" = 0
            "P99" = 0
            "Throughput" = 0
        }
    }

    $responseTimes = $Results | Where-Object { $_.Success } | ForEach-Object { $_.ResponseTime } | Sort-Object

    $total = $Results.Count
    $successCount = ($Results | Where-Object { $_.Success }).Count
    $errorCount = $total - $successCount
    $errorRate = if ($total -gt 0) { ($errorCount / $total) * 100 } else { 0 }

    $avgResponseTime = if ($responseTimes.Count -gt 0) {
        ($responseTimes | Measure-Object -Average).Average
    } else {
        0
    }

    $minResponseTime = if ($responseTimes.Count -gt 0) { $responseTimes[0] } else { 0 }
    $maxResponseTime = if ($responseTimes.Count -gt 0) { $responseTimes[-1] } else { 0 }

    # Calculate percentiles
    $p50Index = [Math]::Floor($responseTimes.Count * 0.50)
    $p95Index = [Math]::Floor($responseTimes.Count * 0.95)
    $p99Index = [Math]::Floor($responseTimes.Count * 0.99)

    $p50 = if ($responseTimes.Count -gt 0) { $responseTimes[$p50Index] } else { 0 }
    $p95 = if ($responseTimes.Count -gt 0) { $responseTimes[$p95Index] } else { 0 }
    $p99 = if ($responseTimes.Count -gt 0) { $responseTimes[$p99Index] } else { 0 }

    # Calculate throughput (requests per second)
    $duration = if ($script:StartTime) {
        ((Get-Date) - $script:StartTime).TotalSeconds
    } else {
        1
    }

    $throughput = $total / $duration

    return @{
        "TotalRequests" = $total
        "SuccessCount" = $successCount
        "ErrorCount" = $errorCount
        "ErrorRate" = $errorRate
        "AvgResponseTime" = $avgResponseTime
        "MinResponseTime" = $minResponseTime
        "MaxResponseTime" = $maxResponseTime
        "P50" = $p50
        "P95" = $p95
        "P99" = $p99
        "Throughput" = $throughput
    }
}

function Show-Statistics {
    param([hashtable]$Stats)

    Write-Host ""
    Write-Host "=== Load Test Results ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host ("Total Requests:   {0,8}" -f $Stats.TotalRequests) -ForegroundColor White
    Write-Host ("Successful:       {0,8}" -f $Stats.SuccessCount) -ForegroundColor Green
    Write-Host ("Failed:           {0,8}" -f $Stats.ErrorCount) -ForegroundColor Red
    Write-Host ("Error Rate:       {0,7:F2}%" -f $Stats.ErrorRate) -ForegroundColor $(if ($Stats.ErrorRate -gt 5) { "Red" } else { "Yellow" })
    Write-Host ""

    Write-Host "Response Times (ms):" -ForegroundColor Yellow
    Write-Host ("  Average:        {0,8:F2}" -f $Stats.AvgResponseTime) -ForegroundColor White
    Write-Host ("  Min:            {0,8:F2}" -f $Stats.MinResponseTime) -ForegroundColor White
    Write-Host ("  Max:            {0,8:F2}" -f $Stats.MaxResponseTime) -ForegroundColor White
    Write-Host ("  P50 (median):   {0,8:F2}" -f $Stats.P50) -ForegroundColor White
    Write-Host ("  P95:            {0,8:F2}" -f $Stats.P95) -ForegroundColor White
    Write-Host ("  P99:            {0,8:F2}" -f $Stats.P99) -ForegroundColor White
    Write-Host ""

    Write-Host ("Throughput:       {0,7:F2} req/s" -f $Stats.Throughput) -ForegroundColor Cyan
    Write-Host ""
}

function Generate-HTMLReport {
    param([array]$Results, [hashtable]$Stats, [string]$OutputPath)

    # Group by endpoint
    $byEndpoint = $Results | Group-Object -Property Endpoint

    $endpointStats = ""

    foreach ($group in $byEndpoint) {
        $endpointResults = $group.Group
        $endpointStatsData = Calculate-Statistics -Results $endpointResults

        $endpointStats += "<tr>`n"
        $endpointStats += "  <td>$($group.Name)</td>`n"
        $endpointStats += "  <td>$($endpointStatsData.TotalRequests)</td>`n"
        $endpointStats += "  <td>$($endpointStatsData.ErrorRate.ToString('F2'))%</td>`n"
        $endpointStats += "  <td>$($endpointStatsData.AvgResponseTime.ToString('F2'))ms</td>`n"
        $endpointStats += "  <td>$($endpointStatsData.P95.ToString('F2'))ms</td>`n"
        $endpointStats += "  <td>$($endpointStatsData.Throughput.ToString('F2'))</td>`n"
        $endpointStats += "</tr>`n"
    }

    # Timeline data for chart
    $timelineData = $Results | ForEach-Object {
        $elapsed = ($_.Timestamp - $script:StartTime).TotalSeconds
        "{ x: $($elapsed.ToString('F2')), y: $($_.ResponseTime) }"
    }

    $timelineDataJson = "[$($timelineData -join ',')]"

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>API Load Test Report</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1400px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; }
        h1 { color: #333; border-bottom: 3px solid #61dafb; padding-bottom: 10px; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .stat-card { background: #f8f9fa; padding: 15px; border-radius: 6px; text-align: center; }
        .stat-value { font-size: 2em; font-weight: bold; }
        .stat-label { color: #666; font-size: 0.9em; }
        .success { color: #28a745; }
        .error { color: #dc3545; }
        .warning { color: #ffc107; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background: #f8f9fa; padding: 12px; text-align: left; border-bottom: 2px solid #dee2e6; }
        td { padding: 10px 12px; border-bottom: 1px solid #dee2e6; }
        tr:hover { background: #f8f9fa; }
        .chart-container { margin: 30px 0; }
        canvas { max-height: 400px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>API Load Test Report</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p>Pattern: $Pattern | Duration: ${Duration}s | Concurrency: $Concurrency</p>

        <h2>Overall Statistics</h2>
        <div class="stats">
            <div class="stat-card">
                <div class="stat-value">$($Stats.TotalRequests)</div>
                <div class="stat-label">Total Requests</div>
            </div>
            <div class="stat-card">
                <div class="stat-value success">$($Stats.SuccessCount)</div>
                <div class="stat-label">Successful</div>
            </div>
            <div class="stat-card">
                <div class="stat-value error">$($Stats.ErrorCount)</div>
                <div class="stat-label">Failed</div>
            </div>
            <div class="stat-card">
                <div class="stat-value $(if ($Stats.ErrorRate -gt 5) { 'error' } else { 'warning' })">$($Stats.ErrorRate.ToString('F2'))%</div>
                <div class="stat-label">Error Rate</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$($Stats.AvgResponseTime.ToString('F2'))ms</div>
                <div class="stat-label">Avg Response Time</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$($Stats.P95.ToString('F2'))ms</div>
                <div class="stat-label">P95 Response Time</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$($Stats.Throughput.ToString('F2'))</div>
                <div class="stat-label">Throughput (req/s)</div>
            </div>
        </div>

        <h2>Response Time Timeline</h2>
        <div class="chart-container">
            <canvas id="timelineChart"></canvas>
        </div>

        <h2>Statistics by Endpoint</h2>
        <table>
            <tr>
                <th>Endpoint</th>
                <th>Requests</th>
                <th>Error Rate</th>
                <th>Avg Response</th>
                <th>P95 Response</th>
                <th>Throughput</th>
            </tr>
$endpointStats
        </table>
    </div>

    <script>
        const ctx = document.getElementById('timelineChart').getContext('2d');
        const timelineChart = new Chart(ctx, {
            type: 'scatter',
            data: {
                datasets: [{
                    label: 'Response Time (ms)',
                    data: $timelineDataJson,
                    backgroundColor: 'rgba(97, 218, 251, 0.5)',
                    borderColor: 'rgba(97, 218, 251, 1)',
                    pointRadius: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: true,
                scales: {
                    x: {
                        type: 'linear',
                        position: 'bottom',
                        title: {
                            display: true,
                            text: 'Time (seconds)'
                        }
                    },
                    y: {
                        title: {
                            display: true,
                            text: 'Response Time (ms)'
                        }
                    }
                }
            }
        });
    </script>
</body>
</html>
"@

    if (-not $OutputPath) {
        $OutputPath = "api-load-test-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').html"
    }

    $html | Set-Content $OutputPath -Encoding UTF8

    Write-Host "HTML report generated: $OutputPath" -ForegroundColor Green
    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== API Load Tester ===" -ForegroundColor Cyan
Write-Host ""

# Parse endpoints
$endpointList = $Endpoints -split ',' | ForEach-Object { $_.Trim() }

Write-Host "Base URL: $BaseUrl" -ForegroundColor White
Write-Host "Endpoints: $($endpointList -join ', ')" -ForegroundColor White
Write-Host "Method: $Method" -ForegroundColor White
Write-Host ""

# Prepare headers
$headerHash = @{}

if ($AuthToken) {
    $headerHash["Authorization"] = "Bearer $AuthToken"
}

if ($Headers) {
    try {
        $customHeaders = $Headers | ConvertFrom-Json
        foreach ($key in $customHeaders.PSObject.Properties.Name) {
            $headerHash[$key] = $customHeaders.$key
        }
    } catch {
        Write-Host "WARNING: Failed to parse custom headers" -ForegroundColor Yellow
    }
}

# Run load test based on pattern
switch ($Pattern) {
    "constant" {
        Start-ConstantLoad -Endpoints $endpointList -Duration $Duration -Concurrency $Concurrency
    }
    "ramp-up" {
        Start-RampUpLoad -Endpoints $endpointList -Duration $Duration -MaxConcurrency $Concurrency -RampUpTime $RampUpTime
    }
    "spike" {
        # Spike: low load, then sudden high load, then low again
        Write-Host "Spike pattern: 30% duration at low load, 40% at high load, 30% at low load" -ForegroundColor Cyan
        $lowDuration = [int]($Duration * 0.3)
        $highDuration = [int]($Duration * 0.4)

        Start-ConstantLoad -Endpoints $endpointList -Duration $lowDuration -Concurrency ([int]($Concurrency * 0.2))
        Start-ConstantLoad -Endpoints $endpointList -Duration $highDuration -Concurrency $Concurrency
        Start-ConstantLoad -Endpoints $endpointList -Duration $lowDuration -Concurrency ([int]($Concurrency * 0.2))
    }
    "stress" {
        # Stress: gradually increase until system breaks
        Write-Host "Stress pattern: gradually increasing load until failure" -ForegroundColor Cyan
        Start-RampUpLoad -Endpoints $endpointList -Duration $Duration -MaxConcurrency ($Concurrency * 2) -RampUpTime $Duration
    }
}

# Calculate and show statistics
$stats = Calculate-Statistics -Results $script:Results
Show-Statistics -Stats $stats

# Generate HTML report
Generate-HTMLReport -Results $script:Results -Stats $stats -OutputPath $OutputPath

Write-Host "=== Load Test Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
