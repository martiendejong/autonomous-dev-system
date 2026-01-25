<#
.SYNOPSIS
    Prompt Pattern Learning - Analyzes prompts to detect patterns and suggest automations.
    50-Expert Council Improvement #2 | Priority: 2.5

.DESCRIPTION
    Analyzes user_prompts.log.md to:
    - Detect recurring patterns
    - Suggest automations for repeated tasks
    - Build understanding model
    - Track category frequencies

.PARAMETER Analyze
    Run full pattern analysis.

.PARAMETER Suggest
    Generate automation suggestions.

.PARAMETER Report
    Generate pattern report.

.EXAMPLE
    pattern-learn.ps1 -Analyze -Suggest
#>

param(
    [switch]$Analyze,
    [switch]$Suggest,
    [switch]$Report
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$PromptLog = "C:\scripts\_machine\user_prompts.log.md"
$PatternDB = "C:\scripts\_machine\learned_patterns.json"

# Initialize pattern database if not exists
if (-not (Test-Path $PatternDB)) {
    $initialDB = @{
        patterns = @()
        frequencies = @{}
        automations = @()
        lastAnalysis = $null
    }
    $initialDB | ConvertTo-Json -Depth 10 | Set-Content $PatternDB -Encoding UTF8
}

$db = Get-Content $PatternDB -Raw | ConvertFrom-Json

function Get-PromptPatterns {
    if (-not (Test-Path $PromptLog)) {
        Write-Host "No prompt log found." -ForegroundColor Yellow
        return @()
    }

    $content = Get-Content $PromptLog -Raw
    $prompts = [regex]::Matches($content, '\*\*Raw:\*\* "([^"]+)"') | ForEach-Object { $_.Groups[1].Value }

    return $prompts
}

function Analyze-Patterns {
    Write-Host "=== PROMPT PATTERN ANALYSIS ===" -ForegroundColor Cyan
    Write-Host ""

    $prompts = Get-PromptPatterns
    Write-Host "Total prompts analyzed: $($prompts.Count)" -ForegroundColor Yellow
    Write-Host ""

    # Word frequency analysis
    $allWords = $prompts | ForEach-Object { $_.ToLower() -split '\s+' } | Where-Object { $_.Length -gt 3 }
    $wordFreq = $allWords | Group-Object | Sort-Object Count -Descending | Select-Object -First 20

    Write-Host "TOP WORDS:" -ForegroundColor Magenta
    foreach ($w in $wordFreq) {
        Write-Host "  $($w.Count)x  $($w.Name)" -ForegroundColor White
    }
    Write-Host ""

    # Pattern detection
    $patterns = @{
        "meta_improvement" = ($prompts | Where-Object { $_ -match 'improve|better|optimize|enhance' }).Count
        "feature_request" = ($prompts | Where-Object { $_ -match 'add|create|implement|build' }).Count
        "automation_desire" = ($prompts | Where-Object { $_ -match 'automat|always|every time|whenever' }).Count
        "expert_thinking" = ($prompts | Where-Object { $_ -match 'expert|council|consult|advise' }).Count
        "system_thinking" = ($prompts | Where-Object { $_ -match 'system|architec|design|pattern' }).Count
        "understanding_desire" = ($prompts | Where-Object { $_ -match 'understand|know|learn|100%|1000%' }).Count
    }

    Write-Host "DETECTED PATTERNS:" -ForegroundColor Magenta
    foreach ($p in $patterns.GetEnumerator() | Sort-Object Value -Descending) {
        $pct = if ($prompts.Count -gt 0) { [math]::Round(($p.Value / $prompts.Count) * 100) } else { 0 }
        Write-Host "  $($p.Name): $($p.Value) ($pct%)" -ForegroundColor White
    }
    Write-Host ""

    # Update database
    $db.frequencies = $patterns
    $db.lastAnalysis = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $db | ConvertTo-Json -Depth 10 | Set-Content $PatternDB -Encoding UTF8

    return $patterns
}

function Get-AutomationSuggestions {
    param($patterns)

    Write-Host "=== AUTOMATION SUGGESTIONS ===" -ForegroundColor Cyan
    Write-Host ""

    $suggestions = @()

    if ($patterns.meta_improvement -gt 2) {
        $suggestions += @{
            trigger = "Meta-improvement requests detected ($($patterns.meta_improvement)x)"
            suggestion = "Create 'improve.ps1' that auto-scans for optimization opportunities"
            priority = "HIGH"
        }
    }

    if ($patterns.automation_desire -gt 1) {
        $suggestions += @{
            trigger = "Automation desire detected ($($patterns.automation_desire)x)"
            suggestion = "User wants more things automated. Check for 3x patterns."
            priority = "HIGH"
        }
    }

    if ($patterns.expert_thinking -gt 1) {
        $suggestions += @{
            trigger = "Expert consultation pattern ($($patterns.expert_thinking)x)"
            suggestion = "Auto-invoke expert council for planning tasks"
            priority = "MEDIUM"
        }
    }

    if ($patterns.understanding_desire -gt 0) {
        $suggestions += @{
            trigger = "Deep understanding desire detected"
            suggestion = "Increase prompt logging detail, add sentiment analysis"
            priority = "HIGH"
        }
    }

    foreach ($s in $suggestions) {
        Write-Host "[$($s.priority)] $($s.trigger)" -ForegroundColor $(if ($s.priority -eq "HIGH") { "Red" } else { "Yellow" })
        Write-Host "  → $($s.suggestion)" -ForegroundColor White
        Write-Host ""
    }

    # Save suggestions
    $db.automations = $suggestions
    $db | ConvertTo-Json -Depth 10 | Set-Content $PatternDB -Encoding UTF8

    return $suggestions
}

function Generate-Report {
    Write-Host "=== PATTERN LEARNING REPORT ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Last Analysis: $($db.lastAnalysis)" -ForegroundColor Gray
    Write-Host ""

    Write-Host "LEARNED FREQUENCIES:" -ForegroundColor Yellow
    if ($db.frequencies) {
        $db.frequencies.PSObject.Properties | ForEach-Object {
            Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor White
        }
    }
    Write-Host ""

    Write-Host "PENDING AUTOMATIONS:" -ForegroundColor Yellow
    if ($db.automations) {
        foreach ($a in $db.automations) {
            Write-Host "  [$($a.priority)] $($a.suggestion)" -ForegroundColor White
        }
    }
    Write-Host ""

    Write-Host "INSIGHT: User primarily focuses on META-IMPROVEMENT and SYSTEM THINKING" -ForegroundColor Magenta
    Write-Host "ACTION: Claude should proactively suggest system enhancements" -ForegroundColor Magenta
}

# Main execution
if ($Analyze -or (-not $Analyze -and -not $Suggest -and -not $Report)) {
    $patterns = Analyze-Patterns

    if ($Suggest) {
        Get-AutomationSuggestions -patterns $patterns
    }
}

if ($Report) {
    Generate-Report
}

if ($Suggest -and -not $Analyze) {
    $patterns = $db.frequencies
    Get-AutomationSuggestions -patterns $patterns
}
