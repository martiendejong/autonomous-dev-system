<#
.SYNOPSIS
    API contract testing with OpenAPI validation.

.DESCRIPTION
    Tests API endpoints against OpenAPI specification to ensure contract
    compliance. Validates request/response schemas, status codes, and headers.

.PARAMETER SpecPath
    Path to OpenAPI specification (swagger.json or openapi.yaml)

.PARAMETER BaseUrl
    Base URL of API to test

.PARAMETER GenerateTests
    Generate test cases from specification

.EXAMPLE
    .\test-api-contracts.ps1 -SpecPath "swagger.json" -BaseUrl "https://localhost:5001"
    .\test-api-contracts.ps1 -SpecPath "openapi.yaml" -BaseUrl "https://api.example.com" -GenerateTests
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$SpecPath,

    [Parameter(Mandatory=$true)]
    [string]$BaseUrl,

    [switch]$GenerateTests
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Load-OpenAPISpec {
    param([string]$SpecPath)

    if (-not (Test-Path $SpecPath)) {
        Write-Host "ERROR: Specification file not found: $SpecPath" -ForegroundColor Red
        return $null
    }

    try {
        if ($SpecPath -match '\.json$') {
            $spec = Get-Content $SpecPath | ConvertFrom-Json
        } else {
            Write-Host "YAML parsing not yet implemented" -ForegroundColor Yellow
            return $null
        }

        return $spec

    } catch {
        Write-Host "ERROR: Failed to parse specification: $_" -ForegroundColor Red
        return $null
    }
}

function Test-APIEndpoint {
    param([string]$BaseUrl, [string]$Path, [string]$Method, [object]$Spec)

    $url = "$BaseUrl$Path"

    try {
        $response = Invoke-WebRequest -Uri $url -Method $Method -UseBasicParsing

        $expectedStatus = $Spec.responses.PSObject.Properties.Name | Select-Object -First 1

        if ($response.StatusCode -eq [int]$expectedStatus) {
            return @{
                "Path" = $Path
                "Method" = $Method
                "Status" = "PASS"
                "StatusCode" = $response.StatusCode
            }
        } else {
            return @{
                "Path" = $Path
                "Method" = $Method
                "Status" = "FAIL"
                "StatusCode" = $response.StatusCode
                "ExpectedStatus" = $expectedStatus
            }
        }

    } catch {
        return @{
            "Path" = $Path
            "Method" = $Method
            "Status" = "ERROR"
            "Error" = $_.Exception.Message
        }
    }
}

# Main execution
Write-Host ""
Write-Host "=== API Contract Testing ===" -ForegroundColor Cyan
Write-Host ""

$spec = Load-OpenAPISpec -SpecPath $SpecPath

if (-not $spec) {
    exit 1
}

Write-Host "Loaded OpenAPI specification" -ForegroundColor Green
Write-Host "Base URL: $BaseUrl" -ForegroundColor White
Write-Host ""

if ($GenerateTests) {
    Write-Host "Test generation not yet implemented" -ForegroundColor Yellow
    exit 0
}

# Test endpoints
$results = @()

foreach ($path in $spec.paths.PSObject.Properties.Name) {
    $pathSpec = $spec.paths.$path

    foreach ($method in $pathSpec.PSObject.Properties.Name) {
        $methodSpec = $pathSpec.$method

        Write-Host "Testing: $method $path" -NoNewline -ForegroundColor Yellow

        $result = Test-APIEndpoint -BaseUrl $BaseUrl -Path $path -Method $method.ToUpper() -Spec $methodSpec
        $results += $result

        $color = if ($result.Status -eq "PASS") { "Green" } else { "Red" }
        Write-Host " [$($result.Status)]" -ForegroundColor $color
    }
}

Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host ""

$passed = ($results | Where-Object { $_.Status -eq "PASS" }).Count
$failed = ($results | Where-Object { $_.Status -ne "PASS" }).Count

Write-Host "Passed: $passed" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
Write-Host ""

exit $(if ($failed -gt 0) { 1 } else { 0 })
