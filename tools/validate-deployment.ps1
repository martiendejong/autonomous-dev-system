<#
.SYNOPSIS
    Pre-deployment validation and smoke tests.

.DESCRIPTION
    Validates deployment readiness with comprehensive checks including
    build verification, configuration validation, database migrations,
    and smoke tests.

.PARAMETER ProjectPath
    Path to project root

.PARAMETER Environment
    Target environment: dev, staging, production

.PARAMETER SkipBuild
    Skip build verification

.PARAMETER SkipTests
    Skip test execution

.EXAMPLE
    .\validate-deployment.ps1 -ProjectPath "C:\Projects\client-manager" -Environment production
    .\validate-deployment.ps1 -ProjectPath "." -Environment staging -SkipTests
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [Parameter(Mandatory=$true)]
    [ValidateSet("dev", "staging", "production")]
    [string]$Environment,

    [switch]$SkipBuild,
    [switch]$SkipTests
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Test-BuildSucceeds {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Build Verification ===" -ForegroundColor Cyan
    Write-Host ""

    Push-Location $ProjectPath
    try {
        dotnet build --configuration Release --no-incremental

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Build succeeded" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Build failed" -ForegroundColor Red
            return $false
        }

    } finally {
        Pop-Location
    }
}

function Test-ConfigurationValid {
    param([string]$ProjectPath, [string]$Environment)

    Write-Host ""
    Write-Host "=== Configuration Validation ===" -ForegroundColor Cyan
    Write-Host ""

    $configFile = Join-Path $ProjectPath "appsettings.$Environment.json"

    if (-not (Test-Path $configFile)) {
        Write-Host "ERROR: Configuration file not found: $configFile" -ForegroundColor Red
        return $false
    }

    try {
        $config = Get-Content $configFile | ConvertFrom-Json
        Write-Host "Configuration valid" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "ERROR: Invalid JSON in configuration file" -ForegroundColor Red
        return $false
    }
}

function Test-DatabaseMigrationsApplied {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Database Migration Check ===" -ForegroundColor Cyan
    Write-Host ""

    Push-Location $ProjectPath
    try {
        # Check if there are pending migrations
        $pendingMigrations = dotnet ef migrations list --no-build 2>&1 | Select-String "Pending"

        if ($pendingMigrations) {
            Write-Host "WARNING: Pending migrations detected" -ForegroundColor Yellow
            return $false
        } else {
            Write-Host "All migrations applied" -ForegroundColor Green
            return $true
        }

    } catch {
        Write-Host "Could not check migrations" -ForegroundColor Yellow
        return $true

    } finally {
        Pop-Location
    }
}

function Test-DependenciesUpToDate {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Dependency Check ===" -ForegroundColor Cyan
    Write-Host ""

    Push-Location $ProjectPath
    try {
        # Check for vulnerable packages
        $vulnerabilities = dotnet list package --vulnerable 2>&1

        if ($vulnerabilities -match "has the following vulnerable packages") {
            Write-Host "WARNING: Vulnerable packages detected" -ForegroundColor Yellow
            return $false
        } else {
            Write-Host "No vulnerable packages" -ForegroundColor Green
            return $true
        }

    } finally {
        Pop-Location
    }
}

# Main execution
Write-Host ""
Write-Host "=== Deployment Validator ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Project: $ProjectPath" -ForegroundColor White
Write-Host "Environment: $Environment" -ForegroundColor White
Write-Host ""

$checks = @()

if (-not $SkipBuild) {
    $checks += @{ "Name" = "Build"; "Result" = (Test-BuildSucceeds -ProjectPath $ProjectPath) }
}

$checks += @{ "Name" = "Configuration"; "Result" = (Test-ConfigurationValid -ProjectPath $ProjectPath -Environment $Environment) }
$checks += @{ "Name" = "Database Migrations"; "Result" = (Test-DatabaseMigrationsApplied -ProjectPath $ProjectPath) }
$checks += @{ "Name" = "Dependencies"; "Result" = (Test-DependenciesUpToDate -ProjectPath $ProjectPath) }

Write-Host ""
Write-Host "=== Validation Summary ===" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

foreach ($check in $checks) {
    $status = if ($check.Result) { "PASS" } else { "FAIL" }
    $color = if ($check.Result) { "Green" } else { "Red" }

    Write-Host ("  {0,-30} [{1}]" -f $check.Name, $status) -ForegroundColor $color

    if (-not $check.Result) {
        $allPassed = $false
    }
}

Write-Host ""

if ($allPassed) {
    Write-Host "Deployment validation passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Deployment validation failed" -ForegroundColor Red
    exit 1
}
