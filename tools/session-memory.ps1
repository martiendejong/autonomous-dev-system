<#
.SYNOPSIS
    Session Continuity & Cross-Session Memory
    50-Expert Council Improvements #8, #24 | Priority: 1.6, 1.43

.DESCRIPTION
    Maintains state across sessions. Saves and restores:
    - Current work context
    - Active tasks
    - Pending decisions
    - Recent learnings

.PARAMETER Save
    Save current session state.

.PARAMETER Restore
    Restore previous session state.

.PARAMETER Show
    Show current memory state.

.PARAMETER Note
    Add a note for next session.

.EXAMPLE
    session-memory.ps1 -Save
    session-memory.ps1 -Restore
    session-memory.ps1 -Note "Continue with auth feature"
#>

param(
    [switch]$Save,
    [switch]$Restore,
    [switch]$Show,
    [string]$Note = ""
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$MemoryFile = "C:\scripts\_machine\session_memory.json"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Initialize memory
if (-not (Test-Path $MemoryFile)) {
    $memory = @{
        lastSession = $null
        currentContext = ""
        pendingTasks = @()
        notes = @()
        recentLearnings = @()
        workflowState = @{
            pattern = $null
            step = 0
        }
    }
    $memory | ConvertTo-Json -Depth 10 | Set-Content $MemoryFile -Encoding UTF8
}

$memory = Get-Content $MemoryFile -Raw | ConvertFrom-Json

function Save-Session {
    Write-Host "=== SAVING SESSION STATE ===" -ForegroundColor Cyan
    Write-Host ""

    # Gather current state
    $memory.lastSession = $Timestamp

    # Get prediction state
    $predFile = "C:\scripts\_machine\task_predictions.json"
    if (Test-Path $predFile) {
        $pred = Get-Content $predFile -Raw | ConvertFrom-Json
        $memory.workflowState.pattern = $pred.currentPattern
        $memory.workflowState.step = $pred.currentStep
    }

    # Get recent from prompt log
    $promptLog = "C:\scripts\_machine\user_prompts.log.md"
    if (Test-Path $promptLog) {
        $recentPrompts = Get-Content $promptLog -Tail 50 | Where-Object { $_ -match '\*\*Raw:\*\*' } | Select-Object -Last 3
        $memory.recentLearnings = $recentPrompts | ForEach-Object {
            if ($_ -match '"([^"]+)"') { $matches[1] }
        }
    }

    $memory | ConvertTo-Json -Depth 10 | Set-Content $MemoryFile -Encoding UTF8

    Write-Host "✓ Session saved" -ForegroundColor Green
    Write-Host "  Timestamp: $Timestamp" -ForegroundColor Gray
    Write-Host "  Workflow: $($memory.workflowState.pattern) (step $($memory.workflowState.step))" -ForegroundColor Gray
    Write-Host "  Notes: $($memory.notes.Count)" -ForegroundColor Gray
}

function Restore-Session {
    Write-Host "=== RESTORING SESSION STATE ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $memory.lastSession) {
        Write-Host "No previous session to restore." -ForegroundColor Yellow
        return
    }

    Write-Host "Last session: $($memory.lastSession)" -ForegroundColor Yellow
    Write-Host ""

    if ($memory.notes.Count -gt 0) {
        Write-Host "NOTES FROM PREVIOUS SESSION:" -ForegroundColor Magenta
        foreach ($note in $memory.notes) {
            Write-Host "  • $($note.text)" -ForegroundColor White
            Write-Host "    ($($note.timestamp))" -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($memory.workflowState.pattern) {
        Write-Host "WORKFLOW STATE:" -ForegroundColor Magenta
        Write-Host "  Pattern: $($memory.workflowState.pattern)" -ForegroundColor White
        Write-Host "  Step: $($memory.workflowState.step)" -ForegroundColor White
        Write-Host ""
        Write-Host "  Resuming..." -ForegroundColor Cyan
        & "C:\scripts\tools\predict-tasks.ps1" -Show
    }

    if ($memory.recentLearnings.Count -gt 0) {
        Write-Host ""
        Write-Host "RECENT CONTEXT:" -ForegroundColor Magenta
        foreach ($learning in $memory.recentLearnings) {
            Write-Host "  • $learning" -ForegroundColor Gray
        }
    }

    # Clear notes after restore
    $memory.notes = @()
    $memory | ConvertTo-Json -Depth 10 | Set-Content $MemoryFile -Encoding UTF8
}

function Show-Memory {
    Write-Host "=== SESSION MEMORY ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Last session: $($memory.lastSession ?? 'Never')" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "PENDING NOTES:" -ForegroundColor Magenta
    if ($memory.notes.Count -eq 0) {
        Write-Host "  (none)" -ForegroundColor Gray
    } else {
        foreach ($note in $memory.notes) {
            Write-Host "  • $($note.text)" -ForegroundColor White
        }
    }
    Write-Host ""

    Write-Host "WORKFLOW STATE:" -ForegroundColor Magenta
    Write-Host "  Pattern: $($memory.workflowState.pattern ?? 'None')" -ForegroundColor White
    Write-Host "  Step: $($memory.workflowState.step ?? 0)" -ForegroundColor White
}

function Add-Note {
    param([string]$Text)

    $memory.notes += @{
        text = $Text
        timestamp = $Timestamp
    }
    $memory | ConvertTo-Json -Depth 10 | Set-Content $MemoryFile -Encoding UTF8

    Write-Host "✓ Note added for next session" -ForegroundColor Green
    Write-Host "  `"$Text`"" -ForegroundColor White
}

# Main
if ($Save) { Save-Session }
elseif ($Restore) { Restore-Session }
elseif ($Note) { Add-Note -Text $Note }
elseif ($Show) { Show-Memory }
else { Show-Memory }
