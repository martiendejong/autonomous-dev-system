<#
.SYNOPSIS
    Export emails to disk from multiple accounts

.DESCRIPTION
    Search and export emails from configured email accounts to a local folder

.EXAMPLE
    email-export -Query "gemeente meppel" -OutputDir "C:\gemeente_emails"

.EXAMPLE
    email-export -Query "anthropic" -OutputDir "C:\temp\emails"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Query,

    [Parameter(Mandatory=$true)]
    [string]$OutputDir,

    [string]$GmailAppPassword = $env:GMAIL_APP_PASSWORD
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$scriptPath = Join-Path $PSScriptRoot "email-export.js"

# Set environment variable if provided
if ($GmailAppPassword) {
    $env:GMAIL_APP_PASSWORD = $GmailAppPassword
}

# Check if Node.js is available
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js is not installed or not in PATH"
    exit 1
}

# Check if required npm packages are installed
Write-Host "Checking dependencies..." -ForegroundColor Cyan
$toolsDir = $PSScriptRoot
Push-Location $toolsDir

if (-not (Test-Path "node_modules\imap")) {
    Write-Host "Installing imap package..." -ForegroundColor Yellow
    npm install imap
}

if (-not (Test-Path "node_modules\mailparser")) {
    Write-Host "Installing mailparser package..." -ForegroundColor Yellow
    npm install mailparser
}

Pop-Location

# Run the export
Write-Host "`nStarting email export..." -ForegroundColor Green
node $scriptPath --query="$Query" --output="$OutputDir"

Write-Host "`nExport complete! Check $OutputDir for results." -ForegroundColor Green
