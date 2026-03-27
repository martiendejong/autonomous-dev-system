<#
.SYNOPSIS
    Detect whether to use Feature Development Mode or Active Debugging Mode

.DESCRIPTION
    CRITICAL: Prevents mode detection mistakes that violate zero-tolerance rules.

    HARD RULE: If ClickUp URL/task reference present → ALWAYS Feature Development Mode

    Why this tool exists:
    - 2026-01-20: Agent mistakenly used Debug Mode for ClickUp task, corrupted workflow
    - User mandate: "do not ever forget that again"
    - Prevention: Automated detection before any code edit

.PARAMETER UserMessage
    The user's message/request (full text)

.PARAMETER Analyze
    Perform deep analysis and show reasoning

.EXAMPLE
    detect-mode.ps1 -UserMessage "https://app.clickup.com/t/869bu9cnd"
    # Output: FEATURE_DEVELOPMENT_MODE
    # Reason: ClickUp URL detected

.EXAMPLE
    detect-mode.ps1 -UserMessage "I'm debugging on branch fix/auth, help me fix this error" -Analyze
    # Output: ACTIVE_DEBUGGING_MODE
    # Reason: User actively debugging, mentions current branch, no ClickUp reference

.NOTES
    This tool should be called BEFORE any code editing decision.
    Created: 2026-01-20
    Reason: Prevention of critical mode detection mistake
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$UserMessage,

    [switch]$Analyze
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

# ClickUp detection patterns
$clickupPatterns = @(
    'clickup\.com',
    '869[a-z0-9]{6}',  # ClickUp task ID format
    'task\s+#?\d{9}',
    'clickup\s+task',
    'clickup\s+url'
)

# Active debugging signals
$debugPatterns = @(
    'i\'m debugging',
    'help me fix',
    'getting this error',
    'build is failing',
    'on branch',
    'current branch',
    'error:\s+',
    'exception:',
    'stack trace'
)

# Feature development signals
$featurePatterns = @(
    'implement',
    'add feature',
    'create',
    'refactor',
    'there\'s an issue with',
    'fix this bug',
    'new feature'
)

# HARD RULE CHECK: ClickUp reference?
$hasClickUpReference = $false
foreach ($pattern in $clickupPatterns) {
    if ($UserMessage -match $pattern) {
        $hasClickUpReference = $true
        $matchedPattern = $pattern
        break
    }
}

# If ClickUp reference found → ALWAYS Feature Development Mode
if ($hasClickUpReference) {
    Write-Output "FEATURE_DEVELOPMENT_MODE"

    if ($Analyze) {
        Write-Host ""
        Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host " MODE DETECTION RESULT" -ForegroundColor Cyan
        Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Mode: " -NoNewline
        Write-Host "FEATURE DEVELOPMENT MODE" -ForegroundColor Green
        Write-Host ""
        Write-Host "Reason: " -NoNewline
        Write-Host "ClickUp reference detected" -ForegroundColor Yellow
        Write-Host "Pattern: $matchedPattern" -ForegroundColor Gray
        Write-Host ""
        Write-Host "HARD RULE:" -ForegroundColor Red
        Write-Host "  ClickUp URL/task → ALWAYS Feature Development Mode" -ForegroundColor Red
        Write-Host "  NO EXCEPTIONS" -ForegroundColor Red
        Write-Host ""
        Write-Host "Required Workflow:" -ForegroundColor Green
        Write-Host "  1. Allocate worktree (find FREE seat)" -ForegroundColor White
        Write-Host "  2. Create branch: feature/TASKID-description" -ForegroundColor White
        Write-Host "  3. Work in: C:\Projects\worker-agents\agent-XXX\" -ForegroundColor White
        Write-Host "  4. Create PR" -ForegroundColor White
        Write-Host "  5. Link PR to ClickUp task" -ForegroundColor White
        Write-Host "  6. Release worktree" -ForegroundColor White
        Write-Host ""
        Write-Host "DO NOT:" -ForegroundColor Red
        Write-Host "  ❌ Edit C:\Projects\<repo> directly" -ForegroundColor Red
        Write-Host "  ❌ Skip worktree allocation" -ForegroundColor Red
        Write-Host "  ❌ Forget to create PR" -ForegroundColor Red
        Write-Host "  ❌ Forget to link PR to ClickUp" -ForegroundColor Red
        Write-Host ""
    }

    exit 0
}

# No ClickUp reference - analyze other signals
$debugScore = 0
$featureScore = 0

foreach ($pattern in $debugPatterns) {
    if ($UserMessage -match $pattern) {
        $debugScore++
    }
}

foreach ($pattern in $featurePatterns) {
    if ($UserMessage -match $pattern) {
        $featureScore++
    }
}

# Decision logic
if ($debugScore -gt $featureScore -and $debugScore -gt 0) {
    Write-Output "ACTIVE_DEBUGGING_MODE"

    if ($Analyze) {
        Write-Host ""
        Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host " MODE DETECTION RESULT" -ForegroundColor Cyan
        Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Mode: " -NoNewline
        Write-Host "ACTIVE DEBUGGING MODE" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Reason: Strong debugging signals detected" -ForegroundColor Gray
        Write-Host "Debug Score: $debugScore | Feature Score: $featureScore" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Workflow:" -ForegroundColor Green
        Write-Host "  1. Work in base repo (C:\Projects\<repo>)" -ForegroundColor White
        Write-Host "  2. Stay on user's current branch" -ForegroundColor White
        Write-Host "  3. Fast turnaround - help debug immediately" -ForegroundColor White
        Write-Host "  4. DO NOT allocate worktree" -ForegroundColor White
        Write-Host "  5. DO NOT switch branches" -ForegroundColor White
        Write-Host ""
    }
} else {
    Write-Output "FEATURE_DEVELOPMENT_MODE"

    if ($Analyze) {
        Write-Host ""
        Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host " MODE DETECTION RESULT" -ForegroundColor Cyan
        Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Mode: " -NoNewline
        Write-Host "FEATURE DEVELOPMENT MODE" -ForegroundColor Green
        Write-Host ""
        Write-Host "Reason: Feature development signals or default mode" -ForegroundColor Gray
        Write-Host "Debug Score: $debugScore | Feature Score: $featureScore" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Workflow:" -ForegroundColor Green
        Write-Host "  1. Allocate worktree (find FREE seat)" -ForegroundColor White
        Write-Host "  2. Create proper branch name" -ForegroundColor White
        Write-Host "  3. Work in: C:\Projects\worker-agents\agent-XXX\" -ForegroundColor White
        Write-Host "  4. Create PR" -ForegroundColor White
        Write-Host "  5. Release worktree" -ForegroundColor White
        Write-Host ""
    }
}
