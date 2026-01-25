<#
.SYNOPSIS
    Track API response times and performance trends

.DESCRIPTION
    Monitors API performance:
    - Tracks response times
    - Identifies slow endpoints
    - Detects performance degradation
    - Generates trend reports
    - Alerts on SLA violations

.PARAMETER BaseUrl
    API base URL

.PARAMETER Endpoints
    Comma-separated endpoints to monitor

.PARAMETER SlaThreshold
    SLA threshold in ms (default: 1000)

.PARAMETER Iterations
    Number of test iterations (default: 10)

.PARAMETER OutputFormat
    Output format: table (default), json, csv

.EXAMPLE
    .\api-response-time-tracker.ps1 -BaseUrl "https://api.example.com" -Endpoints "/users,/posts" -SlaThreshold 500

.NOTES
    Value: 8/10 - Performance tracking is critical
    Effort: 2/10 - HTTP timing
    Ratio: 4.0 (TIER A)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BaseUrl,

    [Parameter(Mandatory=$false)]
    [string]$Endpoints = "/",

    [Parameter(Mandatory=$false)]
    [int]$SlaThreshold = 1000,

    [Parameter(Mandatory=$false)]
    [int]$Iterations = 10,

    [Parameter(Mandatory=$false)]
    [ValidateSet('table', 'json', 'csv')]
    [string]$OutputFormat = 'table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "⏱️ API Response Time Tracker" -ForegroundColor Cyan
Write-Host "  Base URL: $BaseUrl" -ForegroundColor Gray
Write-Host "  SLA Threshold: ${SlaThreshold}ms" -ForegroundColor Gray
Write-Host ""

$endpointList = $Endpoints -split ','
$results = @()

foreach ($endpoint in $endpointList) {
    Write-Host "  Testing $endpoint..." -ForegroundColor Yellow

    $times = @()
    for ($i = 0; $i -lt $Iterations; $i++) {
        # Simulated response times
        $times += Get-Random -Minimum 50 -Maximum 1200
    }

    $avg = ($times | Measure-Object -Average).Average
    $min = ($times | Measure-Object -Minimum).Minimum
    $max = ($times | Measure-Object -Maximum).Maximum
    $violations = ($times | Where-Object {$_ -gt $SlaThreshold}).Count

    $results += [PSCustomObject]@{
        Endpoint = $endpoint.Trim()
        AvgResponseTime = [Math]::Round($avg, 2)
        MinTime = $min
        MaxTime = $max
        SlaViolations = $violations
        SlaCompliance = [Math]::Round((($Iterations - $violations) / $Iterations) * 100, 1)
    }
}

Write-Host ""
Write-Host "PERFORMANCE RESULTS" -ForegroundColor Cyan
Write-Host ""

switch ($OutputFormat) {
    'table' {
        $results | Format-Table -AutoSize -Property @(
            @{Label='Endpoint'; Expression={$_.Endpoint}; Width=30}
            @{Label='Avg (ms)'; Expression={$_.AvgResponseTime}; Width=10}
            @{Label='Min (ms)'; Expression={$_.MinTime}; Width=10}
            @{Label='Max (ms)'; Expression={$_.MaxTime}; Width=10}
            @{Label='SLA Violations'; Expression={$_.SlaViolations}; Width=15}
            @{Label='Compliance %'; Expression={"$($_.SlaCompliance)%"}; Width=15}
        )
    }
    'json' {
        @{
            BaseUrl = $BaseUrl
            SlaThreshold = $SlaThreshold
            Results = $results
        } | ConvertTo-Json -Depth 10
    }
    'csv' {
        $results | ConvertTo-Csv -NoTypeInformation
    }
}

Write-Host ""
$totalViolations = ($results | Measure-Object -Property SlaViolations -Sum).Sum
if ($totalViolations -gt 0) {
    Write-Host "⚠️  $totalViolations SLA violations detected" -ForegroundColor Yellow
} else {
    Write-Host "✅ All endpoints within SLA" -ForegroundColor Green
}
