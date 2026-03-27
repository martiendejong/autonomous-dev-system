<#
.SYNOPSIS
    Commits all changes in active worktrees and releases them to their base branches.

.DESCRIPTION
    For each active worktree:
    1. Checks for uncommitted changes
    2. Commits changes with auto-generated message (or prompts for message)
    3. Pushes to remote
    4. Switches worktree back to its base branch (agent-001, agent-002, etc.)
    5. Updates worktrees.pool.md to mark seat as FREE

.PARAMETER DryRun
    Show what would be done without making changes.

.PARAMETER AutoCommit
    Automatically commit with generated message (no prompt).

.PARAMETER SkipPush
    Don't push commits to remote.

.PARAMETER Seats
    Specific seats to release (e.g., "agent-001", "agent-003"). Default: all with worktrees.

.EXAMPLE
    .\worktree-release-all.ps1 -DryRun

.EXAMPLE
    .\worktree-release-all.ps1 -AutoCommit

.EXAMPLE
    .\worktree-release-all.ps1 -Seats "agent-003"
#>

param(
    [switch]$DryRun,
    [switch]$AutoCommit,
    [switch]$SkipPush,
    [string[]]$Seats = @()

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

)

$ErrorActionPreference = "Continue"

# Configuration
$WorkerAgentsRoot = "C:\Projects\worker-agents"
$BaseRepos = @(
    "C:\Projects\client-manager",
    "C:\Projects\hazina"
)
$PoolFile = "C:\scripts\_machine\worktrees.pool.md"

# Colors
function Write-Header($text) {
    Write-Host "`n$text" -ForegroundColor Cyan
    Write-Host ("=" * $text.Length) -ForegroundColor DarkCyan
}

function Write-Step($text) {
    Write-Host "  -> $text" -ForegroundColor White
}

function Write-Success($text) {
    Write-Host "  [OK] $text" -ForegroundColor Green
}

function Write-Warn($text) {
    Write-Host "  [WARN] $text" -ForegroundColor Yellow
}

function Write-Err($text) {
    Write-Host "  [ERR] $text" -ForegroundColor Red
}

function Write-DryRun($text) {
    Write-Host "  [DRY-RUN] $text" -ForegroundColor Magenta
}

