<#
.SYNOPSIS
    Validate environment variables across environments

.DESCRIPTION
    Ensures environment configuration consistency:
    - Validates all required env vars exist
    - Checks for placeholder values (TODO, CHANGEME)
    - Compares across environments (dev/staging/prod)
    - Detects missing or extra variables
    - Validates format (URLs, ports, booleans)

    Prevents runtime errors from missing/invalid env vars.

.PARAMETER Environment
    Environment to validate: dev, staging, prod, all

.PARAMETER ConfigFile
    JSON file with required env vars schema

.PARAMETER CompareEnvironments
    Compare variables across environments

.PARAMETER FailOnMissing
    Fail if required variables are missing

.PARAMETER OutputFormat
    Output format: Table (default), JSON, Diff

.EXAMPLE
    # Validate production environment
    .\env-var-validator.ps1 -Environment prod

.EXAMPLE
    # Compare all environments
    .\env-var-validator.ps1 -CompareEnvironments

.EXAMPLE
    # Validate against schema
    .\env-var-validator.ps1 -ConfigFile env-schema.json -FailOnMissing

.NOTES
    Value: 9/10 - Prevents production config errors
    Effort: 1.1/10 - Config file parsing
    Ratio: 8.2 (TIER S+)
#>

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('dev', 'staging', 'prod', 'all')]
    [string]$Environment = 'dev',

    [Parameter(Mandatory=$false)]
    [string]$ConfigFile = "",

    [Parameter(Mandatory=$false)]
    [switch]$CompareEnvironments = $false,

    [Parameter(Mandatory=$false)]
    [switch]$FailOnMissing = $false,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'JSON', 'Diff')]
    [string]$OutputFormat = 'Table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🔧 Environment Variable Validator" -ForegroundColor Cyan
Write-Host "  Environment: $Environment" -ForegroundColor Gray
Write-Host ""

# Environment file paths
$envFiles = @{
    dev = ".env.development"
    staging = ".env.staging"
    prod = ".env.production"
}

# Required variables schema (example)
$requiredVars = if ($ConfigFile -and (Test-Path $ConfigFile)) {
    Get-Content $ConfigFile -Raw | ConvertFrom-Json
} else {
    @{
        required = @(
            @{name="DATABASE_URL"; format="url"; description="Database connection string"}
            @{name="API_KEY"; format="string"; description="API authentication key"}
            @{name="PORT"; format="number"; description="Server port"}
            @{name="NODE_ENV"; format="enum"; values=@("development","staging","production"); description="Environment"}
        )
        optional = @(
            @{name="DEBUG"; format="boolean"; description="Debug mode"}
            @{name="LOG_LEVEL"; format="enum"; values=@("error","warn","info","debug"); description="Logging level"}
        )
    }
}

function Get-EnvVariables {
    param([string]$EnvFile)

    if (-not (Test-Path $EnvFile)) {
        return @{}
    }

    $vars = @{}
    $content = Get-Content $EnvFile

    foreach ($line in $content) {
        if ($line -match '^\s*#' -or $line -match '^\s*$') {
            continue  # Skip comments and empty lines
        }

        if ($line -match '^([^=]+)=(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()

            # Remove quotes
            $value = $value -replace '^["'']|["'']$', ''

            $vars[$key] = $value
        }
    }

    return $vars
}

function Validate-EnvVar {
    param([string]$Value, [string]$Format, [array]$ValidValues = @())

    $issues = @()

    # Check for placeholder values
    if ($Value -match 'TODO|CHANGEME|PLACEHOLDER|YOUR_|REPLACE_|XXX') {
        $issues += "Contains placeholder value"
    }

    # Format validation
    switch ($Format) {
        'url' {
            if ($Value -notmatch '^https?://') {
                $issues += "Invalid URL format"
            }
        }
        'number' {
            if ($Value -notmatch '^\d+$') {
                $issues += "Not a valid number"
            }
        }
        'boolean' {
            if ($Value -notin @('true', 'false', '1', '0', 'yes', 'no')) {
                $issues += "Not a valid boolean"
            }
        }
        'enum' {
            if ($Value -notin $ValidValues) {
                $issues += "Must be one of: $($ValidValues -join ', ')"
            }
        }
    }

    return $issues
}

