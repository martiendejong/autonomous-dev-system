<#
.SYNOPSIS
    Interrupt-Resume Protocol & Background Optimization
    50-Expert Council Improvements #38, #39, #33 | Priority: 1.8, 1.17, 2.0

.DESCRIPTION
    Pause and resume operations.
    Runs background optimization tasks.
    Zero-startup session restoration.

.PARAMETER Pause
    Pause current work with checkpoint.

.PARAMETER Resume
    Resume from last checkpoint.

.PARAMETER Background
    Run background optimization.

.PARAMETER ZeroStart
    Zero-startup session (restore everything).

.PARAMETER Checkpoint
    Description of current state.

.EXAMPLE
    task-control.ps1 -Pause -Checkpoint "Halfway through auth feature"
    task-control.ps1 -Resume
    task-control.ps1 -Background
    task-control.ps1 -ZeroStart
#>

param(
    [switch]$Pause,
    [switch]$Resume,
    [switch]$Background,
    [switch]$ZeroStart,
    [string]$Checkpoint = ""
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ControlFile = "C:\scripts\_machine\task_control.json"
$ToolsPath = "C:\scripts\tools"

if (-not (Test-Path $ControlFile)) {
    @{
        paused = $false
        checkpoint = $null
        lastPause = $null
        backgroundRuns = 0
    } | ConvertTo-Json -Depth 10 | Set-Content $ControlFile -Encoding UTF8
}

$ctrl = Get-Content $ControlFile -Raw | ConvertFrom-Json

if ($Pause) {
    Write-Host "=== PAUSING WORK ===" -ForegroundColor Yellow
    Write-Host ""

    # Save session memory
    & "$ToolsPath\session-memory.ps1" -Save

    $ctrl.paused = $true
    $ctrl.checkpoint = if ($Checkpoint) { $Checkpoint } else { "Paused at $(Get-Date -Format 'HH:mm')" }
    $ctrl.lastPause = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $ctrl | ConvertTo-Json -Depth 10 | Set-Content $ControlFile -Encoding UTF8

    Write-Host "✓ Work paused" -ForegroundColor Green
    Write-Host "  Checkpoint: $($ctrl.checkpoint)" -ForegroundColor White
    Write-Host ""
    Write-Host "Resume with: task-control.ps1 -Resume" -ForegroundColor Gray
}
elseif ($Resume) {
    Write-Host "=== RESUMING WORK ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $ctrl.paused) {
        Write-Host "No paused work to resume." -ForegroundColor Yellow
        return
    }

    Write-Host "Last checkpoint: $($ctrl.checkpoint)" -ForegroundColor Yellow
    Write-Host "Paused at: $($ctrl.lastPause)" -ForegroundColor Gray
    Write-Host ""

    # Restore session
    & "$ToolsPath\session-memory.ps1" -Restore

    $ctrl.paused = $false
    $ctrl | ConvertTo-Json -Depth 10 | Set-Content $ControlFile -Encoding UTF8

    Write-Host ""
    Write-Host "✓ Work resumed" -ForegroundColor Green
}
elseif ($Background) {
    Write-Host "=== RUNNING BACKGROUND OPTIMIZATION ===" -ForegroundColor Cyan
    Write-Host ""

    $tasks = @(
        @{ name = "Pattern learning"; cmd = { & "$ToolsPath\pattern-learn.ps1" -Analyze } }
        @{ name = "Context graph"; cmd = { & "$ToolsPath\context-graph.ps1" -Build } }
        @{ name = "Cache preload"; cmd = { & "$ToolsPath\smart-cache.ps1" -Preload } }
        @{ name = "Insight deduplication"; cmd = { & "$ToolsPath\context-graph.ps1" -Dedupe } }
        @{ name = "Documentation update"; cmd = { & "$ToolsPath\anticipate-docs.ps1" -Generate } }
    )

    foreach ($t in $tasks) {
        Write-Host "  → $($t.name)..." -ForegroundColor Gray
        try {
            & $t.cmd | Out-Null
            Write-Host "    ✓ Done" -ForegroundColor Green
        } catch {
            Write-Host "    ⚠ Skipped" -ForegroundColor Yellow
        }
    }

    $ctrl.backgroundRuns++
    $ctrl | ConvertTo-Json -Depth 10 | Set-Content $ControlFile -Encoding UTF8

    Write-Host ""
    Write-Host "✓ Background optimization complete (run #$($ctrl.backgroundRuns))" -ForegroundColor Green
}
elseif ($ZeroStart) {
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           ZERO-STARTUP SESSION                               ║" -ForegroundColor Cyan
    Write-Host "║           Restoring full context...                          ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $steps = @(
        @{ name = "Restore session memory"; cmd = { & "$ToolsPath\session-memory.ps1" -Restore } }
        @{ name = "Load cached context"; cmd = { & "$ToolsPath\smart-cache.ps1" -Stats } }
        @{ name = "Check orchestration"; cmd = { & "$ToolsPath\parallel-orchestrate.ps1" -Status } }
        @{ name = "Load preferences"; cmd = { & "$ToolsPath\user-preferences.ps1" -Show } }
        @{ name = "Show task predictions"; cmd = { & "$ToolsPath\predict-tasks.ps1" -Show } }
    )

    foreach ($s in $steps) {
        Write-Host ""
        Write-Host "[$($s.name)]" -ForegroundColor Yellow
        try {
            & $s.cmd
        } catch {
            Write-Host "  (skipped)" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "✓ ZERO-STARTUP COMPLETE - Full context restored" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Pause -Checkpoint 'x'   Pause with checkpoint" -ForegroundColor White
    Write-Host "  -Resume                  Resume from checkpoint" -ForegroundColor White
    Write-Host "  -Background              Run optimization tasks" -ForegroundColor White
    Write-Host "  -ZeroStart               Full context restoration" -ForegroundColor White
}
