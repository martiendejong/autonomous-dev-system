<#
.SYNOPSIS
    Unified CLI - Single entry point routing to all tools.
    50-Expert Council Improvement #11 | Priority: 1.67

.DESCRIPTION
    Master CLI that intelligently routes commands to appropriate tools.
    Natural language and structured command support.

.PARAMETER Command
    The command or natural language request.

.PARAMETER Args
    Additional arguments to pass to the tool.

.EXAMPLE
    claude-cli.ps1 status
    claude-cli.ps1 "check worktrees"
    claude-cli.ps1 workflow feature my-feature
#>

param(
    [Parameter(Position=0)]
    [string]$Command = "help",

    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Args
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ToolsPath = "C:\scripts\tools"

# Command routing table
$Routes = @{
    # Quick commands
    "s" = { & "$ToolsPath\q.ps1" s }
    "status" = { & "$ToolsPath\q.ps1" s }
    "w" = { & "$ToolsPath\q.ps1" w }
    "worktree" = { & "$ToolsPath\worktree-status.ps1" @Args }
    "c" = { & "$ToolsPath\q.ps1" c }
    "clickup" = { & "$ToolsPath\clickup-sync.ps1" @Args }
    "g" = { & "$ToolsPath\q.ps1" g }
    "github" = { & "$ToolsPath\q.ps1" g }

    # Workflows
    "start" = { & "$ToolsPath\workflow.ps1" -Workflow start }
    "end" = { & "$ToolsPath\workflow.ps1" -Workflow end }
    "feature" = { & "$ToolsPath\workflow.ps1" -Workflow feature -Name ($Args -join '-') }
    "bugfix" = { & "$ToolsPath\workflow.ps1" -Workflow bugfix -Name ($Args -join '-') }
    "pr" = { & "$ToolsPath\workflow.ps1" -Workflow pr }
    "release" = { & "$ToolsPath\workflow.ps1" -Workflow release }
    "improve" = { & "$ToolsPath\workflow.ps1" -Workflow improve }

    # Tools
    "reflect" = { & "$ToolsPath\reflect.ps1" @Args }
    "align" = { & "$ToolsPath\align.ps1" @Args }
    "predict" = { & "$ToolsPath\predict-tasks.ps1" @Args }
    "prevent" = { & "$ToolsPath\prevent-errors.ps1" @Args }
    "pattern" = { & "$ToolsPath\pattern-library.ps1" @Args }
    "success" = { & "$ToolsPath\success-to-pattern.ps1" @Args }
    "mistake" = { & "$ToolsPath\mistake-to-prevention.ps1" @Args }
    "find" = { & "$ToolsPath\find-tool.ps1" -Need ($Args -join ' ') }
    "desire" = { & "$ToolsPath\detect-desire.ps1" -Prompt ($Args -join ' ') -Deep }
    "learn" = { & "$ToolsPath\pattern-learn.ps1" -Analyze -Suggest }
    "docs" = { & "$ToolsPath\anticipate-docs.ps1" -Scan -Generate }

    # Health and system
    "health" = { & "$ToolsPath\system-health.ps1" @Args }
    "activity" = { & "$ToolsPath\monitor-activity.ps1" -Mode context }
}

function Show-Help {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║           CLAUDE UNIFIED CLI                                 ║" -ForegroundColor Cyan
    Write-Host "║           50-Expert Council #11                              ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "QUICK COMMANDS:" -ForegroundColor Yellow
    Write-Host "  s, status     Full status snapshot" -ForegroundColor White
    Write-Host "  w, worktree   Worktree status" -ForegroundColor White
    Write-Host "  c, clickup    ClickUp tasks" -ForegroundColor White
    Write-Host "  g, github     GitHub PRs" -ForegroundColor White
    Write-Host ""

    Write-Host "WORKFLOWS:" -ForegroundColor Yellow
    Write-Host "  start         Start session workflow" -ForegroundColor White
    Write-Host "  end           End session workflow" -ForegroundColor White
    Write-Host "  feature <n>   Start feature workflow" -ForegroundColor White
    Write-Host "  bugfix <n>    Start bugfix workflow" -ForegroundColor White
    Write-Host "  pr            Create PR workflow" -ForegroundColor White
    Write-Host "  release       Release worktree workflow" -ForegroundColor White
    Write-Host "  improve       Meta-improvement workflow" -ForegroundColor White
    Write-Host ""

    Write-Host "TOOLS:" -ForegroundColor Yellow
    Write-Host "  reflect       Mid-work reflection" -ForegroundColor White
    Write-Host "  align         Goal alignment check" -ForegroundColor White
    Write-Host "  predict       Task predictions" -ForegroundColor White
    Write-Host "  prevent       Error prevention" -ForegroundColor White
    Write-Host "  pattern       Pattern library" -ForegroundColor White
    Write-Host "  success       Log success pattern" -ForegroundColor White
    Write-Host "  mistake       Log mistake prevention" -ForegroundColor White
    Write-Host "  find <desc>   Find tool by need" -ForegroundColor White
    Write-Host "  desire <text> Analyze desire in text" -ForegroundColor White
    Write-Host "  learn         Analyze patterns" -ForegroundColor White
    Write-Host "  docs          Update documentation" -ForegroundColor White
    Write-Host "  health        System health check" -ForegroundColor White
    Write-Host "  activity      Activity context" -ForegroundColor White
    Write-Host ""

    Write-Host "NATURAL LANGUAGE:" -ForegroundColor Yellow
    Write-Host "  claude-cli.ps1 'check worktree status'" -ForegroundColor Gray
    Write-Host "  claude-cli.ps1 'start a feature'" -ForegroundColor Gray
    Write-Host ""
}

# Try natural language routing if command not in routes
function Route-NaturalLanguage {
    param([string]$Text)

    $lower = $Text.ToLower()

    if ($lower -match 'status|check|see|show') {
        if ($lower -match 'worktree') { return "worktree" }
        if ($lower -match 'github|pr') { return "github" }
        if ($lower -match 'clickup|task') { return "clickup" }
        return "status"
    }

    if ($lower -match 'start|begin|new') {
        if ($lower -match 'feature') { return "feature" }
        if ($lower -match 'bug|fix') { return "bugfix" }
        if ($lower -match 'session') { return "start" }
    }

    if ($lower -match 'end|finish|done|complete') {
        return "end"
    }

    if ($lower -match 'reflect|pause|think|contemplate') {
        return "reflect"
    }

    if ($lower -match 'pattern|library|search|find solution') {
        return "pattern"
    }

    if ($lower -match 'find|tool|need|want') {
        return "find"
    }

    return $null
}

# Main execution
if ($Command -eq "help" -or $Command -eq "?" -or $Command -eq "-h") {
    Show-Help
    return
}

# Check direct routes
if ($Routes.ContainsKey($Command)) {
    & $Routes[$Command]
    return
}

# Try natural language
$nlRoute = Route-NaturalLanguage -Text $Command
if ($nlRoute -and $Routes.ContainsKey($nlRoute)) {
    Write-Host "Interpreted as: $nlRoute" -ForegroundColor Gray
    & $Routes[$nlRoute]
    return
}

# Fall back to find-tool
Write-Host "Unknown command. Searching tools..." -ForegroundColor Yellow
& "$ToolsPath\find-tool.ps1" -Need "$Command $($Args -join ' ')"
