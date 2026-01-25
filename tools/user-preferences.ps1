<#
.SYNOPSIS
    Preference Extraction & Style Matching
    50-Expert Council Improvements #43, #47 | Priority: 2.0, 1.75

.DESCRIPTION
    Systematically learns and applies user preferences.
    Matches communication style dynamically.

.PARAMETER Learn
    Learn preference from example.

.PARAMETER Category
    Preference category (communication, code, workflow, etc.)

.PARAMETER Preference
    The preference to learn.

.PARAMETER Show
    Show all learned preferences.

.PARAMETER Apply
    Get preferences for a category.

.EXAMPLE
    user-preferences.ps1 -Learn -Category "communication" -Preference "Be direct, no fluff"
    user-preferences.ps1 -Show
#>

param(
    [switch]$Learn,
    [string]$Category = "",
    [string]$Preference = "",
    [switch]$Show,
    [string]$Apply = ""
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$PrefsFile = "C:\scripts\_machine\user_preferences.json"

# Initialize with known preferences
if (-not (Test-Path $PrefsFile)) {
    @{
        communication = @(
            "Be direct and technical - no unnecessary pleasantries",
            "Lead with insights and patterns - explain WHY",
            "Present dense, multi-layered information",
            "Challenge assumptions respectfully - Dutch directness",
            "Show reasoning - transparency builds trust"
        )
        code = @(
            "Boy Scout Rule - leave code better than found",
            "Explicit over implicit",
            "Single responsibility principle",
            "Production-grade quality always"
        )
        workflow = @(
            "Allocate worktree for all feature work",
            "Never edit base repo directly",
            "Commit frequently with meaningful messages",
            "Release worktree immediately after PR"
        )
        decisions = @(
            "Act autonomously for Tier 1-2 decisions",
            "Confirm for architecture decisions",
            "Ask for ambiguous requirements",
            "Default to action, not waiting"
        )
        tools = @(
            "Use existing tools before creating new ones",
            "One command for complex workflows",
            "Automate anything done 3+ times"
        )
    } | ConvertTo-Json -Depth 10 | Set-Content $PrefsFile -Encoding UTF8
}

$prefs = Get-Content $PrefsFile -Raw | ConvertFrom-Json

if ($Learn -and $Category -and $Preference) {
    if (-not $prefs.$Category) {
        $prefs | Add-Member -NotePropertyName $Category -NotePropertyValue @() -Force
    }
    $prefs.$Category += $Preference
    $prefs | ConvertTo-Json -Depth 10 | Set-Content $PrefsFile -Encoding UTF8

    Write-Host "✓ Preference learned" -ForegroundColor Green
    Write-Host "  Category: $Category" -ForegroundColor Yellow
    Write-Host "  Preference: $Preference" -ForegroundColor White
}
elseif ($Show) {
    Write-Host "=== USER PREFERENCES ===" -ForegroundColor Cyan
    Write-Host ""

    foreach ($cat in $prefs.PSObject.Properties) {
        Write-Host "$($cat.Name.ToUpper()):" -ForegroundColor Yellow
        foreach ($p in $cat.Value) {
            Write-Host "  • $p" -ForegroundColor White
        }
        Write-Host ""
    }
}
elseif ($Apply) {
    Write-Host "=== PREFERENCES: $($Apply.ToUpper()) ===" -ForegroundColor Cyan
    Write-Host ""

    if ($prefs.$Apply) {
        foreach ($p in $prefs.$Apply) {
            Write-Host "  • $p" -ForegroundColor White
        }
    } else {
        Write-Host "No preferences for category '$Apply'" -ForegroundColor Yellow
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Show                     Show all preferences" -ForegroundColor White
    Write-Host "  -Apply <category>         Get preferences for category" -ForegroundColor White
    Write-Host "  -Learn -Category x -Preference y   Learn new preference" -ForegroundColor White
}
