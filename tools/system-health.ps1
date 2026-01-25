<#
.SYNOPSIS
    Comprehensive system health checker for Claude Agent environment.

.DESCRIPTION
    Performs extensive health checks across:
    - File system integrity
    - Git repository states
    - Worktree pool consistency
    - Tool availability
    - Documentation completeness
    - Configuration validity

.PARAMETER Fix
    Attempt to auto-fix discovered issues

.PARAMETER Verbose
    Show detailed output for each check

.EXAMPLE
    .\system-health.ps1
    .\system-health.ps1 -Fix
    .\system-health.ps1 -Verbose
#>

param(
    [switch]$Fix,
    [switch]$Detailed
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ErrorActionPreference = "SilentlyContinue"

# Configuration
$Config = @{
    ControlPlane = "C:\scripts"
    MachineContext = "C:\scripts\_machine"
    WorkerAgents = "C:\Projects\worker-agents"
    BaseRepos = @(
        @{ Name = "client-manager"; Path = "C:\Projects\client-manager"; MainBranch = "develop" }
        @{ Name = "hazina"; Path = "C:\Projects\hazina"; MainBranch = "develop" }
    )
    RequiredFiles = @(
        "C:\scripts\CLAUDE.md"
        "C:\scripts\QUICKSTART.md"
        "C:\scripts\NAVIGATION.md"
        "C:\scripts\ZERO_TOLERANCE_RULES.md"
        "C:\scripts\MACHINE_CONFIG.md"
        "C:\scripts\_machine\worktrees.pool.md"
        "C:\scripts\_machine\worktrees.activity.md"
        "C:\scripts\_machine\reflection.log.md"
    )
    RequiredTools = @(
        "C:\scripts\tools\bootstrap-snapshot.ps1"
        "C:\scripts\tools\worktree-status.ps1"
        "C:\scripts\tools\worktree-release-all.ps1"
        "C:\scripts\tools\claude-ctl.ps1"
    )
}

$Issues = @()
$Warnings = @()
$Fixed = @()

function Write-Check {
    param([string]$Name, [string]$Status, [string]$Details = "")

    $color = switch ($Status) {
        "OK" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
        "FIXED" { "Cyan" }
        default { "White" }
    }

    Write-Host "[$Status] " -ForegroundColor $color -NoNewline
    Write-Host $Name -NoNewline
    if ($Details) {
        Write-Host " - $Details" -ForegroundColor DarkGray
    } else {
        Write-Host ""
    }
}

function Test-FileIntegrity {
    Write-Host ""
    Write-Host "FILE INTEGRITY" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan

    # Required files
    foreach ($file in $Config.RequiredFiles) {
        if (Test-Path $file) {
            $size = (Get-Item $file).Length
            if ($size -eq 0) {
                Write-Check $file "WARN" "File is empty"
                $script:Warnings += "Empty file: $file"
            } else {
                if ($Detailed) { Write-Check $file "OK" "$size bytes" }
            }
        } else {
            Write-Check $file "FAIL" "Missing"
            $script:Issues += "Missing required file: $file"
        }
    }

    # Required tools
    foreach ($tool in $Config.RequiredTools) {
        if (Test-Path $tool) {
            if ($Detailed) { Write-Check $tool "OK" }
        } else {
            Write-Check $tool "FAIL" "Missing tool"
            $script:Issues += "Missing required tool: $tool"
        }
    }

    if (-not $Detailed) {
        $missingCount = ($Config.RequiredFiles + $Config.RequiredTools | Where-Object { -not (Test-Path $_) }).Count
        if ($missingCount -eq 0) {
            Write-Check "All required files" "OK"
        } else {
            Write-Check "Required files" "FAIL" "$missingCount missing"
        }
    }
}

function Test-GitRepositories {
    Write-Host ""
    Write-Host "GIT REPOSITORIES" -ForegroundColor Cyan
    Write-Host "================" -ForegroundColor Cyan

    foreach ($repo in $Config.BaseRepos) {
        if (-not (Test-Path $repo.Path)) {
            Write-Check $repo.Name "FAIL" "Repository not found at $($repo.Path)"
            $script:Issues += "Missing repository: $($repo.Path)"
            continue
        }

        # Check branch
        $branch = git -C $repo.Path branch --show-current 2>$null
        if ($branch -ne $repo.MainBranch) {
            Write-Check "$($repo.Name) branch" "WARN" "On '$branch' instead of '$($repo.MainBranch)'"
            $script:Warnings += "$($repo.Name) not on $($repo.MainBranch)"

            if ($Fix) {
                $status = git -C $repo.Path status --porcelain 2>$null
                if ([string]::IsNullOrWhiteSpace($status)) {
                    git -C $repo.Path checkout $repo.MainBranch 2>$null
                    Write-Check "$($repo.Name) branch" "FIXED" "Switched to $($repo.MainBranch)"
                    $script:Fixed += "Switched $($repo.Name) to $($repo.MainBranch)"
                } else {
                    Write-Check "$($repo.Name) branch" "WARN" "Cannot fix - has uncommitted changes"
                }
            }
        } else {
            Write-Check "$($repo.Name) branch" "OK" $branch
        }

        # Check for uncommitted changes
        $status = git -C $repo.Path status --porcelain 2>$null
        if (-not [string]::IsNullOrWhiteSpace($status)) {
            $changeCount = ($status -split "`n").Count
            Write-Check "$($repo.Name) status" "WARN" "$changeCount uncommitted changes"
            $script:Warnings += "$($repo.Name) has uncommitted changes"
        } else {
            if ($Detailed) { Write-Check "$($repo.Name) status" "OK" "Clean" }
        }

        # Check remote sync
        git -C $repo.Path fetch --dry-run 2>$null
        $behind = git -C $repo.Path rev-list --count "HEAD..@{u}" 2>$null
        $ahead = git -C $repo.Path rev-list --count "@{u}..HEAD" 2>$null
        if ($behind -gt 0) {
            Write-Check "$($repo.Name) sync" "WARN" "$behind commits behind remote"
            $script:Warnings += "$($repo.Name) is $behind commits behind"
        } elseif ($ahead -gt 0) {
            Write-Check "$($repo.Name) sync" "WARN" "$ahead commits ahead of remote"
        } else {
            if ($Detailed) { Write-Check "$($repo.Name) sync" "OK" "Up to date" }
        }
    }
}

function Test-WorktreePool {
    Write-Host ""
    Write-Host "WORKTREE POOL" -ForegroundColor Cyan
    Write-Host "=============" -ForegroundColor Cyan

    $poolPath = "$($Config.MachineContext)\worktrees.pool.md"

    if (-not (Test-Path $poolPath)) {
        Write-Check "Pool file" "FAIL" "Missing"
        return
    }

    $poolContent = Get-Content $poolPath -Raw
    $poolSeats = @{}

    # Parse pool
    $lines = $poolContent -split "`n" | Where-Object { $_ -match '^\| agent-' }
    foreach ($line in $lines) {
        if ($line -match '\| (agent-\d+) .* \| (FREE|BUSY|STALE|BROKEN) \|') {
            $poolSeats[$matches[1]] = $matches[2]
        }
    }

    Write-Check "Pool parsed" "OK" "$($poolSeats.Count) seats defined"

    # Check actual worktrees
    $actualWorktrees = @{}
    if (Test-Path $Config.WorkerAgents) {
        Get-ChildItem $Config.WorkerAgents -Directory | ForEach-Object {
            $seat = $_.Name
            $repos = Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue
            $actualWorktrees[$seat] = @()
            foreach ($repo in $repos) {
                $branch = git -C $repo.FullName branch --show-current 2>$null
                if ($branch) {
                    $actualWorktrees[$seat] += @{ repo = $repo.Name; branch = $branch }
                }
            }
        }
    }

    # Consistency checks
    foreach ($seat in $poolSeats.Keys) {
        $status = $poolSeats[$seat]
        $hasWorktrees = $actualWorktrees.ContainsKey($seat) -and $actualWorktrees[$seat].Count -gt 0

        if ($status -eq "BUSY" -and -not $hasWorktrees) {
            Write-Check "$seat" "WARN" "Marked BUSY but no worktrees found"
            $script:Warnings += "$seat marked BUSY but empty"

            if ($Fix) {
                # Update pool to FREE
                $poolContent = $poolContent -replace "(\| $seat .* \|) BUSY (\|)", "`$1 FREE `$2"
                Write-Check "$seat" "FIXED" "Marked as FREE"
                $script:Fixed += "Marked $seat as FREE"
            }
        } elseif ($status -eq "FREE" -and $hasWorktrees) {
            $repos = ($actualWorktrees[$seat] | ForEach-Object { $_.repo }) -join ", "
            Write-Check "$seat" "WARN" "Marked FREE but has worktrees: $repos"
            $script:Warnings += "$seat marked FREE but has worktrees"
        } elseif ($status -eq "BUSY" -and $hasWorktrees) {
            $repos = ($actualWorktrees[$seat] | ForEach-Object { "$($_.repo)@$($_.branch)" }) -join ", "
            Write-Check "$seat" "OK" "BUSY with: $repos"
        } else {
            if ($Detailed) { Write-Check "$seat" "OK" "FREE" }
        }
    }

    # Check for orphaned worktrees (not in pool)
    foreach ($seat in $actualWorktrees.Keys) {
        if (-not $poolSeats.ContainsKey($seat) -and $actualWorktrees[$seat].Count -gt 0) {
            Write-Check "$seat" "WARN" "Not in pool but has worktrees"
            $script:Warnings += "Orphaned seat: $seat"
        }
    }

    if ($Fix -and $script:Fixed.Count -gt 0) {
        $poolContent | Set-Content $poolPath -Encoding UTF8
    }
}

function Test-Tools {
    Write-Host ""
    Write-Host "EXTERNAL TOOLS" -ForegroundColor Cyan
    Write-Host "==============" -ForegroundColor Cyan

    # Git
    $gitVersion = git --version 2>$null
    if ($gitVersion) {
        Write-Check "git" "OK" $gitVersion
    } else {
        Write-Check "git" "FAIL" "Not available"
        $script:Issues += "Git not installed"
    }

    # GitHub CLI
    $ghVersion = gh --version 2>$null | Select-Object -First 1
    if ($ghVersion) {
        Write-Check "gh (GitHub CLI)" "OK" $ghVersion
    } else {
        Write-Check "gh (GitHub CLI)" "WARN" "Not installed (PR creation will fail)"
        $script:Warnings += "GitHub CLI not installed"
    }

    # Node.js
    $nodeVersion = node --version 2>$null
    if ($nodeVersion) {
        Write-Check "node" "OK" $nodeVersion
    } else {
        Write-Check "node" "WARN" "Not installed"
        $script:Warnings += "Node.js not installed"
    }

    # PowerShell
    Write-Check "PowerShell" "OK" $PSVersionTable.PSVersion.ToString()
}

function Test-Documentation {
    Write-Host ""
    Write-Host "DOCUMENTATION" -ForegroundColor Cyan
    Write-Host "=============" -ForegroundColor Cyan

    # Check for broken internal links
    $mdFiles = Get-ChildItem $Config.ControlPlane -Filter "*.md" -Recurse | Where-Object { $_.FullName -notlike "*node_modules*" }
    $brokenLinks = @()

    foreach ($file in $mdFiles) {
        $content = Get-Content $file.FullName -Raw
        # Find markdown links [text](path)
        $links = [regex]::Matches($content, '\[([^\]]+)\]\(([^)]+)\)')
        foreach ($link in $links) {
            $path = $link.Groups[2].Value
            # Skip external links
            if ($path -match '^https?://') { continue }
            # Skip anchors
            if ($path -match '^#') { continue }

            $resolvedPath = Join-Path (Split-Path $file.FullName) $path
            if (-not (Test-Path $resolvedPath)) {
                $brokenLinks += "$($file.Name): $path"
            }
        }
    }

    if ($brokenLinks.Count -eq 0) {
        Write-Check "Internal links" "OK" "All verified"
    } else {
        Write-Check "Internal links" "WARN" "$($brokenLinks.Count) broken links"
        if ($Detailed) {
            $brokenLinks | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
        }
        $script:Warnings += "Broken documentation links: $($brokenLinks.Count)"
    }

    # Check CLAUDE.md size
    $claudeMd = Get-Item "$($Config.ControlPlane)\CLAUDE.md" -ErrorAction SilentlyContinue
    if ($claudeMd) {
        $lines = (Get-Content $claudeMd.FullName).Count
        if ($lines -gt 500) {
            Write-Check "CLAUDE.md size" "WARN" "$lines lines (consider splitting)"
            $script:Warnings += "CLAUDE.md is very large ($lines lines)"
        } else {
            Write-Check "CLAUDE.md size" "OK" "$lines lines"
        }
    }
}

function Show-Summary {
    Write-Host ""
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host "HEALTH CHECK SUMMARY" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host ""

    if ($script:Issues.Count -eq 0 -and $script:Warnings.Count -eq 0) {
        Write-Host "ALL CHECKS PASSED" -ForegroundColor Green
        Write-Host ""
        return 0
    }

    if ($script:Issues.Count -gt 0) {
        Write-Host "CRITICAL ISSUES: $($script:Issues.Count)" -ForegroundColor Red
        $script:Issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        Write-Host ""
    }

    if ($script:Warnings.Count -gt 0) {
        Write-Host "WARNINGS: $($script:Warnings.Count)" -ForegroundColor Yellow
        $script:Warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
        Write-Host ""
    }

    if ($script:Fixed.Count -gt 0) {
        Write-Host "AUTO-FIXED: $($script:Fixed.Count)" -ForegroundColor Cyan
        $script:Fixed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }
        Write-Host ""
    }

    return $script:Issues.Count
}

# Main execution
Write-Host ""
Write-Host "CLAUDE AGENT SYSTEM HEALTH CHECK" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
if ($Fix) { Write-Host "Mode: AUTO-FIX ENABLED" -ForegroundColor Yellow }

Test-FileIntegrity
Test-GitRepositories
Test-WorktreePool
Test-Tools
Test-Documentation

$exitCode = Show-Summary
exit $exitCode
