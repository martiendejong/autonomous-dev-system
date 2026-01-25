<#
.SYNOPSIS
    Interactive Git helper for complex operations.

.DESCRIPTION
    Provides interactive wizards for complex Git operations including
    rebase, cherry-pick, conflict resolution, stash management.

    Features:
    - Interactive rebase wizard
    - Cherry-pick automation
    - Intelligent conflict resolution
    - Branch comparison and merge preview
    - Stash management
    - Commit history visualization
    - Undo last operation

.PARAMETER Operation
    Git operation: rebase, cherry-pick, resolve-conflicts, compare-branches, manage-stash, undo

.PARAMETER SourceBranch
    Source branch for operations

.PARAMETER TargetBranch
    Target branch for operations

.PARAMETER CommitHash
    Commit hash for cherry-pick

.PARAMETER DryRun
    Preview changes without executing

.EXAMPLE
    .\git-interactive.ps1 -Operation rebase -SourceBranch feature/new-feature -TargetBranch develop
    .\git-interactive.ps1 -Operation cherry-pick -CommitHash abc123
    .\git-interactive.ps1 -Operation resolve-conflicts
    .\git-interactive.ps1 -Operation compare-branches -SourceBranch feature/a -TargetBranch develop
    .\git-interactive.ps1 -Operation manage-stash
    .\git-interactive.ps1 -Operation undo
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("rebase", "cherry-pick", "resolve-conflicts", "compare-branches", "manage-stash", "undo")]
    [string]$Operation,

    [string]$SourceBranch,
    [string]$TargetBranch,
    [string]$CommitHash,
    [switch]$DryRun
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Interactive-Rebase {
    param([string]$SourceBranch, [string]$TargetBranch, [bool]$DryRun)

    Write-Host ""
    Write-Host "=== Interactive Rebase ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $TargetBranch) {
        $TargetBranch = Read-Host "Target branch (rebase onto)"
    }

    if (-not $TargetBranch) {
        Write-Host "ERROR: Target branch required" -ForegroundColor Red
        return
    }

    # Show commit history
    Write-Host "Commits to rebase:" -ForegroundColor Yellow
    git log --oneline "$TargetBranch..HEAD"
    Write-Host ""

    # Confirm
    $confirm = Read-Host "Proceed with rebase? (yes/no)"

    if ($confirm -ne "yes") {
        Write-Host "Cancelled" -ForegroundColor Yellow
        return
    }

    if ($DryRun) {
        Write-Host "DRY RUN: Would execute: git rebase $TargetBranch" -ForegroundColor Yellow
    } else {
        git rebase $TargetBranch

        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "Rebase encountered conflicts" -ForegroundColor Red
            Write-Host "Resolve conflicts and run: git rebase --continue" -ForegroundColor Yellow
            Write-Host "Or abort with: git rebase --abort" -ForegroundColor Yellow
        } else {
            Write-Host ""
            Write-Host "Rebase completed successfully!" -ForegroundColor Green
        }
    }
}

function Interactive-CherryPick {
    param([string]$CommitHash, [bool]$DryRun)

    Write-Host ""
    Write-Host "=== Interactive Cherry-Pick ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $CommitHash) {
        Write-Host "Recent commits:" -ForegroundColor Yellow
        git log --oneline -20
        Write-Host ""

        $CommitHash = Read-Host "Enter commit hash to cherry-pick"
    }

    if (-not $CommitHash) {
        Write-Host "ERROR: Commit hash required" -ForegroundColor Red
        return
    }

    # Show commit details
    Write-Host "Commit details:" -ForegroundColor Yellow
    git show --stat $CommitHash
    Write-Host ""

    # Confirm
    $confirm = Read-Host "Cherry-pick this commit? (yes/no)"

    if ($confirm -ne "yes") {
        Write-Host "Cancelled" -ForegroundColor Yellow
        return
    }

    if ($DryRun) {
        Write-Host "DRY RUN: Would execute: git cherry-pick $CommitHash" -ForegroundColor Yellow
    } else {
        git cherry-pick $CommitHash

        if ($LASTEXITCODE -ne 0) {
            Write-Host ""
            Write-Host "Cherry-pick encountered conflicts" -ForegroundColor Red
            Write-Host "Resolve conflicts and run: git cherry-pick --continue" -ForegroundColor Yellow
            Write-Host "Or abort with: git cherry-pick --abort" -ForegroundColor Yellow
        } else {
            Write-Host ""
            Write-Host "Cherry-pick completed successfully!" -ForegroundColor Green
        }
    }
}

