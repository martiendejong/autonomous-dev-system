<#
.SYNOPSIS
    Validates PR base branch before creation to prevent violations.

.DESCRIPTION
    Checks that PRs target the correct base branch (develop for most repos).
    Prevents common mistake of targeting main instead of develop.

.PARAMETER Repo
    Repository to check (client-manager, hazina, etc.)

.PARAMETER BaseBranch
    Expected base branch (default: develop)

.EXAMPLE
    .\validate-pr-base.ps1 -Repo "client-manager"
    .\validate-pr-base.ps1 -Repo "hazina" -BaseBranch "develop"
#>

param(
    [string]$Repo,
    [string]$BaseBranch = "develop"
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$RepoMappings = @{
    "client-manager" = "C:\Projects\client-manager"
    "hazina" = "C:\Projects\hazina"
    "artrevisionist" = "C:\Projects\artrevisionist"
    "bugattiinsights" = "C:\Projects\bugattiinsights"
}

function Get-RepoPath {
    param([string]$RepoName)

    if ($RepoMappings.ContainsKey($RepoName)) {
        return $RepoMappings[$RepoName]
    }

    if (Test-Path $RepoName) {
        return $RepoName
    }

    return $null
}

# Main execution
if (-not $Repo) {
    Write-Host "ERROR: -Repo parameter required" -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor White
    Write-Host "  .\validate-pr-base.ps1 -Repo 'client-manager' [-BaseBranch 'develop']" -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}

$repoPath = Get-RepoPath -RepoName $Repo
if (-not $repoPath) {
    Write-Host "ERROR: Repository not found: $Repo" -ForegroundColor Red
    Write-Host "Available repos: $($RepoMappings.Keys -join ', ')" -ForegroundColor Yellow
    exit 1
}

Push-Location $repoPath
try {
    Write-Host ""
    Write-Host "=== PR Base Branch Validation ===" -ForegroundColor Cyan
    Write-Host "  Repository: $Repo" -ForegroundColor White
    Write-Host "  Expected base: $BaseBranch" -ForegroundColor White
    Write-Host ""

    $currentBranch = git branch --show-current
    if (-not $currentBranch) {
        Write-Host "ERROR: Not on any branch" -ForegroundColor Red
        exit 1
    }

    Write-Host "  Current branch: $currentBranch" -ForegroundColor White

    if ($currentBranch -eq $BaseBranch) {
        Write-Host ""
        Write-Host "WARNING: You are on the base branch ($BaseBranch)" -ForegroundColor Yellow
        Write-Host "Create a feature branch first before creating a PR" -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    $defaultBase = gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>$null

    if ($defaultBase -and $defaultBase -ne $BaseBranch) {
        Write-Host ""
        Write-Host "WARNING: Repo default is '$defaultBase' but expecting '$BaseBranch'" -ForegroundColor Yellow
        Write-Host "When creating PR, use:" -ForegroundColor Yellow
        Write-Host "  gh pr create --base $BaseBranch ..." -ForegroundColor Cyan
        Write-Host ""
    }

    Write-Host "Validation passed" -ForegroundColor Green
    Write-Host "  PR will target: $BaseBranch" -ForegroundColor Green
    Write-Host ""

} finally {
    Pop-Location
}

exit 0
