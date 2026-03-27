<#
.SYNOPSIS
    Pre-emptive Error Prevention - Pattern match against known mistakes.
    50-Expert Council Improvement #7 | Priority: 2.5

.DESCRIPTION
    Scans reflection.log.md for past mistakes and creates prevention rules.
    Before any action, checks if it matches a known error pattern.

.PARAMETER Action
    The action about to be performed (for checking).

.PARAMETER Scan
    Scan reflection log and build prevention database.

.PARAMETER List
    List all known error patterns and preventions.

.EXAMPLE
    prevent-errors.ps1 -Scan
    prevent-errors.ps1 -Action "editing C:\Projects\client-manager directly"
    prevent-errors.ps1 -List
#>

param(
    [string]$Action = "",
    [switch]$Scan,
    [switch]$List
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ReflectionLog = "C:\scripts\_machine\reflection.log.md"
$PreventionDB = "C:\scripts\_machine\error_prevention.json"

# Known error patterns (hardcoded + learned)
$KnownPatterns = @(
    @{
        pattern = "edit.*C:\\Projects\\(client-manager|hazina)[^\\]"
        error = "Editing base repo directly instead of worktree"
        prevention = "STOP! Use worktree. Run: worktree-allocate.ps1"
        severity = "CRITICAL"
    },
    @{
        pattern = "git push.*--force.*main"
        error = "Force pushing to main branch"
        prevention = "NEVER force push to main. Create PR instead."
        severity = "CRITICAL"
    },
    @{
        pattern = "clickup.*debug.*mode"
        error = "Using Debug Mode for ClickUp task"
        prevention = "ClickUp task = ALWAYS Feature Mode. Allocate worktree."
        severity = "CRITICAL"
    },
    @{
        pattern = "worktree.*not.*release"
        error = "Forgetting to release worktree after PR"
        prevention = "After PR creation, IMMEDIATELY run release-worktree skill"
        severity = "HIGH"
    },
    @{
        pattern = "commit.*without.*test"
        error = "Committing without running tests"
        prevention = "Run build and tests before commit"
        severity = "MEDIUM"
    },
    @{
        pattern = "merge.*develop.*feature"
        error = "Merging develop into feature (wrong direction)"
        prevention = "Merge feature INTO develop, not reverse"
        severity = "HIGH"
    },
    @{
        pattern = "delete.*migration"
        error = "Deleting EF migration that may be deployed"
        prevention = "Check if migration exists in production first"
        severity = "HIGH"
    },
    @{
        pattern = "hardcod.*path|absolute.*path"
        error = "Hardcoding paths that should be configurable"
        prevention = "Use MACHINE_CONFIG.md variables or environment variables"
        severity = "MEDIUM"
    }
)

# Initialize or load prevention database
if (-not (Test-Path $PreventionDB)) {
    $db = @{
        patterns = $KnownPatterns
        learnedPatterns = @()
        lastScan = $null
        preventionCount = 0
    }
    $db | ConvertTo-Json -Depth 10 | Set-Content $PreventionDB -Encoding UTF8
} else {
    $db = Get-Content $PreventionDB -Raw | ConvertFrom-Json
}

function Scan-ReflectionLog {
    Write-Host "=== SCANNING REFLECTION LOG FOR ERROR PATTERNS ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $ReflectionLog)) {
        Write-Host "Reflection log not found." -ForegroundColor Yellow
        return
    }

    # Read reflection log (limited for performance)
    $content = Get-Content $ReflectionLog -Raw -ErrorAction SilentlyContinue
    if (-not $content) {
        Write-Host "Could not read reflection log." -ForegroundColor Yellow
        return
    }

    # Find error/mistake sections
    $errorMatches = [regex]::Matches($content, '(?i)(mistake|error|wrong|failed|violated|broke).*?(?=\n\n|\n###|\n---)', [System.Text.RegularExpressions.RegexOptions]::Singleline)

    Write-Host "Found $($errorMatches.Count) potential error patterns" -ForegroundColor Yellow
    Write-Host ""

    $learned = @()
    foreach ($match in $errorMatches | Select-Object -First 20) {
        $text = $match.Value.Trim()
        if ($text.Length -gt 20) {
            $learned += @{
                pattern = ($text -split '\n')[0].Substring(0, [Math]::Min(100, ($text -split '\n')[0].Length))
                source = "reflection.log.md"
                learned = (Get-Date).ToString("yyyy-MM-dd")
            }
        }
    }

    $db.learnedPatterns = $learned
    $db.lastScan = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $db | ConvertTo-Json -Depth 10 | Set-Content $PreventionDB -Encoding UTF8

    Write-Host "Learned $($learned.Count) new patterns from reflection log" -ForegroundColor Green
}

function Check-Action {
    param([string]$ActionText)

    Write-Host "=== PRE-EMPTIVE ERROR CHECK ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Checking action: $ActionText" -ForegroundColor Yellow
    Write-Host ""

    $violations = @()

    foreach ($p in $KnownPatterns) {
        if ($ActionText -match $p.pattern) {
            $violations += $p
        }
    }

    if ($violations.Count -eq 0) {
        Write-Host "✓ No known error patterns detected. Safe to proceed." -ForegroundColor Green
        return $true
    }

    Write-Host "⚠️  ERROR PATTERNS DETECTED!" -ForegroundColor Red
    Write-Host ""

    foreach ($v in $violations) {
        $color = switch ($v.severity) {
            "CRITICAL" { "Red" }
            "HIGH" { "Yellow" }
            default { "White" }
        }
        Write-Host "[$($v.severity)] $($v.error)" -ForegroundColor $color
        Write-Host "  Prevention: $($v.prevention)" -ForegroundColor White
        Write-Host ""
    }

    $db.preventionCount++
    $db | ConvertTo-Json -Depth 10 | Set-Content $PreventionDB -Encoding UTF8

    Write-Host "Total errors prevented: $($db.preventionCount)" -ForegroundColor Magenta
    return $false
}

function List-Patterns {
    Write-Host "=== KNOWN ERROR PATTERNS ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Last scan: $($db.lastScan)" -ForegroundColor Gray
    Write-Host "Errors prevented: $($db.preventionCount)" -ForegroundColor Gray
    Write-Host ""

    Write-Host "HARDCODED PATTERNS:" -ForegroundColor Yellow
    foreach ($p in $KnownPatterns) {
        $color = switch ($p.severity) {
            "CRITICAL" { "Red" }
            "HIGH" { "Yellow" }
            default { "White" }
        }
        Write-Host "  [$($p.severity)] $($p.error)" -ForegroundColor $color
        Write-Host "    Prevention: $($p.prevention)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "LEARNED PATTERNS ($($db.learnedPatterns.Count)):" -ForegroundColor Yellow
    foreach ($p in $db.learnedPatterns | Select-Object -First 10) {
        Write-Host "  - $($p.pattern)" -ForegroundColor White
    }
}

# Main execution
if ($Scan) {
    Scan-ReflectionLog
}

if ($Action) {
    $safe = Check-Action -ActionText $Action
    if (-not $safe) {
        exit 1
    }
}

if ($List) {
    List-Patterns
}

if (-not $Scan -and -not $Action -and -not $List) {
    List-Patterns
}
