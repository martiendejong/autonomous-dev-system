<#
.SYNOPSIS
    Manages environment variables and .env files across environments.

.DESCRIPTION
    Creates, validates, and synchronizes .env files for different environments.
    Ensures all required variables are set and provides templates.

    Features:
    - Create .env files from templates
    - Validate environment variables
    - Sync variables across environments
    - Secret rotation reminders
    - Environment documentation
    - Type checking for variables

.PARAMETER Action
    Action: create, validate, sync, list, document, rotate-secrets

.PARAMETER Environment
    Target environment: development, staging, production

.PARAMETER TemplatePath
    Path to .env.template file

.PARAMETER OutputPath
    Output path for .env file

.PARAMETER SourceEnv
    Source environment for sync

.PARAMETER TargetEnv
    Target environment for sync

.EXAMPLE
    .\manage-environment.ps1 -Action create -Environment development
    .\manage-environment.ps1 -Action validate -Environment production
    .\manage-environment.ps1 -Action sync -SourceEnv development -TargetEnv staging
    .\manage-environment.ps1 -Action document -Environment production
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("create", "validate", "sync", "list", "document", "rotate-secrets")]
    [string]$Action,

    [ValidateSet("development", "staging", "production")]
    [string]$Environment,

    [string]$TemplatePath = ".env.template",
    [string]$OutputPath,
    [string]$SourceEnv,
    [string]$TargetEnv
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$script:ValidationRules = @{
    "PORT" = @{ "Type" = "number"; "Min" = 1; "Max" = 65535 }
    "NODE_ENV" = @{ "Type" = "enum"; "Values" = @("development", "production", "test") }
    "DATABASE_URL" = @{ "Type" = "url"; "Required" = $true }
    "API_KEY" = @{ "Type" = "string"; "MinLength" = 32; "Secret" = $true }
    "JWT_SECRET" = @{ "Type" = "string"; "MinLength" = 32; "Secret" = $true }
}

function Get-EnvFilePath {
    param([string]$Environment)

    switch ($Environment) {
        "development" { return ".env.development" }
        "staging" { return ".env.staging" }
        "production" { return ".env.production" }
        default { return ".env" }
    }
}

function Read-EnvFile {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        return @{}
    }

    $vars = @{}

    foreach ($line in Get-Content $FilePath) {
        $line = $line.Trim()

        # Skip comments and empty lines
        if ($line -match '^#' -or $line -eq "") { continue }

        # Parse KEY=VALUE
        if ($line -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()

            # Remove quotes
            $value = $value -replace '^"(.*)"$', '$1'
            $value = $value -replace "^'(.*)'$", '$1'

            $vars[$key] = $value
        }
    }

    return $vars
}

function Write-EnvFile {
    param([hashtable]$Variables, [string]$FilePath, [string]$Environment)

    $content = "# Environment: $Environment`n"
    $content += "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    $content += "`n"

    foreach ($key in $vars.Keys | Sort-Object) {
        $value = $Variables[$key]

        $content += "$key=$value`n"
    }

    $content | Set-Content $FilePath -Encoding UTF8

    Write-Host "Environment file created: $FilePath" -ForegroundColor Green
}

function Create-EnvFromTemplate {
    param([string]$TemplatePath, [string]$Environment)

    Write-Host ""
    Write-Host "=== Creating Environment File ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $TemplatePath)) {
        Write-Host "Template not found: $TemplatePath" -ForegroundColor Yellow
        Write-Host "Creating default template..." -ForegroundColor Cyan

        Create-DefaultTemplate -TemplatePath $TemplatePath
    }

    $template = Read-EnvFile -FilePath $TemplatePath

    Write-Host "Template variables: $($template.Count)" -ForegroundColor White
    Write-Host ""

    # Collect values
    $vars = @{}

    foreach ($key in $template.Keys | Sort-Object) {
        $defaultValue = $template[$key]

        Write-Host "  $key" -ForegroundColor Yellow

        if ($defaultValue) {
            Write-Host "    Default: $defaultValue" -ForegroundColor DarkGray
        }

        $value = Read-Host "    Value"

        if (-not $value -and $defaultValue) {
            $value = $defaultValue
        }

        $vars[$key] = $value
    }

    # Write file
    $outputFile = if ($OutputPath) { $OutputPath } else { Get-EnvFilePath -Environment $Environment }

    Write-EnvFile -Variables $vars -FilePath $outputFile -Environment $Environment

    Write-Host ""
}

