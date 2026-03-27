<#
.SYNOPSIS
    Comprehensive worktree cleanup and pool synchronization.

.DESCRIPTION
    Handles multiple worktree issues:
    - Orphaned worktrees (folders that don't match pool seats)
    - Pool/reality desync (FREE seats with worktrees, BUSY seats without)
    - Stale worktrees (no recent activity)
    - Invalid worktree folders

.PARAMETER DryRun
    Show what would be cleaned without making changes

.PARAMETER Force
    Clean without confirmation

.PARAMETER SyncOnly
    Only sync pool.md with reality, don't remove worktrees

.EXAMPLE
    .\worktree-cleanup.ps1 -DryRun
    .\worktree-cleanup.ps1 -SyncOnly
    .\worktree-cleanup.ps1 -Force
#>

param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$SyncOnly
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$PoolPath = "C:\scripts\_machine\worktrees.pool.md"
$WorkerAgentsPath = "C:\Projects\worker-agents"
$BaseRepos = @("C:\Projects\client-manager", "C:\Projects\hazina")

function Get-PoolSeats {
    $seats = @{}
    if (Test-Path $PoolPath) {
        $content = Get-Content $PoolPath -Raw
        $lines = $content -split "`n" | Where-Object { $_ -match '^\| agent-' }
        foreach ($line in $lines) {
            if ($line -match '\| (agent-\d+) .* \| (FREE|BUSY|STALE|BROKEN) \|') {
                $seats[$matches[1]] = $matches[2]
            }
        }
    }
    return $seats
}

function Get-ActualWorktrees {
    $worktrees = @{}

    if (-not (Test-Path $WorkerAgentsPath)) {
        return $worktrees
    }

    Get-ChildItem $WorkerAgentsPath -Directory | ForEach-Object {
        $seatName = $_.Name
        $repos = @()

        Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $repoPath = $_.FullName
            $branch = git -C $repoPath branch --show-current 2>$null
            if ($branch) {
                $repos += @{
                    name = $_.Name
                    path = $repoPath
                    branch = $branch
                }
            }
        }

        if ($repos.Count -gt 0) {
            $worktrees[$seatName] = $repos
        }
    }

    return $worktrees
}

function Test-ValidSeatName {
    param([string]$Name)
    return $Name -match '^agent-\d+$'
}

# Main execution
Write-Host ""
Write-Host "=== WORKTREE CLEANUP ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } elseif ($SyncOnly) { 'SYNC ONLY' } else { 'FULL CLEANUP' })"
Write-Host ""

$poolSeats = Get-PoolSeats
$actualWorktrees = Get-ActualWorktrees

Write-Host "Pool seats: $($poolSeats.Count)" -ForegroundColor DarkGray
Write-Host "Folders with worktrees: $($actualWorktrees.Count)" -ForegroundColor DarkGray
Write-Host ""

$issues = @{
    orphaned = @()      # Folders that aren't valid seat names
    desyncFree = @()    # FREE in pool but has worktrees
    desyncBusy = @()    # BUSY in pool but no worktrees
    needsCleanup = @()  # Worktrees to remove
}

# Find orphaned folders (not valid seat names)
foreach ($folder in $actualWorktrees.Keys) {
    if (-not (Test-ValidSeatName -Name $folder)) {
        $issues.orphaned += @{
            folder = $folder
            repos = $actualWorktrees[$folder]
        }
    }
}

# Find desync issues
foreach ($seat in $poolSeats.Keys) {
    $status = $poolSeats[$seat]
    $hasWorktrees = $actualWorktrees.ContainsKey($seat)

    if ($status -eq "FREE" -and $hasWorktrees) {
        $issues.desyncFree += @{
            seat = $seat
            repos = $actualWorktrees[$seat]
        }
    } elseif ($status -eq "BUSY" -and -not $hasWorktrees) {
        $issues.desyncBusy += $seat
    }
}

# Report issues
Write-Host "ISSUES FOUND:" -ForegroundColor Yellow
Write-Host ""

