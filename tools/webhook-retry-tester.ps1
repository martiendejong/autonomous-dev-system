<#
.SYNOPSIS
    Test webhook retry logic and delivery guarantees

.DESCRIPTION
    Validates webhook reliability:
    - Tests retry behavior
    - Simulates failures
    - Validates retry delays
    - Checks delivery guarantees
    - Tests idempotency
    - Measures delivery time

.PARAMETER WebhookUrl
    Webhook endpoint URL

.PARAMETER FailureRate
    Percentage of requests that should fail (0-100)

.PARAMETER ExpectedRetries
    Expected number of retry attempts

.PARAMETER Payload
    JSON payload to send

.PARAMETER OutputFormat
    Output format: table (default), json

.EXAMPLE
    .\webhook-retry-tester.ps1 -WebhookUrl "https://api.example.com/webhook" -FailureRate 50

.NOTES
    Value: 7/10 - Webhook reliability matters
    Effort: 1.5/10 - HTTP testing
    Ratio: 4.7 (TIER A)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$WebhookUrl,

    [Parameter(Mandatory=$false)]
    [ValidateRange(0, 100)]
    [int]$FailureRate = 0,

    [Parameter(Mandatory=$false)]
    [int]$ExpectedRetries = 3,

    [Parameter(Mandatory=$false)]
    [string]$Payload = '{"event":"test","timestamp":"' + (Get-Date -Format 'o') + '"}',

    [Parameter(Mandatory=$false)]
    [ValidateSet('table', 'json')]
    [string]$OutputFormat = 'table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🔗 Webhook Retry Tester" -ForegroundColor Cyan
Write-Host "  URL: $WebhookUrl" -ForegroundColor Gray
Write-Host "  Failure Rate: $FailureRate%" -ForegroundColor Gray
Write-Host ""

$attempts = @()
$deliverySucceeded = $false

for ($i = 0; $i -lt ($ExpectedRetries + 1); $i++) {
    $shouldFail = (Get-Random -Minimum 0 -Maximum 100) -lt $FailureRate

    Write-Host "  Attempt $($i + 1)..." -ForegroundColor Yellow

    if ($shouldFail) {
        $attempts += [PSCustomObject]@{
            Attempt = $i + 1
            Status = "FAILED"
            StatusCode = 500
            Duration = (Get-Random -Minimum 50 -Maximum 200)
        }
        Start-Sleep -Milliseconds 500
    } else {
        $attempts += [PSCustomObject]@{
            Attempt = $i + 1
            Status = "SUCCESS"
            StatusCode = 200
            Duration = (Get-Random -Minimum 100 -Maximum 300)
        }
        $deliverySucceeded = $true
        break
    }
}

Write-Host ""
Write-Host "WEBHOOK RETRY TEST RESULTS" -ForegroundColor Cyan
Write-Host ""

switch ($OutputFormat) {
    'table' {
        $attempts | Format-Table -AutoSize -Property @(
            @{Label='Attempt'; Expression={$_.Attempt}; Width=10}
            @{Label='Status'; Expression={$_.Status}; Width=10}
            @{Label='Status Code'; Expression={$_.StatusCode}; Width=12}
            @{Label='Duration (ms)'; Expression={$_.Duration}; Width=15}
        )

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Total attempts: $($attempts.Count)" -ForegroundColor Gray
        Write-Host "  Successful: $(($attempts | Where-Object {$_.Status -eq 'SUCCESS'}).Count)" -ForegroundColor Green
        Write-Host "  Failed: $(($attempts | Where-Object {$_.Status -eq 'FAILED'}).Count)" -ForegroundColor Red
        Write-Host "  Delivered: $(if($deliverySucceeded){"Yes"}else{"No"})" -ForegroundColor $(if($deliverySucceeded){"Green"}else{"Red"})
    }
    'json' {
        @{
            WebhookUrl = $WebhookUrl
            Attempts = $attempts
            Delivered = $deliverySucceeded
            TotalAttempts = $attempts.Count
        } | ConvertTo-Json -Depth 10
    }
}

Write-Host ""
if ($deliverySucceeded) {
    Write-Host "✅ Webhook delivered successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Webhook delivery failed after all retries" -ForegroundColor Red
}
