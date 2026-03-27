<#
.SYNOPSIS
    Prunes stale and merged branches from repositories.

.DESCRIPTION
    Identifies and removes:
    - Branches merged to develop/main
    - Branches older than specified days with no activity
    - Agent resting branches with no active worktrees
    - Remote tracking branches for deleted remotes

.PARAMETER DryRun
    Show what would be deleted without actually deleting

.PARAMETER MaxAge
    Days of inactivity before considering branch stale (default: 14)

.PARAMETER IncludeRemote
    Also delete branches from remote

.PARAMETER Repo
    Specific repo to prune (default: all base repos)

.EXAMPLE
    .\prune-branches.ps1 -DryRun
    .\prune-branches.ps1 -MaxAge 7
    .\prune-branches.ps1 -IncludeRemote -Repo "C:\Projects\client-manager"
#>

param(
    [switch]$DryRun,
    [int]$MaxAge = 14,
    [switch]$IncludeRemote,
    [string]$Repo
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$BaseRepos = @(
    "C:\Projects\client-manager",
    "C:\Projects\hazina"
)

$ProtectedBranches = @(
    "main",
    "master",
    "develop",
    "release/*",
    "hotfix/*"
)

$AgentBranches = @(
    "agent001", "agent002", "agent003", "agent004", "agent005",
    "agent006", "agent007", "agent008", "agent009", "agent010",
    "agent011", "agent012"
)

function Test-ProtectedBranch {
    param([string]$Branch)

    foreach ($pattern in $ProtectedBranches) {
        if ($pattern.Contains("*")) {
            $regex = "^" + ($pattern -replace "\*", ".*") + "$"
            if ($Branch -match $regex) { return $true }
        } elseif ($Branch -eq $pattern) {
            return $true
        }
    }
    return $false
}

function Get-BranchAge {
    param([string]$RepoPath, [string]$Branch)

    $date = git -C $RepoPath log -1 --format="%ci" $Branch 2>$null
    if ($date) {
        $lastCommit = [DateTime]::Parse($date)
        return (Get-Date) - $lastCommit
    }
    return $null
}

function Test-BranchMerged {
    param([string]$RepoPath, [string]$Branch, [string]$Target = "develop")

    $merged = git -C $RepoPath branch --merged $Target 2>$null
    if ($merged) {
        return ($merged -split "`n" | ForEach-Object { $_.Trim() -replace "^\* ", "" }) -contains $Branch
    }
    return $false
}

function Prune-Repository {
    param([string]$RepoPath)

    $repoName = Split-Path $RepoPath -Leaf
    Write-Host ""
    Write-Host "=== $repoName ===" -ForegroundColor Cyan
    Write-Host "Path: $RepoPath" -ForegroundColor DarkGray

    if (-not (Test-Path $RepoPath)) {
        Write-Host "  [SKIP] Repository not found" -ForegroundColor Yellow
        return
    }

    # Fetch to ensure we have latest remote info
    Write-Host "  Fetching latest..." -ForegroundColor DarkGray
    git -C $RepoPath fetch --prune 2>$null

    # Get all local branches
    $branches = git -C $RepoPath branch --format="%(refname:short)" 2>$null
    if (-not $branches) {
        Write-Host "  [SKIP] No branches found" -ForegroundColor Yellow
        return
    }

    $toDelete = @()
    $currentBranch = git -C $RepoPath branch --show-current 2>$null

    foreach ($branch in ($branches -split "`n" | Where-Object { $_ })) {
        $branch = $branch.Trim()

        # Skip current branch
        if ($branch -eq $currentBranch) {
            continue
        }

        # Skip protected branches
        if (Test-ProtectedBranch -Branch $branch) {
            continue
        }

        # Skip agent resting branches
        if ($branch -in $AgentBranches) {
            continue
        }

        $reason = $null

        # Check if merged
        if (Test-BranchMerged -RepoPath $RepoPath -Branch $branch) {
            $reason = "merged to develop"
        }

        # Check age
        if (-not $reason) {
            $age = Get-BranchAge -RepoPath $RepoPath -Branch $branch
            if ($age -and $age.Days -gt $MaxAge) {
                $reason = "stale ($($age.Days) days old)"
            }
        }

        if ($reason) {
            $toDelete += @{
                branch = $branch
                reason = $reason
            }
        }
    }

    # Report findings
    if ($toDelete.Count -eq 0) {
        Write-Host "  [OK] No branches to prune" -ForegroundColor Green
        return
    }

    Write-Host "  Found $($toDelete.Count) branches to prune:" -ForegroundColor Yellow
    foreach ($item in $toDelete) {
        Write-Host "    - $($item.branch) ($($item.reason))" -ForegroundColor DarkGray
    }

    # Delete if not dry run
    if ($DryRun) {
        Write-Host "  [DRY RUN] Would delete $($toDelete.Count) branches" -ForegroundColor Cyan
    } else {
        foreach ($item in $toDelete) {
            Write-Host "  Deleting $($item.branch)..." -NoNewline
            git -C $RepoPath branch -D $item.branch 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host " OK" -ForegroundColor Green

                if ($IncludeRemote) {
                    git -C $RepoPath push origin --delete $item.branch 2>$null
                }
            } else {
                Write-Host " FAILED" -ForegroundColor Red
            }
        }
    }
}

# Main execution
Write-Host ""
Write-Host "BRANCH PRUNER" -ForegroundColor Cyan
Write-Host "=============" -ForegroundColor Cyan
Write-Host "Max age: $MaxAge days"
Write-Host "Include remote: $IncludeRemote"
if ($DryRun) { Write-Host "Mode: DRY RUN" -ForegroundColor Yellow }

$repos = if ($Repo) { @($Repo) } else { $BaseRepos }

foreach ($repoPath in $repos) {
    Prune-Repository -RepoPath $repoPath
}

Write-Host ""
Write-Host "Done." -ForegroundColor Green
