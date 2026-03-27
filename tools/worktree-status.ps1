<#
.SYNOPSIS
    Shows active git worktrees across all worker agent seats.

.DESCRIPTION
    Scans base repositories and displays which worktrees are active,
    which branches they use, and compares with worktrees.pool.md status.

.PARAMETER BaseRepos
    Array of base repository paths. Defaults to client-manager and hazina.

.PARAMETER PoolFile
    Path to worktrees.pool.md for status comparison.

.PARAMETER Compact
    Show compact single-line-per-worktree output.

.EXAMPLE
    .\worktree-status.ps1

.EXAMPLE
    .\worktree-status.ps1 -Compact
#>

param(
    [string[]]$BaseRepos = @(
        "C:\Projects\client-manager",
        "C:\Projects\hazina"
    )

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
,
    [string]$PoolFile = "C:\scripts\_machine\worktrees.pool.md",
    [switch]$Compact
)

$ErrorActionPreference = "Continue"

# Colors
function Write-Header($text) {
    Write-Host "`n$text" -ForegroundColor Cyan
    Write-Host ("=" * $text.Length) -ForegroundColor DarkCyan
}

function Write-RepoHeader($text) {
    Write-Host "`n  $text" -ForegroundColor Yellow
}

# Parse pool file for status comparison
function Get-PoolStatus {
    param([string]$PoolPath)

    $status = @{}
    if (Test-Path $PoolPath) {
        $content = Get-Content $PoolPath -Raw
        # Parse table rows: | agent-XXX | ... | Status | ...
        $pattern = '\|\s*(agent-\d+)\s*\|[^|]*\|[^|]*\|[^|]*\|\s*(\w+)\s*\|'
        $matches = [regex]::Matches($content, $pattern)
        foreach ($match in $matches) {
            $seat = $match.Groups[1].Value
            $state = $match.Groups[2].Value
            $status[$seat] = $state
        }
    }
    return $status
}

# Get all worktrees from a repo
function Get-RepoWorktrees {
    param([string]$RepoPath)

    $worktrees = @()
    if (-not (Test-Path $RepoPath)) {
        return $worktrees
    }

    Push-Location $RepoPath
    try {
        $output = git worktree list --porcelain 2>$null
        if ($LASTEXITCODE -eq 0 -and $output) {
            $current = @{}
            foreach ($line in $output) {
                if ($line -match '^worktree (.+)$') {
                    if ($current.Count -gt 0) {
                        $worktrees += [PSCustomObject]$current
                    }
                    $current = @{ Path = $matches[1]; Branch = ""; Commit = ""; Bare = $false; Detached = $false }
                }
                elseif ($line -match '^HEAD ([a-f0-9]+)$') {
                    $current.Commit = $matches[1].Substring(0, 7)
                }
                elseif ($line -match '^branch refs/heads/(.+)$') {
                    $current.Branch = $matches[1]
                }
                elseif ($line -eq 'bare') {
                    $current.Bare = $true
                }
                elseif ($line -eq 'detached') {
                    $current.Detached = $true
                }
            }
            if ($current.Count -gt 0) {
                $worktrees += [PSCustomObject]$current
            }
        }
    }
    finally {
        Pop-Location
    }

    return $worktrees
}

# Extract agent seat from path
function Get-AgentSeat {
    param([string]$Path)

    if ($Path -match 'worker-agents[/\\](agent-\d+)') {
        return $matches[1]
    }
    elseif ($Path -match 'worker-agents[/\\]([^/\\]+)') {
        return $matches[1]
    }
    return $null
}

# Main execution
Write-Header "Git Worktree Status Overview"
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray

# Load pool status
$poolStatus = Get-PoolStatus -PoolPath $PoolFile

# Collect all worktrees by agent
$agentWorktrees = @{}

foreach ($repo in $BaseRepos) {
    $repoName = Split-Path $repo -Leaf
    $worktrees = Get-RepoWorktrees -RepoPath $repo

    foreach ($wt in $worktrees) {
        $seat = Get-AgentSeat -Path $wt.Path

        if ($seat) {
            if (-not $agentWorktrees.ContainsKey($seat)) {
                $agentWorktrees[$seat] = @()
            }
            $agentWorktrees[$seat] += [PSCustomObject]@{
                Repo = $repoName
                Branch = $wt.Branch
                Commit = $wt.Commit
                Path = $wt.Path
            }
        }
    }
}

