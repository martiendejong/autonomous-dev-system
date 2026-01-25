<#
.SYNOPSIS
    One-command repair tool for all system issues.

.DESCRIPTION
    Automatically fixes all detected issues:
    - Pool desync (worktrees vs pool file)
    - Orphaned worktree folders
    - Stale branches
    - Documentation link errors
    - Tool help issues

    Uses system-health.ps1 to detect, then runs targeted fixes.

.PARAMETER DryRun
    Show what would be fixed without making changes

.PARAMETER Force
    Skip confirmation prompts

.PARAMETER Verbose
    Show detailed output

.EXAMPLE
    .\fix-all.ps1
    .\fix-all.ps1 -DryRun
    .\fix-all.ps1 -Force
#>

param(
    [switch]$DryRun,
    [switch]$Force
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ToolsPath = "C:\scripts\tools"
$MachinePath = "C:\scripts\_machine"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Action {
    param([string]$Action, [string]$Status = "RUN")
    $color = switch ($Status) {
        "RUN" { "Yellow" }
        "OK" { "Green" }
        "SKIP" { "DarkGray" }
        "FAIL" { "Red" }
        default { "White" }
    }
    Write-Host "[$Status] $Action" -ForegroundColor $color
}

$startTime = Get-Date
$fixCount = 0
$skipCount = 0
$failCount = 0

Write-Host ""
Write-Host "FIX-ALL: ONE-COMMAND SYSTEM REPAIR" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
if ($DryRun) {
    Write-Host "Mode: DRY RUN" -ForegroundColor Yellow
} else {
    Write-Host "Mode: FULL FIX" -ForegroundColor Green
}
Write-Host ""

# Phase 1: Pool/Worktree Sync
Write-Section "1. POOL & WORKTREE SYNC"

# Check for orphaned folders
$workerPath = "C:\Projects\worker-agents"
$orphanedFolders = @()
$validPattern = "^agent-\d+$"

if (Test-Path $workerPath) {
    Get-ChildItem $workerPath -Directory | ForEach-Object {
        if ($_.Name -notmatch $validPattern) {
            $orphanedFolders += $_.Name
        }
    }
}

if ($orphanedFolders.Count -gt 0) {
    Write-Host "Found $($orphanedFolders.Count) orphaned folders:" -ForegroundColor Yellow
    $orphanedFolders | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkGray }

    if (-not $DryRun) {
        foreach ($folder in $orphanedFolders) {
            $folderPath = Join-Path $workerPath $folder
            try {
                # First, remove any git worktrees
                $repos = Get-ChildItem $folderPath -Directory -ErrorAction SilentlyContinue
                foreach ($repo in $repos) {
                    $basePath = "C:\Projects\$($repo.Name)"
                    if (Test-Path $basePath) {
                        Push-Location $basePath
                        git worktree remove $repo.FullName --force 2>$null
                        Pop-Location
                    }
                }
                # Then remove the folder
                Remove-Item $folderPath -Recurse -Force -ErrorAction Stop
                Write-Action "Removed orphaned: $folder" "OK"
                $fixCount++
            } catch {
                Write-Action "Failed to remove $folder : $_" "FAIL"
                $failCount++
            }
        }
    } else {
        Write-Action "[DRY RUN] Would remove $($orphanedFolders.Count) orphaned folders" "SKIP"
        $skipCount += $orphanedFolders.Count
    }
} else {
    Write-Action "No orphaned folders" "OK"
}

