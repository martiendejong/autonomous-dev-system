<#
.SYNOPSIS
    Celebration Mode - Celebrate wins with stats
    50-Expert Council V2 Improvement #42 | Priority: 3.0

.DESCRIPTION
    Celebrates successes with visual feedback and stats.
    Tracks wins over time for motivation.

.PARAMETER Win
    Record a win.

.PARAMETER Message
    Win description.

.PARAMETER Stats
    Show win statistics.

.PARAMETER Recent
    Show recent wins.

.EXAMPLE
    celebrate.ps1 -Win -Message "Shipped feature X!"
    celebrate.ps1 -Stats
#>

param(
    [switch]$Win,
    [string]$Message = "",
    [switch]$Stats,
    [switch]$Recent
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$WinsFile = "C:\scripts\_machine\wins.json"

if (-not (Test-Path $WinsFile)) {
    @{
        wins = @()
        streaks = @{
            current = 0
            longest = 0
            lastWinDate = $null
        }
        totals = @{
            allTime = 0
            thisWeek = 0
            thisMonth = 0
        }
    } | ConvertTo-Json -Depth 10 | Set-Content $WinsFile -Encoding UTF8
}

$data = Get-Content $WinsFile -Raw | ConvertFrom-Json

function Show-Celebration {
    param([string]$Msg)

    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║                                                            ║" -ForegroundColor Green
    Write-Host "  ║    🎉🎉🎉  CELEBRATION TIME!  🎉🎉🎉                       ║" -ForegroundColor Yellow
    Write-Host "  ║                                                            ║" -ForegroundColor Green
    Write-Host "  ╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  ⭐ $Msg" -ForegroundColor Cyan
    Write-Host ""

    # ASCII confetti
    $colors = @("Red", "Yellow", "Green", "Cyan", "Magenta", "Blue")
    $confetti = @("*", "•", "○", "★", "◆", "♦")

    for ($i = 0; $i -lt 3; $i++) {
        $line = "  "
        for ($j = 0; $j -lt 30; $j++) {
            $c = $confetti | Get-Random
            $color = $colors | Get-Random
            Write-Host $c -ForegroundColor $color -NoNewline
        }
        Write-Host ""
    }

    Write-Host ""
}

if ($Win) {
    $msg = if ($Message) { $Message } else { "Another win!" }

    # Record the win
    $win = @{
        message = $msg
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        date = (Get-Date).ToString("yyyy-MM-dd")
    }

    $data.wins += $win
    $data.totals.allTime++

    # Update streak
    $today = (Get-Date).ToString("yyyy-MM-dd")
    $yesterday = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")

    if ($data.streaks.lastWinDate -eq $yesterday -or $data.streaks.lastWinDate -eq $today) {
        if ($data.streaks.lastWinDate -ne $today) {
            $data.streaks.current++
        }
    } else {
        $data.streaks.current = 1
    }

    if ($data.streaks.current -gt $data.streaks.longest) {
        $data.streaks.longest = $data.streaks.current
    }

    $data.streaks.lastWinDate = $today

    # Update weekly/monthly counts
    $weekStart = (Get-Date).AddDays(-7)
    $monthStart = (Get-Date).AddDays(-30)
    $data.totals.thisWeek = ($data.wins | Where-Object {
        [datetime]::Parse($_.date) -gt $weekStart
    }).Count
    $data.totals.thisMonth = ($data.wins | Where-Object {
        [datetime]::Parse($_.date) -gt $monthStart
    }).Count

    $data | ConvertTo-Json -Depth 10 | Set-Content $WinsFile -Encoding UTF8

    Show-Celebration $msg

    Write-Host "  📊 Stats:" -ForegroundColor Magenta
    Write-Host "     Total wins: $($data.totals.allTime)" -ForegroundColor White
    Write-Host "     Current streak: $($data.streaks.current) days 🔥" -ForegroundColor Yellow
    Write-Host "     This week: $($data.totals.thisWeek)" -ForegroundColor White
    Write-Host ""
}
elseif ($Stats) {
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                    WIN STATISTICS                          ║" -ForegroundColor Cyan
    Write-Host "  ╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  🏆 ALL TIME WINS: $($data.totals.allTime)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  📅 This Week:     $($data.totals.thisWeek)" -ForegroundColor White
    Write-Host "  📅 This Month:    $($data.totals.thisMonth)" -ForegroundColor White
    Write-Host ""
    Write-Host "  🔥 Current Streak: $($data.streaks.current) days" -ForegroundColor $(if ($data.streaks.current -ge 3) { "Green" } else { "Yellow" })
    Write-Host "  🏅 Longest Streak: $($data.streaks.longest) days" -ForegroundColor Magenta
    Write-Host ""
}
elseif ($Recent) {
    Write-Host ""
    Write-Host "=== RECENT WINS ===" -ForegroundColor Cyan
    Write-Host ""

    $recent = $data.wins | Select-Object -Last 10

    if ($recent.Count -eq 0) {
        Write-Host "  No wins recorded yet. Time to make some! 💪" -ForegroundColor Yellow
    } else {
        foreach ($w in $recent) {
            Write-Host "  ⭐ $($w.message)" -ForegroundColor Green
            Write-Host "     $($w.timestamp)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Win -Message 'x'   Record a win" -ForegroundColor White
    Write-Host "  -Stats              Show statistics" -ForegroundColor White
    Write-Host "  -Recent             Show recent wins" -ForegroundColor White
}