if ($issues.orphaned.Count -gt 0) {
    Write-Host "ORPHANED FOLDERS (invalid seat names):" -ForegroundColor Red
    foreach ($item in $issues.orphaned) {
        Write-Host "  $($item.folder)/" -ForegroundColor Red
        foreach ($repo in $item.repos) {
            Write-Host "    - $($repo.name) @ $($repo.branch)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

if ($issues.desyncFree.Count -gt 0) {
    Write-Host "DESYNC: Marked FREE but have worktrees:" -ForegroundColor Yellow
    foreach ($item in $issues.desyncFree) {
        Write-Host "  $($item.seat):" -ForegroundColor Yellow
        foreach ($repo in $item.repos) {
            Write-Host "    - $($repo.name) @ $($repo.branch)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}

if ($issues.desyncBusy.Count -gt 0) {
    Write-Host "DESYNC: Marked BUSY but empty:" -ForegroundColor Yellow
    foreach ($seat in $issues.desyncBusy) {
        Write-Host "  $seat" -ForegroundColor Yellow
    }
    Write-Host ""
}

$totalIssues = $issues.orphaned.Count + $issues.desyncFree.Count + $issues.desyncBusy.Count

if ($totalIssues -eq 0) {
    Write-Host "NO ISSUES FOUND - System is consistent" -ForegroundColor Green
    Write-Host ""
    exit 0
}

Write-Host "Total issues: $totalIssues" -ForegroundColor White
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] No changes made. Run without -DryRun to fix." -ForegroundColor Cyan
    exit 0
}

if (-not $Force) {
    $confirm = Read-Host "Fix these issues? (y/N)"
    if ($confirm -ne 'y') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "FIXING ISSUES..." -ForegroundColor Cyan
Write-Host ""

# Fix orphaned folders
foreach ($item in $issues.orphaned) {
    $folderPath = Join-Path $WorkerAgentsPath $item.folder
    Write-Host "Removing orphaned folder: $($item.folder)" -ForegroundColor Yellow

    if (-not $SyncOnly) {
        # Remove worktrees from base repos first
        foreach ($repo in $item.repos) {
            foreach ($basePath in $BaseRepos) {
                git -C $basePath worktree remove $repo.path --force 2>$null
            }
        }
        # Remove the folder
        Remove-Item -Path $folderPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [REMOVED] $folderPath" -ForegroundColor Green
    }
}

# Fix desync FREE (mark as BUSY or clean up)
$poolContent = Get-Content $PoolPath -Raw
foreach ($item in $issues.desyncFree) {
    Write-Host "Fixing desync for $($item.seat)..." -ForegroundColor Yellow

    if ($SyncOnly) {
        # Update pool to BUSY
        $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        $poolContent = $poolContent -replace "(\| $($item.seat) [^|]* \|[^|]*\|[^|]*\|) FREE (\|)", "`$1 BUSY `$2"
        Write-Host "  [SYNCED] $($item.seat) -> BUSY" -ForegroundColor Green
    } else {
        # Remove worktrees and mark FREE
        foreach ($repo in $item.repos) {
            foreach ($basePath in $BaseRepos) {
                git -C $basePath worktree remove $repo.path --force 2>$null
            }
        }
        $seatPath = Join-Path $WorkerAgentsPath $item.seat
        Remove-Item -Path $seatPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [CLEANED] $($item.seat) worktrees removed" -ForegroundColor Green
    }
}

# Fix desync BUSY (mark as FREE)
foreach ($seat in $issues.desyncBusy) {
    Write-Host "Fixing desync for $seat..." -ForegroundColor Yellow
    $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $poolContent = $poolContent -replace "(\| $seat [^|]* \|[^|]*\|[^|]*\|) BUSY (\|)", "`$1 FREE `$2"
    Write-Host "  [SYNCED] $seat -> FREE" -ForegroundColor Green
}

# Save updated pool
$poolContent | Set-Content $PoolPath -Encoding UTF8

# Prune worktrees in base repos
Write-Host ""
Write-Host "Pruning worktree references..." -ForegroundColor Cyan
foreach ($basePath in $BaseRepos) {
    if (Test-Path $basePath) {
        git -C $basePath worktree prune 2>$null
        Write-Host "  [PRUNED] $(Split-Path $basePath -Leaf)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "CLEANUP COMPLETE" -ForegroundColor Green
Write-Host ""
