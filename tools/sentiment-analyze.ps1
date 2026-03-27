<#
.SYNOPSIS
    Prompt Sentiment Analysis & Behavioral Pattern Learning
    50-Expert Council Improvements #41, #42 | Priority: 2.25, 1.8

.DESCRIPTION
    Real-time analysis of prompts for:
    - Sentiment (positive/negative/neutral)
    - Urgency level
    - Frustration detection
    - Behavioral patterns over time

.PARAMETER Prompt
    Text to analyze.

.PARAMETER History
    Show sentiment history.

.PARAMETER Patterns
    Show behavioral patterns.

.EXAMPLE
    sentiment-analyze.ps1 -Prompt "just fix it already!"
#>

param(
    [string]$Prompt = "",
    [switch]$History,
    [switch]$Patterns
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$SentimentDB = "C:\scripts\_machine\sentiment_history.json"

if (-not (Test-Path $SentimentDB)) {
    @{
        history = @()
        patterns = @{
            avgSentiment = 0
            avgUrgency = 0
            frustrationCount = 0
            totalAnalyzed = 0
        }
    } | ConvertTo-Json -Depth 10 | Set-Content $SentimentDB -Encoding UTF8
}

$db = Get-Content $SentimentDB -Raw | ConvertFrom-Json

function Analyze-Sentiment {
    param([string]$Text)

    $lower = $Text.ToLower()

    # Sentiment scoring
    $positive = @('thanks', 'great', 'awesome', 'love', 'perfect', 'excellent', 'amazing', 'good', 'nice')
    $negative = @('hate', 'terrible', 'wrong', 'bad', 'stupid', 'wtf', 'damn', 'ugh', 'annoying', 'frustrated')
    $urgent = @('now', 'asap', 'urgent', 'immediately', 'hurry', 'quick', 'fast', '!')

    $posScore = ($positive | Where-Object { $lower -match $_ }).Count
    $negScore = ($negative | Where-Object { $lower -match $_ }).Count
    $urgScore = ($urgent | Where-Object { $lower -match $_ }).Count

    $sentiment = $posScore - $negScore
    $sentimentLabel = if ($sentiment -gt 0) { "Positive" } elseif ($sentiment -lt 0) { "Negative" } else { "Neutral" }

    return @{
        text = $Text
        sentiment = $sentiment
        sentimentLabel = $sentimentLabel
        urgency = $urgScore
        frustration = $negScore -gt 1
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

if ($Prompt) {
    $analysis = Analyze-Sentiment -Text $Prompt

    Write-Host "=== SENTIMENT ANALYSIS ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Text: `"$Prompt`"" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Sentiment: $($analysis.sentimentLabel) ($($analysis.sentiment))" -ForegroundColor $(
        switch ($analysis.sentimentLabel) {
            "Positive" { "Green" }
            "Negative" { "Red" }
            default { "White" }
        }
    )
    Write-Host "Urgency: $($analysis.urgency)/5" -ForegroundColor $(if ($analysis.urgency -gt 2) { "Yellow" } else { "Gray" })

    if ($analysis.frustration) {
        Write-Host ""
        Write-Host "⚠ FRUSTRATION DETECTED" -ForegroundColor Red
        Write-Host "  Recommendation: Deliver results fast, minimize explanations" -ForegroundColor Yellow
    }

    # Save to history
    $db.history += $analysis
    $db.patterns.totalAnalyzed++
    if ($analysis.frustration) { $db.patterns.frustrationCount++ }
    $db | ConvertTo-Json -Depth 10 | Set-Content $SentimentDB -Encoding UTF8
}
elseif ($History) {
    Write-Host "=== SENTIMENT HISTORY ===" -ForegroundColor Cyan
    Write-Host ""

    $recent = $db.history | Select-Object -Last 10
    foreach ($h in $recent) {
        $color = switch ($h.sentimentLabel) { "Positive" { "Green" } "Negative" { "Red" } default { "White" } }
        Write-Host "[$($h.sentimentLabel)] $($h.text.Substring(0, [Math]::Min(50, $h.text.Length)))..." -ForegroundColor $color
    }
}
elseif ($Patterns) {
    Write-Host "=== BEHAVIORAL PATTERNS ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Total analyzed: $($db.patterns.totalAnalyzed)" -ForegroundColor Yellow
    Write-Host "Frustration occurrences: $($db.patterns.frustrationCount)" -ForegroundColor $(if ($db.patterns.frustrationCount -gt 5) { "Red" } else { "Green" })

    $frustrationRate = if ($db.patterns.totalAnalyzed -gt 0) {
        [math]::Round(($db.patterns.frustrationCount / $db.patterns.totalAnalyzed) * 100)
    } else { 0 }
    Write-Host "Frustration rate: $frustrationRate%" -ForegroundColor White
}
else {
    Write-Host "Usage: sentiment-analyze.ps1 -Prompt 'text'" -ForegroundColor Yellow
}
