<#
.SYNOPSIS
    Quick Commands - Single letter access to top operations.
    Expert: Tim Ferriss | Impact: 8 | Effort: 2 | Priority: 4.0

.DESCRIPTION
    Implements 50-Expert Council Improvement #40.
    Single-letter aliases for the top 10 most common operations.
    Eliminates friction for repetitive tasks.

.PARAMETER Command
    Single letter command:
    s = status (full environment snapshot)
    w = worktree status
    c = clickup list
    g = github PRs
    r = reflections (recent)
    p = prompt log (recent)
    a = activity (ManicTime context)
    h = health check
    t = todos/tasks
    ? = help

.EXAMPLE
    q s    # Full status snapshot
    q w    # Worktree status
    q c    # ClickUp tasks
#>

param(
    [Parameter(Position=0)]
    [string]$Command = "?"
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$scriptDir = "C:\scripts\tools"

switch ($Command.ToLower()) {
    "s" {
        Write-Host "=== FULL STATUS SNAPSHOT ===" -ForegroundColor Cyan
        Write-Host ""

        # Worktree status
        Write-Host "[WORKTREES]" -ForegroundColor Yellow
        & "$scriptDir\worktree-status.ps1" -Compact 2>$null

        Write-Host ""
        Write-Host "[GIT STATUS - client-manager]" -ForegroundColor Yellow
        Push-Location "C:\Projects\client-manager"
        git status -sb
        Pop-Location

        Write-Host ""
        Write-Host "[GIT STATUS - hazina]" -ForegroundColor Yellow
        Push-Location "C:\Projects\hazina"
        git status -sb
        Pop-Location

        Write-Host ""
        Write-Host "[RECENT PRs]" -ForegroundColor Yellow
        gh pr list --author @me --limit 5 2>$null

        Write-Host ""
        Write-Host "[PROMPT LOG - Last Entry]" -ForegroundColor Yellow
        if (Test-Path "C:\scripts\_machine\user_prompts.log.md") {
            Get-Content "C:\scripts\_machine\user_prompts.log.md" -Tail 20
        }
    }

    "w" {
        Write-Host "=== WORKTREE STATUS ===" -ForegroundColor Cyan
        & "$scriptDir\worktree-status.ps1" 2>$null
        if ($LASTEXITCODE -ne 0) {
            # Fallback to direct file read
            Get-Content "C:\scripts\_machine\worktrees.pool.md" -Head 50
        }
    }

    "c" {
        Write-Host "=== CLICKUP TASKS ===" -ForegroundColor Cyan
        & "$scriptDir\clickup-sync.ps1" -Action list 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ClickUp sync not available. Check API key." -ForegroundColor Yellow
        }
    }

    "g" {
        Write-Host "=== GITHUB PRs ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[My Open PRs]" -ForegroundColor Yellow
        gh pr list --author @me --state open

        Write-Host ""
        Write-Host "[PRs Needing Review]" -ForegroundColor Yellow
        gh pr list --search "review-requested:@me" --state open 2>$null
    }

    "r" {
        Write-Host "=== RECENT REFLECTIONS ===" -ForegroundColor Cyan
        $reflectionFile = "C:\scripts\_machine\reflection.log.md"
        if (Test-Path $reflectionFile) {
            # Show last 50 lines
            Get-Content $reflectionFile -Tail 50
        } else {
            Write-Host "No reflection log found." -ForegroundColor Yellow
        }
    }

    "p" {
        Write-Host "=== PROMPT LOG ===" -ForegroundColor Cyan
        $promptFile = "C:\scripts\_machine\user_prompts.log.md"
        if (Test-Path $promptFile) {
            Get-Content $promptFile -Tail 100
        } else {
            Write-Host "No prompt log found." -ForegroundColor Yellow
        }
    }

    "a" {
        Write-Host "=== ACTIVITY CONTEXT ===" -ForegroundColor Cyan
        & "$scriptDir\monitor-activity.ps1" -Mode context 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ManicTime monitoring not available." -ForegroundColor Yellow
        }
    }

    "h" {
        Write-Host "=== HEALTH CHECK ===" -ForegroundColor Cyan
        & "$scriptDir\system-health.ps1" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Running basic health check..." -ForegroundColor Yellow

            # Basic checks
            Write-Host ""
            Write-Host "[Git]" -ForegroundColor Yellow
            git --version

            Write-Host ""
            Write-Host "[Node]" -ForegroundColor Yellow
            node --version

            Write-Host ""
            Write-Host "[GitHub CLI]" -ForegroundColor Yellow
            gh --version | Select-Object -First 1
        }
    }

    "t" {
        Write-Host "=== CURRENT TODOS ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Check active Claude session for todo list." -ForegroundColor Yellow
        Write-Host "Or view ClickUp tasks with: q c" -ForegroundColor Gray
    }

    "?" {
        Write-Host "=== QUICK COMMANDS ===" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Usage: q <letter>" -ForegroundColor White
        Write-Host ""
        Write-Host "Commands:" -ForegroundColor Yellow
        Write-Host "  s  Status     Full environment snapshot" -ForegroundColor White
        Write-Host "  w  Worktree   Worktree pool status" -ForegroundColor White
        Write-Host "  c  ClickUp    List ClickUp tasks" -ForegroundColor White
        Write-Host "  g  GitHub     Show PRs (mine + review requests)" -ForegroundColor White
        Write-Host "  r  Reflect    Recent reflections/learnings" -ForegroundColor White
        Write-Host "  p  Prompts    Recent user prompts" -ForegroundColor White
        Write-Host "  a  Activity   ManicTime activity context" -ForegroundColor White
        Write-Host "  h  Health     System health check" -ForegroundColor White
        Write-Host "  t  Todos      Current task list" -ForegroundColor White
        Write-Host "  ?  Help       This help message" -ForegroundColor White
        Write-Host ""
        Write-Host "Expert: Tim Ferriss | 50-Expert Council #40" -ForegroundColor DarkGray
    }

    default {
        Write-Host "Unknown command: $Command" -ForegroundColor Red
        Write-Host "Use 'q ?' for help" -ForegroundColor Yellow
    }
}
