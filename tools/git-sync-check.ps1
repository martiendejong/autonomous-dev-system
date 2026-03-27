#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Check if local git repository is synchronized with remote
.DESCRIPTION
    Verifies local branch state against remote to detect uncommitted changes,
    unpushed commits, and incoming changes. Essential for multi-agent coordination.
.PARAMETER RepoPath
    Path to git repository (default: current directory)
.PARAMETER Fetch
    Fetch from remote before checking (default: true)
.PARAMETER Verbose
    Show detailed status information
.EXAMPLE
    .\git-sync-check.ps1
.EXAMPLE
    .\git-sync-check.ps1 -RepoPath C:\Projects\client-manager -Verbose
.EXAMPLE
    .\git-sync-check.ps1 -Fetch:$false
#>

param(
    [string]$RepoPath = ".",
    [bool]$Fetch = $true,
    [switch]$Verbose
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


Write-Host "=== Git Sync Check ===" -ForegroundColor Cyan

Push-Location $RepoPath

try {
    # Verify it's a git repo
    if (-not (Test-Path ".git")) {
        Write-Host "❌ Not a git repository: $RepoPath" -ForegroundColor Red
        exit 1
    }

    # Get current branch
    $currentBranch = git branch --show-current
    if (-not $currentBranch) {
        Write-Host "❌ Not on any branch (detached HEAD)" -ForegroundColor Red
        exit 1
    }

    Write-Host "Branch: $currentBranch" -ForegroundColor Gray
    Write-Host ""

    # Fetch from remote
    if ($Fetch) {
        Write-Host "🔄 Fetching from remote..." -ForegroundColor Cyan
        git fetch --quiet 2>&1 | Out-Null
    }

    # Check status
    $statusShort = git status --short
    $statusBranch = git status --short --branch

    # Parse branch status
    $branchStatus = git status --short --branch | Select-Object -First 1

    $ahead = 0
    $behind = 0
    $hasRemote = $false

    if ($branchStatus -match 'ahead (\d+)') {
        $ahead = [int]$matches[1]
        $hasRemote = $true
    }
    if ($branchStatus -match 'behind (\d+)') {
        $behind = [int]$matches[1]
        $hasRemote = $true
    }
    if ($branchStatus -match '\.\.\.\w+/') {
        $hasRemote = $true
    }

    # Check working tree
    $hasUncommitted = $statusShort.Count -gt 1  # First line is branch info
    $uncommittedCount = if ($hasUncommitted) { $statusShort.Count - 1 } else { 0 }

    # Display results
    Write-Host "📊 Status:" -ForegroundColor Cyan

    # Working tree
    if ($hasUncommitted) {
        Write-Host "  ⚠️  Uncommitted changes: $uncommittedCount file(s)" -ForegroundColor Yellow
        if ($Verbose) {
            foreach ($line in $statusShort | Select-Object -Skip 1) {
                Write-Host "     $line" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "  ✅ Working tree clean" -ForegroundColor Green
    }

    # Remote sync
    if (-not $hasRemote) {
        Write-Host "  ⚠️  No remote tracking branch" -ForegroundColor Yellow
    } else {
        if ($ahead -gt 0) {
            Write-Host "  ⚠️  Ahead of remote by $ahead commit(s) - UNPUSHED" -ForegroundColor Yellow
        }
        if ($behind -gt 0) {
            Write-Host "  ⚠️  Behind remote by $behind commit(s) - INCOMING CHANGES" -ForegroundColor Yellow
        }
        if ($ahead -eq 0 -and $behind -eq 0) {
            Write-Host "  ✅ In sync with remote" -ForegroundColor Green
        }
    }

    # Stash
    $stashCount = (git stash list).Count
    if ($stashCount -gt 0) {
        Write-Host "  📦 Stashed changes: $stashCount" -ForegroundColor Cyan
        if ($Verbose) {
            git stash list | Select-Object -First 5 | ForEach-Object {
                Write-Host "     $_" -ForegroundColor Gray
            }
        }
    }

    # Summary
    Write-Host ""
    Write-Host "=== Summary ===" -ForegroundColor Cyan

    $isSafe = $true

    if ($hasUncommitted) {
        Write-Host "⚠️  UNCOMMITTED CHANGES - Commit or stash before major operations" -ForegroundColor Yellow
        $isSafe = $false
    }

    if ($ahead -gt 0) {
        Write-Host "⚠️  UNPUSHED COMMITS - Push to remote before switching context" -ForegroundColor Yellow
        $isSafe = $false
    }

    if ($behind -gt 0) {
        Write-Host "⚠️  INCOMING CHANGES - Pull or merge before making changes" -ForegroundColor Yellow
        Write-Host "   Run: git pull origin $currentBranch" -ForegroundColor Gray
        $isSafe = $false
    }

    if ($isSafe) {
        Write-Host "✅ Repository is clean and synchronized" -ForegroundColor Green
        exit 0
    } else {
        Write-Host ""
        Write-Host "⚠️  Multi-Agent Warning:" -ForegroundColor Yellow
        Write-Host "   Another agent or user may be working on this repository." -ForegroundColor Yellow
        Write-Host "   Synchronize before making changes to avoid conflicts." -ForegroundColor Yellow
        exit 1
    }

} finally {
    Pop-Location
}
