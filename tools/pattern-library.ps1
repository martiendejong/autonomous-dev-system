<#
.SYNOPSIS
    Pattern Library with Search - All patterns tagged, searchable, with examples.
    50-Expert Council Improvement #21 | Priority: 2.25

.DESCRIPTION
    Central repository of learned patterns from successes and solutions.
    Enables quick lookup of proven approaches.

.PARAMETER Search
    Search patterns by keyword or tag.

.PARAMETER List
    List all patterns.

.PARAMETER Tag
    Filter by specific tag.

.PARAMETER Recent
    Show N most recent patterns.

.PARAMETER Use
    Mark a pattern as used (increases its ranking).

.EXAMPLE
    pattern-library.ps1 -Search "workflow"
    pattern-library.ps1 -List
    pattern-library.ps1 -Tag "efficiency"
    pattern-library.ps1 -Recent 10
#>

param(
    [string]$Search = "",
    [switch]$List,
    [string]$Tag = "",
    [int]$Recent = 0,
    [string]$Use = ""
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$PatternLibrary = "C:\scripts\_machine\pattern_library.json"

# Initialize library if not exists
if (-not (Test-Path $PatternLibrary)) {
    # Seed with known good patterns
    $seedPatterns = @{
        patterns = @(
            @{
                id = "seed001"
                success = "Worktree workflow prevents conflicts"
                context = "Multi-agent development"
                pattern = "Always allocate worktree before editing code"
                tags = @("worktree", "workflow", "conflict-prevention")
                created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                useCount = 10
                source = "seed"
            },
            @{
                id = "seed002"
                success = "Quick commands reduce friction"
                context = "Daily operations"
                pattern = "Single-letter commands for frequent operations (q s, q w, etc.)"
                tags = @("efficiency", "commands", "quick")
                created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                useCount = 5
                source = "seed"
            },
            @{
                id = "seed003"
                success = "Error prevention catches mistakes early"
                context = "Before commits and major actions"
                pattern = "Run prevent-errors.ps1 before significant actions"
                tags = @("safety", "prevention", "quality")
                created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                useCount = 8
                source = "seed"
            },
            @{
                id = "seed004"
                success = "50-Expert Council improves decisions"
                context = "Planning and architecture"
                pattern = "Consult multiple expert perspectives before major decisions"
                tags = @("planning", "experts", "decisions")
                created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                useCount = 3
                source = "seed"
            },
            @{
                id = "seed005"
                success = "Reflection checkpoints prevent rabbit holes"
                context = "During long work sessions"
                pattern = "Pause every 15 minutes to verify direction"
                tags = @("reflection", "focus", "productivity")
                created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                useCount = 4
                source = "seed"
            }
        )
        tags = @{
            worktree = @("seed001")
            workflow = @("seed001")
            efficiency = @("seed002")
            commands = @("seed002")
            safety = @("seed003")
            planning = @("seed004")
            reflection = @("seed005")
        }
        successCount = 5
    }
    $seedPatterns | ConvertTo-Json -Depth 10 | Set-Content $PatternLibrary -Encoding UTF8
}

$library = Get-Content $PatternLibrary -Raw | ConvertFrom-Json

function Show-Pattern {
    param($p)
    Write-Host ""
    Write-Host "[$($p.id)] $($p.pattern)" -ForegroundColor Cyan
    Write-Host "  Context: $($p.context)" -ForegroundColor Gray
    Write-Host "  Tags: $($p.tags -join ', ')" -ForegroundColor Yellow
    Write-Host "  Used: $($p.useCount)x | Created: $($p.created)" -ForegroundColor DarkGray
}

function Search-Patterns {
    param([string]$Query)

    Write-Host "=== PATTERN LIBRARY SEARCH ===" -ForegroundColor Cyan
    Write-Host "Query: $Query" -ForegroundColor Yellow
    Write-Host ""

    $results = $library.patterns | Where-Object {
        $_.pattern -match $Query -or
        $_.success -match $Query -or
        $_.context -match $Query -or
        ($_.tags -join ' ') -match $Query
    } | Sort-Object useCount -Descending

    if ($results.Count -eq 0) {
        Write-Host "No patterns found matching '$Query'" -ForegroundColor Yellow
        Write-Host "Try: pattern-library.ps1 -List" -ForegroundColor Gray
        return
    }

    Write-Host "Found $($results.Count) patterns:" -ForegroundColor Green

    foreach ($p in $results) {
        Show-Pattern $p
    }
}

function List-AllPatterns {
    Write-Host "=== ALL PATTERNS ===" -ForegroundColor Cyan
    Write-Host "Total: $($library.patterns.Count) patterns" -ForegroundColor Yellow
    Write-Host ""

    $sorted = $library.patterns | Sort-Object useCount -Descending

    foreach ($p in $sorted) {
        Show-Pattern $p
    }
}

function Filter-ByTag {
    param([string]$TagName)

    Write-Host "=== PATTERNS TAGGED: $TagName ===" -ForegroundColor Cyan
    Write-Host ""

    $tagIds = $library.tags.$TagName
    if (-not $tagIds -or $tagIds.Count -eq 0) {
        Write-Host "No patterns found with tag '$TagName'" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Available tags:" -ForegroundColor Gray
        $library.tags.PSObject.Properties | ForEach-Object {
            Write-Host "  - $($_.Name) ($($_.Value.Count) patterns)" -ForegroundColor White
        }
        return
    }

    $patterns = $library.patterns | Where-Object { $tagIds -contains $_.id }

    foreach ($p in $patterns) {
        Show-Pattern $p
    }
}

function Show-Recent {
    param([int]$Count)

    Write-Host "=== RECENT PATTERNS ===" -ForegroundColor Cyan
    Write-Host ""

    $recent = $library.patterns | Sort-Object created -Descending | Select-Object -First $Count

    foreach ($p in $recent) {
        Show-Pattern $p
    }
}

function Mark-Used {
    param([string]$PatternId)

    $pattern = $library.patterns | Where-Object { $_.id -eq $PatternId }

    if (-not $pattern) {
        Write-Host "Pattern not found: $PatternId" -ForegroundColor Red
        return
    }

    $pattern.useCount++
    $library | ConvertTo-Json -Depth 10 | Set-Content $PatternLibrary -Encoding UTF8

    Write-Host "✓ Pattern '$PatternId' marked as used (now: $($pattern.useCount)x)" -ForegroundColor Green
}

# Main execution
if ($Search) {
    Search-Patterns -Query $Search
} elseif ($List) {
    List-AllPatterns
} elseif ($Tag) {
    Filter-ByTag -TagName $Tag
} elseif ($Recent -gt 0) {
    Show-Recent -Count $Recent
} elseif ($Use) {
    Mark-Used -PatternId $Use
} else {
    # Default: show help and stats
    Write-Host "=== PATTERN LIBRARY ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Total patterns: $($library.patterns.Count)" -ForegroundColor Yellow
    Write-Host "Total uses: $(($library.patterns | Measure-Object -Property useCount -Sum).Sum)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Magenta
    Write-Host "  -Search <query>  Search patterns" -ForegroundColor White
    Write-Host "  -List            Show all patterns" -ForegroundColor White
    Write-Host "  -Tag <tag>       Filter by tag" -ForegroundColor White
    Write-Host "  -Recent <n>      Show recent patterns" -ForegroundColor White
    Write-Host "  -Use <id>        Mark pattern as used" -ForegroundColor White
    Write-Host ""
    Write-Host "Add patterns with: success-to-pattern.ps1" -ForegroundColor Gray
}
