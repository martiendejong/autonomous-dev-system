<#
.SYNOPSIS
    Unified CLI for Claude Agent operations.

.DESCRIPTION
    Single entry point for all common agent operations:
    - status: Show current system state
    - allocate: Allocate a worktree seat
    - release: Release a worktree seat
    - health: Run system health checks
    - reflect: Add entry to reflection log
    - pr: Create PR from current worktree
    - mode: Check or set current mode (feature/debug)

.PARAMETER Command
    The command to execute

.PARAMETER Args
    Additional arguments for the command

.EXAMPLE
    .\claude-ctl.ps1 status
    .\claude-ctl.ps1 allocate -Seat agent-002 -Repo client-manager -Branch feature/new-thing
    .\claude-ctl.ps1 release -Seat agent-002
    .\claude-ctl.ps1 health
    .\claude-ctl.ps1 reflect -Tag "PATTERN" -Message "Learned something"
#>

param(
    [Parameter(Position=0)]
    [ValidateSet("status", "allocate", "release", "health", "reflect", "pr", "mode", "help", "snapshot")]
    [string]$Command = "help",

    [string]$Seat,
    [string]$Repo,
    [string]$Branch,
    [string]$Tag,
    [string]$Message,
    [string]$Mode,
    [switch]$Compact,
    [switch]$AutoCommit,
    [switch]$DryRun
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$MachineContext = "C:\scripts\_machine"
$PoolPath = "$MachineContext\worktrees.pool.md"
$ActivityPath = "$MachineContext\worktrees.activity.md"
$ReflectionPath = "$MachineContext\reflection.log.md"

function Show-Help {
    Write-Host ""
    Write-Host "CLAUDE-CTL - Unified Claude Agent CLI" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "COMMANDS:" -ForegroundColor Yellow
    Write-Host "  status      Show current system state (worktrees, repos, health)"
    Write-Host "  snapshot    Generate/read bootstrap snapshot"
    Write-Host "  allocate    Allocate a worktree seat"
    Write-Host "  release     Release a worktree seat"
    Write-Host "  health      Run comprehensive health checks"
    Write-Host "  reflect     Add entry to reflection log"
    Write-Host "  mode        Show current operating mode"
    Write-Host "  help        Show this help"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  .\claude-ctl.ps1 status"
    Write-Host "  .\claude-ctl.ps1 status -Compact"
    Write-Host "  .\claude-ctl.ps1 snapshot"
    Write-Host "  .\claude-ctl.ps1 allocate -Seat agent-002 -Repo client-manager -Branch feature/x"
    Write-Host "  .\claude-ctl.ps1 release -Seat agent-002 -AutoCommit"
    Write-Host "  .\claude-ctl.ps1 health"
    Write-Host "  .\claude-ctl.ps1 reflect -Tag 'BUG-FIX' -Message 'Fixed issue with...'"
    Write-Host ""
}

function Show-Status {
    Write-Host ""
    Write-Host "=== SYSTEM STATUS ===" -ForegroundColor Cyan
    Write-Host ""

    # Pool status
    Write-Host "WORKTREE POOL:" -ForegroundColor Yellow
    if (Test-Path $PoolPath) {
        $content = Get-Content $PoolPath -Raw
        $lines = $content -split "`n" | Where-Object { $_ -match '^\| agent-' }
        foreach ($line in $lines) {
            if ($line -match '\| (agent-\d+) .* \| (FREE|BUSY|STALE|BROKEN) \|') {
                $seat = $matches[1]
                $status = $matches[2]
                $color = switch ($status) {
                    "FREE" { "Green" }
                    "BUSY" { "Red" }
                    "STALE" { "Yellow" }
                    default { "Gray" }
                }
                if ($Compact) {
                    Write-Host "  $seat : " -NoNewline
                    Write-Host $status -ForegroundColor $color
                } else {
                    Write-Host "  $seat : " -NoNewline
                    Write-Host $status -ForegroundColor $color
                }
            }
        }
    }
    Write-Host ""

    # Base repos
    Write-Host "BASE REPOSITORIES:" -ForegroundColor Yellow
    @("C:\Projects\client-manager", "C:\Projects\hazina") | ForEach-Object {
        if (Test-Path $_) {
            $name = Split-Path $_ -Leaf
            $branch = git -C $_ branch --show-current 2>$null
            $status = git -C $_ status --porcelain 2>$null
            $clean = if ([string]::IsNullOrWhiteSpace($status)) { "[clean]" } else { "[dirty]" }
            $branchColor = if ($branch -eq "develop") { "Green" } else { "Yellow" }
            Write-Host "  $name : " -NoNewline
            Write-Host $branch -ForegroundColor $branchColor -NoNewline
            Write-Host " $clean"
        }
    }
    Write-Host ""

    # Active worktrees
    Write-Host "ACTIVE WORKTREES:" -ForegroundColor Yellow
    $agentPath = "C:\Projects\worker-agents"
    $found = $false
    if (Test-Path $agentPath) {
        Get-ChildItem $agentPath -Directory | ForEach-Object {
            $seat = $_.Name
            Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $branch = git -C $_.FullName branch --show-current 2>$null
                if ($branch) {
                    Write-Host "  $seat/$($_.Name) @ $branch"
                    $found = $true
                }
            }
        }
    }
    if (-not $found) {
        Write-Host "  (none)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Invoke-Allocate {
    if (-not $Seat -or -not $Repo -or -not $Branch) {
        Write-Host "ERROR: allocate requires -Seat, -Repo, and -Branch" -ForegroundColor Red
        Write-Host "Example: .\claude-ctl.ps1 allocate -Seat agent-002 -Repo client-manager -Branch feature/x"
        return
    }

    Write-Host "Allocating $Seat for $Repo on branch $Branch..." -ForegroundColor Cyan

    # Check if seat is free
    $poolContent = Get-Content $PoolPath -Raw
    if ($poolContent -match "\| $Seat .* \| BUSY \|") {
        Write-Host "ERROR: $Seat is already BUSY" -ForegroundColor Red
        return
    }

    # Create worktree
    $basePath = "C:\Projects\$Repo"
    $worktreePath = "C:\Projects\worker-agents\$Seat\$Repo"

    if (-not (Test-Path $basePath)) {
        Write-Host "ERROR: Base repo not found at $basePath" -ForegroundColor Red
        return
    }

    # Create directory if needed
    $parentPath = Split-Path $worktreePath -Parent
    if (-not (Test-Path $parentPath)) {
        New-Item -ItemType Directory -Path $parentPath -Force | Out-Null
    }

    if ($DryRun) {
        Write-Host "[DRY RUN] Would execute: git -C $basePath worktree add $worktreePath -b $Branch"
        Write-Host "[DRY RUN] Would update pool.md: $Seat -> BUSY"
        return
    }

    # Create worktree
    $result = git -C $basePath worktree add $worktreePath -b $Branch 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR creating worktree: $result" -ForegroundColor Red
        return
    }

    # Update pool.md
    $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $poolContent = $poolContent -replace "(\| $Seat .* \|) FREE (\|.*\|).*\|", "`$1 BUSY `$2 $timestamp | Allocated for $Repo on $Branch |"
    $poolContent | Set-Content $PoolPath -Encoding UTF8

    # Log activity
    $activity = "`n| $(Get-Date -Format 'yyyy-MM-dd HH:mm') | $Seat | ALLOCATE | $Repo | $Branch | claude-ctl |"
    Add-Content $ActivityPath $activity

    Write-Host "SUCCESS: $Seat allocated for $Repo on $Branch" -ForegroundColor Green
    Write-Host "Worktree: $worktreePath" -ForegroundColor DarkGray
}

