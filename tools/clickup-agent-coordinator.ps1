<#
.SYNOPSIS
    Multi-agent coordination for ClickUp task management

.DESCRIPTION
    Enables multiple Claude agents to coordinate on ClickUp tasks.
    Prevents conflicts, enables communication, tracks agent assignments.

.PARAMETER Action
    claim      - Claim a task for current agent
    release    - Release a task after completion
    status     - Show all agent task assignments
    message    - Post message to coordination log
    check      - Check if task is available (not claimed by another agent)

.PARAMETER TaskId
    ClickUp task ID

.PARAMETER AgentId
    Agent identifier (e.g., "clickhub-001", "clickhub-002")

.PARAMETER Message
    Message text for coordination log

.EXAMPLE
    .\clickup-agent-coordinator.ps1 -Action claim -TaskId "869bx1me1" -AgentId "clickhub-001"
    .\clickup-agent-coordinator.ps1 -Action status
    .\clickup-agent-coordinator.ps1 -Action message -AgentId "clickhub-001" -Message "Starting work on 3 todo tasks"
    .\clickup-agent-coordinator.ps1 -Action check -TaskId "869bx1me1"
    .\clickup-agent-coordinator.ps1 -Action release -TaskId "869bx1me1" -AgentId "clickhub-001"

.NOTES
    Coordination state stored in: C:\scripts\_machine\clickup-agent-coordination.json
    Communication log: C:\scripts\_machine\clickup-agent-coordination.log.md
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("claim", "release", "status", "message", "check")]
    [string]$Action,

    [string]$TaskId,
    [string]$AgentId,
    [string]$Message
)

$stateFile = "C:\scripts\_machine\clickup-agent-coordination.json"
$logFile = "C:\scripts\_machine\clickup-agent-coordination.log.md"

# Initialize state file if doesn't exist
if (-not (Test-Path $stateFile)) {
    @{
        agents = @{}
        claims = @{}
        last_updated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    } | ConvertTo-Json -Depth 5 | Set-Content $stateFile -Encoding UTF8
}

# Initialize log file if doesn't exist
if (-not (Test-Path $logFile)) {
    @"
# ClickUp Agent Coordination Log

**Purpose:** Communication channel for multiple Claude agents working on ClickUp tasks
**Created:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

---

"@ | Set-Content $logFile -Encoding UTF8
}

# Load current state
$state = Get-Content $stateFile -Raw | ConvertFrom-Json

