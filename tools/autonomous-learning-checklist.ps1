<#
.SYNOPSIS
    Post-correction autonomous learning checklist - ensures complete learning cycle

.DESCRIPTION
    After user correction, mistake, or success - this tool guides through
    the AUTONOMOUS learning protocol to ensure nothing is missed.

    User mandate: "Self-improvement must be autonomous, not prompted"

    This tool helps Claude complete the full learning cycle automatically.

.PARAMETER Type
    Type of trigger: Correction, Mistake, Success

.PARAMETER Description
    Brief description of what happened

.PARAMETER Interactive
    Run in interactive mode with prompts for each step

.EXAMPLE
    autonomous-learning-checklist.ps1 -Type Correction -Description "ClickUp task mode detection"

.EXAMPLE
    autonomous-learning-checklist.ps1 -Type Mistake -Description "Forgot to create PR" -Interactive

.NOTES
    Created: 2026-01-20
    Purpose: Ensure autonomous learning happens without user prompting
    User mandate: "zorg dat je dus constant leert van jezelf"
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('Correction', 'Mistake', 'Success', 'Pattern')]
    [string]$Type,

    [Parameter(Mandatory=$true)]
    [string]$Description,

    [switch]$Interactive
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " AUTONOMOUS LEARNING CHECKLIST" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Type: " -NoNewline
Write-Host $Type -ForegroundColor Yellow
Write-Host "Description: " -NoNewline
Write-Host $Description -ForegroundColor White
Write-Host ""

# Define checklist based on type
$checklist = @()

switch ($Type) {
    'Correction' {
        $checklist = @(
            @{ Task = "Fix the immediate issue"; File = "N/A" },
            @{ Task = "Extract general pattern"; File = "N/A" },
            @{ Task = "Update PERSONAL_INSIGHTS.md"; File = "C:\scripts\_machine\PERSONAL_INSIGHTS.md" },
            @{ Task = "Update reflection.log.md"; File = "C:\scripts\_machine\reflection.log.md" },
            @{ Task = "Create prevention tool (if applicable)"; File = "C:\scripts\tools\" },
            @{ Task = "Update related skills"; File = "C:\scripts\.claude\skills\" },
            @{ Task = "Update CLAUDE.md if needed"; File = "C:\scripts\CLAUDE.md" },
            @{ Task = "Commit all changes"; File = "N/A" },
            @{ Task = "Present: 'Fixed X, learned Y, created Z'"; File = "N/A" }
        )
    }
    'Mistake' {
        $checklist = @(
            @{ Task = "Acknowledge and fix mistake"; File = "N/A" },
            @{ Task = "Log in reflection.log.md with root cause"; File = "C:\scripts\_machine\reflection.log.md" },
            @{ Task = "Create prevention tool/script"; File = "C:\scripts\tools\" },
            @{ Task = "Update zero-tolerance rules if applicable"; File = "C:\scripts\GENERAL_ZERO_TOLERANCE_RULES.md" },
            @{ Task = "Update skills that should have prevented it"; File = "C:\scripts\.claude\skills\" },
            @{ Task = "Update PERSONAL_INSIGHTS.md"; File = "C:\scripts\_machine\PERSONAL_INSIGHTS.md" },
            @{ Task = "Commit changes"; File = "N/A" },
            @{ Task = "Present complete prevention package"; File = "N/A" }
        )
    }
    'Success' {
        $checklist = @(
            @{ Task = "Complete the task"; File = "N/A" },
            @{ Task = "Extract reusable pattern"; File = "N/A" },
            @{ Task = "Document in appropriate skill"; File = "C:\scripts\.claude\skills\" },
            @{ Task = "Create tool if pattern repeats 3+ times"; File = "C:\scripts\tools\" },
            @{ Task = "Update reflection.log.md"; File = "C:\scripts\_machine\reflection.log.md" },
            @{ Task = "Update PERSONAL_INSIGHTS.md if new understanding"; File = "C:\scripts\_machine\PERSONAL_INSIGHTS.md" },
            @{ Task = "Commit changes"; File = "N/A" }
        )
    }
    'Pattern' {
        $checklist = @(
            @{ Task = "Identify the pattern"; File = "N/A" },
            @{ Task = "Check if it repeats 3+ times"; File = "N/A" },
            @{ Task = "Create automation tool"; File = "C:\scripts\tools\" },
            @{ Task = "Create or update skill"; File = "C:\scripts\.claude\skills\" },
            @{ Task = "Update CLAUDE.md with new tool"; File = "C:\scripts\CLAUDE.md" },
            @{ Task = "Document in reflection.log.md"; File = "C:\scripts\_machine\reflection.log.md" },
            @{ Task = "Commit changes"; File = "N/A" }
        )
    }
}

Write-Host "CHECKLIST:" -ForegroundColor Green
Write-Host ""

$completed = 0
$total = $checklist.Count

foreach ($item in $checklist) {
    if ($Interactive) {
        Write-Host "  [ ] $($item.Task)" -ForegroundColor Yellow
        if ($item.File -ne "N/A") {
            Write-Host "      File: $($item.File)" -ForegroundColor Gray
        }
        Write-Host ""
        $response = Read-Host "      Completed? (y/n)"
        if ($response -eq 'y') {
            $completed++
            Write-Host "  [✓] $($item.Task)" -ForegroundColor Green
        } else {
            Write-Host "  [✗] $($item.Task)" -ForegroundColor Red
        }
        Write-Host ""
    } else {
        Write-Host "  [ ] $($item.Task)" -ForegroundColor Yellow
        if ($item.File -ne "N/A") {
            Write-Host "      File: $($item.File)" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

if (-not $Interactive) {
    Write-Host "Run with -Interactive to track completion" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($Interactive) {
    $percentage = [math]::Round(($completed / $total) * 100)
    Write-Host "Progress: $completed / $total ($percentage%)" -ForegroundColor $(if ($percentage -eq 100) { "Green" } else { "Yellow" })
    Write-Host ""

    if ($percentage -eq 100) {
        Write-Host "✓ AUTONOMOUS LEARNING CYCLE COMPLETE" -ForegroundColor Green
        Write-Host ""
        Write-Host "Remember: User should NEVER need to prompt for this." -ForegroundColor Cyan
        Write-Host "This checklist is for internal verification only." -ForegroundColor Cyan
    } else {
        Write-Host "⚠ INCOMPLETE - Autonomous learning not finished" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Complete remaining items before moving on." -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "User Mandate: 'Self-improvement must be autonomous, not prompted EXACTLY'" -ForegroundColor Magenta
Write-Host ""