function Invoke-Release {
    if (-not $Seat) {
        Write-Host "ERROR: release requires -Seat" -ForegroundColor Red
        return
    }

    Write-Host "Releasing $Seat..." -ForegroundColor Cyan

    $worktreePath = "C:\Projects\worker-agents\$Seat"

    if (-not (Test-Path $worktreePath)) {
        Write-Host "WARNING: No worktree found at $worktreePath" -ForegroundColor Yellow
    } else {
        # Check for uncommitted changes
        Get-ChildItem $worktreePath -Directory | ForEach-Object {
            $repoPath = $_.FullName
            $status = git -C $repoPath status --porcelain 2>$null

            if (-not [string]::IsNullOrWhiteSpace($status)) {
                if ($AutoCommit) {
                    Write-Host "  $($_.Name): Auto-committing changes..." -ForegroundColor Yellow
                    git -C $repoPath add -A
                    git -C $repoPath commit -m "WIP: Auto-commit on release by claude-ctl"
                    git -C $repoPath push origin HEAD 2>$null
                } else {
                    Write-Host "  $($_.Name): Has uncommitted changes! Use -AutoCommit to commit them." -ForegroundColor Red
                    return
                }
            }
        }

        if (-not $DryRun) {
            # Remove worktree contents
            Get-ChildItem $worktreePath -Directory | ForEach-Object {
                $basePath = "C:\Projects\$($_.Name)"
                if (Test-Path $basePath) {
                    git -C $basePath worktree remove $_.FullName --force 2>$null
                }
            }
        }
    }

    if ($DryRun) {
        Write-Host "[DRY RUN] Would update pool.md: $Seat -> FREE"
        return
    }

    # Update pool.md
    $poolContent = Get-Content $PoolPath -Raw
    $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $poolContent = $poolContent -replace "(\| $Seat .* \|) BUSY (\|.*\|).*\|", "`$1 FREE `$2 $timestamp | Released by claude-ctl |"
    $poolContent | Set-Content $PoolPath -Encoding UTF8

    # Log activity
    $activity = "`n| $(Get-Date -Format 'yyyy-MM-dd HH:mm') | $Seat | RELEASE | - | - | claude-ctl |"
    Add-Content $ActivityPath $activity

    Write-Host "SUCCESS: $Seat released" -ForegroundColor Green
}