function Write-Log {
    param($Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $Message" | Add-Content $logFile -Encoding UTF8
}

function Get-AgentColor {
    param($AgentId)
    $colors = @{
        "clickhub-001" = "Cyan"
        "clickhub-002" = "Green"
        "clickhub-003" = "Yellow"
        "clickhub-004" = "Magenta"
    }
    if ($colors.ContainsKey($AgentId)) {
        return $colors[$AgentId]
    }
    return "White"
}

switch ($Action) {
    "claim" {
        if (-not $TaskId) {
            Write-Error "TaskId required for claim action"
            exit 1
        }
        if (-not $AgentId) {
            Write-Error "AgentId required for claim action"
            exit 1
        }

        # Check if task already claimed
        if ($state.claims.PSObject.Properties.Name -contains $TaskId) {
            $existingClaim = $state.claims.$TaskId
            if ($existingClaim.agent_id -ne $AgentId) {
                Write-Host "❌ CONFLICT: Task $TaskId already claimed by $($existingClaim.agent_id)" -ForegroundColor Red
                Write-Host "   Claimed at: $($existingClaim.claimed_at)" -ForegroundColor Red
                Write-Host "   Duration: $((New-TimeSpan -Start ([DateTime]$existingClaim.claimed_at) -End (Get-Date)).TotalMinutes.ToString('0.0')) minutes" -ForegroundColor Red
                exit 1
            } else {
                Write-Host "ℹ️  Task $TaskId already claimed by you" -ForegroundColor Yellow
                exit 0
            }
        }

        # Claim task
        $claim = @{
            agent_id = $AgentId
            claimed_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            status = "claimed"
        }

        # Add claim to state
        if (-not $state.claims) {
            $state.claims = @{}
        }
        $state.claims | Add-Member -NotePropertyName $TaskId -NotePropertyValue $claim -Force
        $state.last_updated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")

        $state | ConvertTo-Json -Depth 5 | Set-Content $stateFile -Encoding UTF8

        Write-Host "✅ Task $TaskId claimed by $AgentId" -ForegroundColor Green
        Write-Log "CLAIM | Agent: $AgentId | Task: $TaskId"
    }

    "release" {
        if (-not $TaskId) {
            Write-Error "TaskId required for release action"
            exit 1
        }
        if (-not $AgentId) {
            Write-Error "AgentId required for release action"
            exit 1
        }

        # Check if task is claimed
        if ($state.claims.PSObject.Properties.Name -contains $TaskId) {
            $existingClaim = $state.claims.$TaskId
            if ($existingClaim.agent_id -ne $AgentId) {
                Write-Host "⚠️  WARNING: Task $TaskId claimed by $($existingClaim.agent_id), not you ($AgentId)" -ForegroundColor Yellow
            }

            # Remove claim
            $state.claims.PSObject.Properties.Remove($TaskId)
            $state.last_updated = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            $state | ConvertTo-Json -Depth 5 | Set-Content $stateFile -Encoding UTF8

            Write-Host "✅ Task $TaskId released by $AgentId" -ForegroundColor Green
            Write-Log "RELEASE | Agent: $AgentId | Task: $TaskId"
        } else {
            Write-Host "ℹ️  Task $TaskId was not claimed" -ForegroundColor Yellow
        }
    }

    "status" {
        Write-Host "`n=== ClickUp Agent Coordination Status ===" -ForegroundColor Cyan
        Write-Host "Last Updated: $($state.last_updated)`n"

        if ($state.claims.PSObject.Properties.Count -eq 0) {
            Write-Host "No active task claims" -ForegroundColor Yellow
        } else {
            Write-Host "Active Task Claims:" -ForegroundColor Green
            foreach ($taskId in $state.claims.PSObject.Properties.Name) {
                $claim = $state.claims.$taskId
                $duration = (New-TimeSpan -Start ([DateTime]$claim.claimed_at) -End (Get-Date)).TotalMinutes
                $color = Get-AgentColor $claim.agent_id
                Write-Host "  📌 Task: $taskId" -ForegroundColor $color
                Write-Host "     Agent: $($claim.agent_id)" -ForegroundColor $color
                Write-Host "     Claimed: $($claim.claimed_at) ($($duration.ToString('0.0')) min ago)" -ForegroundColor $color
                Write-Host ""
            }
        }

        # Show recent log entries
        Write-Host "`nRecent Activity (last 10 entries):" -ForegroundColor Cyan
        if (Test-Path $logFile) {
            Get-Content $logFile -Tail 10 | ForEach-Object {
                if ($_ -match '^\[') {
                    Write-Host $_ -ForegroundColor Gray
                }
            }
        }
    }

    "message" {
        if (-not $AgentId) {
            Write-Error "AgentId required for message action"
            exit 1
        }
        if (-not $Message) {
            Write-Error "Message required for message action"
            exit 1
        }

        Write-Log "MESSAGE | Agent: $AgentId | $Message"
        Write-Host "✅ Message posted to coordination log" -ForegroundColor Green
    }

    "check" {
        if (-not $TaskId) {
            Write-Error "TaskId required for check action"
            exit 1
        }

        if ($state.claims.PSObject.Properties.Name -contains $TaskId) {
            $claim = $state.claims.$TaskId
            Write-Host "❌ Task $TaskId is CLAIMED by $($claim.agent_id)" -ForegroundColor Red
            Write-Host "   Claimed at: $($claim.claimed_at)" -ForegroundColor Red
            exit 1
        } else {
            Write-Host "✅ Task $TaskId is AVAILABLE" -ForegroundColor Green
            exit 0
        }
    }
}
