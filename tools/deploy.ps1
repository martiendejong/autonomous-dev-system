<#
.SYNOPSIS
    Deploy client-manager frontend and/or backend to production.

.DESCRIPTION
    Wrapper around the publish scripts for easy deployment.
    Handles build, msdeploy to VPS, and verification.

.PARAMETER Target
    What to deploy: 'frontend', 'backend', or 'both' (default: 'frontend')

.PARAMETER SkipBuild
    Skip the build step (use existing dist/publish folder)

.PARAMETER DryRun
    Show what would be deployed without actually deploying

.EXAMPLE
    deploy.ps1
    # Deploys frontend only

.EXAMPLE
    deploy.ps1 -Target both
    # Deploys both frontend and backend

.EXAMPLE
    deploy.ps1 -Target backend
    # Deploys backend only
#>

param(
    [ValidateSet('frontend', 'backend', 'both')

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
]
    [string]$Target = 'frontend',

    [switch]$SkipBuild,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$RepoRoot = "C:\Projects\client-manager"

function Write-Status($message, $color = 'Cyan') {
    Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] $message" -ForegroundColor $color
}

function Deploy-Frontend {
    Write-Status "Deploying FRONTEND..." "Yellow"

    $script = Join-Path $RepoRoot "publish-brand2boost-frontend.ps1"
    if (-not (Test-Path $script)) {
        Write-Status "ERROR: Frontend publish script not found at $script" "Red"
        return $false
    }

    if ($DryRun) {
        Write-Status "[DRY RUN] Would execute: $script" "Magenta"
        return $true
    }

    try {
        & powershell -ExecutionPolicy Bypass -File $script
        Write-Status "Frontend deployment COMPLETE" "Green"
        return $true
    }
    catch {
        Write-Status "Frontend deployment FAILED: $_" "Red"
        return $false
    }
}

function Deploy-Backend {
    Write-Status "Deploying BACKEND..." "Yellow"

    $script = Join-Path $RepoRoot "publish-brand2boost-backend.ps1"
    if (-not (Test-Path $script)) {
        Write-Status "ERROR: Backend publish script not found at $script" "Red"
        return $false
    }

    if ($DryRun) {
        Write-Status "[DRY RUN] Would execute: $script" "Magenta"
        return $true
    }

    try {
        & powershell -ExecutionPolicy Bypass -File $script
        Write-Status "Backend deployment COMPLETE" "Green"
        return $true
    }
    catch {
        Write-Status "Backend deployment FAILED: $_" "Red"
        return $false
    }
}

# Main
Write-Status "=== DEPLOYMENT TOOL ===" "White"
Write-Status "Target: $Target" "White"

if ($DryRun) {
    Write-Status "[DRY RUN MODE - No actual deployment]" "Magenta"
}

$success = $true

switch ($Target) {
    'frontend' {
        $success = Deploy-Frontend
    }
    'backend' {
        $success = Deploy-Backend
    }
    'both' {
        $success = Deploy-Backend
        if ($success) {
            $success = Deploy-Frontend
        }
    }
}

if ($success) {
    Write-Status "=== DEPLOYMENT SUCCESSFUL ===" "Green"
    Write-Host ""
    Write-Host "Production URL: https://app.brand2boost.com" -ForegroundColor Cyan
    Write-Host "Reminder: Hard refresh (Ctrl+Shift+R) to see changes" -ForegroundColor Yellow
}
else {
    Write-Status "=== DEPLOYMENT FAILED ===" "Red"
    exit 1
}