function Invoke-Health {
    Write-Host ""
    Write-Host "=== SYSTEM HEALTH CHECK ===" -ForegroundColor Cyan
    Write-Host ""

    $issues = @()

    # Check 1: Pool file exists
    Write-Host "[Check] Pool file... " -NoNewline
    if (Test-Path $PoolPath) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "MISSING" -ForegroundColor Red
        $issues += "Pool file missing at $PoolPath"
    }

    # Check 2: Base repos on develop
    Write-Host "[Check] Base repos on develop... " -NoNewline
    $repoIssues = @()
    @("C:\Projects\client-manager", "C:\Projects\hazina") | ForEach-Object {
        if (Test-Path $_) {
            $branch = git -C $_ branch --show-current 2>$null
            if ($branch -ne "develop") {
                $repoIssues += "$(Split-Path $_ -Leaf) is on $branch"
            }
        }
    }
    if ($repoIssues.Count -eq 0) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "WARNING: $($repoIssues -join ', ')" -ForegroundColor Yellow
        $issues += $repoIssues
    }

    # Check 3: Pool/worktree consistency
    Write-Host "[Check] Pool/worktree consistency... " -NoNewline
    $poolContent = Get-Content $PoolPath -Raw
    $inconsistencies = @()
    Get-ChildItem "C:\Projects\worker-agents" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $seat = $_.Name
        $hasWorktrees = (Get-ChildItem $_.FullName -Directory -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
        $isBusy = $poolContent -match "\| $seat .* \| BUSY \|"

        if ($hasWorktrees -and -not $isBusy) {
            $inconsistencies += "$seat has worktrees but marked FREE"
        }
    }
    if ($inconsistencies.Count -eq 0) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "ISSUES FOUND" -ForegroundColor Red
        $inconsistencies | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        $issues += $inconsistencies
    }

    # Check 4: Git availability
    Write-Host "[Check] Git available... " -NoNewline
    $gitVersion = git --version 2>$null
    if ($gitVersion) {
        Write-Host "OK ($gitVersion)" -ForegroundColor Green
    } else {
        Write-Host "NOT FOUND" -ForegroundColor Red
        $issues += "Git not available"
    }

    # Check 5: gh CLI
    Write-Host "[Check] GitHub CLI... " -NoNewline
    $ghVersion = gh --version 2>$null | Select-Object -First 1
    if ($ghVersion) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "NOT FOUND" -ForegroundColor Yellow
        $issues += "GitHub CLI not available"
    }

    # Summary
    Write-Host ""
    if ($issues.Count -eq 0) {
        Write-Host "HEALTH: ALL CHECKS PASSED" -ForegroundColor Green
    } else {
        Write-Host "HEALTH: $($issues.Count) ISSUE(S) FOUND" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    }
    Write-Host ""

    return $issues.Count -eq 0
}

function Invoke-Reflect {
    if (-not $Tag -or -not $Message) {
        Write-Host "ERROR: reflect requires -Tag and -Message" -ForegroundColor Red
        Write-Host "Example: .\claude-ctl.ps1 reflect -Tag 'BUG-FIX' -Message 'Fixed null reference in...'"
        return
    }

    $date = Get-Date -Format "yyyy-MM-dd"
    $entry = @"

## $date [$Tag] - Quick Entry

**Pattern Type:** Quick Entry via claude-ctl
**Context:** Manual reflection entry
**Outcome:** Documented

### Details

$Message

---
"@

    if ($DryRun) {
        Write-Host "[DRY RUN] Would prepend to reflection.log.md:"
        Write-Host $entry
        return
    }

    # Prepend to reflection log (after header)
    $content = Get-Content $ReflectionPath -Raw
    $headerEnd = $content.IndexOf("---`n") + 4
    $newContent = $content.Substring(0, $headerEnd) + $entry + $content.Substring($headerEnd)
    $newContent | Set-Content $ReflectionPath -Encoding UTF8

    Write-Host "SUCCESS: Reflection entry added" -ForegroundColor Green
}

function Invoke-Snapshot {
    & "$ScriptRoot\bootstrap-snapshot.ps1" -Generate
}

function Show-Mode {
    Write-Host ""
    Write-Host "=== OPERATING MODE ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Mode detection is context-based. Check the current conversation:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "FEATURE DEVELOPMENT MODE if:" -ForegroundColor Green
    Write-Host "  - User asks for new feature, refactoring, code changes"
    Write-Host "  - No active debugging session"
    Write-Host "  - Working on planned work"
    Write-Host ""
    Write-Host "ACTIVE DEBUGGING MODE if:" -ForegroundColor Red
    Write-Host "  - User posts build errors"
    Write-Host "  - User says 'I'm debugging' or 'fix this'"
    Write-Host "  - User is actively developing and needs quick fixes"
    Write-Host ""
    Write-Host "See: GENERAL_DUAL_MODE_WORKFLOW.md for details"
    Write-Host ""
}

# Main dispatch
switch ($Command) {
    "help" { Show-Help }
    "status" { Show-Status }
    "snapshot" { Invoke-Snapshot }
    "allocate" { Invoke-Allocate }
    "release" { Invoke-Release }
    "health" { Invoke-Health }
    "reflect" { Invoke-Reflect }
    "mode" { Show-Mode }
}
