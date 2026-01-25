<#
.SYNOPSIS
    Configuration drift detector across environments.

.DESCRIPTION
    Detects configuration drift between environments by comparing
    settings, environment variables, and infrastructure state.

.PARAMETER SourceEnvironment
    Source environment: dev, staging, production

.PARAMETER TargetEnvironment
    Target environment to compare

.PARAMETER ConfigType
    Configuration type: appsettings, env, infrastructure

.PARAMETER ProjectPath
    Project path for appsettings comparison

.PARAMETER AutoFix
    Automatically fix detected drift

.EXAMPLE
    .\detect-config-drift.ps1 -SourceEnvironment production -TargetEnvironment staging -ConfigType appsettings -ProjectPath "."
    .\detect-config-drift.ps1 -SourceEnvironment staging -TargetEnvironment dev -ConfigType env
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "production")]
    [string]$SourceEnvironment,

    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "production")]
    [string]$TargetEnvironment,

    [Parameter(Mandatory=$true)]
    [ValidateSet("appsettings", "env", "infrastructure")]
    [string]$ConfigType,

    [string]$ProjectPath,
    [switch]$AutoFix
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Compare-AppSettings {
    param([string]$SourceEnv, [string]$TargetEnv, [string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Comparing AppSettings ===" -ForegroundColor Cyan
    Write-Host ""

    $sourceFile = Join-Path $ProjectPath "appsettings.$SourceEnv.json"
    $targetFile = Join-Path $ProjectPath "appsettings.$TargetEnv.json"

    if (-not (Test-Path $sourceFile)) {
        Write-Host "ERROR: Source file not found: $sourceFile" -ForegroundColor Red
        return @()
    }

    if (-not (Test-Path $targetFile)) {
        Write-Host "ERROR: Target file not found: $targetFile" -ForegroundColor Red
        return @()
    }

    $source = Get-Content $sourceFile | ConvertFrom-Json
    $target = Get-Content $targetFile | ConvertFrom-Json

    $drifts = @()

    # Compare keys
    foreach ($key in $source.PSObject.Properties.Name) {
        if (-not ($target.PSObject.Properties.Name -contains $key)) {
            $drifts += @{
                "Type" = "Missing"
                "Key" = $key
                "SourceValue" = $source.$key
                "TargetValue" = $null
            }
        } elseif ($source.$key -ne $target.$key) {
            $drifts += @{
                "Type" = "Different"
                "Key" = $key
                "SourceValue" = $source.$key
                "TargetValue" = $target.$key
            }
        }
    }

    return $drifts
}

function Show-DriftReport {
    param([array]$Drifts, [string]$SourceEnv, [string]$TargetEnv)

    Write-Host ""
    Write-Host "=== Configuration Drift Report ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Source: $SourceEnv" -ForegroundColor White
    Write-Host "Target: $TargetEnv" -ForegroundColor White
    Write-Host ""

    if ($Drifts.Count -eq 0) {
        Write-Host "No drift detected!" -ForegroundColor Green
        return
    }

    Write-Host "Detected $($Drifts.Count) differences:" -ForegroundColor Yellow
    Write-Host ""

    foreach ($drift in $Drifts) {
        $color = if ($drift.Type -eq "Missing") { "Red" } else { "Yellow" }

        Write-Host "  $($drift.Key) [$($drift.Type)]" -ForegroundColor $color
        Write-Host "    Source: $($drift.SourceValue)" -ForegroundColor DarkGray
        Write-Host "    Target: $($drift.TargetValue)" -ForegroundColor DarkGray
        Write-Host ""
    }
}

# Main execution
Write-Host ""
Write-Host "=== Configuration Drift Detector ===" -ForegroundColor Cyan
Write-Host ""

$drifts = switch ($ConfigType) {
    "appsettings" {
        if (-not $ProjectPath) {
            Write-Host "ERROR: -ProjectPath required for appsettings comparison" -ForegroundColor Red
            exit 1
        }
        Compare-AppSettings -SourceEnv $SourceEnvironment -TargetEnv $TargetEnvironment -ProjectPath $ProjectPath
    }
    "env" {
        Write-Host "Environment variable comparison not yet implemented" -ForegroundColor Yellow
        @()
    }
    "infrastructure" {
        Write-Host "Infrastructure drift detection not yet implemented" -ForegroundColor Yellow
        @()
    }
}

Show-DriftReport -Drifts $drifts -SourceEnv $SourceEnvironment -TargetEnv $TargetEnvironment

if ($AutoFix -and $drifts.Count -gt 0) {
    Write-Host "Auto-fix not yet implemented" -ForegroundColor Yellow
}

Write-Host "=== Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
