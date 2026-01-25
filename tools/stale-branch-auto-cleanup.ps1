<#
.SYNOPSIS
    Auto-delete merged branches older than X days

.DESCRIPTION
    Automatically cleans up stale branches:
    - Merged branches older than threshold
    - Branches with no recent commits
    - Local and remote cleanup

    Prevents:
    - Branch pollution
    - Confusion about active work
    - Merge conflicts from stale branches

.PARAMETER DaysOld
    Delete branches merged more than X days ago (default: 30)

.PARAMETER DryRun
    Show what would be deleted without deleting

.PARAMETER IncludeRemote
    Also delete remote branches

.PARAMETER ExcludePattern
    Regex pattern for branches to exclude (default: main|master|develop|staging|production)

.EXAMPLE
    # Dry run - see what would be deleted
    .\stale-branch-auto-cleanup.ps1 -DryRun

.EXAMPLE
    # Delete local merged branches older than 60 days
    .\stale-branch-auto-cleanup.ps1 -DaysOld 60

.EXAMPLE
    # Delete local AND remote stale branches
    .\stale-branch-auto-cleanup.ps1 -IncludeRemote

.NOTES
    Value: 7/10 - Keeps repo clean
    Effort: 1/10 - Git command wrapper
    Ratio: 7.0 (TIER S)
#>

param(
    [Parameter(Mandatory=$false)]
    [int]$DaysOld = 30,

    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false,

    [Parameter(Mandatory=$false)]
    [switch]$IncludeRemote = $false,

    [Parameter(Mandatory=$false)]
    [string]$ExcludePattern = "main|master|develop|staging|production"
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "Stale Branch Auto-Cleanup" -ForegroundColor Cyan
Write-Host "  Threshold: $DaysOld days" -ForegroundColor Gray
Write-Host "  Dry run: $DryRun" -ForegroundColor Gray
Write-Host "  Include remote: $IncludeRemote" -ForegroundColor Gray
Write-Host ""

$cutoffDate = (Get-Date).AddDays(-$DaysOld)

# Get merged branches
$mergedBranches = git branch --merged | ForEach-Object { $_.Trim().TrimStart('* ') }

$staleBranches = @()

foreach ($branch in $mergedBranches) {
    # Skip excluded branches
    if ($branch -match $ExcludePattern) {
        continue
    }

    # Get last commit date
    $lastCommitDate = git log -1 --format="%ci" $branch 2>$null

    if ($lastCommitDate) {
        $commitDate = [DateTime]::Parse($lastCommitDate)

        if ($commitDate -lt $cutoffDate) {
            $daysSinceCommit = ((Get-Date) - $commitDate).Days

            $staleBranches += [PSCustomObject]@{
                Branch = $branch
                LastCommit = $commitDate.ToString("yyyy-MM-dd")
                DaysOld = $daysSinceCommit
                Type = "Local"
            }
        }
    }
}

# Get remote merged branches if requested
if ($IncludeRemote) {
    $remoteBranches = git branch -r --merged | ForEach-Object { $_.Trim() } |
        Where-Object { $_ -notmatch 'HEAD|' + $ExcludePattern }

    foreach ($branch in $remoteBranches) {
        $lastCommitDate = git log -1 --format="%ci" $branch 2>$null

        if ($lastCommitDate) {
            $commitDate = [DateTime]::Parse($lastCommitDate)

            if ($commitDate -lt $cutoffDate) {
                $daysSinceCommit = ((Get-Date) - $commitDate).Days

                $staleBranches += [PSCustomObject]@{
                    Branch = $branch
                    LastCommit = $commitDate.ToString("yyyy-MM-dd")
                    DaysOld = $daysSinceCommit
                    Type = "Remote"
                }
            }
        }
    }
}

Write-Host "STALE BRANCHES ANALYSIS" -ForegroundColor Yellow
Write-Host ""

if ($staleBranches.Count -eq 0) {
    Write-Host "✅ No stale branches found!" -ForegroundColor Green
    exit 0
}

$staleBranches | Format-Table -AutoSize -Property @(
    @{Label='Type'; Expression={$_.Type}; Width=8}
    @{Label='Branch'; Expression={$_.Branch}; Width=50}
    @{Label='Last Commit'; Expression={$_.LastCommit}; Width=12}
    @{Label='Days Old'; Expression={$_.DaysOld}; Align='Right'}
)

Write-Host ""
Write-Host "SUMMARY:" -ForegroundColor Cyan
Write-Host "  Total stale branches: $($staleBranches.Count)" -ForegroundColor Gray
Write-Host "  Local: $(($staleBranches | Where-Object {$_.Type -eq 'Local'}).Count)" -ForegroundColor Gray
Write-Host "  Remote: $(($staleBranches | Where-Object {$_.Type -eq 'Remote'}).Count)" -ForegroundColor Gray
Write-Host ""

if ($DryRun) {
    Write-Host "DRY RUN - No branches deleted" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To delete these branches, run without -DryRun" -ForegroundColor Cyan
} else {
    Write-Host "DELETING STALE BRANCHES..." -ForegroundColor Red
    Write-Host ""

    $deleted = 0
    $errors = 0

    foreach ($branch in $staleBranches) {
        try {
            if ($branch.Type -eq "Local") {
                Write-Host "  Deleting local: $($branch.Branch)" -ForegroundColor Gray
                git branch -d $branch.Branch 2>&1 | Out-Null

                if ($LASTEXITCODE -ne 0) {
                    # Force delete if -d fails
                    git branch -D $branch.Branch 2>&1 | Out-Null
                }
            } else {
                # Remote branch
                $remoteName = $branch.Branch -replace '^([^/]+)/.*', '$1'
                $branchName = $branch.Branch -replace '^[^/]+/', ''

                Write-Host "  Deleting remote: $($branch.Branch)" -ForegroundColor Gray
                git push $remoteName --delete $branchName 2>&1 | Out-Null
            }

            $deleted++
        } catch {
            Write-Host "  ❌ Error deleting $($branch.Branch): $_" -ForegroundColor Red
            $errors++
        }
    }

    Write-Host ""
    Write-Host "CLEANUP COMPLETE" -ForegroundColor Green
    Write-Host "  Deleted: $deleted" -ForegroundColor Green
    Write-Host "  Errors: $errors" -ForegroundColor Red
}
