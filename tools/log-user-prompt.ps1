<#
.SYNOPSIS
    Logs user prompts for pattern analysis and deep understanding.

.DESCRIPTION
    Captures user prompts with metadata, performs quick analysis,
    and stores for cumulative pattern recognition. Enables Claude
    to understand user at 1000% level through systematic analysis.

.PARAMETER Prompt
    The user's prompt text to log.

.PARAMETER SessionId
    Optional session identifier for grouping.

.PARAMETER Analyze
    Run immediate pattern analysis on the prompt.

.EXAMPLE
    log-user-prompt.ps1 -Prompt "Add authentication" -Analyze

.EXAMPLE
    log-user-prompt.ps1 -Prompt "Fix the build error" -SessionId "2026-01-21-001"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Prompt,

    [string]$SessionId = (Get-Date -Format "yyyy-MM-dd"),

    [switch]$Analyze
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$LogFile = "C:\scripts\_machine\user_prompts.log.md"
$InsightsFile = "C:\scripts\_machine\PERSONAL_INSIGHTS.md"
$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Category detection
function Get-PromptCategory {
    param([string]$Text)

    $categories = @()
    $lower = $Text.ToLower()

    # Feature Request indicators
    if ($lower -match 'add|create|implement|build|make|new') {
        $categories += "Feature Request"
    }

    # Frustration indicators
    if ($lower -match 'why|again|still|broken|not working|wtf|damn') {
        $categories += "Frustration"
    }

    # Meta-Improvement indicators
    if ($lower -match 'better|improve|optimize|enhance|upgrade|smarter|faster') {
        $categories += "Meta-Improvement"
    }

    # Direction Change indicators
    if ($lower -match 'actually|instead|wait|nevermind|scratch that|no,') {
        $categories += "Direction Change"
    }

    # Deep Desire indicators
    if ($lower -match 'always|never|every|philosophy|principle|fundamental') {
        $categories += "Deep Desire"
    }

    # Debug Mode indicators
    if ($lower -match 'error|bug|fix|debug|broken|crash|fail') {
        $categories += "Debug Mode"
    }

    # Question indicators
    if ($Text -match '\?') {
        $categories += "Question"
    }

    if ($categories.Count -eq 0) {
        $categories += "General"
    }

    return $categories -join ", "
}

# Emotion detection
function Get-PromptEmotion {
    param([string]$Text)

    $emotions = @()
    $lower = $Text.ToLower()

    if ($lower -match 'please|thanks|appreciate') { $emotions += "Polite" }
    if ($lower -match '!{2,}|caps|urgent|asap|now') { $emotions += "Urgent" }
    if ($lower -match 'awesome|brilliant|amazing|super') { $emotions += "Enthusiastic" }
    if ($lower -match 'frustrated|annoyed|angry|wtf') { $emotions += "Frustrated" }
    if ($lower -match 'think|consider|maybe|perhaps') { $emotions += "Contemplative" }
    if ($lower -match 'must|need|require|essential') { $emotions += "Directive" }
    if ($lower -match '100%|1000%|50x|10x') { $emotions += "Ambitious" }

    if ($emotions.Count -eq 0) { $emotions += "Neutral" }

    return $emotions -join ", "
}

# Key number extraction
function Get-KeyNumbers {
    param([string]$Text)

    $numbers = [regex]::Matches($Text, '\d+') | ForEach-Object { $_.Value }
    return ($numbers | Select-Object -Unique) -join ", "
}

# Word count and complexity
function Get-PromptComplexity {
    param([string]$Text)

    $words = ($Text -split '\s+').Count
    $sentences = ($Text -split '[.!?]').Count

    if ($words -lt 10) { return "Simple" }
    if ($words -lt 50) { return "Medium" }
    if ($words -lt 150) { return "Complex" }
    return "Very Complex"
}

# Create log entry
$category = Get-PromptCategory -Text $Prompt
$emotion = Get-PromptEmotion -Text $Prompt
$numbers = Get-KeyNumbers -Text $Prompt
$complexity = Get-PromptComplexity -Text $Prompt

$logEntry = @"

### Prompt - $Timestamp
**Session:** $SessionId
**Raw:** "$Prompt"

**Quick Analysis:**
- **Category:** $category
- **Emotion:** $emotion
- **Complexity:** $complexity
- **Key Numbers:** $(if ($numbers) { $numbers } else { "None" })

---
"@

# Append to log file
Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8

Write-Host "Prompt logged successfully" -ForegroundColor Green
Write-Host "  Category: $category" -ForegroundColor Cyan
Write-Host "  Emotion: $emotion" -ForegroundColor Cyan
Write-Host "  Complexity: $complexity" -ForegroundColor Cyan

if ($Analyze) {
    Write-Host "`nPattern Analysis:" -ForegroundColor Yellow

    # Read recent prompts for pattern detection
    $logContent = Get-Content $LogFile -Raw
    $promptCount = ([regex]::Matches($logContent, '### Prompt -')).Count

    Write-Host "  Total prompts logged: $promptCount"

    # Category frequency
    $featureCount = ([regex]::Matches($logContent, 'Feature Request')).Count
    $metaCount = ([regex]::Matches($logContent, 'Meta-Improvement')).Count
    $debugCount = ([regex]::Matches($logContent, 'Debug Mode')).Count

    Write-Host "  Feature Requests: $featureCount"
    Write-Host "  Meta-Improvements: $metaCount"
    Write-Host "  Debug Sessions: $debugCount"

    # Dominant pattern
    $max = [Math]::Max([Math]::Max($featureCount, $metaCount), $debugCount)
    if ($max -eq $metaCount) {
        Write-Host "`n  DOMINANT PATTERN: User focuses on META-IMPROVEMENT" -ForegroundColor Magenta
        Write-Host "  → Claude should proactively suggest system enhancements" -ForegroundColor Magenta
    }
}

return @{
    Category = $category
    Emotion = $emotion
    Complexity = $complexity
    Numbers = $numbers
    Timestamp = $Timestamp
}