function Validate-Environment {
    param([string]$Environment)

    Write-Host ""
    Write-Host "=== Validating Environment ===" -ForegroundColor Cyan
    Write-Host ""

    $envFile = Get-EnvFilePath -Environment $Environment

    if (-not (Test-Path $envFile)) {
        Write-Host "ERROR: Environment file not found: $envFile" -ForegroundColor Red
        return $false
    }

    $vars = Read-EnvFile -FilePath $envFile

    Write-Host "Environment: $Environment" -ForegroundColor White
    Write-Host "File: $envFile" -ForegroundColor White
    Write-Host "Variables: $($vars.Count)" -ForegroundColor White
    Write-Host ""

    $errors = @()

    foreach ($key in $script:ValidationRules.Keys) {
        $rule = $script:ValidationRules[$key]

        if ($rule.Required -and -not $vars.ContainsKey($key)) {
            $errors += "Missing required variable: $key"
            continue
        }

        if ($vars.ContainsKey($key)) {
            $value = $vars[$key]

            # Type validation
            switch ($rule.Type) {
                "number" {
                    if ($value -notmatch '^\d+$') {
                        $errors += "$key must be a number"
                    } else {
                        $num = [int]$value

                        if ($rule.Min -and $num -lt $rule.Min) {
                            $errors += "$key must be >= $($rule.Min)"
                        }

                        if ($rule.Max -and $num -gt $rule.Max) {
                            $errors += "$key must be <= $($rule.Max)"
                        }
                    }
                }
                "enum" {
                    if ($rule.Values -notcontains $value) {
                        $errors += "$key must be one of: $($rule.Values -join ', ')"
                    }
                }
                "url" {
                    if ($value -notmatch '^https?://') {
                        $errors += "$key must be a valid URL"
                    }
                }
                "string" {
                    if ($rule.MinLength -and $value.Length -lt $rule.MinLength) {
                        $errors += "$key must be at least $($rule.MinLength) characters"
                    }
                }
            }
        }
    }

    if ($errors.Count -gt 0) {
        Write-Host "VALIDATION ERRORS:" -ForegroundColor Red
        Write-Host ""

        foreach ($error in $errors) {
            Write-Host "  - $error" -ForegroundColor Yellow
        }

        Write-Host ""
        return $false
    }

    Write-Host "Validation passed!" -ForegroundColor Green
    Write-Host ""

    return $true
}

function Sync-Environments {
    param([string]$SourceEnv, [string]$TargetEnv)

    Write-Host ""
    Write-Host "=== Syncing Environments ===" -ForegroundColor Cyan
    Write-Host ""

    $sourceFile = Get-EnvFilePath -Environment $SourceEnv
    $targetFile = Get-EnvFilePath -Environment $TargetEnv

    if (-not (Test-Path $sourceFile)) {
        Write-Host "ERROR: Source environment not found: $sourceFile" -ForegroundColor Red
        return
    }

    $sourceVars = Read-EnvFile -FilePath $sourceFile
    $targetVars = if (Test-Path $targetFile) {
        Read-EnvFile -FilePath $targetFile
    } else {
        @{}
    }

    Write-Host "Source: $SourceEnv ($($sourceVars.Count) variables)" -ForegroundColor White
    Write-Host "Target: $TargetEnv ($($targetVars.Count) variables)" -ForegroundColor White
    Write-Host ""

    # Find missing keys in target
    $missing = @()

    foreach ($key in $sourceVars.Keys) {
        if (-not $targetVars.ContainsKey($key)) {
            $missing += $key
        }
    }

    if ($missing.Count -gt 0) {
        Write-Host "Variables missing in target:" -ForegroundColor Yellow

        foreach ($key in $missing) {
            Write-Host "  - $key" -ForegroundColor White

            # Don't copy secret values
            $rule = $script:ValidationRules[$key]

            if ($rule -and $rule.Secret) {
                $targetVars[$key] = "<SET_SECRET_VALUE>"
            } else {
                $targetVars[$key] = $sourceVars[$key]
            }
        }

        # Write updated target
        Write-EnvFile -Variables $targetVars -FilePath $targetFile -Environment $TargetEnv

        Write-Host ""
        Write-Host "Synced $($missing.Count) variables" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "No missing variables" -ForegroundColor Green
        Write-Host ""
    }
}

