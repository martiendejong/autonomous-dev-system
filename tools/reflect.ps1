<#
.SYNOPSIS
    Auto-Reflection Checkpoint - Pause and verify direction.
    Expert: Kahneman + HP Meta-Cognitive Rule #5

.DESCRIPTION
    Implements 50-Expert Council Improvement #5.
    Forces a contemplation pause to verify:
    - Still solving the right problem?
    - Simplest solution?
    - Going down a rabbit hole?
    - Assumptions still valid?

.PARAMETER Context
    Brief description of current work.

.PARAMETER Goal
    Original goal being pursued.

.PARAMETER CheckOnly
    Just show questions, don't log.

.EXAMPLE
    reflect.ps1 -Context "Implementing auth" -Goal "Add user login"

.EXAMPLE
    reflect.ps1 -CheckOnly
#>

param(
    [string]$Context = "",
    [string]$Goal = "",
    [switch]$CheckOnly
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$ReflectionFile = "C:\scripts\_machine\reflection_checkpoints.md"

# Reflection Questions
$questions = @(
    "1. Am I still solving the RIGHT problem?",
    "2. Is this the SIMPLEST solution?",
    "3. Am I going down a RABBIT HOLE?",
    "4. What ASSUMPTIONS am I making?",
    "5. Would HP APPROVE of this approach?",
    "6. Is there a TOOL/SKILL that should handle this?",
    "7. Should I CHECKPOINT/COMMIT now?",
    "8. Do I need to consult the EXPERTS again?"
)

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           AUTO-REFLECTION CHECKPOINT                         ║" -ForegroundColor Cyan
Write-Host "║           (50-Expert Council #5 + Meta-Rule #5)              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if ($Context) {
    Write-Host "Current Context: $Context" -ForegroundColor Yellow
}
if ($Goal) {
    Write-Host "Original Goal:   $Goal" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "CONTEMPLATION QUESTIONS:" -ForegroundColor Magenta
Write-Host ""

foreach ($q in $questions) {
    Write-Host "  $q" -ForegroundColor White
}

Write-Host ""
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

# Quick self-check prompts
Write-Host ""
Write-Host "QUICK CHECKS:" -ForegroundColor Green
Write-Host "  [Y/N] On track with original goal?" -ForegroundColor White
Write-Host "  [Y/N] This is the simplest approach?" -ForegroundColor White
Write-Host "  [Y/N] No rabbit holes?" -ForegroundColor White
Write-Host "  [Y/N] Should continue current direction?" -ForegroundColor White
Write-Host ""

if (-not $CheckOnly) {
    # Log the checkpoint
    $logEntry = @"

---
## Reflection Checkpoint - $Timestamp

**Context:** $Context
**Goal:** $Goal

### Questions Reviewed:
$(($questions | ForEach-Object { "- $_" }) -join "`n")

### Outcome:
[To be filled by Claude]

"@

    # Create file if doesn't exist
    if (-not (Test-Path $ReflectionFile)) {
        $header = @"
# Reflection Checkpoints Log

**Purpose:** Track contemplation pauses and direction verification.
**Created:** $Timestamp
**Expert Source:** Kahneman (System 2 thinking) + HP Meta-Cognitive Rule #5

---
"@
        Set-Content -Path $ReflectionFile -Value $header -Encoding UTF8
    }

    Add-Content -Path $ReflectionFile -Value $logEntry -Encoding UTF8
    Write-Host "Checkpoint logged to: $ReflectionFile" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "If ANY answer is NO → STOP, reassess, consult reflection.log.md" -ForegroundColor Red
Write-Host ""
