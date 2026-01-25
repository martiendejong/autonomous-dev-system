<#
.SYNOPSIS
    Smart Tool Discovery - "I need to X" → suggests/runs correct tool.
    50-Expert Council Improvement #13 | Priority: 2.25

.DESCRIPTION
    Natural language tool discovery. Describe what you need,
    get the right tool suggested and optionally executed.

.PARAMETER Need
    Describe what you need to do.

.PARAMETER Run
    Automatically run the suggested tool.

.PARAMETER List
    List all available tools with descriptions.

.EXAMPLE
    find-tool.ps1 -Need "check worktree status"
    find-tool.ps1 -Need "create a PR" -Run
    find-tool.ps1 -List
#>

param(
    [string]$Need = "",
    [switch]$Run,
    [switch]$List
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ToolsPath = "C:\scripts\tools"

# Tool registry with keywords and descriptions
$ToolRegistry = @(
    @{
        name = "q.ps1"
        keywords = @("quick", "status", "snapshot", "overview", "check", "see")
        description = "Quick commands - single letter access (q s, q w, q c, etc.)"
        usage = "q.ps1 s  # or q.ps1 w, q.ps1 c, q.ps1 g"
    },
    @{
        name = "workflow.ps1"
        keywords = @("workflow", "feature", "bugfix", "pr", "start", "end", "improve")
        description = "One-command workflows for complete operations"
        usage = "workflow.ps1 -Workflow feature -Name 'my-feature'"
    },
    @{
        name = "worktree-allocate.ps1"
        keywords = @("worktree", "allocate", "branch", "checkout", "workspace")
        description = "Allocate a worktree for isolated development"
        usage = "worktree-allocate.ps1 -Repo client-manager -Branch feature/x"
    },
    @{
        name = "worktree-status.ps1"
        keywords = @("worktree", "status", "pool", "agents", "busy", "free")
        description = "Check worktree pool status"
        usage = "worktree-status.ps1 -Compact"
    },
    @{
        name = "prevent-errors.ps1"
        keywords = @("prevent", "error", "mistake", "check", "safe", "verify")
        description = "Check action against known error patterns"
        usage = "prevent-errors.ps1 -Action 'description of action'"
    },
    @{
        name = "mistake-to-prevention.ps1"
        keywords = @("mistake", "error", "learn", "prevention", "rule")
        description = "Create prevention rule from a mistake"
        usage = "mistake-to-prevention.ps1 -Mistake 'what happened' -Severity HIGH"
    },
    @{
        name = "success-to-pattern.ps1"
        keywords = @("success", "pattern", "win", "worked", "reuse")
        description = "Save a success as reusable pattern"
        usage = "success-to-pattern.ps1 -Success 'what worked' -Tags 'tag1,tag2'"
    },
    @{
        name = "pattern-library.ps1"
        keywords = @("pattern", "library", "search", "find", "solution")
        description = "Search pattern library for solutions"
        usage = "pattern-library.ps1 -Search 'keyword'"
    },
    @{
        name = "pattern-learn.ps1"
        keywords = @("learn", "analyze", "prompt", "pattern", "behavior")
        description = "Analyze prompts for patterns"
        usage = "pattern-learn.ps1 -Analyze -Suggest"
    },
    @{
        name = "predict-tasks.ps1"
        keywords = @("predict", "next", "task", "queue", "forecast")
        description = "Predict next tasks based on workflow"
        usage = "predict-tasks.ps1 -Context 'current work'"
    },
    @{
        name = "reflect.ps1"
        keywords = @("reflect", "pause", "contemplate", "check", "direction")
        description = "Mid-work reflection checkpoint"
        usage = "reflect.ps1 -Context 'what im doing' -Goal 'original goal'"
    },
    @{
        name = "align.ps1"
        keywords = @("align", "goal", "verify", "direction", "on track")
        description = "Goal alignment verification"
        usage = "align.ps1 -CurrentTask 'task' -SessionGoal 'goal'"
    },
    @{
        name = "log-user-prompt.ps1"
        keywords = @("log", "prompt", "user", "track", "record")
        description = "Log user prompt for analysis"
        usage = "log-user-prompt.ps1 -Prompt 'user text' -Analyze"
    },
    @{
        name = "clickup-sync.ps1"
        keywords = @("clickup", "task", "sync", "todo", "list")
        description = "Sync with ClickUp tasks"
        usage = "clickup-sync.ps1 -Action list"
    },
    @{
        name = "monitor-activity.ps1"
        keywords = @("activity", "monitor", "manictime", "context", "user")
        description = "Monitor user activity via ManicTime"
        usage = "monitor-activity.ps1 -Mode context"
    },
    @{
        name = "system-health.ps1"
        keywords = @("health", "system", "check", "status", "environment")
        description = "System health check"
        usage = "system-health.ps1 -Fix"
    },
    @{
        name = "cs-format.ps1"
        keywords = @("format", "csharp", "code", "style", "lint")
        description = "Format C# code"
        usage = "cs-format.ps1 -Path ."
    },
    @{
        name = "detect-mode.ps1"
        keywords = @("mode", "debug", "feature", "detect", "workflow")
        description = "Detect Feature vs Debug mode"
        usage = "detect-mode.ps1 -UserMessage 'message' -Analyze"
    }
)

function Find-BestTool {
    param([string]$Description)

    $desc = $Description.ToLower()
    $scores = @()

    foreach ($tool in $ToolRegistry) {
        $score = 0
        foreach ($keyword in $tool.keywords) {
            if ($desc -match $keyword) {
                $score += 10
            }
        }
        # Partial matches
        $descWords = $desc -split '\s+'
        foreach ($word in $descWords) {
            if ($word.Length -gt 3) {
                foreach ($keyword in $tool.keywords) {
                    if ($keyword -match $word -or $word -match $keyword) {
                        $score += 3
                    }
                }
            }
        }

        if ($score -gt 0) {
            $scores += @{
                tool = $tool
                score = $score
            }
        }
    }

    return $scores | Sort-Object score -Descending
}

function Show-AllTools {
    Write-Host "=== ALL AVAILABLE TOOLS ===" -ForegroundColor Cyan
    Write-Host ""

    $categories = @{
        "Quick & Status" = @("q.ps1", "workflow.ps1")
        "Worktree Management" = @("worktree-allocate.ps1", "worktree-status.ps1")
        "Error Prevention" = @("prevent-errors.ps1", "mistake-to-prevention.ps1")
        "Pattern Learning" = @("success-to-pattern.ps1", "pattern-library.ps1", "pattern-learn.ps1")
        "Task & Planning" = @("predict-tasks.ps1", "reflect.ps1", "align.ps1")
        "Logging & Monitoring" = @("log-user-prompt.ps1", "monitor-activity.ps1")
        "System & Code" = @("system-health.ps1", "cs-format.ps1", "detect-mode.ps1", "clickup-sync.ps1")
    }

    foreach ($cat in $categories.GetEnumerator()) {
        Write-Host "$($cat.Key):" -ForegroundColor Yellow
        foreach ($toolName in $cat.Value) {
            $tool = $ToolRegistry | Where-Object { $_.name -eq $toolName }
            if ($tool) {
                Write-Host "  $($tool.name)" -ForegroundColor Cyan
                Write-Host "    $($tool.description)" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
}

# Main execution
if ($List) {
    Show-AllTools
    return
}

if (-not $Need) {
    Write-Host "=== SMART TOOL DISCOVERY ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: find-tool.ps1 -Need 'what you need to do'" -ForegroundColor Yellow
    Write-Host "       find-tool.ps1 -List  # show all tools" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Magenta
    Write-Host "  find-tool.ps1 -Need 'check worktree status'" -ForegroundColor White
    Write-Host "  find-tool.ps1 -Need 'create a feature'" -ForegroundColor White
    Write-Host "  find-tool.ps1 -Need 'prevent mistakes' -Run" -ForegroundColor White
    return
}

Write-Host "=== SMART TOOL DISCOVERY ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "You need: $Need" -ForegroundColor Yellow
Write-Host ""

$matches = Find-BestTool -Description $Need

if ($matches.Count -eq 0) {
    Write-Host "No matching tools found." -ForegroundColor Yellow
    Write-Host "Try: find-tool.ps1 -List" -ForegroundColor Gray
    return
}

Write-Host "RECOMMENDED TOOLS:" -ForegroundColor Magenta
Write-Host ""

$top = $matches | Select-Object -First 3

foreach ($match in $top) {
    $t = $match.tool
    $confidence = [math]::Min(100, $match.score * 5)
    Write-Host "[$confidence% match] $($t.name)" -ForegroundColor $(if ($confidence -ge 70) { "Green" } elseif ($confidence -ge 40) { "Yellow" } else { "Gray" })
    Write-Host "  $($t.description)" -ForegroundColor White
    Write-Host "  Usage: $($t.usage)" -ForegroundColor Gray
    Write-Host ""
}

if ($Run -and $top.Count -gt 0) {
    $bestTool = $top[0].tool
    Write-Host "EXECUTING: $($bestTool.name)" -ForegroundColor Cyan
    Write-Host ""
    & "$ToolsPath\$($bestTool.name)"
}
