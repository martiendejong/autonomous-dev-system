<#
.SYNOPSIS
    ClickUp synchronization tool for Claude Agent

.DESCRIPTION
    Syncs tasks between ClickUp and local development workflow.
    Supports listing, updating, and creating tasks.

.PARAMETER Action
    list    - List open tasks from Vera AI list
    update  - Update a task's status
    create  - Create a new task
    comment - Add comment to a task
    show    - Show task details

.PARAMETER TaskId
    ClickUp task ID (for update/comment/show actions)

.PARAMETER Status
    New status for task (for update action)

.PARAMETER Assignee
    User ID to assign task to (for update action, optional)

.PARAMETER Comment
    Comment text (for comment action)

.PARAMETER Name
    Task name (for create action)

.PARAMETER Description
    Task description (for create action)

.EXAMPLE
    .\clickup-sync.ps1 -Action list
    .\clickup-sync.ps1 -Action update -TaskId "869bhfw7r" -Status "busy"
    .\clickup-sync.ps1 -Action update -TaskId "869bhfw7r" -Status "busy" -Assignee "74525428"
    .\clickup-sync.ps1 -Action comment -TaskId "869bhfw7r" -Comment "PR #149 created"
    .\clickup-sync.ps1 -Action create -Name "Fix login bug" -Description "Details here"

.NOTES
    Workflow:
    - todo     : Task created
    - busy     : Agent working, branch/PR created
    - review   : PR merged, ready for acceptance test
    - done     : Acceptance test passed (user sets this)

    Branch naming: feature/<task-id>-<description>
    Example: feature/869bhfw7r-restaurant-menu
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("list", "update", "create", "comment", "show", "link-pr", "pr-merged")]
    [string]$Action,

    [string]$TaskId,
    [string]$Status,
    [string]$Assignee,
    [string]$Comment,
    [string]$Name,
    [string]$Description,
    [int]$PrNumber,
    [string]$Repo = "martiendejong/client-manager",
    [string]$ListId = "901214097647"  # Default: Brand Designer list (client-manager)
)

# DISABLED: Usage logger interferes with output capture when called from bash
# TODO: Fix usage logger to not suppress stdout/stderr
# # AUTO-USAGE TRACKING
# try {
#     $toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
#     . "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction Stop
# } catch {
#     # Silently continue if usage logging fails
# }

# Load config
$configPath = "C:\scripts\_machine\clickup-config.json"
if (-not (Test-Path $configPath)) {
    Write-Error "Config not found: $configPath"
    exit 1
}
$config = Get-Content $configPath | ConvertFrom-Json
$apiKey = $config.api_key
$apiBase = $config.api_base

$headers = @{
    Authorization = $apiKey
    "Content-Type" = "application/json"
}

function Format-TaskTable {
    param($tasks)

    $tasks | ForEach-Object {
        [PSCustomObject]@{
            ID = $_.id
            Name = if ($_.name.Length -gt 50) { $_.name.Substring(0,47) + "..." } else { $_.name }
            Status = $_.status.status
            Updated = [DateTimeOffset]::FromUnixTimeMilliseconds([long]$_.date_updated).ToString("yyyy-MM-dd")
        }
    } | Format-Table -AutoSize
}

