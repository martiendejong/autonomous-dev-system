<#
.SYNOPSIS
    Desire Detection - Understand emotional subtext and true needs.
    50-Expert Council Improvement #6 | Priority: 1.5

.DESCRIPTION
    Analyzes prompts beyond literal meaning to understand:
    - Underlying desires and motivations
    - Emotional state
    - Urgency level
    - What user REALLY wants

.PARAMETER Prompt
    The user prompt to analyze.

.PARAMETER Deep
    Perform deep analysis with recommendations.

.EXAMPLE
    detect-desire.ps1 -Prompt "just fix it already" -Deep
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Prompt,

    [switch]$Deep
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$DesirePatterns = @{
    # Frustration patterns
    frustration = @{
        patterns = @('again', 'still', 'why', 'just', 'already', 'wtf', 'damn', 'ugh', 'seriously')
        underlying = "User is frustrated. Past attempts failed. They want IMMEDIATE results."
        recommendation = "Acknowledge the frustration briefly, then deliver fast results. No lengthy explanations."
    }

    # Control/autonomy desire
    control = @{
        patterns = @('i want', 'make it', 'let me', 'give me', 'show me how')
        underlying = "User values autonomy and control. They want to understand, not just receive."
        recommendation = "Explain the 'why', show them how to do it themselves, build their capability."
    }

    # Perfectionism
    perfectionism = @{
        patterns = @('better', 'best', 'perfect', 'optimal', '100%', '1000%', 'excellent')
        underlying = "User has high standards. Mediocre won't satisfy them."
        recommendation = "Exceed expectations. Add polish. Show you care about quality."
    }

    # Speed/efficiency desire
    speed = @{
        patterns = @('quick', 'fast', 'now', 'asap', 'hurry', 'immediately', 'urgent')
        underlying = "Time pressure is real. User needs results, not process."
        recommendation = "Skip explanations, deliver results first, explain later if asked."
    }

    # Understanding desire
    understanding = @{
        patterns = @('understand', 'know', 'learn', 'explain', 'why', 'how does')
        underlying = "User wants to understand deeply, not just get an answer."
        recommendation = "Teach, don't just tell. Explain the underlying principles."
    }

    # Meta-improvement
    meta = @{
        patterns = @('improve', 'better', 'optimize', 'enhance', 'upgrade', 'smarter')
        underlying = "User thinks in systems. They want exponential improvement, not incremental."
        recommendation = "Think big. Propose transformative changes. Challenge assumptions."
    }

    # Collaboration desire
    collaboration = @{
        patterns = @('we', 'together', 'help me', 'let''s', 'partner')
        underlying = "User sees Claude as partner, not tool. They want collaboration."
        recommendation = "Use 'we' language. Share thinking process. Ask for input."
    }

    # Delegation desire
    delegation = @{
        patterns = @('you', 'do it', 'handle', 'take care', 'figure out', 'just')
        underlying = "User wants to delegate completely. They trust Claude's judgment."
        recommendation = "Act autonomously. Make decisions. Report results, not options."
    }
}

function Analyze-Desire {
    param([string]$Text)

    $lower = $Text.ToLower()
    $detected = @()

    foreach ($desire in $DesirePatterns.GetEnumerator()) {
        $matchCount = 0
        foreach ($pattern in $desire.Value.patterns) {
            if ($lower -match $pattern) {
                $matchCount++
            }
        }
        if ($matchCount -gt 0) {
            $detected += @{
                desire = $desire.Key
                matches = $matchCount
                info = $desire.Value
            }
        }
    }

    return $detected | Sort-Object { $_.matches } -Descending
}

function Get-EmotionalState {
    param([string]$Text)

    $indicators = @{
        positive = @('thanks', 'great', 'awesome', 'love', 'perfect', 'excellent', '!')
        negative = @('hate', 'terrible', 'wrong', 'bad', 'stupid', 'wtf', 'damn')
        neutral = @('please', 'could', 'would', 'can')
        urgent = @('!', 'now', 'asap', 'urgent', 'immediately', 'hurry')
    }

    $scores = @{
        positive = 0
        negative = 0
        neutral = 0
        urgent = 0
    }

    $lower = $Text.ToLower()

    foreach ($category in $indicators.GetEnumerator()) {
        foreach ($word in $category.Value) {
            if ($lower -match $word) {
                $scores[$category.Key]++
            }
        }
    }

    # Determine dominant emotion
    $dominant = $scores.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1

    return @{
        dominant = $dominant.Key
        scores = $scores
        urgency = $scores.urgent
    }
}

# Main analysis
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║           DESIRE DETECTION ANALYSIS                          ║" -ForegroundColor Magenta
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

Write-Host "Prompt: `"$Prompt`"" -ForegroundColor Yellow
Write-Host ""

# Emotional state
$emotion = Get-EmotionalState -Text $Prompt
Write-Host "EMOTIONAL STATE:" -ForegroundColor Cyan
Write-Host "  Dominant: $($emotion.dominant)" -ForegroundColor $(
    switch ($emotion.dominant) {
        "positive" { "Green" }
        "negative" { "Red" }
        "urgent" { "Yellow" }
        default { "White" }
    }
)
Write-Host "  Urgency: $($emotion.urgency)/5" -ForegroundColor $(if ($emotion.urgency -gt 2) { "Red" } else { "Gray" })
Write-Host ""

# Desire analysis
$desires = Analyze-Desire -Text $Prompt

Write-Host "DETECTED DESIRES:" -ForegroundColor Cyan
Write-Host ""

if ($desires.Count -eq 0) {
    Write-Host "  No strong desire patterns detected." -ForegroundColor Gray
    Write-Host "  Treating as neutral/informational request." -ForegroundColor Gray
} else {
    foreach ($d in $desires | Select-Object -First 3) {
        Write-Host "  [$($d.matches) matches] $($d.desire.ToUpper())" -ForegroundColor Yellow
        Write-Host "    Underlying: $($d.info.underlying)" -ForegroundColor White
        if ($Deep) {
            Write-Host "    → Recommendation: $($d.info.recommendation)" -ForegroundColor Green
        }
        Write-Host ""
    }
}

if ($Deep) {
    Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "SYNTHESIS - What User REALLY Wants:" -ForegroundColor Magenta
    Write-Host ""

    $primary = $desires | Select-Object -First 1
    if ($primary) {
        Write-Host "  $($primary.info.underlying)" -ForegroundColor White
        Write-Host ""
        Write-Host "  RECOMMENDED APPROACH:" -ForegroundColor Green
        Write-Host "  $($primary.info.recommendation)" -ForegroundColor White
    } else {
        Write-Host "  User is making a neutral request." -ForegroundColor White
        Write-Host "  Respond directly and efficiently." -ForegroundColor White
    }

    Write-Host ""
    Write-Host "  AUTONOMY TIER: $(if ($desires | Where-Object { $_.desire -eq 'delegation' }) { '1 (Auto)' } elseif ($desires | Where-Object { $_.desire -eq 'collaboration' }) { '2 (Inform)' } else { '3 (Confirm)' })" -ForegroundColor Cyan
}

Write-Host ""
