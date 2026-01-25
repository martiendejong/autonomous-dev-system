<#
.SYNOPSIS
    System Health Score
    50-Expert Council V2 Improvement #49 | Priority: 2.0

.DESCRIPTION
    Single number for overall system health.

.PARAMETER Calculate
    Calculate health score.

.PARAMETER Detailed
    Show detailed breakdown.

.EXAMPLE
    system-health-score.ps1 -Calculate
    system-health-score.ps1 -Calculate -Detailed
#>

param(
    [switch]$Calculate,
    [switch]$Detailed,
    [switch]$History
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$HealthFile = "C:\scripts\_machine\health_scores.json"

if (-not (Test-Path $HealthFile)) {
    @{
        scores = @()
        currentScore = 0
    } | ConvertTo-Json -Depth 10 | Set-Content $HealthFile -Encoding UTF8
}

$data = Get-Content $HealthFile -Raw | ConvertFrom-Json

function Check-GitHealth {
    $score = 100
    $issues = @()

    # Check for uncommitted changes
    $status = git status --porcelain 2>$null
    $uncommitted = ($status -split "`n" | Where-Object { $_ }).Count
    if ($uncommitted -gt 20) {
        $score -= 20
        $issues += "Many uncommitted changes ($uncommitted)"
    }
    elseif ($uncommitted -gt 5) {
        $score -= 10
        $issues += "Some uncommitted changes ($uncommitted)"
    }

    return @{ score = $score; issues = $issues; category = "Git" }
}

function Check-WorktreeHealth {
    $score = 100
    $issues = @()

    $poolFile = "C:\scripts\_machine\worktrees.pool.json"
    if (Test-Path $poolFile) {
        $pool = Get-Content $poolFile -Raw | ConvertFrom-Json
        $busy = ($pool.agents | Where-Object { $_.status -eq "BUSY" }).Count
        $total = $pool.agents.Count

        if ($busy -eq $total) {
            $score -= 30
            $issues += "All agents BUSY"
        }
        elseif ($busy -gt ($total * 0.7)) {
            $score -= 15
            $issues += "Most agents BUSY ($busy/$total)"
        }
    }

    return @{ score = $score; issues = $issues; category = "Worktrees" }
}

function Check-ToolHealth {
    $score = 100
    $issues = @()

    # Check for broken tools
    $tools = Get-ChildItem "C:\scripts\tools\*.ps1" -ErrorAction SilentlyContinue
    $toolCount = $tools.Count

    if ($toolCount -lt 50) {
        $score -= 10
        $issues += "Limited tool coverage ($toolCount tools)"
    }

    return @{ score = $score; issues = $issues; category = "Tools" }
}

function Check-DocsHealth {
    $score = 100
    $issues = @()

    # Check key docs exist
    $keyDocs = @(
        "C:\scripts\CLAUDE.md",
        "C:\scripts\_machine\reflection.log.md",
        "C:\scripts\_machine\PERSONAL_INSIGHTS.md"
    )

    foreach ($doc in $keyDocs) {
        if (-not (Test-Path $doc)) {
            $score -= 15
            $issues += "Missing: $($doc | Split-Path -Leaf)"
        }
    }

    return @{ score = $score; issues = $issues; category = "Documentation" }
}

function Check-ProcessHealth {
    $score = 100
    $issues = @()

    # Check CPU usage
    $cpuUsage = (Get-WmiObject Win32_Processor).LoadPercentage
    if ($cpuUsage -gt 90) {
        $score -= 25
        $issues += "High CPU usage ($cpuUsage%)"
    }
    elseif ($cpuUsage -gt 70) {
        $score -= 10
        $issues += "Elevated CPU usage ($cpuUsage%)"
    }

    return @{ score = $score; issues = $issues; category = "System" }
}

if ($Calculate) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "                    SYSTEM HEALTH CHECK                         " -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    $checks = @(
        (Check-GitHealth),
        (Check-WorktreeHealth),
        (Check-ToolHealth),
        (Check-DocsHealth),
        (Check-ProcessHealth)
    )

    $totalScore = 0
    $allIssues = @()

    foreach ($check in $checks) {
        $totalScore += $check.score
        $allIssues += $check.issues
    }

    $overallScore = [Math]::Round($totalScore / $checks.Count)

    # Display overall score
    $color = if ($overallScore -ge 80) { "Green" } elseif ($overallScore -ge 60) { "Yellow" } else { "Red" }
    $emoji = if ($overallScore -ge 80) { "🟢" } elseif ($overallScore -ge 60) { "🟡" } else { "🔴" }

    Write-Host "  $emoji OVERALL HEALTH SCORE: $overallScore/100" -ForegroundColor $color
    Write-Host ""

    # Progress bar
    $filled = [Math]::Round($overallScore / 5)
    $bar = "█" * $filled + "░" * (20 - $filled)
    Write-Host "  [$bar]" -ForegroundColor $color
    Write-Host ""

    if ($Detailed) {
        Write-Host "BREAKDOWN BY CATEGORY:" -ForegroundColor Yellow
        Write-Host ""
        foreach ($check in $checks) {
            $catColor = if ($check.score -ge 80) { "Green" } elseif ($check.score -ge 60) { "Yellow" } else { "Red" }
            Write-Host "  $($check.category.PadRight(15)) $($check.score)/100" -ForegroundColor $catColor

            foreach ($issue in $check.issues) {
                Write-Host "    ⚠ $issue" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }

    if ($allIssues.Count -gt 0) {
        Write-Host "ISSUES TO ADDRESS:" -ForegroundColor Yellow
        foreach ($issue in $allIssues | Select-Object -First 5) {
            Write-Host "  • $issue" -ForegroundColor White
        }
        Write-Host ""
    }

    # Save score
    $data.scores += @{
        score = $overallScore
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        issues = $allIssues.Count
    }
    $data.currentScore = $overallScore
    $data | ConvertTo-Json -Depth 10 | Set-Content $HealthFile -Encoding UTF8

    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}
elseif ($History) {
    Write-Host "=== HEALTH SCORE HISTORY ===" -ForegroundColor Cyan
    Write-Host ""

    foreach ($s in $data.scores | Select-Object -Last 10) {
        $color = if ($s.score -ge 80) { "Green" } elseif ($s.score -ge 60) { "Yellow" } else { "Red" }
        $bar = "█" * [Math]::Round($s.score / 5)
        Write-Host "  $($s.timestamp.Substring(5,11)) [$bar] $($s.score)" -ForegroundColor $color
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Calculate            Calculate health score" -ForegroundColor White
    Write-Host "  -Detailed             Show breakdown" -ForegroundColor White
    Write-Host "  -History              Show history" -ForegroundColor White
}
