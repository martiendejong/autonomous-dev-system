<#
.SYNOPSIS
    Runs scheduled maintenance tasks for the Claude Agent system.

.DESCRIPTION
    Combines multiple maintenance operations:
    - System health check
    - Stale branch cleanup
    - Worktree consistency check
    - Reflection archival
    - Bootstrap snapshot refresh

.PARAMETER DryRun
    Show what would be done without making changes

.PARAMETER Quick
    Run only essential checks (health + snapshot)

.PARAMETER Full
    Run all maintenance tasks including cleanup

.EXAMPLE
    .\maintenance.ps1 -DryRun
    .\maintenance.ps1 -Quick
    .\maintenance.ps1 -Full
#>

param(
    [switch]$DryRun,
    [switch]$Quick,
    [switch]$Full
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ToolsPath = "C:\scripts\tools"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-Task {
    param(
        [string]$Name,
        [scriptblock]$Script,
        [switch]$Skip
    )

    if ($Skip) {
        Write-Host "[ SKIP ] $Name" -ForegroundColor DarkGray
        return
    }

    Write-Host "[ RUN  ] $Name" -ForegroundColor Yellow

    if ($DryRun) {
        Write-Host "         (dry run - skipped)" -ForegroundColor DarkGray
    } else {
        try {
            & $Script
            Write-Host "[ OK   ] $Name" -ForegroundColor Green
        } catch {
            Write-Host "[ FAIL ] $Name - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Main execution
$startTime = Get-Date

Write-Host ""
Write-Host "CLAUDE AGENT MAINTENANCE" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } elseif ($Quick) { 'QUICK' } elseif ($Full) { 'FULL' } else { 'STANDARD' })"
Write-Host ""

# Task 1: System Health
Write-Section "1. SYSTEM HEALTH CHECK"
Invoke-Task -Name "System health" -Script {
    & "$ToolsPath\system-health.ps1"
}

# Task 2: Bootstrap Snapshot
Write-Section "2. BOOTSTRAP SNAPSHOT"
Invoke-Task -Name "Refresh snapshot" -Script {
    & "$ToolsPath\bootstrap-snapshot.ps1" -Generate -Format summary
}

if ($Quick) {
    Write-Section "QUICK MODE COMPLETE"
    Write-Host "Skipped: Branch cleanup, archival, pool sync"
    Write-Host ""
    exit 0
}

# Task 3: Branch Cleanup (standard and full)
Write-Section "3. BRANCH CLEANUP"
Invoke-Task -Name "Prune stale branches" -Script {
    & "$ToolsPath\prune-branches.ps1" -DryRun:$DryRun
}

# Task 4: Pool JSON Sync
Write-Section "4. POOL SYNCHRONIZATION"
Invoke-Task -Name "Sync pool to JSON" -Script {
    & "$ToolsPath\migrate-pool-to-json.ps1"
}

# Full mode only tasks
if ($Full) {
    # Task 5: Reflection Archival
    Write-Section "5. REFLECTION ARCHIVAL"
    Invoke-Task -Name "Archive old reflections" -Script {
        & "$ToolsPath\archive-reflections.ps1" -DaysToKeep 30 -Force
    }

    # Task 6: Git Cleanup
    Write-Section "6. GIT CLEANUP"
    Invoke-Task -Name "Prune worktrees (client-manager)" -Script {
        git -C "C:\Projects\client-manager" worktree prune
    }
    Invoke-Task -Name "Prune worktrees (hazina)" -Script {
        git -C "C:\Projects\hazina" worktree prune
    }
    Invoke-Task -Name "Garbage collection (client-manager)" -Script {
        git -C "C:\Projects\client-manager" gc --auto
    }
    Invoke-Task -Name "Garbage collection (hazina)" -Script {
        git -C "C:\Projects\hazina" gc --auto
    }
}

# Summary
$elapsed = (Get-Date) - $startTime
Write-Section "MAINTENANCE COMPLETE"
Write-Host "Duration: $($elapsed.TotalSeconds.ToString('0.0')) seconds"
Write-Host ""

if ($DryRun) {
    Write-Host "This was a dry run. No changes were made." -ForegroundColor Yellow
    Write-Host "Run without -DryRun to execute maintenance." -ForegroundColor Yellow
}
