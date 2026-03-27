<#
.SYNOPSIS
    Recovery Mode - Gentle guidance after failures
    50-Expert Council V2 Improvement #43 | Priority: 2.33

.DESCRIPTION
    Provides supportive recovery after failures.
    Suggests next steps and maintains morale.

.PARAMETER Activate
    Activate recovery mode.

.PARAMETER Failure
    Description of what failed.

.PARAMETER Suggest
    Get recovery suggestions.

.EXAMPLE
    recovery-mode.ps1 -Activate -Failure "Build failed with 5 errors"
#>

param(
    [switch]$Activate,
    [string]$Failure = "",
    [switch]$Suggest,
    [switch]$Deactivate
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$RecoveryFile = "C:\scripts\_machine\recovery_state.json"

if (-not (Test-Path $RecoveryFile)) {
    @{
        active = $false
        failures = @()
        recoveries = @()
    } | ConvertTo-Json -Depth 10 | Set-Content $RecoveryFile -Encoding UTF8
}

$state = Get-Content $RecoveryFile -Raw | ConvertFrom-Json

function Get-RecoverySuggestions {
    param([string]$FailureType)

    $lower = $FailureType.ToLower()

    $suggestions = @()

    if ($lower -match 'build|compile|error') {
        $suggestions = @(
            "1. Take a deep breath - build errors are normal",
            "2. Read the FIRST error message carefully",
            "3. Check recent changes: git diff HEAD~1",
            "4. Try: dotnet clean && dotnet build",
            "5. Search error-memory.ps1 for known solutions"
        )
    }
    elseif ($lower -match 'test|fail|assert') {
        $suggestions = @(
            "1. Tests fail for a reason - they're protecting you",
            "2. Read the assertion message carefully",
            "3. Check if test assumptions are still valid",
            "4. Run single test: dotnet test --filter 'FullyQualifiedName~TestName'",
            "5. Consider if the test or the code needs fixing"
        )
    }
    elseif ($lower -match 'merge|conflict') {
        $suggestions = @(
            "1. Merge conflicts are common - don't panic",
            "2. Use: git status to see conflicted files",
            "3. Open each file and resolve <<<<< markers",
            "4. After resolving: git add . && git commit",
            "5. Consider: git mergetool for visual resolution"
        )
    }
    elseif ($lower -match 'deploy|ci|pipeline') {
        $suggestions = @(
            "1. CI failures happen - check the logs first",
            "2. Look at the specific step that failed",
            "3. Check if it works locally",
            "4. Common issues: secrets, permissions, dependencies",
            "5. Try re-running the pipeline (transient failures)"
        )
    }
    else {
        $suggestions = @(
            "1. Take a short break (5 min) to clear your mind",
            "2. Re-read the error message with fresh eyes",
            "3. Search for similar issues in error-memory.ps1",
            "4. Break the problem into smaller parts",
            "5. Ask for help if stuck for >30 minutes"
        )
    }

    return $suggestions
}

if ($Activate) {
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════════╗" -ForegroundColor Blue
    Write-Host "  ║                                                            ║" -ForegroundColor Blue
    Write-Host "  ║    💙  RECOVERY MODE ACTIVATED  💙                         ║" -ForegroundColor Cyan
    Write-Host "  ║                                                            ║" -ForegroundColor Blue
    Write-Host "  ╚════════════════════════════════════════════════════════════╝" -ForegroundColor Blue
    Write-Host ""

    if ($Failure) {
        Write-Host "  What happened: $Failure" -ForegroundColor Yellow
        Write-Host ""

        # Log the failure
        $state.failures += @{
            description = $Failure
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        $state.active = $true
        $state | ConvertTo-Json -Depth 10 | Set-Content $RecoveryFile -Encoding UTF8

        # Get suggestions
        $suggestions = Get-RecoverySuggestions $Failure

        Write-Host "  💡 Recovery suggestions:" -ForegroundColor Green
        Write-Host ""
        foreach ($s in $suggestions) {
            Write-Host "     $s" -ForegroundColor White
            Start-Sleep -Milliseconds 300  # Gentle pacing
        }
    }

    Write-Host ""
    Write-Host "  ───────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Remember:" -ForegroundColor Magenta
    Write-Host "  • Failures are learning opportunities" -ForegroundColor Gray
    Write-Host "  • Every expert was once a beginner" -ForegroundColor Gray
    Write-Host "  • You've solved harder problems before" -ForegroundColor Gray
    Write-Host "  • It's okay to take a break" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Run: recovery-mode.ps1 -Deactivate when ready to continue" -ForegroundColor DarkGray
    Write-Host ""
}
elseif ($Suggest) {
    $lastFailure = if ($state.failures.Count -gt 0) { $state.failures[-1].description } else { "general" }
    $suggestions = Get-RecoverySuggestions $lastFailure

    Write-Host "=== RECOVERY SUGGESTIONS ===" -ForegroundColor Cyan
    Write-Host ""
    foreach ($s in $suggestions) {
        Write-Host "  $s" -ForegroundColor White
    }
    Write-Host ""
}
elseif ($Deactivate) {
    $state.active = $false
    $state.recoveries += @{
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        failuresRecovered = $state.failures.Count
    }
    $state | ConvertTo-Json -Depth 10 | Set-Content $RecoveryFile -Encoding UTF8

    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║                                                            ║" -ForegroundColor Green
    Write-Host "  ║    ✅  RECOVERY COMPLETE - Back to normal!  ✅             ║" -ForegroundColor White
    Write-Host "  ║                                                            ║" -ForegroundColor Green
    Write-Host "  ╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Great job working through that! 💪" -ForegroundColor Yellow
    Write-Host ""
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Activate -Failure 'x'   Enter recovery mode" -ForegroundColor White
    Write-Host "  -Suggest                 Get suggestions" -ForegroundColor White
    Write-Host "  -Deactivate              Exit recovery mode" -ForegroundColor White
}