function Resolve-Conflicts {
    Write-Host ""
    Write-Host "=== Conflict Resolution Helper ===" -ForegroundColor Cyan
    Write-Host ""

    # Check for conflicts
    $status = git status --porcelain

    $conflicts = $status | Where-Object { $_ -match '^UU|^AA|^DD' }

    if ($conflicts.Count -eq 0) {
        Write-Host "No conflicts found" -ForegroundColor Green
        return
    }

    Write-Host "Conflicted files:" -ForegroundColor Yellow
    foreach ($conflict in $conflicts) {
        $file = $conflict.Substring(3)
        Write-Host "  - $file" -ForegroundColor White
    }

    Write-Host ""

    # Interactive resolution
    foreach ($conflict in $conflicts) {
        $file = $conflict.Substring(3)

        Write-Host "Resolve: $file" -ForegroundColor Cyan
        Write-Host "  1. Accept ours (current branch)" -ForegroundColor White
        Write-Host "  2. Accept theirs (incoming branch)" -ForegroundColor White
        Write-Host "  3. Open in editor" -ForegroundColor White
        Write-Host "  4. Skip" -ForegroundColor White
        Write-Host ""

        $choice = Read-Host "Choice"

        switch ($choice) {
            "1" {
                git checkout --ours $file
                git add $file
                Write-Host "Accepted ours for $file" -ForegroundColor Green
            }
            "2" {
                git checkout --theirs $file
                git add $file
                Write-Host "Accepted theirs for $file" -ForegroundColor Green
            }
            "3" {
                code $file
                Write-Host "Opened $file in editor" -ForegroundColor Yellow
                Write-Host "Resolve manually, save, and run: git add $file" -ForegroundColor Yellow
            }
            "4" {
                Write-Host "Skipped $file" -ForegroundColor Yellow
            }
        }

        Write-Host ""
    }

    Write-Host "After resolving all conflicts, run:" -ForegroundColor Cyan
    Write-Host "  git commit (if merging)" -ForegroundColor White
    Write-Host "  git rebase --continue (if rebasing)" -ForegroundColor White
    Write-Host "  git cherry-pick --continue (if cherry-picking)" -ForegroundColor White
    Write-Host ""
}

function Compare-Branches {
    param([string]$SourceBranch, [string]$TargetBranch)

    Write-Host ""
    Write-Host "=== Branch Comparison ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $SourceBranch) {
        $SourceBranch = Read-Host "Source branch"
    }

    if (-not $TargetBranch) {
        $TargetBranch = Read-Host "Target branch"
    }

    Write-Host "Comparing: $SourceBranch -> $TargetBranch" -ForegroundColor Yellow
    Write-Host ""

    # Commits in source not in target
    Write-Host "Commits in $SourceBranch not in $TargetBranch:" -ForegroundColor Cyan
    git log --oneline "$TargetBranch..$SourceBranch"
    Write-Host ""

    # Commits in target not in source
    Write-Host "Commits in $TargetBranch not in $SourceBranch:" -ForegroundColor Cyan
    git log --oneline "$SourceBranch..$TargetBranch"
    Write-Host ""

    # File differences
    Write-Host "File differences:" -ForegroundColor Cyan
    git diff --stat "$TargetBranch...$SourceBranch"
    Write-Host ""

    # Merge preview
    Write-Host "Merge preview (dry run):" -ForegroundColor Cyan
    git merge --no-commit --no-ff $SourceBranch 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Merge preview successful - no conflicts" -ForegroundColor Green
        git merge --abort 2>$null
    } else {
        Write-Host "Merge would have conflicts" -ForegroundColor Red
        git merge --abort 2>$null
    }

    Write-Host ""
}

