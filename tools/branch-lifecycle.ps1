<#
.SYNOPSIS
    Branch Lifecycle Manager
    50-Expert Council V2 Improvement #20 | Priority: 2.33

.DESCRIPTION
    Auto-cleanup merged/stale branches.
    Manages branch lifecycle from creation to deletion.

.PARAMETER Scan
    Scan for branches to cleanup.

.PARAMETER Clean
    Actually delete stale/merged branches.

.PARAMETER DaysStale
    Days without activity to consider stale (default: 30).

.PARAMETER Repo
    Repository path.

.EXAMPLE
    branch-lifecycle.ps1 -Scan
    branch-lifecycle.ps1 -Clean -DaysStale 14
#>

param(
    [switch]$Scan,
    [switch]$Clean,
    [int]$DaysStale = 30,
    [string]$Repo = ".",
    [switch]$Remote,
    [switch]$Force
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


Push-Location $Repo

Write-Host "=== BRANCH LIFECYCLE MANAGER ===" -ForegroundColor Cyan
Write-Host ""

# Fetch latest
Write-Host "Fetching latest..." -ForegroundColor Gray
git fetch --all --prune 2>&1 | Out-Null

$currentBranch = git branch --show-current
$defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null | ForEach-Object { $_ -replace 'refs/remotes/origin/', '' }
if (-not $defaultBranch) { $defaultBranch = "develop" }

Write-Host "Current branch: $currentBranch" -ForegroundColor Yellow
Write-Host "Default branch: $defaultBranch" -ForegroundColor Gray
Write-Host ""

$toDelete = @{
    merged = @()
    stale = @()
    orphaned = @()
}

# Get all local branches
$localBranches = git branch --format='%(refname:short)' | Where-Object { $_ -ne $currentBranch -and $_ -ne $defaultBranch -and $_ -ne "main" }

foreach ($branch in $localBranches) {
    # Check if merged
    $isMerged = git branch --merged $defaultBranch | ForEach-Object { $_.Trim() } | Where-Object { $_ -eq $branch }

    if ($isMerged) {
        $toDelete.merged += $branch
        continue
    }

    # Check if stale (no commits in X days)
    $lastCommit = git log -1 --format="%ci" $branch 2>$null
    if ($lastCommit) {
        $lastDate = [datetime]::Parse($lastCommit)
        $daysSince = ((Get-Date) - $lastDate).Days

        if ($daysSince -gt $DaysStale) {
            $toDelete.stale += @{
                branch = $branch
                days = $daysSince
                lastCommit = $lastCommit
            }
        }
    }

    # Check if orphaned (no remote tracking)
    $tracking = git config "branch.$branch.remote" 2>$null
    if (-not $tracking) {
        $remoteBranch = git branch -r | Where-Object { $_ -match "origin/$branch$" }
        if (-not $remoteBranch) {
            $toDelete.orphaned += $branch
        }
    }
}

# Report
Write-Host "ANALYSIS:" -ForegroundColor Magenta
Write-Host ""

Write-Host "Merged branches ($($toDelete.merged.Count)):" -ForegroundColor Green
foreach ($b in $toDelete.merged) {
    Write-Host "  ✓ $b" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Stale branches ($($toDelete.stale.Count)):" -ForegroundColor Yellow
foreach ($b in $toDelete.stale) {
    Write-Host "  ⏰ $($b.branch) ($($b.days) days old)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Orphaned branches ($($toDelete.orphaned.Count)):" -ForegroundColor Red
foreach ($b in $toDelete.orphaned) {
    Write-Host "  ⚠ $b (no remote)" -ForegroundColor Gray
}

$totalToDelete = $toDelete.merged.Count + $toDelete.stale.Count + $toDelete.orphaned.Count
Write-Host ""
Write-Host "Total candidates for cleanup: $totalToDelete" -ForegroundColor White

if ($Clean -and $totalToDelete -gt 0) {
    Write-Host ""
    Write-Host "CLEANING..." -ForegroundColor Yellow
    Write-Host ""

    $deleted = 0

    # Delete merged (safe)
    foreach ($b in $toDelete.merged) {
        Write-Host "  Deleting merged: $b..." -ForegroundColor Gray
        git branch -d $b 2>&1 | Out-Null
        if ($Remote) {
            git push origin --delete $b 2>&1 | Out-Null
        }
        $deleted++
    }

    # Delete orphaned (safe)
    foreach ($b in $toDelete.orphaned) {
        Write-Host "  Deleting orphaned: $b..." -ForegroundColor Gray
        git branch -d $b 2>&1 | Out-Null
        $deleted++
    }

    # Delete stale (requires Force or confirmation)
    if ($Force) {
        foreach ($b in $toDelete.stale) {
            Write-Host "  Deleting stale: $($b.branch)..." -ForegroundColor Gray
            git branch -D $b.branch 2>&1 | Out-Null
            if ($Remote) {
                git push origin --delete $b.branch 2>&1 | Out-Null
            }
            $deleted++
        }
    }
    else {
        if ($toDelete.stale.Count -gt 0) {
            Write-Host ""
            Write-Host "  ⚠ Stale branches not deleted (use -Force)" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "✓ Deleted $deleted branches" -ForegroundColor Green
}
elseif (-not $Scan -and -not $Clean) {
    Write-Host ""
    Write-Host "To cleanup: branch-lifecycle.ps1 -Clean" -ForegroundColor Gray
    Write-Host "With stale: branch-lifecycle.ps1 -Clean -Force" -ForegroundColor Gray
}

Pop-Location
