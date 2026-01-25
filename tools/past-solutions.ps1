<#
.SYNOPSIS
    Past Solution Retrieval
    50-Expert Council V2 Improvement #24 | Priority: 1.8

.DESCRIPTION
    "How did we solve X last time?" - instant answer.

.PARAMETER Search
    Search for past solutions.

.PARAMETER Query
    What to search for.

.PARAMETER Add
    Add a solution.

.PARAMETER Problem
    Problem description.

.PARAMETER Solution
    Solution description.

.EXAMPLE
    past-solutions.ps1 -Search -Query "authentication"
    past-solutions.ps1 -Add -Problem "JWT not validating" -Solution "Check clock skew"
#>

param(
    [switch]$Search,
    [string]$Query = "",
    [switch]$Add,
    [string]$Problem = "",
    [string]$Solution = "",
    [switch]$Recent,
    [switch]$Stats
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$SolutionsFile = "C:\scripts\_machine\past_solutions.json"

if (-not (Test-Path $SolutionsFile)) {
    @{
        solutions = @()
        searches = 0
        hits = 0
    } | ConvertTo-Json -Depth 10 | Set-Content $SolutionsFile -Encoding UTF8
}

$data = Get-Content $SolutionsFile -Raw | ConvertFrom-Json

if ($Search -and $Query) {
    Write-Host "=== PAST SOLUTIONS SEARCH ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Query: `"$Query`"" -ForegroundColor Yellow
    Write-Host ""

    $data.searches++
    $queryLower = $Query.ToLower()
    $results = @()

    foreach ($s in $data.solutions) {
        $score = 0

        # Check problem match
        if ($s.problem.ToLower() -match [regex]::Escape($queryLower)) {
            $score += 50
        }

        # Check solution match
        if ($s.solution.ToLower() -match [regex]::Escape($queryLower)) {
            $score += 30
        }

        # Check keywords
        foreach ($kw in $s.keywords) {
            if ($queryLower -match [regex]::Escape($kw)) {
                $score += 20
            }
        }

        if ($score -gt 0) {
            $results += @{
                solution = $s
                score = $score
            }
        }
    }

    if ($results.Count -eq 0) {
        Write-Host "  No past solutions found for: $Query" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  When you solve this, add it:" -ForegroundColor Gray
        Write-Host "  past-solutions.ps1 -Add -Problem 'x' -Solution 'y'" -ForegroundColor Gray
    }
    else {
        $data.hits++
        $sorted = $results | Sort-Object { $_.score } -Descending

        Write-Host "Found $($results.Count) relevant solution(s):" -ForegroundColor Green
        Write-Host ""

        $rank = 1
        foreach ($r in $sorted | Select-Object -First 5) {
            $s = $r.solution
            Write-Host "$rank. [$($r.score)%] $($s.problem)" -ForegroundColor White
            Write-Host "   SOLUTION: $($s.solution)" -ForegroundColor Cyan
            Write-Host "   (saved $($s.date), used $($s.useCount)x)" -ForegroundColor DarkGray
            Write-Host ""
            $rank++
        }
    }

    $data | ConvertTo-Json -Depth 10 | Set-Content $SolutionsFile -Encoding UTF8
}
elseif ($Add -and $Problem -and $Solution) {
    # Extract keywords
    $keywords = ($Problem + " " + $Solution).ToLower() -split '\s+' |
                Where-Object { $_.Length -gt 3 } |
                Select-Object -Unique

    $entry = @{
        problem = $Problem
        solution = $Solution
        keywords = $keywords
        date = (Get-Date).ToString("yyyy-MM-dd")
        useCount = 0
    }

    $data.solutions += $entry
    $data | ConvertTo-Json -Depth 10 | Set-Content $SolutionsFile -Encoding UTF8

    Write-Host "✓ Solution saved!" -ForegroundColor Green
    Write-Host "  Problem: $Problem" -ForegroundColor White
    Write-Host "  Solution: $Solution" -ForegroundColor Cyan
}
elseif ($Recent) {
    Write-Host "=== RECENT SOLUTIONS ===" -ForegroundColor Cyan
    Write-Host ""

    $recent = $data.solutions | Select-Object -Last 10

    foreach ($s in $recent) {
        Write-Host "  📝 $($s.problem)" -ForegroundColor Yellow
        Write-Host "     → $($s.solution)" -ForegroundColor Green
        Write-Host "     ($($s.date))" -ForegroundColor DarkGray
        Write-Host ""
    }
}
elseif ($Stats) {
    Write-Host "=== PAST SOLUTIONS STATISTICS ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Total solutions: $($data.solutions.Count)" -ForegroundColor White
    Write-Host "  Total searches: $($data.searches)" -ForegroundColor White
    Write-Host "  Hits: $($data.hits)" -ForegroundColor White

    $hitRate = if ($data.searches -gt 0) { [Math]::Round(($data.hits / $data.searches) * 100) } else { 0 }
    Write-Host "  Hit rate: $hitRate%" -ForegroundColor $(if ($hitRate -ge 50) { "Green" } else { "Yellow" })
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Search -Query 'x'              Search for solutions" -ForegroundColor White
    Write-Host "  -Add -Problem 'x' -Solution 'y' Add a solution" -ForegroundColor White
    Write-Host "  -Recent                         Show recent solutions" -ForegroundColor White
    Write-Host "  -Stats                          Show statistics" -ForegroundColor White
}