# Display results
if ($Compact) {
    Write-Host "`n"
    Write-Host "SEAT        POOL     REPO              BRANCH" -ForegroundColor White
    Write-Host "----        ----     ----              ------" -ForegroundColor DarkGray

    $sortedSeats = $agentWorktrees.Keys | Sort-Object {
        if ($_ -match '^agent-(\d+)$') { [int]$matches[1] } else { 9999 }
    }, { $_ }
    foreach ($seat in $sortedSeats) {
        $poolState = if ($poolStatus.ContainsKey($seat)) { $poolStatus[$seat] } else { "???" }
        $stateColor = switch ($poolState) {
            "BUSY" { "Yellow" }
            "FREE" { "Green" }
            "STALE" { "Red" }
            default { "Gray" }
        }

        $first = $true
        foreach ($wt in $agentWorktrees[$seat]) {
            if ($first) {
                Write-Host ("{0,-11}" -f $seat) -NoNewline -ForegroundColor Cyan
                Write-Host ("{0,-8}" -f $poolState) -NoNewline -ForegroundColor $stateColor
                $first = $false
            }
            else {
                Write-Host ("{0,-11}{1,-8}" -f "", "") -NoNewline
            }
            Write-Host ("{0,-17}" -f $wt.Repo) -NoNewline -ForegroundColor White
            Write-Host $wt.Branch -ForegroundColor Magenta
        }
    }
}
else {
    # Detailed view by agent
    $sortedSeats = $agentWorktrees.Keys | Sort-Object {
        if ($_ -match '^agent-(\d+)$') { [int]$matches[1] } else { 9999 }
    }, { $_ }

    foreach ($seat in $sortedSeats) {
        $poolState = if ($poolStatus.ContainsKey($seat)) { $poolStatus[$seat] } else { "UNKNOWN" }
        $stateColor = switch ($poolState) {
            "BUSY" { "Yellow" }
            "FREE" { "Green" }
            "STALE" { "Red" }
            default { "Gray" }
        }

        Write-Host "`n$seat " -NoNewline -ForegroundColor Cyan
        Write-Host "[$poolState]" -ForegroundColor $stateColor

        foreach ($wt in $agentWorktrees[$seat]) {
            Write-Host "  - " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($wt.Repo)" -NoNewline -ForegroundColor White
            Write-Host " @ " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($wt.Branch)" -NoNewline -ForegroundColor Magenta
            Write-Host " ($($wt.Commit))" -ForegroundColor DarkGray
        }
    }
}

# Summary
Write-Host "`n"
Write-Header "Summary"

$busyCount = ($agentWorktrees.Keys | Where-Object { $poolStatus[$_] -eq "BUSY" }).Count
$freeWithWorktrees = ($agentWorktrees.Keys | Where-Object { $poolStatus[$_] -eq "FREE" }).Count
$totalWorktrees = ($agentWorktrees.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum

Write-Host "  Active worktrees: $totalWorktrees" -ForegroundColor White
Write-Host "  Seats with worktrees: $($agentWorktrees.Count)" -ForegroundColor White
Write-Host "  Marked BUSY in pool: $busyCount" -ForegroundColor Yellow

if ($freeWithWorktrees -gt 0) {
    Write-Host "`n  WARNING: $freeWithWorktrees seats marked FREE but still have worktrees!" -ForegroundColor Red
    $freeSeats = $agentWorktrees.Keys | Where-Object { $poolStatus[$_] -eq "FREE" }
    foreach ($seat in $freeSeats) {
        Write-Host "    - $seat" -ForegroundColor Red
    }
}

# Check for orphaned worktrees (not in agent folders)
Write-Host "`n"
Write-Header "Base Repository Worktrees"
foreach ($repo in $BaseRepos) {
    $repoName = Split-Path $repo -Leaf
    Write-RepoHeader $repoName

    $worktrees = Get-RepoWorktrees -RepoPath $repo
    foreach ($wt in $worktrees) {
        $seat = Get-AgentSeat -Path $wt.Path
        $isBase = $wt.Path -eq $repo -or $wt.Path -eq $repo.Replace('\', '/')

        if ($isBase) {
            Write-Host "    [BASE] " -NoNewline -ForegroundColor Green
            Write-Host "$($wt.Branch)" -NoNewline -ForegroundColor White
            Write-Host " ($($wt.Commit))" -ForegroundColor DarkGray
        }
        elseif (-not $seat) {
            Write-Host "    [ORPHAN] " -NoNewline -ForegroundColor Red
            Write-Host "$($wt.Path)" -NoNewline -ForegroundColor White
            Write-Host " @ $($wt.Branch)" -ForegroundColor Magenta
        }
    }
}

Write-Host ""
