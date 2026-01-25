<#
.SYNOPSIS
    ClickHub Coding Agent - Single Cycle Execution

.DESCRIPTION
    Runs one cycle of the ClickHub agent workflow:
    - Fetch unassigned tasks
    - Analyze for uncertainties
    - Post questions / move to blocked
    - Execute todo tasks
    - Does NOT sleep (single cycle only)

.PARAMETER DryRun
    If specified, shows what would be done without making changes

.PARAMETER MaxTasks
    Maximum number of tasks to process in this cycle (default: 5)

.EXAMPLE
    .\clickhub-single-cycle.ps1 -DryRun
    .\clickhub-single-cycle.ps1 -MaxTasks 3

.NOTES
    This script is designed to be called by Claude Agent
    For continuous operation, use clickhub-continuous.ps1
#>

param(
    [switch]$DryRun,
    [int]$MaxTasks = 5
)

$ErrorActionPreference = "Stop"

# Paths
$scriptRoot = Split-Path -Parent $PSCommandPath
$toolsPath = "C:\scripts\tools"
$machinePath = "C:\scripts\_machine"
$activityLog = "$machinePath\clickhub-activity.log"

# Ensure log file exists
if (-not (Test-Path $activityLog)) {
    New-Item -Path $activityLog -ItemType File -Force | Out-Null
}

function Write-Log {
    param($Message)
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $logLine = "$timestamp | $Message"
    Add-Content -Path $activityLog -Value $logLine
    Write-Host "[$timestamp] $Message"
}

function Get-UnassignedTasks {
    Write-Log "Fetching unassigned tasks from ClickUp..."

    # Call clickup-sync.ps1 to list tasks
    $output = & "$toolsPath\clickup-sync.ps1" -Action list 2>&1

    # Parse output to extract task IDs
    # This is a simplified parser - actual implementation would parse the table output
    # For now, return placeholder

    Write-Log "Found tasks to process"

    # Return array of task objects
    # In real implementation, parse the clickup-sync.ps1 output
    return @()
}

function Test-TaskUncertainties {
    param(
        [Parameter(Mandatory)]
        [string]$TaskId,
        [Parameter(Mandatory)]
        [string]$TaskName,
        [Parameter(Mandatory)]
        [string]$TaskDescription
    )

    Write-Log "ANALYZE | Task $TaskId | Checking for uncertainties..."

    # Placeholder for uncertainty detection logic
    # In real implementation, Claude would analyze:
    # 1. Task description completeness
    # 2. Existing code/branches
    # 3. Architectural decisions needed
    # 4. UI/UX specifications

    $uncertainties = @()

    # Example heuristics:
    if ($TaskDescription -match "should|could|might") {
        $uncertainties += "Vague requirements detected (should/could/might)"
    }

    if ($TaskDescription.Length -lt 50) {
        $uncertainties += "Description too short - lacks implementation details"
    }

    return $uncertainties
}

function Move-TaskToBlocked {
    param(
        [Parameter(Mandatory)]
        [string]$TaskId,
        [Parameter(Mandatory)]
        [string[]]$Questions
    )

    $questionText = ($Questions | ForEach-Object { "- $_" }) -join "`n"

    $comment = @"
QUESTIONS BEFORE IMPLEMENTATION:

$questionText

Please clarify before I proceed with implementation.

-- ClickHub Coding Agent ($(Get-Date -Format "yyyy-MM-dd HH:mm"))
"@

    if ($DryRun) {
        Write-Log "DRY-RUN | Would post comment to task $TaskId"
        Write-Log "DRY-RUN | Would update task $TaskId to blocked"
    } else {
        Write-Log "BLOCK | Task $TaskId | Posting questions and moving to blocked..."

        # Post comment
        & "$toolsPath\clickup-sync.ps1" -Action comment -TaskId $TaskId -Comment $comment

        # Update status
        & "$toolsPath\clickup-sync.ps1" -Action update -TaskId $TaskId -Status "blocked"

        Write-Log "BLOCK | Task $TaskId | Moved to blocked"
    }
}

function Start-TaskImplementation {
    param(
        [Parameter(Mandatory)]
        [string]$TaskId,
        [Parameter(Mandatory)]
        [string]$TaskName
    )

    Write-Log "IMPLEMENT | Task $TaskId | Starting implementation..."

    if ($DryRun) {
        Write-Log "DRY-RUN | Would allocate worktree for task $TaskId"
        Write-Log "DRY-RUN | Would implement task: $TaskName"
        Write-Log "DRY-RUN | Would create PR and link to task"
    } else {
        Write-Log "IMPLEMENT | Task $TaskId | This would trigger Claude to:"
        Write-Log "  1. Allocate worktree (via allocate-worktree skill)"
        Write-Log "  2. Implement changes"
        Write-Log "  3. Create PR"
        Write-Log "  4. Link PR to ClickUp"
        Write-Log "  5. Release worktree"
        Write-Host "`nNOTE: Actual implementation requires Claude Agent execution context" -ForegroundColor Yellow
    }
}

# Main Execution
Write-Log "CYCLE_START | MaxTasks=$MaxTasks, DryRun=$DryRun"

try {
    # Step 1: Fetch unassigned tasks
    $tasks = Get-UnassignedTasks

    if ($tasks.Count -eq 0) {
        Write-Log "CYCLE_END | No unassigned tasks found"
        exit 0
    }

    Write-Log "CYCLE_START | $($tasks.Count) unassigned tasks found"

    # Step 2: Process each task (up to MaxTasks)
    $processedCount = 0
    foreach ($task in $tasks) {
        if ($processedCount -ge $MaxTasks) {
            Write-Log "CYCLE_LIMIT | Reached max tasks ($MaxTasks), stopping"
            break
        }

        # Analyze task for uncertainties
        $uncertainties = Test-TaskUncertainties -TaskId $task.Id -TaskName $task.Name -TaskDescription $task.Description

        if ($uncertainties.Count -gt 0) {
            # Has uncertainties - post questions and block
            Move-TaskToBlocked -TaskId $task.Id -Questions $uncertainties
        } else {
            # No uncertainties - implement
            Start-TaskImplementation -TaskId $task.Id -TaskName $task.Name
        }

        $processedCount++
    }

    Write-Log "CYCLE_END | Processed $processedCount tasks"

} catch {
    Write-Log "ERROR | $($_.Exception.Message)"
    Write-Error $_
    exit 1
}
