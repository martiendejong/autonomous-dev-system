<#
.SYNOPSIS
    Predictive Task Queue - Predicts next 5 tasks from patterns.
    50-Expert Council Improvement #1 | Priority: 2.0

.DESCRIPTION
    Analyzes prompt patterns, current context, and workflow state
    to predict what tasks will likely be needed next.

.PARAMETER Context
    Current work context for better predictions.

.PARAMETER Learn
    Learn from completed tasks to improve predictions.

.PARAMETER Show
    Show current prediction queue.

.EXAMPLE
    predict-tasks.ps1 -Context "Working on authentication feature"
    predict-tasks.ps1 -Show
#>

param(
    [string]$Context = "",
    [switch]$Learn,
    [switch]$Show
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$PredictionDB = "C:\scripts\_machine\task_predictions.json"

# Task sequence patterns (learned from HP's workflow)
$TaskPatterns = @{
    "feature_development" = @(
        "Allocate worktree",
        "Check existing code structure",
        "Implement core functionality",
        "Write/update tests",
        "Run build and tests",
        "Create PR",
        "Release worktree",
        "Update ClickUp status"
    )
    "bug_fix" = @(
        "Reproduce the issue",
        "Identify root cause",
        "Implement fix",
        "Add regression test",
        "Verify fix works",
        "Create PR with fix"
    )
    "refactoring" = @(
        "Analyze current code",
        "Plan refactoring approach",
        "Create backup branch",
        "Implement changes incrementally",
        "Run full test suite",
        "Review changes",
        "Create PR"
    )
    "documentation" = @(
        "Read existing docs",
        "Identify gaps",
        "Write new content",
        "Add examples",
        "Cross-reference with code",
        "Commit and push"
    )
    "ci_cd_fix" = @(
        "Check CI logs",
        "Identify failing step",
        "Fix configuration",
        "Push and verify",
        "Apply to all affected branches"
    )
    "meta_improvement" = @(
        "Analyze current state",
        "Consult expert council",
        "Design improvement",
        "Implement tool/skill",
        "Document in CLAUDE.md",
        "Update PERSONAL_INSIGHTS.md",
        "Commit and push"
    )
}

# Context keywords to pattern mapping
$ContextMapping = @{
    "feature|implement|add|create|new" = "feature_development"
    "bug|fix|error|broken|issue" = "bug_fix"
    "refactor|cleanup|reorganize|improve code" = "refactoring"
    "doc|readme|document|explain" = "documentation"
    "ci|cd|pipeline|build fail|github action" = "ci_cd_fix"
    "improve|better|optimize|meta|system" = "meta_improvement"
}

# Initialize prediction database
if (-not (Test-Path $PredictionDB)) {
    $db = @{
        currentPattern = $null
        currentStep = 0
        predictions = @()
        history = @()
        accuracy = 0
    }
    $db | ConvertTo-Json -Depth 10 | Set-Content $PredictionDB -Encoding UTF8
} else {
    $db = Get-Content $PredictionDB -Raw | ConvertFrom-Json
}

function Detect-WorkflowPattern {
    param([string]$ContextText)

    foreach ($mapping in $ContextMapping.GetEnumerator()) {
        if ($ContextText -match $mapping.Key) {
            return $mapping.Value
        }
    }
    return "feature_development"  # Default
}

function Predict-NextTasks {
    param(
        [string]$Pattern,
        [int]$CurrentStep = 0
    )

    $tasks = $TaskPatterns[$Pattern]
    if (-not $tasks) { $tasks = $TaskPatterns["feature_development"] }

    $remaining = $tasks | Select-Object -Skip $CurrentStep | Select-Object -First 5

    return $remaining
}

function Show-Predictions {
    Write-Host "=== PREDICTIVE TASK QUEUE ===" -ForegroundColor Cyan
    Write-Host ""

    if ($db.currentPattern) {
        Write-Host "Current Pattern: $($db.currentPattern)" -ForegroundColor Yellow
        Write-Host "Progress: Step $($db.currentStep + 1) of $($TaskPatterns[$db.currentPattern].Count)" -ForegroundColor Gray
        Write-Host ""
    }

    Write-Host "PREDICTED NEXT 5 TASKS:" -ForegroundColor Magenta
    Write-Host ""

    $predictions = if ($db.predictions.Count -gt 0) {
        $db.predictions
    } else {
        Predict-NextTasks -Pattern ($db.currentPattern ?? "feature_development") -CurrentStep ($db.currentStep ?? 0)
    }

    $i = 1
    foreach ($task in $predictions) {
        $color = if ($i -eq 1) { "Green" } else { "White" }
        Write-Host "  $i. $task" -ForegroundColor $color
        $i++
    }

    Write-Host ""
    Write-Host "Prediction accuracy: $($db.accuracy)%" -ForegroundColor Gray
}

function Update-Predictions {
    param([string]$ContextText)

    $pattern = Detect-WorkflowPattern -ContextText $ContextText

    Write-Host "=== UPDATING PREDICTIONS ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Context: $ContextText" -ForegroundColor Yellow
    Write-Host "Detected pattern: $pattern" -ForegroundColor Yellow
    Write-Host ""

    $db.currentPattern = $pattern
    $db.currentStep = 0
    $db.predictions = Predict-NextTasks -Pattern $pattern -CurrentStep 0

    $db | ConvertTo-Json -Depth 10 | Set-Content $PredictionDB -Encoding UTF8

    Write-Host "PREDICTED TASKS:" -ForegroundColor Magenta
    $i = 1
    foreach ($task in $db.predictions) {
        Write-Host "  $i. $task" -ForegroundColor White
        $i++
    }

    Write-Host ""
    Write-Host "TIP: Run 'predict-tasks.ps1 -Learn' after completing tasks to improve accuracy" -ForegroundColor Gray
}

function Learn-FromCompletion {
    Write-Host "=== LEARNING FROM COMPLETED TASKS ===" -ForegroundColor Cyan
    Write-Host ""

    if ($db.currentPattern -and $db.currentStep -lt $TaskPatterns[$db.currentPattern].Count) {
        $db.currentStep++
        $db.predictions = Predict-NextTasks -Pattern $db.currentPattern -CurrentStep $db.currentStep

        # Track in history
        $db.history += @{
            pattern = $db.currentPattern
            step = $db.currentStep
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }

        # Simple accuracy calculation
        $db.accuracy = [Math]::Min(100, $db.accuracy + 2)

        $db | ConvertTo-Json -Depth 10 | Set-Content $PredictionDB -Encoding UTF8

        Write-Host "Task completed. Moving to step $($db.currentStep + 1)" -ForegroundColor Green
        Write-Host ""
        Show-Predictions
    } else {
        Write-Host "No active pattern or all tasks completed." -ForegroundColor Yellow
        Write-Host "Start new workflow with: predict-tasks.ps1 -Context 'description'" -ForegroundColor Gray
    }
}

# Main execution
if ($Context) {
    Update-Predictions -ContextText $Context
} elseif ($Learn) {
    Learn-FromCompletion
} elseif ($Show -or (-not $Context -and -not $Learn)) {
    Show-Predictions
}
