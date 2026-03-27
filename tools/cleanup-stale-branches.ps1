<#
.SYNOPSIS
    Identifies and cleans up stale git branches.

.DESCRIPTION
    Finds merged branches and inactive branches for cleanup.

    Criteria:
    - Merged branches (>30 days old)
    - No commits in 90+ days
    - Already pushed/merged to develop or main

.PARAMETER Repo
    Repository path (default: current directory)

.PARAMETER DryRun
    Show what would be deleted without deleting

.PARAMETER AutoDelete
    Automatically delete without confirmation

.PARAMETER MergedOnly
    Only show/delete merged branches

.PARAMETER DaysInactive
    Consider branches inactive after N days (default: 90)

.EXAMPLE
    .\cleanup-stale-branches.ps1 -DryRun
    .\cleanup-stale-branches.ps1 -Repo "C:\Projects\client-manager" -MergedOnly
    .\cleanup-stale-branches.ps1 -AutoDelete -DaysInactive 60
#>

param(
    [string]$Repo = ".",
    [switch]$DryRun,
    [switch]$AutoDelete,
    [switch]$MergedOnly,
    [int]$DaysInactive = 90
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


function Get-MergedBranches {
    param([string]$RepoPath)

    Push-Location $RepoPath
    try {
        # Get branches merged into develop or main
        $developBranches = git branch --merged develop 2>$null | Where-Object { $_ -notmatch '^\*' -and $_ -notmatch 'develop|main|master' }
        $mainBranches = git branch --merged main 2>$null | Where-Object { $_ -notmatch '^\*' -and $_ -notmatch 'develop|main|master' }

        $merged = ($developBranches + $mainBranches) | ForEach-Object { $_.Trim() } | Select-Object -Unique

        $branchInfo = @()

        foreach ($branch in $merged) {
            $lastCommitDate = git log -1 --format="%ci" $branch 2>$null
            if ($lastCommitDate) {
                $date = [DateTime]::Parse($lastCommitDate)
                $daysAgo = ((Get-Date) - $date).Days

                $branchInfo += @{
                    "Name" = $branch
                    "LastCommit" = $date
                    "DaysAgo" = $daysAgo
                    "Status" = "Merged"
                }
            }
        }

        return $branchInfo

    } finally {
        Pop-Location
    }
}

function Get-InactiveBranches {
    param([string]$RepoPath, [int]$InactiveDays)

    Push-Location $RepoPath
    try {
        $allBranches = git branch | Where-Object { $_ -notmatch '^\*' -and $_ -notmatch 'develop|main|master' } | ForEach-Object { $_.Trim() }

        $branchInfo = @()

        foreach ($branch in $allBranches) {
            $lastCommitDate = git log -1 --format="%ci" $branch 2>$null
            if ($lastCommitDate) {
                $date = [DateTime]::Parse($lastCommitDate)
                $daysAgo = ((Get-Date) - $date).Days

                if ($daysAgo -ge $InactiveDays) {
                    # Check if merged
                    $isMerged = (git branch --merged develop | Select-String $branch) -or
                                (git branch --merged main | Select-String $branch)

                    $branchInfo += @{
                        "Name" = $branch
                        "LastCommit" = $date
                        "DaysAgo" = $daysAgo
                        "Status" = if ($isMerged) { "Merged + Inactive" } else { "Inactive" }
                    }
                }
            }
        }

        return $branchInfo

    } finally {
        Pop-Location
    }
}

function Remove-Branches {
    param([array]$Branches, [string]$RepoPath, [bool]$DryRunMode, [bool]$Auto)

    if ($Branches.Count -eq 0) {
        Write-Host "No branches to delete" -ForegroundColor Green
        return 0
    }

    Write-Host ""
    Write-Host "=== Branches to Delete ===" -ForegroundColor Yellow
    Write-Host ""

    foreach ($branch in $Branches) {
        Write-Host ("  {0,-40} ({1} days ago)" -f $branch.Name, $branch.DaysAgo) -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Total: $($Branches.Count) branches" -ForegroundColor White
    Write-Host ""

    if ($DryRunMode) {
        Write-Host "[DRY RUN] Would delete these branches" -ForegroundColor Cyan
        return 0
    }

    if (-not $Auto) {
        $confirm = Read-Host "Delete these branches? (yes/no)"
        if ($confirm -ne "yes") {
            Write-Host "Cancelled" -ForegroundColor Yellow
            return 0
        }
    }

    # Delete branches
    Push-Location $RepoPath
    try {
        $deleted = 0
        foreach ($branch in $Branches) {
            Write-Host "Deleting: $($branch.Name)..." -ForegroundColor DarkGray

            git branch -d $branch.Name 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                $deleted++
            } else {
                Write-Host "  Failed to delete (use -D to force)" -ForegroundColor Red
            }
        }

        Write-Host ""
        Write-Host "Deleted $deleted branches" -ForegroundColor Green
        return $deleted

    } finally {
        Pop-Location
    }
}

# Main execution
Write-Host ""
Write-Host "=== Stale Branch Cleanup ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Repo)) {
    Write-Host "ERROR: Repository not found: $Repo" -ForegroundColor Red
    exit 1
}

Write-Host "Repository: $Repo" -ForegroundColor White
Write-Host "Inactive threshold: $DaysInactive days" -ForegroundColor DarkGray
Write-Host ""

# Get stale branches
Write-Host "Scanning for stale branches..." -ForegroundColor Cyan

$staleBranches = if ($MergedOnly) {
    Get-MergedBranches -RepoPath $Repo | Where-Object { $_.DaysAgo -ge 30 }
} else {
    Get-InactiveBranches -RepoPath $Repo -InactiveDays $DaysInactive
}

if ($staleBranches.Count -eq 0) {
    Write-Host ""
    Write-Host "No stale branches found!" -ForegroundColor Green
    Write-Host ""
    exit 0
}

# Group by status
$merged = $staleBranches | Where-Object { $_.Status -match "Merged" }
$inactive = $staleBranches | Where-Object { $_.Status -eq "Inactive" }

Write-Host ""
Write-Host "=== Results ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Merged branches (>30 days): $($merged.Count)" -ForegroundColor Green
Write-Host "  Inactive branches (>$DaysInactive days): $($inactive.Count)" -ForegroundColor Yellow
Write-Host ""

# Show details
if ($merged.Count -gt 0) {
    Write-Host "Merged Branches:" -ForegroundColor Green
    foreach ($branch in $merged | Sort-Object DaysAgo -Descending) {
        Write-Host ("  {0,-40} Last commit: {1:yyyy-MM-dd} ({2} days ago)" -f $branch.Name, $branch.LastCommit, $branch.DaysAgo) -ForegroundColor DarkGray
    }
    Write-Host ""
}

if ($inactive.Count -gt 0) {
    Write-Host "Inactive Branches:" -ForegroundColor Yellow
    foreach ($branch in $inactive | Sort-Object DaysAgo -Descending) {
        Write-Host ("  {0,-40} Last commit: {1:yyyy-MM-dd} ({2} days ago)" -f $branch.Name, $branch.LastCommit, $branch.DaysAgo) -ForegroundColor DarkGray
    }
    Write-Host ""
}

# Delete if requested
if (-not $DryRun) {
    $deleted = Remove-Branches -Branches $staleBranches -RepoPath $Repo -DryRunMode:$DryRun -Auto:$AutoDelete
} else {
    Write-Host "[DRY RUN] Use without -DryRun to delete these branches" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "=== Cleanup Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