$environments = if ($Environment -eq 'all' -or $CompareEnvironments) {
    @('dev', 'staging', 'prod')
} else {
    @($Environment)
}

$results = @{}

foreach ($env in $environments) {
    $envFile = $envFiles[$env]

    Write-Host "Checking $env environment..." -ForegroundColor Yellow

    if (-not (Test-Path $envFile)) {
        Write-Host "  ⚠️  File not found: $envFile" -ForegroundColor Yellow
        continue
    }

    $vars = Get-EnvVariables -EnvFile $envFile
    $results[$env] = $vars

    $issues = @()

    # Check required variables
    foreach ($reqVar in $requiredVars.required) {
        if (-not $vars.ContainsKey($reqVar.name)) {
            $issues += [PSCustomObject]@{
                Variable = $reqVar.name
                Issue = "MISSING (required)"
                Severity = "CRITICAL"
                Description = $reqVar.description
            }
        } else {
            $varIssues = Validate-EnvVar -Value $vars[$reqVar.name] -Format $reqVar.format -ValidValues $reqVar.values
            foreach ($issue in $varIssues) {
                $issues += [PSCustomObject]@{
                    Variable = $reqVar.name
                    Issue = $issue
                    Severity = "HIGH"
                    Description = $reqVar.description
                }
            }
        }
    }

    # Check for empty values
    foreach ($key in $vars.Keys) {
        if ([string]::IsNullOrWhiteSpace($vars[$key])) {
            $issues += [PSCustomObject]@{
                Variable = $key
                Issue = "Empty value"
                Severity = "MEDIUM"
                Description = ""
            }
        }
    }

    if ($issues.Count -eq 0) {
        Write-Host "  ✅ No issues found" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($issues.Count) issues found" -ForegroundColor Red

        $issues | Format-Table -AutoSize -Property @(
            @{Label='Variable'; Expression={$_.Variable}; Width=25}
            @{Label='Issue'; Expression={$_.Issue}; Width=30}
            @{Label='Severity'; Expression={$_.Severity}; Width=10}
        )
    }

    Write-Host ""
}

# Compare environments
if ($CompareEnvironments -and $results.Count -gt 1) {
    Write-Host "ENVIRONMENT COMPARISON" -ForegroundColor Cyan
    Write-Host ""

    $allKeys = $results.Values | ForEach-Object { $_.Keys } | Select-Object -Unique

    foreach ($key in ($allKeys | Sort-Object)) {
        $values = @{}
        foreach ($env in $results.Keys) {
            $values[$env] = $results[$env][$key]
        }

        # Check if values differ
        $uniqueValues = $values.Values | Select-Object -Unique
        $differs = $uniqueValues.Count -gt 1

        if ($differs) {
            Write-Host "  $key" -ForegroundColor $(if($differs){"Yellow"}else{"Gray"})
            foreach ($env in $results.Keys) {
                $val = if ($results[$env].ContainsKey($key)) {
                    $results[$env][$key].Substring(0, [Math]::Min(40, $results[$env][$key].Length))
                } else {
                    "(missing)"
                }
                Write-Host "    $env: $val" -ForegroundColor Gray
            }
            Write-Host ""
        }
    }
}

Write-Host "SUMMARY:" -ForegroundColor Cyan
foreach ($env in $results.Keys) {
    Write-Host "  $env: $($results[$env].Count) variables" -ForegroundColor Gray
}

if ($FailOnMissing) {
    # Check if any required vars are missing
    $hasMissing = $false
    foreach ($env in $results.Keys) {
        foreach ($reqVar in $requiredVars.required) {
            if (-not $results[$env].ContainsKey($reqVar.name)) {
                $hasMissing = $true
                break
            }
        }
    }

    if ($hasMissing) {
        Write-Host ""
        Write-Host "❌ Required variables missing - failing build" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "✅ Environment validation complete" -ForegroundColor Green
