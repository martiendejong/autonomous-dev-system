<#
.SYNOPSIS
    Error Solution Memory
    50-Expert Council V2 Improvement #21 | Priority: 2.5

.DESCRIPTION
    Remembers how errors were fixed, suggests solutions instantly.
    Learns from every fix to improve suggestions.

.PARAMETER Log
    Log an error and its solution.

.PARAMETER Error
    Error message or pattern.

.PARAMETER Solution
    How it was fixed.

.PARAMETER Search
    Search for solutions to an error.

.PARAMETER Query
    Error to search for.

.PARAMETER Stats
    Show error/solution statistics.

.EXAMPLE
    error-memory.ps1 -Log -Error "CS0535: does not implement" -Solution "Add missing interface members"
    error-memory.ps1 -Search -Query "CS0535"
#>

param(
    [switch]$Log,
    [string]$Error = "",
    [string]$Solution = "",
    [switch]$Search,
    [string]$Query = "",
    [switch]$Stats,
    [switch]$Recent
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ErrorMemoryFile = "C:\scripts\_machine\error_memory.json"

if (-not (Test-Path $ErrorMemoryFile)) {
    @{
        errors = @()
        searchCount = 0
        hitCount = 0
        lastUpdate = $null
    } | ConvertTo-Json -Depth 10 | Set-Content $ErrorMemoryFile -Encoding UTF8
}

$memory = Get-Content $ErrorMemoryFile -Raw | ConvertFrom-Json

if ($Log -and $Error -and $Solution) {
    # Check for duplicates
    $existing = $memory.errors | Where-Object { $_.pattern -eq $Error }

    if ($existing) {
        # Update existing
        $existing.solutions += @{
            text = $Solution
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        $existing.useCount++
    }
    else {
        # Add new
        $entry = @{
            pattern = $Error
            keywords = ($Error -split '\s+' | Where-Object { $_.Length -gt 3 })
            solutions = @(
                @{
                    text = $Solution
                    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                }
            )
            useCount = 1
            created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        $memory.errors += $entry
    }

    $memory.lastUpdate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $memory | ConvertTo-Json -Depth 10 | Set-Content $ErrorMemoryFile -Encoding UTF8

    Write-Host "✓ Error solution logged!" -ForegroundColor Green
    Write-Host "  Pattern: $Error" -ForegroundColor Gray
    Write-Host "  Solution: $Solution" -ForegroundColor White
}
elseif ($Search -and $Query) {
    $memory.searchCount++

    Write-Host "=== ERROR SOLUTION SEARCH ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Query: $Query" -ForegroundColor Yellow
    Write-Host ""

    $queryLower = $Query.ToLower()
    $matches = @()

    foreach ($err in $memory.errors) {
        $score = 0

        # Exact match
        if ($err.pattern.ToLower() -eq $queryLower) {
            $score = 100
        }
        # Contains match
        elseif ($err.pattern.ToLower() -match [regex]::Escape($queryLower)) {
            $score = 80
        }
        # Keyword match
        else {
            foreach ($kw in $err.keywords) {
                if ($queryLower -match [regex]::Escape($kw.ToLower())) {
                    $score += 20
                }
            }
        }

        if ($score -gt 0) {
            $matches += @{
                error = $err
                score = $score
            }
        }
    }

    if ($matches.Count -eq 0) {
        Write-Host "  No solutions found for this error." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  When you fix it, log the solution:" -ForegroundColor Gray
        Write-Host "  error-memory.ps1 -Log -Error '$Query' -Solution 'your fix'" -ForegroundColor Gray
    }
    else {
        $memory.hitCount++

        $sorted = $matches | Sort-Object { $_.score } -Descending

        Write-Host "Found $($sorted.Count) potential solution(s):" -ForegroundColor Green
        Write-Host ""

        $rank = 1
        foreach ($m in $sorted | Select-Object -First 5) {
            $e = $m.error
            Write-Host "$rank. [$($m.score)%] $($e.pattern)" -ForegroundColor White

            Write-Host "   Solutions:" -ForegroundColor Magenta
            foreach ($s in $e.solutions | Select-Object -Last 3) {
                Write-Host "   → $($s.text)" -ForegroundColor Cyan
            }

            Write-Host "   (used $($e.useCount) times)" -ForegroundColor DarkGray
            Write-Host ""
            $rank++
        }
    }

    $memory | ConvertTo-Json -Depth 10 | Set-Content $ErrorMemoryFile -Encoding UTF8
}
elseif ($Stats) {
    Write-Host "=== ERROR MEMORY STATISTICS ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Total errors logged: $($memory.errors.Count)" -ForegroundColor White
    Write-Host "  Total searches: $($memory.searchCount)" -ForegroundColor White
    Write-Host "  Search hits: $($memory.hitCount)" -ForegroundColor White

    $hitRate = if ($memory.searchCount -gt 0) {
        [Math]::Round(($memory.hitCount / $memory.searchCount) * 100)
    } else { 0 }

    Write-Host "  Hit rate: $hitRate%" -ForegroundColor $(if ($hitRate -ge 50) { "Green" } else { "Yellow" })
    Write-Host ""

    Write-Host "  Most common errors:" -ForegroundColor Magenta
    $memory.errors | Sort-Object { $_.useCount } -Descending | Select-Object -First 5 | ForEach-Object {
        Write-Host "    [$($_.useCount)x] $($_.pattern.Substring(0, [Math]::Min(50, $_.pattern.Length)))..." -ForegroundColor White
    }
}
elseif ($Recent) {
    Write-Host "=== RECENT ERROR SOLUTIONS ===" -ForegroundColor Cyan
    Write-Host ""

    $recent = $memory.errors | Sort-Object { $_.created } -Descending | Select-Object -First 10

    foreach ($e in $recent) {
        Write-Host "  $($e.pattern)" -ForegroundColor Yellow
        Write-Host "  → $($e.solutions[-1].text)" -ForegroundColor Green
        Write-Host "  ($($e.created))" -ForegroundColor DarkGray
        Write-Host ""
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Log -Error 'x' -Solution 'y'   Log error solution" -ForegroundColor White
    Write-Host "  -Search -Query 'error'          Search for solutions" -ForegroundColor White
    Write-Host "  -Stats                          Show statistics" -ForegroundColor White
    Write-Host "  -Recent                         Show recent solutions" -ForegroundColor White
}
