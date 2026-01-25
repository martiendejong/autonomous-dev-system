<#
.SYNOPSIS
    Improvement Suggestion Engine
    50-Expert Council V2 Improvement #47 | Priority: 1.8

.DESCRIPTION
    AI suggests next improvements based on patterns.

.PARAMETER Suggest
    Get improvement suggestions.

.PARAMETER Based
    Base suggestions on (usage, errors, patterns).

.EXAMPLE
    improve-suggest.ps1 -Suggest
    improve-suggest.ps1 -Suggest -Based errors
#>

param(
    [switch]$Suggest,
    [string]$Based = "all",
    [switch]$Implement
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


function Analyze-UsagePatterns {
    $suggestions = @()

    # Check tool analytics
    $analyticsFile = "C:\scripts\_machine\tool_analytics.json"
    if (Test-Path $analyticsFile) {
        $analytics = Get-Content $analyticsFile -Raw | ConvertFrom-Json

        # Find underused powerful tools
        $powerful = @("predict-tasks.ps1", "pattern-learn.ps1", "error-memory.ps1")
        foreach ($p in $powerful) {
            if (-not $analytics.usage.$p -or $analytics.usage.$p.count -lt 5) {
                $suggestions += @{
                    type = "usage"
                    suggestion = "Use $p more - it learns from your patterns"
                    impact = "high"
                }
            }
        }
    }

    return $suggestions
}

function Analyze-ErrorPatterns {
    $suggestions = @()

    # Check error memory
    $errorFile = "C:\scripts\_machine\error_memory.json"
    if (Test-Path $errorFile) {
        $errors = Get-Content $errorFile -Raw | ConvertFrom-Json

        if ($errors.errors.Count -gt 20) {
            # Group by pattern to find repetitive errors
            $grouped = $errors.errors | Group-Object { $_.pattern.Substring(0, [Math]::Min(30, $_.pattern.Length)) }
            $repetitive = $grouped | Where-Object { $_.Count -gt 3 }

            foreach ($r in $repetitive) {
                $suggestions += @{
                    type = "error"
                    suggestion = "Recurring error: '$($r.Name)...' - Consider adding prevention rule"
                    impact = "high"
                }
            }
        }
    }

    return $suggestions
}

function Analyze-WorkflowPatterns {
    $suggestions = @()

    # Check reflection log for patterns
    $reflectionFile = "C:\scripts\_machine\reflection.log.md"
    if (Test-Path $reflectionFile) {
        $content = Get-Content $reflectionFile -Raw -ErrorAction SilentlyContinue

        # Look for repeated patterns
        if ($content -match 'forgot to|should have|mistake:') {
            $suggestions += @{
                type = "workflow"
                suggestion = "Many 'forgot to' patterns - Consider adding checklist tool"
                impact = "medium"
            }
        }
    }

    return $suggestions
}

function Analyze-SystemHealth {
    $suggestions = @()

    # Check worktree status
    $poolFile = "C:\scripts\_machine\worktrees.pool.json"
    if (Test-Path $poolFile) {
        $pool = Get-Content $poolFile -Raw | ConvertFrom-Json
        $agents = $pool.agents

        $stale = $agents | Where-Object {
            $_.status -eq "BUSY" -and $_.startTime -and
            ((Get-Date) - [datetime]::Parse($_.startTime)).TotalHours -gt 4
        }

        if ($stale.Count -gt 0) {
            $suggestions += @{
                type = "system"
                suggestion = "Stale worktrees detected - Run worktree-cleanup.ps1"
                impact = "high"
            }
        }
    }

    return $suggestions
}

if ($Suggest) {
    Write-Host "=== IMPROVEMENT SUGGESTION ENGINE ===" -ForegroundColor Cyan
    Write-Host ""

    $allSuggestions = @()

    if ($Based -eq "all" -or $Based -eq "usage") {
        $allSuggestions += Analyze-UsagePatterns
    }
    if ($Based -eq "all" -or $Based -eq "errors") {
        $allSuggestions += Analyze-ErrorPatterns
    }
    if ($Based -eq "all" -or $Based -eq "patterns") {
        $allSuggestions += Analyze-WorkflowPatterns
    }
    if ($Based -eq "all" -or $Based -eq "system") {
        $allSuggestions += Analyze-SystemHealth
    }

    if ($allSuggestions.Count -eq 0) {
        Write-Host "  🎉 No critical improvements needed - system is healthy!" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Suggestions for continuous improvement:" -ForegroundColor Yellow
        Write-Host "    1. Run tool-effectiveness.ps1 -Analyze weekly" -ForegroundColor White
        Write-Host "    2. Review reflection.log.md monthly" -ForegroundColor White
        Write-Host "    3. Update PERSONAL_INSIGHTS.md with new learnings" -ForegroundColor White
    }
    else {
        # Group by impact
        $high = $allSuggestions | Where-Object { $_.impact -eq "high" }
        $medium = $allSuggestions | Where-Object { $_.impact -eq "medium" }
        $low = $allSuggestions | Where-Object { $_.impact -eq "low" }

        if ($high.Count -gt 0) {
            Write-Host "🔴 HIGH IMPACT SUGGESTIONS:" -ForegroundColor Red
            foreach ($s in $high) {
                Write-Host "  • $($s.suggestion)" -ForegroundColor White
            }
            Write-Host ""
        }

        if ($medium.Count -gt 0) {
            Write-Host "🟡 MEDIUM IMPACT:" -ForegroundColor Yellow
            foreach ($s in $medium) {
                Write-Host "  • $($s.suggestion)" -ForegroundColor Gray
            }
            Write-Host ""
        }

        if ($low.Count -gt 0) {
            Write-Host "🟢 LOW IMPACT:" -ForegroundColor Green
            foreach ($s in $low) {
                Write-Host "  • $($s.suggestion)" -ForegroundColor DarkGray
            }
        }

        Write-Host ""
        Write-Host "Total suggestions: $($allSuggestions.Count)" -ForegroundColor Cyan
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Suggest                Get all suggestions" -ForegroundColor White
    Write-Host "  -Based usage|errors     Filter by source" -ForegroundColor White
}
