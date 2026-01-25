<#
.SYNOPSIS
    Loads Claude Agent tool aliases for quick access.

.DESCRIPTION
    Dot-source this file to load shortcuts:
    . C:\scripts\tools\aliases.ps1

    Then use short commands like:
    - cstatus (system status)
    - chealth (health check)
    - csnap (bootstrap snapshot)
    - cwt (worktree status)
    - cclean (cleanup)

.EXAMPLE
    . .\aliases.ps1
    cstatus
    chealth
#>

$ToolsPath = "C:\scripts\tools"

# Define aliases
$Aliases = @{
    # Status and diagnostics
    "cstatus" = { & "$ToolsPath\claude-ctl.ps1" status }
    "chealth" = { & "$ToolsPath\system-health.ps1" }
    "csnap" = { & "$ToolsPath\bootstrap-snapshot.ps1" -Generate -Format summary }
    "ctest" = { & "$ToolsPath\smoke-test.ps1" }

    # Worktree management
    "cwt" = { & "$ToolsPath\worktree-status.ps1" -Compact }
    "cwtfull" = { & "$ToolsPath\worktree-status.ps1" }
    "calloc" = { param($repo, $branch)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
 & "$ToolsPath\worktree-allocate.ps1" -Repo $repo -Branch $branch -Paired }
    "crelease" = { & "$ToolsPath\worktree-release-all.ps1" -AutoCommit }
    "cclean" = { & "$ToolsPath\worktree-cleanup.ps1" -SyncOnly }

    # Knowledge
    "creflect" = { param($n=5) & "$ToolsPath\read-reflections.ps1" -Recent $n }
    "csearch" = { param($q) & "$ToolsPath\pattern-search.ps1" -Query $q }
    "cdaily" = { & "$ToolsPath\daily-summary.ps1" }

    # Maintenance
    "cmaint" = { & "$ToolsPath\maintenance.ps1" -Quick }
    "cmaintfull" = { & "$ToolsPath\maintenance.ps1" -Full }
    "cprune" = { & "$ToolsPath\prune-branches.ps1" -DryRun }
}

# Create functions for each alias
foreach ($alias in $Aliases.Keys) {
    $scriptBlock = $Aliases[$alias]
    Set-Item -Path "function:global:$alias" -Value $scriptBlock
}

Write-Host "Claude Agent aliases loaded:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  STATUS:" -ForegroundColor Yellow
Write-Host "    cstatus  - System status"
Write-Host "    chealth  - Health check"
Write-Host "    csnap    - Bootstrap snapshot"
Write-Host "    ctest    - Smoke tests"
Write-Host ""
Write-Host "  WORKTREES:" -ForegroundColor Yellow
Write-Host "    cwt      - Worktree status (compact)"
Write-Host "    cwtfull  - Worktree status (full)"
Write-Host "    calloc   - Allocate worktree: calloc <repo> <branch>"
Write-Host "    crelease - Release all worktrees"
Write-Host "    cclean   - Cleanup and sync"
Write-Host ""
Write-Host "  KNOWLEDGE:" -ForegroundColor Yellow
Write-Host "    creflect - Recent reflections: creflect [n]"
Write-Host "    csearch  - Pattern search: csearch <query>"
Write-Host "    cdaily   - Daily summary"
Write-Host ""
Write-Host "  MAINTENANCE:" -ForegroundColor Yellow
Write-Host "    cmaint   - Quick maintenance"
Write-Host "    cmaintfull - Full maintenance"
Write-Host "    cprune   - Prune branches (dry run)"
Write-Host ""