function Manage-Stash {
    Write-Host ""
    Write-Host "=== Stash Management ===" -ForegroundColor Cyan
    Write-Host ""

    while ($true) {
        # List stashes
        $stashes = git stash list

        if ($stashes.Count -eq 0) {
            Write-Host "No stashes found" -ForegroundColor Yellow
            Write-Host ""
            break
        }

        Write-Host "Stashed changes:" -ForegroundColor Yellow
        $i = 0
        foreach ($stash in $stashes) {
            Write-Host "  [$i] $stash" -ForegroundColor White
            $i++
        }

        Write-Host ""
        Write-Host "Actions:" -ForegroundColor Cyan
        Write-Host "  1. Apply stash" -ForegroundColor White
        Write-Host "  2. Pop stash" -ForegroundColor White
        Write-Host "  3. Drop stash" -ForegroundColor White
        Write-Host "  4. Show stash diff" -ForegroundColor White
        Write-Host "  5. Create new stash" -ForegroundColor White
        Write-Host "  6. Exit" -ForegroundColor White
        Write-Host ""

        $choice = Read-Host "Choice"

        switch ($choice) {
            "1" {
                $index = Read-Host "Stash index"
                git stash apply "stash@{$index}"
                Write-Host "Applied stash $index" -ForegroundColor Green
            }
            "2" {
                $index = Read-Host "Stash index"
                git stash pop "stash@{$index}"
                Write-Host "Popped stash $index" -ForegroundColor Green
            }
            "3" {
                $index = Read-Host "Stash index"
                git stash drop "stash@{$index}"
                Write-Host "Dropped stash $index" -ForegroundColor Green
            }
            "4" {
                $index = Read-Host "Stash index"
                git stash show -p "stash@{$index}"
            }
            "5" {
                $message = Read-Host "Stash message"
                git stash save $message
                Write-Host "Created new stash" -ForegroundColor Green
            }
            "6" {
                break
            }
        }

        Write-Host ""
    }
}

function Undo-LastOperation {
    Write-Host ""
    Write-Host "=== Undo Last Operation ===" -ForegroundColor Cyan
    Write-Host ""

    # Show recent operations
    Write-Host "Recent operations:" -ForegroundColor Yellow
    git reflog -10
    Write-Host ""

    Write-Host "What do you want to undo?" -ForegroundColor Cyan
    Write-Host "  1. Last commit (keep changes)" -ForegroundColor White
    Write-Host "  2. Last commit (discard changes)" -ForegroundColor White
    Write-Host "  3. Last merge" -ForegroundColor White
    Write-Host "  4. Go to specific reflog entry" -ForegroundColor White
    Write-Host "  5. Cancel" -ForegroundColor White
    Write-Host ""

    $choice = Read-Host "Choice"

    switch ($choice) {
        "1" {
            git reset --soft HEAD~1
            Write-Host "Undone last commit (changes kept in staging)" -ForegroundColor Green
        }
        "2" {
            $confirm = Read-Host "This will discard all changes. Are you sure? (yes/no)"
            if ($confirm -eq "yes") {
                git reset --hard HEAD~1
                Write-Host "Undone last commit (changes discarded)" -ForegroundColor Green
            }
        }
        "3" {
            git reset --merge ORIG_HEAD
            Write-Host "Undone last merge" -ForegroundColor Green
        }
        "4" {
            $reflog = Read-Host "Reflog entry (e.g., HEAD@{2})"
            git reset --hard $reflog
            Write-Host "Reset to $reflog" -ForegroundColor Green
        }
        "5" {
            Write-Host "Cancelled" -ForegroundColor Yellow
        }
    }

    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== Git Interactive Helper ===" -ForegroundColor Cyan
Write-Host ""

# Execute operation
switch ($Operation) {
    "rebase" {
        Interactive-Rebase -SourceBranch $SourceBranch -TargetBranch $TargetBranch -DryRun $DryRun
    }
    "cherry-pick" {
        Interactive-CherryPick -CommitHash $CommitHash -DryRun $DryRun
    }
    "resolve-conflicts" {
        Resolve-Conflicts
    }
    "compare-branches" {
        Compare-Branches -SourceBranch $SourceBranch -TargetBranch $TargetBranch
    }
    "manage-stash" {
        Manage-Stash
    }
    "undo" {
        Undo-LastOperation
    }
}

Write-Host "=== Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