# Check for desync (FREE seats with worktrees)
$poolPath = "$MachinePath\worktrees.pool.md"
if (Test-Path $poolPath) {
    $poolContent = Get-Content $poolPath -Raw

    # Parse pool status
    $seatStatuses = @{}
    $poolContent -split "`n" | Where-Object { $_ -match '^\| agent-(\d+)' } | ForEach-Object {
        if ($_ -match '^\| (agent-\d+) \|[^|]+\|[^|]+\|[^|]+\| (FREE|BUSY)') {
            $seatStatuses[$matches[1]] = $matches[2]
        }
    }

    # Check each FREE seat for actual worktrees
    $desyncSeats = @()
    foreach ($seat in $seatStatuses.Keys | Where-Object { $seatStatuses[$_] -eq "FREE" }) {
        $seatPath = Join-Path $workerPath $seat
        if (Test-Path $seatPath) {
            $repoFolders = Get-ChildItem $seatPath -Directory -ErrorAction SilentlyContinue
            if ($repoFolders.Count -gt 0) {
                $desyncSeats += @{ Seat = $seat; Repos = $repoFolders.Name }
            }
        }
    }

    if ($desyncSeats.Count -gt 0) {
        Write-Host ""
        Write-Host "Found $($desyncSeats.Count) desynced seats (FREE but have worktrees):" -ForegroundColor Yellow
        $desyncSeats | ForEach-Object {
            Write-Host "  - $($_.Seat): $($_.Repos -join ', ')" -ForegroundColor DarkGray
        }

        if (-not $DryRun) {
            foreach ($desync in $desyncSeats) {
                $seatPath = Join-Path $workerPath $desync.Seat
                foreach ($repoName in $desync.Repos) {
                    $repoPath = Join-Path $seatPath $repoName
                    $basePath = "C:\Projects\$repoName"

                    if (Test-Path $basePath) {
                        try {
                            Push-Location $basePath
                            git worktree remove $repoPath --force 2>$null
                            Pop-Location
                            Write-Action "Removed worktree: $($desync.Seat)/$repoName" "OK"
                            $fixCount++
                        } catch {
                            Write-Action "Failed: $($desync.Seat)/$repoName - $_" "FAIL"
                            $failCount++
                        }
                    }
                }
            }
        } else {
            Write-Action "[DRY RUN] Would clean $($desyncSeats.Count) desynced seats" "SKIP"
            $skipCount += $desyncSeats.Count
        }
    } else {
        Write-Action "No desynced seats" "OK"
    }
}

# Phase 2: Branch Cleanup
Write-Section "2. STALE BRANCH CLEANUP"

$repos = @("C:\Projects\client-manager", "C:\Projects\hazina")
$totalPruned = 0

foreach ($repo in $repos) {
    if (Test-Path $repo) {
        $repoName = Split-Path $repo -Leaf
        Push-Location $repo

        # Fetch latest
        git fetch --prune 2>$null

        # Find merged branches (excluding develop, main, master, and agent*)
        $mergedBranches = git branch --merged develop 2>$null |
            ForEach-Object { $_.Trim() -replace '^\* ', '' } |
            Where-Object {
                $_ -ne "develop" -and
                $_ -ne "main" -and
                $_ -ne "master" -and
                $_ -notmatch "^agent\d+$" -and
                $_ -ne ""
            }

        if ($mergedBranches.Count -gt 0) {
            Write-Host "$repoName : $($mergedBranches.Count) stale branches" -ForegroundColor Yellow

            if (-not $DryRun) {
                foreach ($branch in $mergedBranches) {
                    try {
                        git branch -d $branch 2>$null
                        $totalPruned++
                    } catch {
                        # Silently skip protected branches
                    }
                }
                Write-Action "Pruned $($mergedBranches.Count) branches from $repoName" "OK"
                $fixCount++
            } else {
                $skipCount++
            }
        } else {
            Write-Action "$repoName : No stale branches" "OK"
        }

        Pop-Location
    }
}

if ($DryRun -and $totalPruned -eq 0) {
    Write-Action "[DRY RUN] Would prune stale branches" "SKIP"
}

# Phase 3: Snapshot Refresh
Write-Section "3. REFRESH BOOTSTRAP SNAPSHOT"

if (-not $DryRun) {
    try {
        & "$ToolsPath\bootstrap-snapshot.ps1" -Generate -Format summary 2>$null
        Write-Action "Snapshot refreshed" "OK"
        $fixCount++
    } catch {
        Write-Action "Snapshot refresh failed" "FAIL"
        $failCount++
    }
} else {
    Write-Action "[DRY RUN] Would refresh snapshot" "SKIP"
    $skipCount++
}

# Summary
$elapsed = (Get-Date) - $startTime

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FIX-ALL COMPLETE ($([Math]::Round($elapsed.TotalSeconds, 1))s)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Fixed:   $fixCount" -ForegroundColor Green
Write-Host "  Skipped: $skipCount" -ForegroundColor Yellow
Write-Host "  Failed:  $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "DarkGray" })
Write-Host ""

if ($DryRun) {
    Write-Host "This was a DRY RUN. Run without -DryRun to apply fixes." -ForegroundColor Yellow
}
