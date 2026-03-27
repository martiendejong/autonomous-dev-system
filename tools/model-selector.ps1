<#
.SYNOPSIS
    Intelligent model selection for Claude Code based on task complexity.

.DESCRIPTION
    Analyzes task complexity and recommends the optimal Claude model:
    - Haiku: Simple edits, file reads, routine refactoring ($0.80/M input)
    - Sonnet: Medium complexity, code reviews, testing ($3/M input)
    - Opus: Architecture, complex debugging, multi-file analysis ($15/M input)

    NOTE: Programmatic model switching requires Claude Code feature (Issue #17772).
          This script provides recommendations until that feature is available.

.PARAMETER Task
    Description of the task to perform

.PARAMETER Analyze
    Analyze task complexity and return recommended model

.PARAMETER Stats
    Show cost comparison statistics

.EXAMPLE
    .\model-selector.ps1 -Task "Fix typo in README.md" -Analyze
    .\model-selector.ps1 -Task "Redesign authentication system" -Analyze
    .\model-selector.ps1 -Stats
#>

param(
    [string]$Task,
    [switch]$Analyze,
    [switch]$Stats
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ModelPricing = @{
    "haiku" = @{
        "input" = 0.80
        "output" = 4.00
        "description" = "Fast, cost-effective for routine tasks"
        "use_cases" = @(
            "File reading and simple edits",
            "Code formatting and linting",
            "Simple refactoring (rename, extract)",
            "Documentation updates",
            "TODO extraction and task listing"
        )
    }
    "sonnet" = @{
        "input" = 3.00
        "output" = 15.00
        "description" = "Balanced performance and cost"
        "use_cases" = @(
            "Code reviews and PR analysis",
            "Medium-complexity refactoring",
            "Test writing and debugging",
            "Feature implementation (single file)",
            "API integration"
        )
    }
    "opus" = @{
        "input" = 15.00
        "output" = 75.00
        "description" = "Maximum capability for complex tasks"
        "use_cases" = @(
            "Architecture design and planning",
            "Multi-file refactoring",
            "Complex debugging and root cause analysis",
            "System-wide pattern changes",
            "Performance optimization"
        )
    }
}

function Get-TaskComplexity {
    param([string]$TaskDescription)

    $complexity = 0
    $reasons = @()

    # Keyword analysis for complexity scoring
    $simpleKeywords = @("fix typo", "update readme", "add comment", "format", "lint", "rename variable")
    $mediumKeywords = @("refactor", "add test", "fix bug", "implement", "update", "review")
    $complexKeywords = @("architecture", "design", "optimize", "migrate", "redesign", "multi-file", "system-wide")

    $taskLower = $TaskDescription.ToLower()

    # Simple task indicators
    foreach ($keyword in $simpleKeywords) {
        if ($taskLower -like "*$keyword*") {
            $complexity += 1
            $reasons += "Simple task: $keyword"
        }
    }

    # Medium task indicators
    foreach ($keyword in $mediumKeywords) {
        if ($taskLower -like "*$keyword*") {
            $complexity += 3
            $reasons += "Medium complexity: $keyword"
        }
    }

    # Complex task indicators
    foreach ($keyword in $complexKeywords) {
        if ($taskLower -like "*$keyword*") {
            $complexity += 7
            $reasons += "High complexity: $keyword"
        }
    }

    # File count estimation
    if ($taskLower -match "(\d+)\s*(files?|components?|modules?)") {
        $fileCount = [int]$matches[1]
        if ($fileCount -gt 5) {
            $complexity += 5
            $reasons += "Multi-file change ($fileCount files)"
        } elseif ($fileCount -gt 2) {
            $complexity += 3
        }
    }

    # Default complexity if no keywords matched
    if ($complexity -eq 0) {
        $complexity = 3
        $reasons += "Default medium complexity (no specific indicators)"
    }

    return @{
        "Score" = $complexity
        "Reasons" = $reasons
    }
}

function Get-RecommendedModel {
    param([int]$ComplexityScore)

    if ($ComplexityScore -le 2) {
        return "haiku"
    } elseif ($ComplexityScore -le 6) {
        return "sonnet"
    } else {
        return "opus"
    }
}

function Show-ModelStats {
    Write-Host ""
    Write-Host "=== Claude Model Cost Comparison ===" -ForegroundColor Cyan
    Write-Host ""

    foreach ($model in @("haiku", "sonnet", "opus")) {
        $info = $ModelPricing[$model]
        Write-Host "  $($model.ToUpper())" -ForegroundColor White
        Write-Host "    Input:  `$$($info.input)/M tokens" -ForegroundColor DarkGray
        Write-Host "    Output: `$$($info.output)/M tokens" -ForegroundColor DarkGray
        Write-Host "    $($info.description)" -ForegroundColor DarkGray
        Write-Host ""
    }

    Write-Host "=== Cost Savings Example ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Scenario: 100K tokens input, 10K tokens output" -ForegroundColor White
    Write-Host ""

    $inputTokens = 100000
    $outputTokens = 10000

    foreach ($model in @("haiku", "sonnet", "opus")) {
        $info = $ModelPricing[$model]
        $inputCost = ($inputTokens / 1000000) * $info.input
        $outputCost = ($outputTokens / 1000000) * $info.output
        $totalCost = $inputCost + $outputCost

        Write-Host ("  {0,-10} `${1:F2}" -f $model.ToUpper(), $totalCost) -ForegroundColor $(
            if ($model -eq "haiku") { "Green" }
            elseif ($model -eq "sonnet") { "Yellow" }
            else { "Red" }
        )
    }

    $haiku = ($inputTokens / 1000000) * $ModelPricing["haiku"].input + ($outputTokens / 1000000) * $ModelPricing["haiku"].output
    $opus = ($inputTokens / 1000000) * $ModelPricing["opus"].input + ($outputTokens / 1000000) * $ModelPricing["opus"].output
    $savings = (($opus - $haiku) / $opus) * 100

    Write-Host ""
    Write-Host "  Potential savings: $([math]::Round($savings, 1))% when using Haiku vs Opus" -ForegroundColor Green
    Write-Host ""

    Write-Host "=== GitHub Issue ===" -ForegroundColor Cyan
    Write-Host "  Feature Request: #17772 - Programmatic Model Switching" -ForegroundColor White
    Write-Host "  Status: Awaiting implementation by Anthropic" -ForegroundColor Yellow
    Write-Host ""
}

function Show-TaskAnalysis {
    param([string]$TaskDescription)

    $result = Get-TaskComplexity -TaskDescription $TaskDescription
    $model = Get-RecommendedModel -ComplexityScore $result.Score
    $modelInfo = $ModelPricing[$model]

    Write-Host ""
    Write-Host "=== Task Complexity Analysis ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Task: $TaskDescription" -ForegroundColor White
    Write-Host "  Complexity Score: $($result.Score)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Analysis:" -ForegroundColor DarkGray
    foreach ($reason in $result.Reasons) {
        Write-Host "    - $reason" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  Recommended Model: $($model.ToUpper())" -ForegroundColor $(
        if ($model -eq "haiku") { "Green" }
        elseif ($model -eq "sonnet") { "Yellow" }
        else { "Red" }
    )
    Write-Host "  $($modelInfo.description)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Cost: `$$($modelInfo.input)/M input, `$$($modelInfo.output)/M output" -ForegroundColor DarkGray
    Write-Host ""

    # Show use cases for this model
    Write-Host "  Typical Use Cases for $($model.ToUpper()):" -ForegroundColor Cyan
    foreach ($useCase in $modelInfo.use_cases) {
        Write-Host "    - $useCase" -ForegroundColor DarkGray
    }
    Write-Host ""

    return $model
}

# Main execution
if ($Stats) {
    Show-ModelStats
    exit 0
}

if ($Analyze) {
    if (-not $Task) {
        Write-Host "ERROR: -Task parameter required for analysis" -ForegroundColor Red
        Write-Host "Usage: .\model-selector.ps1 -Task 'your task description' -Analyze" -ForegroundColor Yellow
        exit 1
    }

    $model = Show-TaskAnalysis -TaskDescription $Task
    exit 0
}

# No parameters provided
Write-Host ""
Write-Host "Claude Model Selector" -ForegroundColor Cyan
Write-Host ""
Write-Host "Usage:" -ForegroundColor White
Write-Host "  .\model-selector.ps1 -Task 'task description' -Analyze" -ForegroundColor DarkGray
Write-Host "  .\model-selector.ps1 -Stats" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Examples:" -ForegroundColor White
Write-Host "  .\model-selector.ps1 -Task 'Fix typo in README' -Analyze" -ForegroundColor DarkGray
Write-Host "  .\model-selector.ps1 -Task 'Redesign authentication architecture' -Analyze" -ForegroundColor DarkGray
Write-Host "  .\model-selector.ps1 -Stats" -ForegroundColor DarkGray
Write-Host ""
exit 0
