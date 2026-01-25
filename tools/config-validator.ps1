# Config Validator - Validate appsettings.json against schema
# Wave 2 Tool #5 (Ratio: 8.0)

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "appsettings.json",

    [Parameter(Mandatory=$false)]
    [switch]$CheckSecrets = $true,

    [Parameter(Mandatory=$false)]
    [switch]$Fix = $false
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "Validating configuration: $ConfigPath" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ConfigPath)) {
    Write-Host "ERROR: Config file not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$issues = @()

# Parse JSON
try {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "ERROR: Invalid JSON: $_" -ForegroundColor Red
    exit 1
}

# Check for common typos
$typoCheck = @{
    'ConnectionStrings' = 'ConnectionString'
    'Logging' = 'Loging'
    'AllowedHosts' = 'AllowedHost'
}

foreach ($correct in $typoCheck.Keys) {
    $typo = $typoCheck[$correct]
    if ($config.PSObject.Properties.Name -contains $typo) {
        $issues += "TYPO: Found '$typo', should be '$correct'"
    }
}

# Check for placeholder values
$json = Get-Content $ConfigPath -Raw
if ($json -match 'TODO|CHANGEME|PLACEHOLDER|xxx|YourConnectionString') {
    $issues += "PLACEHOLDER: Contains placeholder values that need replacement"
}

# Check for secrets in non-secret files
if ($CheckSecrets -and $ConfigPath -notmatch 'Secrets') {
    if ($json -match 'Password=|pwd=|ApiKey|Secret|Token') {
        $issues += "SECRET LEAK: Contains potential secrets in non-secret file"
    }
}

# Check environment-specific configs exist
$baseName = $ConfigPath -replace '\.json$', ''
$envs = @('Development', 'Production')
foreach ($env in $envs) {
    $envFile = "$baseName.$env.json"
    if (-not (Test-Path $envFile)) {
        $issues += "MISSING: $envFile not found"
    }
}

# Output results
if ($issues.Count -eq 0) {
    Write-Host "PASS: Configuration valid" -ForegroundColor Green
    exit 0
} else {
    Write-Host "ISSUES FOUND:" -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    exit 1
}
