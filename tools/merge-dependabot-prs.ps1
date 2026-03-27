<#
.SYNOPSIS
    Batch merge or close Dependabot PRs based on merge status

.DESCRIPTION
    Automatically processes all open Dependabot PRs:
    - Merges PRs that are MERGEABLE
    - Closes PRs with conflicts (Dependabot will recreate them)
    - Provides detailed summary report

.PARAMETER Repo
    Repository in format "owner/repo" (default: martiendejong/client-manager)

.PARAMETER DryRun
    Preview actions without making changes

.PARAMETER AutoMerge
    Merge without confirmation prompts

.PARAMETER ClosureMessage
    Custom message for closing conflicting PRs

.EXAMPLE
    .\merge-dependabot-prs.ps1 -DryRun
    Preview what would happen without making changes

.EXAMPLE
    .\merge-dependabot-prs.ps1 -AutoMerge
    Automatically merge all mergeable PRs without prompts

.EXAMPLE
    .\merge-dependabot-prs.ps1 -Repo "myorg/myrepo"
    Process PRs in a different repository
#>

param(
    [string]$Repo = "martiendejong/client-manager",
    [switch]$DryRun,
    [switch]$AutoMerge,
    [string]$ClosureMessage = "Closing due to merge conflicts. Dependabot will automatically recreate this PR against the updated develop branch."
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Dependabot PR Batch Processor" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Repository: $Repo" -ForegroundColor White
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN (preview only)' } else { 'LIVE' })" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Green' })
Write-Host ""

# Get all open PRs
Write-Host "Fetching open PRs..." -ForegroundColor Gray
$allPRs = gh pr list --repo $Repo --limit 100 --json number,author,title,state 2>&1 | ConvertFrom-Json

# Filter Dependabot PRs
$dependabotPRs = $allPRs | Where-Object { $_.author.login -eq "dependabot[bot]" }

if ($dependabotPRs.Count -eq 0) {
    Write-Host "✓ No Dependabot PRs found" -ForegroundColor Green
    exit 0
}

Write-Host "Found $($dependabotPRs.Count) Dependabot PR(s)" -ForegroundColor Cyan
Write-Host ""

$merged = @()
$closed = @()
$skipped = @()
$errors = @()

foreach ($pr in $dependabotPRs) {
    $number = $pr.number
    Write-Host "PR #$number`: $($pr.title)" -ForegroundColor White

    # Get detailed PR info
    try {
        $prDetail = gh pr view $number --repo $Repo --json mergeable,state 2>&1 | ConvertFrom-Json
        $mergeable = $prDetail.mergeable

        Write-Host "  Status: $mergeable" -ForegroundColor $(
            switch ($mergeable) {
                "MERGEABLE" { "Green" }
                "CONFLICTING" { "Yellow" }
                default { "Gray" }
            }
        )

        if ($mergeable -eq "MERGEABLE") {
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would merge and delete branch" -ForegroundColor Yellow
                $merged += $number
            } else {
                if (-not $AutoMerge) {
                    $confirm = Read-Host "  Merge PR #$number? (y/N)"
                    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
                        Write-Host "  Skipped by user" -ForegroundColor Gray
                        $skipped += $number
                        continue
                    }
                }

                Write-Host "  Merging..." -ForegroundColor Green
                gh pr merge $number --repo $Repo --squash --delete-branch 2>&1 | Out-Null
                Write-Host "  ✓ Merged" -ForegroundColor Green
                $merged += $number
            }
        }
        elseif ($mergeable -eq "CONFLICTING") {
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would close with conflict message" -ForegroundColor Yellow
                $closed += $number
            } else {
                Write-Host "  Closing (will be recreated)..." -ForegroundColor Yellow
                gh pr close $number --repo $Repo --comment $ClosureMessage 2>&1 | Out-Null
                Write-Host "  ✓ Closed" -ForegroundColor Yellow
                $closed += $number
            }
        }
        else {
            Write-Host "  Skipped (status: $mergeable)" -ForegroundColor Gray
            $skipped += $number
        }
    }
    catch {
        Write-Host "  ✗ Error: $_" -ForegroundColor Red
        $errors += @{ Number = $number; Error = $_.ToString() }
    }

    Write-Host ""
}

# Summary Report
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Summary Report" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Merged:  $($merged.Count)" -ForegroundColor Green
Write-Host "Closed:  $($closed.Count)" -ForegroundColor Yellow
Write-Host "Skipped: $($skipped.Count)" -ForegroundColor Gray
Write-Host "Errors:  $($errors.Count)" -ForegroundColor Red
Write-Host ""

if ($merged.Count -gt 0) {
    Write-Host "Merged PRs: $($merged -join ', ')" -ForegroundColor Green
}
if ($closed.Count -gt 0) {
    Write-Host "Closed PRs: $($closed -join ', ')" -ForegroundColor Yellow
}
if ($skipped.Count -gt 0) {
    Write-Host "Skipped PRs: $($skipped -join ', ')" -ForegroundColor Gray
}
if ($errors.Count -gt 0) {
    Write-Host "Failed PRs:" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "  PR #$($err.Number): $($err.Error)" -ForegroundColor Red
    }
}

if ($DryRun) {
    Write-Host ""
    Write-Host "This was a DRY RUN - no changes were made" -ForegroundColor Yellow
    Write-Host "Run without -DryRun to apply changes" -ForegroundColor Yellow
}
