# Cross-Repo Sync - Synchronize branches across Hazina + client-manager
# Wave 2 Tool #6 (Ratio: 6.0)

param(
    [Parameter(Mandatory=$false)]
    [string]$BranchName,

    [Parameter(Mandatory=$false)]
    [ValidateSet('create', 'sync', 'status')]
    [string]$Action = 'status',

    [Parameter(Mandatory=$false)]
    [switch]$Paired = $false
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$Repos = @(
    'C:\Projects\hazina',
    'C:\Projects\client-manager'
)

function Get-SyncStatus {
    Write-Host "Cross-Repo Branch Status:" -ForegroundColor Cyan
    Write-Host ""

    foreach ($repo in $Repos) {
        $name = Split-Path $repo -Leaf
        Push-Location $repo

        $branch = git branch --show-current
        $status = git status --porcelain

        Write-Host "[$name]" -ForegroundColor Yellow
        Write-Host "  Branch: $branch" -ForegroundColor Gray
        Write-Host "  Status: $(if ($status) { 'MODIFIED' } else { 'CLEAN' })" -ForegroundColor $(if ($status) { 'Yellow' } else { 'Green' })

        Pop-Location
    }
}

function Create-SyncedBranches {
    param([string]$BranchName)

    Write-Host "Creating branch '$BranchName' in both repos..." -ForegroundColor Cyan

    foreach ($repo in $Repos) {
        $name = Split-Path $repo -Leaf
        Push-Location $repo

        Write-Host "  [$name]" -ForegroundColor Yellow
        git checkout -b $BranchName 2>&1

        Pop-Location
    }

    Write-Host ""
    Write-Host "Branches created successfully" -ForegroundColor Green
}

function Sync-Branches {
    param([string]$BranchName)

    if (-not $BranchName) {
        $BranchName = git -C $Repos[0] branch --show-current
    }

    Write-Host "Syncing branch '$BranchName'..." -ForegroundColor Cyan

    foreach ($repo in $Repos) {
        $name = Split-Path $repo -Leaf
        Push-Location $repo

        Write-Host "  [$name]" -ForegroundColor Yellow
        git checkout $BranchName 2>&1
        git pull origin $BranchName 2>&1

        Pop-Location
    }
}

switch ($Action) {
    'status' { Get-SyncStatus }
    'create' {
        if (-not $BranchName) {
            Write-Host "ERROR: -BranchName required" -ForegroundColor Red
            exit 1
        }
        Create-SyncedBranches -BranchName $BranchName
    }
    'sync' { Sync-Branches -BranchName $BranchName }
}