# Get all worktrees from base repos
function Get-AllWorktrees {
    $worktrees = @()

    foreach ($repo in $BaseRepos) {
        if (-not (Test-Path $repo)) { continue }

        $repoName = Split-Path $repo -Leaf
        Push-Location $repo
        try {
            $output = git worktree list --porcelain 2>$null
            if ($LASTEXITCODE -ne 0) { continue }

            $current = @{}
            foreach ($line in $output) {
                if ($line -match '^worktree (.+)$') {
                    if ($current.Count -gt 0 -and $current.Path -ne $repo -and $current.Path -ne $repo.Replace('\', '/')) {
                        $worktrees += [PSCustomObject]$current
                    }
                    $current = @{
                        Path = $matches[1]
                        Branch = ""
                        Commit = ""
                        Repo = $repoName
                        BaseRepo = $repo
                    }
                }
                elseif ($line -match '^HEAD ([a-f0-9]+)$') {
                    $current.Commit = $matches[1].Substring(0, 7)
                }
                elseif ($line -match '^branch refs/heads/(.+)$') {
                    $current.Branch = $matches[1]
                }
            }
            if ($current.Count -gt 0 -and $current.Path -ne $repo -and $current.Path -ne $repo.Replace('\', '/')) {
                $worktrees += [PSCustomObject]$current
            }
        }
        finally {
            Pop-Location
        }
    }

    return $worktrees
}

# Extract agent seat from path
function Get-AgentSeat {
    param([string]$Path)

    if ($Path -match 'worker-agents[/\\](agent-\d+)') {
        return $matches[1]
    }
    return $null
}

# Get base branch name for a seat (agent-001 -> agent001)
function Get-BaseBranch {
    param([string]$Seat)
    return $Seat -replace '-', ''
}

# Check if worktree has uncommitted changes
function Test-HasChanges {
    param([string]$WorktreePath)

    Push-Location $WorktreePath
    try {
        $status = git status --porcelain 2>$null
        return ($status -and $status.Length -gt 0)
    }
    finally {
        Pop-Location
    }
}

# Get change summary for commit message
function Get-ChangeSummary {
    param([string]$WorktreePath)

    Push-Location $WorktreePath
    try {
        $status = git status --porcelain 2>$null
        $added = @($status | Where-Object { $_ -match '^\?\?' }).Count
        $modified = @($status | Where-Object { $_ -match '^.M' -or $_ -match '^M' }).Count
        $deleted = @($status | Where-Object { $_ -match '^.D' -or $_ -match '^D' }).Count

        $parts = @()
        if ($added -gt 0) { $parts += "$added added" }
        if ($modified -gt 0) { $parts += "$modified modified" }
        if ($deleted -gt 0) { $parts += "$deleted deleted" }

        return $parts -join ", "
    }
    finally {
        Pop-Location
    }
}

# Commit changes in worktree
function Invoke-CommitChanges {
    param(
        [string]$WorktreePath,
        [string]$Repo,
        [string]$Branch,
        [switch]$Auto
    )

    Push-Location $WorktreePath
    try {
        $summary = Get-ChangeSummary -WorktreePath $WorktreePath

        if ($Auto) {
            $message = "WIP: Auto-commit before worktree release ($summary)"
        }
        else {
            Write-Host ""
            Write-Host ("  Changes in " + $Repo + " @ " + $Branch) -ForegroundColor Yellow
            git status --short
            Write-Host ""
            $message = Read-Host "  Enter commit message (or press Enter for auto-message)"
            if ([string]::IsNullOrWhiteSpace($message)) {
                $message = "WIP: Auto-commit before worktree release ($summary)"
            }
        }

        $fullMessage = $message + "`n`nCo-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"

        git add -A
        git commit -m $fullMessage

        return $true
    }
    catch {
        Write-Err ("Failed to commit: " + $_.Exception.Message)
        return $false
    }
    finally {
        Pop-Location
    }
}

# Push changes to remote
function Invoke-PushChanges {
    param([string]$WorktreePath)

    Push-Location $WorktreePath
    try {
        $output = git push 2>&1
        # git push returns 0 on success, even if "Everything up-to-date"
        return $true
    }
    catch {
        return $false
    }
    finally {
        Pop-Location
    }
}

# Switch worktree to base branch
function Switch-WorktreeBranch {
    param(
        [string]$WorktreePath,
        [string]$BaseBranch,
        [string]$BaseRepo
    )

    Push-Location $WorktreePath
    try {
        # Check if base branch exists
        $null = git show-ref --verify --quiet "refs/heads/$BaseBranch" 2>$null
        if ($LASTEXITCODE -ne 0) {
            # Create the base branch from current HEAD
            git branch $BaseBranch 2>$null
        }

        # Switch to base branch
        git checkout $BaseBranch 2>&1 | Out-Null
        return $LASTEXITCODE -eq 0
    }
    finally {
        Pop-Location
    }
}

# Update pool file to mark seat as FREE
function Update-PoolStatus {
    param(
        [string]$Seat,
        [string]$PoolPath
    )

    if (-not (Test-Path $PoolPath)) {
        Write-Warn "Pool file not found: $PoolPath"
        return $false
    }

    $content = Get-Content $PoolPath -Raw
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    # Simple line-by-line replacement
    $lines = Get-Content $PoolPath
    $newLines = @()
    $updated = $false

    foreach ($line in $lines) {
        if ($line -match "^\|\s*$Seat\s*\|" -and $line -match "\|\s*BUSY\s*\|") {
            $line = $line -replace '\|\s*BUSY\s*\|', '| FREE |'
            $updated = $true
        }
        $newLines += $line
    }

    if ($updated) {
        Set-Content $PoolPath -Value $newLines
        return $true
    }

    return $false
}

# Main execution
Write-Header "Worktree Release Tool"

if ($DryRun) {
    Write-Host "Running in DRY-RUN mode - no changes will be made" -ForegroundColor Magenta
}

Write-Host "Scanning worktrees..." -ForegroundColor Gray

$allWorktrees = Get-AllWorktrees

# Group by seat
$seatWorktrees = @{}
foreach ($wt in $allWorktrees) {
    $seat = Get-AgentSeat -Path $wt.Path
    if ($seat) {
        if (-not $seatWorktrees.ContainsKey($seat)) {
            $seatWorktrees[$seat] = @()
        }
        $seatWorktrees[$seat] += $wt
    }
}

# Filter seats if specified
if ($Seats.Count -gt 0) {
    $filtered = @{}
    foreach ($seat in $Seats) {
        if ($seatWorktrees.ContainsKey($seat)) {
            $filtered[$seat] = $seatWorktrees[$seat]
        }
        else {
            Write-Warn "Seat $seat has no active worktrees"
        }
    }
    $seatWorktrees = $filtered
}

if ($seatWorktrees.Count -eq 0) {
    Write-Host "`nNo worktrees to release." -ForegroundColor Yellow
    exit 0
}

Write-Host ("`nFound " + $seatWorktrees.Count + " seat(s) with worktrees:") -ForegroundColor White
foreach ($seat in $seatWorktrees.Keys | Sort-Object) {
    $repos = ($seatWorktrees[$seat] | ForEach-Object { $_.Repo }) -join ", "
    Write-Host "  - $seat ($repos)" -ForegroundColor Gray
}

# Process each seat
$results = @{
    Committed = 0
    Pushed = 0
    Released = 0
    Errors = 0
}

foreach ($seat in $seatWorktrees.Keys | Sort-Object) {
    Write-Header "Processing $seat"

    $baseBranch = Get-BaseBranch -Seat $seat
    $worktrees = $seatWorktrees[$seat]

    foreach ($wt in $worktrees) {
        Write-Host ("`n  Repository: " + $wt.Repo) -ForegroundColor Yellow
        Write-Host ("  Current branch: " + $wt.Branch) -ForegroundColor Gray
        Write-Host ("  Target branch: " + $baseBranch) -ForegroundColor Gray

        # Check for changes
        $hasChanges = Test-HasChanges -WorktreePath $wt.Path

        if ($hasChanges) {
            Write-Step "Uncommitted changes detected"

            if ($DryRun) {
                $summary = Get-ChangeSummary -WorktreePath $wt.Path
                Write-DryRun "Would commit: $summary"
            }
            else {
                $committed = Invoke-CommitChanges -WorktreePath $wt.Path -Repo $wt.Repo -Branch $wt.Branch -Auto:$AutoCommit
                if ($committed) {
                    Write-Success "Changes committed"
                    $results.Committed++
                }
                else {
                    Write-Err "Failed to commit changes"
                    $results.Errors++
                    continue
                }
            }
        }
        else {
            Write-Success "No uncommitted changes"
        }

        # Merge develop into feature branch (NEW: catch conflicts before PR creation)
        if ($wt.Branch -ne "develop" -and $wt.Branch -ne "main" -and $wt.Branch -notmatch "^agent\d+$") {
            if ($DryRun) {
                Write-DryRun "Would merge develop into $($wt.Branch)"
            }
            else {
                Write-Step "Merging develop into feature branch..."
                Push-Location $wt.Path
                try {
                    git fetch origin develop 2>&1 | Out-Null
                    $mergeOutput = git merge origin/develop --no-edit 2>&1

                    if ($LASTEXITCODE -ne 0) {
                        Write-Err "MERGE CONFLICTS detected with develop!"
                        Write-Host ""
                        Write-Host "  Conflicts in:" -ForegroundColor Red
                        git diff --name-only --diff-filter=U | ForEach-Object {
                            Write-Host "    - $_" -ForegroundColor Yellow
                        }
                        Write-Host ""
                        Write-Host "  ACTION REQUIRED:" -ForegroundColor Yellow
                        Write-Host "  1. Resolve conflicts manually in: $($wt.Path)"
                        Write-Host "  2. git add <resolved-files>"
                        Write-Host "  3. git merge --continue"
                        Write-Host "  4. Re-run this script"
                        Write-Host ""
                        $results.Errors++
                        continue
                    }

                    Write-Success "Successfully merged develop"
                }
                finally {
                    Pop-Location
                }
            }
        }

        # Run pre-flight validation (NEW: catch issues before PR creation)
        if ($wt.Branch -ne "develop" -and $wt.Branch -ne "main" -and $wt.Branch -notmatch "^agent\d+$") {
            if ($DryRun) {
                Write-DryRun "Would run pr-preflight.ps1"
            }
            else {
                Write-Step "Running pre-flight validation..."
                Push-Location $wt.Path
                try {
                    $preflightScript = "C:\scripts\tools\pr-preflight.ps1"
                    if (Test-Path $preflightScript) {
                        $preflightOutput = & $preflightScript -Repo $wt.Repo -Branch $wt.Branch 2>&1
                        $preflightExitCode = $LASTEXITCODE

                        if ($preflightExitCode -eq 0) {
                            Write-Success "Pre-flight validation passed"
                        }
                        elseif ($preflightExitCode -eq 1) {
                            Write-Err "Pre-flight validation FAILED"
                            Write-Host ""
                            Write-Host "  Fix issues before creating PR:" -ForegroundColor Yellow
                            Write-Host $preflightOutput
                            Write-Host ""
                            $results.Errors++
                            continue
                        }
                        else {
                            Write-Warn "Pre-flight validation had warnings (continuing)"
                        }
                    }
                    else {
                        Write-Warn "pr-preflight.ps1 not found - skipping validation"
                    }
                }
                finally {
                    Pop-Location
                }
            }
        }

        # Push changes (now includes merged state + validated code)
        if (-not $SkipPush) {
            if ($DryRun) {
                Write-DryRun "Would push to remote"
            }
            else {
                Write-Step "Pushing validated code to remote..."
                $pushed = Invoke-PushChanges -WorktreePath $wt.Path
                if ($pushed) {
                    Write-Success "Pushed to remote"
                    $results.Pushed++
                }
                else {
                    Write-Warn "Push failed (may be up-to-date)"
                }
            }
        }

        # Switch to base branch
        if ($DryRun) {
            Write-DryRun "Would switch to branch: $baseBranch"
        }
        else {
            Write-Step "Switching to $baseBranch..."
            $switched = Switch-WorktreeBranch -WorktreePath $wt.Path -BaseBranch $baseBranch -BaseRepo $wt.BaseRepo
            if ($switched) {
                Write-Success "Switched to $baseBranch"
                $results.Released++
            }
            else {
                Write-Err "Failed to switch branch"
                $results.Errors++
            }
        }
    }

    # Update pool file
    if ($DryRun) {
        Write-DryRun "Would update pool file: $seat -> FREE"
    }
    else {
        Write-Step "Updating pool status..."
        $updated = Update-PoolStatus -Seat $seat -PoolPath $PoolFile
        if ($updated) {
            Write-Success "Pool status updated to FREE"
        }
        else {
            Write-Warn "Could not update pool status (may already be FREE)"
        }
    }
}

# Summary
Write-Header "Summary"

if ($DryRun) {
    Write-Host "  DRY-RUN complete - no changes were made" -ForegroundColor Magenta
}
else {
    $commitColor = if ($results.Committed -gt 0) { "Green" } else { "Gray" }
    $pushColor = if ($results.Pushed -gt 0) { "Green" } else { "Gray" }
    $releaseColor = if ($results.Released -gt 0) { "Green" } else { "Gray" }

    Write-Host ("  Commits: " + $results.Committed) -ForegroundColor $commitColor
    Write-Host ("  Pushes: " + $results.Pushed) -ForegroundColor $pushColor
    Write-Host ("  Released: " + $results.Released) -ForegroundColor $releaseColor

    if ($results.Errors -gt 0) {
        Write-Host ("  Errors: " + $results.Errors) -ForegroundColor Red
    }
}

Write-Host ""