switch ($Action) {
    "list" {
        Write-Host "`n=== Brand Designer Tasks (client-manager/hazina) ===" -ForegroundColor Cyan

        $url = "$apiBase/list/$ListId/task?archived=false&include_closed=false"
        $response = Invoke-RestMethod -Uri $url -Headers $headers

        # Group by status
        $grouped = $response.tasks | Group-Object { $_.status.status }

        foreach ($group in $grouped | Sort-Object { $_.Values[0].status.orderindex }) {
            Write-Host "`n[$($group.Name)] ($($group.Count) tasks)" -ForegroundColor Yellow
            Format-TaskTable $group.Group
        }

        Write-Host "`nTotal: $($response.tasks.Count) open tasks" -ForegroundColor Green
    }

    "show" {
        if (-not $TaskId) {
            Write-Error "TaskId required for show action"
            exit 1
        }

        $url = "$apiBase/task/$TaskId"
        $task = Invoke-RestMethod -Uri $url -Headers $headers

        Write-Host "`n=== Task Details ===" -ForegroundColor Cyan
        Write-Host "ID:          $($task.id)"
        Write-Host "Name:        $($task.name)"
        Write-Host "Status:      $($task.status.status)"
        Write-Host "Created:     $([DateTimeOffset]::FromUnixTimeMilliseconds([long]$task.date_created).ToString("yyyy-MM-dd HH:mm"))"
        Write-Host "Updated:     $([DateTimeOffset]::FromUnixTimeMilliseconds([long]$task.date_updated).ToString("yyyy-MM-dd HH:mm"))"
        Write-Host "URL:         $($task.url)"
        if ($task.description) {
            Write-Host "`nDescription:" -ForegroundColor Yellow
            Write-Host $task.description
        }
    }

    "update" {
        if (-not $TaskId) {
            Write-Error "TaskId required for update action"
            exit 1
        }
        if (-not $Status) {
            Write-Error "Status required for update action"
            exit 1
        }

        # Update status
        $url = "$apiBase/task/$TaskId"
        $body = @{ status = $Status } | ConvertTo-Json
        $task = Invoke-RestMethod -Method PUT -Uri $url -Headers $headers -Body $body
        Write-Host "Task $TaskId updated to status: $Status" -ForegroundColor Green

        # Update assignee if provided
        if ($Assignee) {
            $assignUrl = "$apiBase/task/$TaskId"
            $assignBody = @{
                assignees = @{
                    add = @($Assignee)
                }
            } | ConvertTo-Json -Depth 3

            try {
                Invoke-RestMethod -Method PUT -Uri $assignUrl -Headers $headers -Body $assignBody | Out-Null
                Write-Host "Task $TaskId assigned to user: $Assignee" -ForegroundColor Green
            } catch {
                Write-Warning "Failed to assign task: $($_.Exception.Message)"
            }
        }

        Write-Host "URL: $($task.url)"
    }

    "comment" {
        if (-not $TaskId) {
            Write-Error "TaskId required for comment action"
            exit 1
        }
        if (-not $Comment) {
            Write-Error "Comment required for comment action"
            exit 1
        }

        $url = "$apiBase/task/$TaskId/comment"
        $body = @{ comment_text = $Comment } | ConvertTo-Json

        $result = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
        Write-Host "Comment added to task $TaskId" -ForegroundColor Green
    }

    "create" {
        if (-not $Name) {
            Write-Error "Name required for create action"
            Write-Output "ERROR: Name required for create action"
            exit 1
        }

        $url = "$apiBase/list/$ListId/task"
        $body = @{
            name = $Name
            description = if ($Description) { $Description } else { "" }
            status = "todo"
        } | ConvertTo-Json

        try {
            Write-Host "`nCreating task in list $ListId..." -ForegroundColor Yellow

            $task = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body -ErrorAction Stop

            Write-Host "`n=== Task Created Successfully ===" -ForegroundColor Green
            Write-Host "ID: $($task.id)"
            Write-Host "Name: $($task.name)"
            Write-Host "Status: $($task.status.status)"
            Write-Host "URL: $($task.url)"
        } catch {
            Write-Host "`n=== Error Creating Task ===" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)"
            if ($_.ErrorDetails) {
                Write-Host "Details: $($_.ErrorDetails.Message)"
            }
            exit 1
        }
    }

    "link-pr" {
        # Link a PR to a ClickUp task (when PR is created)
        if (-not $TaskId) {
            Write-Error "TaskId required for link-pr action"
            exit 1
        }
        if (-not $PrNumber) {
            Write-Error "PrNumber required for link-pr action"
            exit 1
        }

        $prUrl = "https://github.com/$Repo/pull/$PrNumber"
        $commentText = "GitHub PR #${PrNumber}: $prUrl"

        $url = "$apiBase/task/$TaskId/comment"
        $body = @{ comment_text = $commentText } | ConvertTo-Json

        $result = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
        Write-Host "PR #$PrNumber linked to task $TaskId" -ForegroundColor Green
        Write-Host "Task URL: https://app.clickup.com/t/$TaskId"
    }

    "pr-merged" {
        # Update task when PR is merged (set to review for acceptance test)
        if (-not $TaskId) {
            Write-Error "TaskId required for pr-merged action"
            exit 1
        }
        if (-not $PrNumber) {
            Write-Error "PrNumber required for pr-merged action"
            exit 1
        }

        # Update status to review
        $url = "$apiBase/task/$TaskId"
        $body = @{ status = "review" } | ConvertTo-Json
        $task = Invoke-RestMethod -Method PUT -Uri $url -Headers $headers -Body $body

        # Add merge comment
        $prUrl = "https://github.com/$Repo/pull/$PrNumber"
        $commentText = "PR #${PrNumber} merged: $prUrl - Ready for acceptance test."
        $commentUrl = "$apiBase/task/$TaskId/comment"
        $commentBody = @{ comment_text = $commentText } | ConvertTo-Json
        Invoke-RestMethod -Method POST -Uri $commentUrl -Headers $headers -Body $commentBody | Out-Null

        Write-Host "Task $TaskId updated to 'review' - ready for acceptance test" -ForegroundColor Green
        Write-Host "Task URL: $($task.url)"
    }
}
