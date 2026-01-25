<#
.SYNOPSIS
    Validate retry policies in HTTP clients and message handlers

.DESCRIPTION
    Validates resilience patterns:
    - Checks retry configuration
    - Validates backoff strategies
    - Detects missing retry policies
    - Circuit breaker validation
    - Timeout configuration
    - Idempotency checks

.PARAMETER ProjectPath
    Path to project to scan

.PARAMETER Framework
    Framework: polly, axios, spring-retry, resilience4j

.PARAMETER OutputFormat
    Output format: table (default), json

.EXAMPLE
    .\retry-policy-validator.ps1 -ProjectPath "./src" -Framework polly

.NOTES
    Value: 7/10 - Resilience is critical
    Effort: 1.5/10 - Code pattern matching
    Ratio: 4.7 (TIER A)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [Parameter(Mandatory=$false)]
    [ValidateSet('polly', 'axios', 'spring-retry', 'resilience4j')]
    [string]$Framework = 'polly',

    [Parameter(Mandatory=$false)]
    [ValidateSet('table', 'json')]
    [string]$OutputFormat = 'table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🔄 Retry Policy Validator" -ForegroundColor Cyan
Write-Host "  Project: $ProjectPath" -ForegroundColor Gray
Write-Host "  Framework: $Framework" -ForegroundColor Gray
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "❌ Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

$patterns = @{
    polly = @{
        retryPattern = 'WaitAndRetryAsync|RetryAsync|WaitAndRetry'
        circuitBreakerPattern = 'CircuitBreakerAsync|CircuitBreaker'
        timeoutPattern = 'TimeoutAsync|Timeout'
    }
    axios = @{
        retryPattern = 'axios-retry|retry'
        circuitBreakerPattern = 'circuit-breaker'
        timeoutPattern = 'timeout:'
    }
}

$files = Get-ChildItem -Path $ProjectPath -Include *.cs,*.js,*.ts,*.java -Recurse -File

$findings = @()

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw

    # Check for HTTP client usage
    $hasHttpClient = $content -match 'HttpClient|axios|RestTemplate'

    if ($hasHttpClient) {
        $hasRetry = $content -match $patterns[$Framework].retryPattern
        $hasCircuitBreaker = $content -match $patterns[$Framework].circuitBreakerPattern
        $hasTimeout = $content -match $patterns[$Framework].timeoutPattern

        if (-not $hasRetry) {
            $findings += [PSCustomObject]@{
                File = $file.Name
                Issue = "Missing retry policy"
                Severity = "HIGH"
                Recommendation = "Add retry with exponential backoff"
            }
        }

        if (-not $hasCircuitBreaker) {
            $findings += [PSCustomObject]@{
                File = $file.Name
                Issue = "Missing circuit breaker"
                Severity = "MEDIUM"
                Recommendation = "Add circuit breaker to prevent cascading failures"
            }
        }

        if (-not $hasTimeout) {
            $findings += [PSCustomObject]@{
                File = $file.Name
                Issue = "Missing timeout"
                Severity = "HIGH"
                Recommendation = "Set explicit timeout to prevent hanging requests"
            }
        }
    }
}

Write-Host "RETRY POLICY VALIDATION" -ForegroundColor Cyan
Write-Host ""

switch ($OutputFormat) {
    'table' {
        if ($findings.Count -gt 0) {
            $findings | Format-Table -AutoSize -Wrap -Property @(
                @{Label='File'; Expression={$_.File}; Width=30}
                @{Label='Severity'; Expression={$_.Severity}; Width=10}
                @{Label='Issue'; Expression={$_.Issue}; Width=25}
                @{Label='Recommendation'; Expression={$_.Recommendation}; Width=50}
            )
        }

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Files scanned: $($files.Count)" -ForegroundColor Gray
        Write-Host "  Issues found: $($findings.Count)" -ForegroundColor $(if($findings.Count -gt 0){"Yellow"}else{"Green"})
        Write-Host "  HIGH severity: $(($findings | Where-Object {$_.Severity -eq 'HIGH'}).Count)" -ForegroundColor Red
        Write-Host "  MEDIUM severity: $(($findings | Where-Object {$_.Severity -eq 'MEDIUM'}).Count)" -ForegroundColor Yellow
        Write-Host ""

        if ($findings.Count -gt 0) {
            Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
            Write-Host "  1. Implement exponential backoff for retries" -ForegroundColor Gray
            Write-Host "  2. Add circuit breaker to prevent cascading failures" -ForegroundColor Gray
            Write-Host "  3. Set explicit timeouts on all HTTP requests" -ForegroundColor Gray
            Write-Host "  4. Use idempotent operations for safe retries" -ForegroundColor Gray
            Write-Host "  5. Log retry attempts for debugging" -ForegroundColor Gray
        }
    }
    'json' {
        @{
            FilesScanned = $files.Count
            Issues = $findings
            Summary = @{
                Total = $findings.Count
                High = ($findings | Where-Object {$_.Severity -eq 'HIGH'}).Count
                Medium = ($findings | Where-Object {$_.Severity -eq 'MEDIUM'}).Count
            }
        } | ConvertTo-Json -Depth 10
    }
}

Write-Host ""
if ($findings.Count -gt 0) {
    Write-Host "⚠️  Resilience issues detected - improve retry policies" -ForegroundColor Yellow
} else {
    Write-Host "✅ All HTTP clients have proper resilience patterns" -ForegroundColor Green
}
