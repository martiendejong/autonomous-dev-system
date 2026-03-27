<#
.SYNOPSIS
    Quick session startup routine for Claude Agent.

.DESCRIPTION
    Runs all recommended startup checks:
    1. Generate bootstrap snapshot
    2. Run system health check
    3. Show worktree status
    4. Display recent reflections

    Use this at the start of every session.

.PARAMETER Quick
    Skip some checks for faster startup

.PARAMETER Fix
    Auto-fix issues found

.EXAMPLE
    .\session-start.ps1
    .\session-start.ps1 -Quick
    .\session-start.ps1 -Fix
#>

param(
    [switch]$Quick,
    [switch]$Fix
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ToolsPath = "C:\scripts\tools"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

$startTime = Get-Date

Write-Host ""
Write-Host "CLAUDE AGENT SESSION STARTUP" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ""

# Step 1: Bootstrap Snapshot
Write-Section "1. SYSTEM STATE"
& "$ToolsPath\bootstrap-snapshot.ps1" -Generate -Format summary

if (-not $Quick) {
    # Step 2: Health Check
    Write-Section "2. HEALTH CHECK"
    if ($Fix) {
        & "$ToolsPath\system-health.ps1" -Fix
    } else {
        & "$ToolsPath\system-health.ps1"
    }

    # Step 3: Worktree Status
    Write-Section "3. WORKTREE STATUS"
    & "$ToolsPath\worktree-status.ps1" -Compact

    # Step 4: Recent Reflections
    Write-Section "4. RECENT LEARNINGS"
    & "$ToolsPath\read-reflections.ps1" -Recent 3 -List
}

# Summary
$elapsed = (Get-Date) - $startTime
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STARTUP COMPLETE ($([Math]::Round($elapsed.TotalSeconds, 1))s)" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Quick reference:" -ForegroundColor Yellow
Write-Host "  cstatus   - System status"
Write-Host "  cwt       - Worktree status"
Write-Host "  calloc    - Allocate worktree"
Write-Host "  crelease  - Release worktrees"
Write-Host ""
Write-Host "Session started. Ready to work." -ForegroundColor Green
Write-Host ""