function List-Environments {
    Write-Host ""
    Write-Host "=== Environment Files ===" -ForegroundColor Cyan
    Write-Host ""

    $envs = @("development", "staging", "production")

    foreach ($env in $envs) {
        $file = Get-EnvFilePath -Environment $env

        if (Test-Path $file) {
            $vars = Read-EnvFile -FilePath $file

            Write-Host ("  {0,-15} {1,-25} {2} variables" -f $env, $file, $vars.Count) -ForegroundColor Green
        } else {
            Write-Host ("  {0,-15} {1,-25} NOT FOUND" -f $env, $file) -ForegroundColor DarkGray
        }
    }

    Write-Host ""
}

function Create-DefaultTemplate {
    param([string]$TemplatePath)

    $template = @"
# Application
NODE_ENV=development
PORT=3000

# Database
DATABASE_URL=postgresql://localhost:5432/mydb

# API Keys
API_KEY=your_api_key_here
JWT_SECRET=your_jwt_secret_here

# External Services
REDIS_URL=redis://localhost:6379
SMTP_HOST=smtp.example.com
SMTP_PORT=587
"@

    $template | Set-Content $TemplatePath -Encoding UTF8

    Write-Host "Created template: $TemplatePath" -ForegroundColor Green
}

function Document-Environment {
    param([string]$Environment)

    Write-Host ""
    Write-Host "=== Environment Documentation ===" -ForegroundColor Cyan
    Write-Host ""

    $envFile = Get-EnvFilePath -Environment $Environment

    if (-not (Test-Path $envFile)) {
        Write-Host "ERROR: Environment file not found: $envFile" -ForegroundColor Red
        return
    }

    $vars = Read-EnvFile -FilePath $envFile

    $doc = "# Environment Variables: $Environment`n`n"
    $doc += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"
    $doc += "| Variable | Value | Type | Notes |`n"
    $doc += "|----------|-------|------|-------|`n"

    foreach ($key in $vars.Keys | Sort-Object) {
        $value = $vars[$key]
        $rule = $script:ValidationRules[$key]

        $type = if ($rule) { $rule.Type } else { "string" }

        $displayValue = if ($rule -and $rule.Secret) {
            "[SECRET]"
        } elseif ($value.Length -gt 50) {
            $value.Substring(0, 47) + "..."
        } else {
            $value
        }

        $notes = ""
        if ($rule -and $rule.Required) {
            $notes = "Required"
        }

        $doc += "| $key | $displayValue | $type | $notes |`n"
    }

    $docPath = "ENV_DOCS_$Environment.md"
    $doc | Set-Content $docPath -Encoding UTF8

    Write-Host "Documentation created: $docPath" -ForegroundColor Green
    Write-Host ""
}

function Check-SecretRotation {
    Write-Host ""
    Write-Host "=== Secret Rotation Check ===" -ForegroundColor Cyan
    Write-Host ""

    $envs = @("development", "staging", "production")

    foreach ($env in $envs) {
        $file = Get-EnvFilePath -Environment $env

        if (-not (Test-Path $file)) { continue }

        $fileInfo = Get-Item $file
        $age = (Get-Date) - $fileInfo.LastWriteTime

        if ($age.TotalDays -gt 90) {
            Write-Host ("WARNING: {0} secrets not rotated in {1} days" -f $env, [int]$age.TotalDays) -ForegroundColor Yellow
        } else {
            Write-Host ("  {0}: Last updated {1} days ago" -f $env, [int]$age.TotalDays) -ForegroundColor Green
        }
    }

    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== Environment Manager ===" -ForegroundColor Cyan
Write-Host ""

switch ($Action) {
    "create" {
        if (-not $Environment) {
            Write-Host "ERROR: -Environment required" -ForegroundColor Red
        } else {
            Create-EnvFromTemplate -TemplatePath $TemplatePath -Environment $Environment
        }
    }
    "validate" {
        if (-not $Environment) {
            Write-Host "ERROR: -Environment required" -ForegroundColor Red
        } else {
            Validate-Environment -Environment $Environment
        }
    }
    "sync" {
        if (-not $SourceEnv -or -not $TargetEnv) {
            Write-Host "ERROR: -SourceEnv and -TargetEnv required" -ForegroundColor Red
        } else {
            Sync-Environments -SourceEnv $SourceEnv -TargetEnv $TargetEnv
        }
    }
    "list" {
        List-Environments
    }
    "document" {
        if (-not $Environment) {
            Write-Host "ERROR: -Environment required" -ForegroundColor Red
        } else {
            Document-Environment -Environment $Environment
        }
    }
    "rotate-secrets" {
        Check-SecretRotation
    }
}

Write-Host "=== Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
