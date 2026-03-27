<#
.SYNOPSIS
    Service health monitor with endpoint checking and alerting.

.DESCRIPTION
    Monitors service health endpoints, tracks uptime, and sends alerts
    on failures. Supports multiple endpoints and health check patterns.

.PARAMETER Endpoints
    Comma-separated list of health check URLs

.PARAMETER Interval
    Check interval in seconds (default: 60)

.PARAMETER Duration
    Monitor duration in minutes (default: infinite)

.PARAMETER AlertOnFailure
    Send alert on failure

.EXAMPLE
    .\monitor-service-health.ps1 -Endpoints "https://api.example.com/health,https://app.example.com/health"
    .\monitor-service-health.ps1 -Endpoints "https://localhost:5001/health" -Interval 30 -Duration 60
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Endpoints,

    [int]$Interval = 60,
    [int]$Duration = 0,
    [switch]$AlertOnFailure
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$script:Results = @()

function Check-HealthEndpoint {
    param([string]$Url)

    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 10
        $stopwatch.Stop()

        return @{
            "Url" = $Url
            "Status" = "Healthy"
            "StatusCode" = $response.StatusCode
            "ResponseTime" = $stopwatch.ElapsedMilliseconds
            "Timestamp" = Get-Date
        }

    } catch {
        $stopwatch.Stop()

        return @{
            "Url" = $Url
            "Status" = "Unhealthy"
            "StatusCode" = 0
            "ResponseTime" = $stopwatch.ElapsedMilliseconds
            "Error" = $_.Exception.Message
            "Timestamp" = Get-Date
        }
    }
}

# Main execution
Write-Host ""
Write-Host "=== Service Health Monitor ===" -ForegroundColor Cyan
Write-Host ""

$endpointList = $Endpoints -split ',' | ForEach-Object { $_.Trim() }

Write-Host "Monitoring endpoints:" -ForegroundColor Yellow
foreach ($endpoint in $endpointList) {
    Write-Host "  - $endpoint" -ForegroundColor White
}
Write-Host ""
Write-Host "Check interval: ${Interval}s" -ForegroundColor White
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

$startTime = Get-Date
$endTime = if ($Duration -gt 0) { $startTime.AddMinutes($Duration) } else { [DateTime]::MaxValue }

while ((Get-Date) -lt $endTime) {
    foreach ($endpoint in $endpointList) {
        $result = Check-HealthEndpoint -Url $endpoint
        $script:Results += $result

        $statusColor = if ($result.Status -eq "Healthy") { "Green" } else { "Red" }
        $timestamp = $result.Timestamp.ToString("HH:mm:ss")

        Write-Host ("[$timestamp] {0,-50} {1,10} ({2}ms)" -f $endpoint, $result.Status, $result.ResponseTime) -ForegroundColor $statusColor

        if ($result.Status -eq "Unhealthy" -and $AlertOnFailure) {
            Write-Host "  ALERT: $($result.Error)" -ForegroundColor Red
        }
    }

    Start-Sleep -Seconds $Interval
}

Write-Host ""
Write-Host "=== Monitoring Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
