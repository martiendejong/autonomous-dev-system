<#
.SYNOPSIS
    Search for patterns in reflection log and problem-solution index.

.DESCRIPTION
    Quickly find past solutions by searching:
    - Reflection log entries
    - Problem-solution index
    - Pattern templates
    - Runbooks

.PARAMETER Query
    Search term or pattern

.PARAMETER Type
    Limit search to specific type: all, reflections, problems, patterns, runbooks

.PARAMETER Recent
    Only search recent N entries (for reflections)

.EXAMPLE
    .\pattern-search.ps1 -Query "build error"
    .\pattern-search.ps1 -Query "worktree" -Type reflections
    .\pattern-search.ps1 -Query "NU1105" -Type problems
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Query,

    [ValidateSet("all", "reflections", "problems", "patterns", "runbooks")]
    [string]$Type = "all",

    [int]$Recent = 0
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$Sources = @{
    reflections = "C:\scripts\_machine\reflection.log.md"
    problems = "C:\scripts\_machine\problem-solution-index.md"
    patterns = "C:\scripts\_machine\pattern-templates"
    runbooks = "C:\scripts\_machine\runbooks"
}

function Search-File {
    param([string]$Path, [string]$Pattern)

    if (-not (Test-Path $Path)) { return @() }

    $results = @()
    $content = Get-Content $Path -Raw

    # Split into sections
    $sections = $content -split '(?=^## )' -ne ''

    foreach ($section in $sections) {
        if ($section -match $Pattern) {
            # Extract section header
            $header = ($section -split "`n")[0]
            $preview = ($section -split "`n" | Select-Object -Skip 1 -First 3) -join " "
            $preview = $preview.Substring(0, [Math]::Min(200, $preview.Length))

            $results += @{
                source = Split-Path $Path -Leaf
                header = $header
                preview = $preview
                matchCount = ([regex]::Matches($section, $Pattern)).Count
            }
        }
    }

    return $results
}

function Search-Directory {
    param([string]$DirPath, [string]$Pattern)

    if (-not (Test-Path $DirPath)) { return @() }

    $results = @()
    Get-ChildItem $DirPath -Filter "*.md" | ForEach-Object {
        $fileResults = Search-File -Path $_.FullName -Pattern $Pattern
        $results += $fileResults
    }

    return $results
}

# Build regex pattern (case insensitive)
$pattern = "(?i)$([regex]::Escape($Query))"

$allResults = @()

# Search based on type
switch ($Type) {
    "reflections" {
        $allResults += Search-File -Path $Sources.reflections -Pattern $pattern
    }
    "problems" {
        $allResults += Search-File -Path $Sources.problems -Pattern $pattern
    }
    "patterns" {
        $allResults += Search-Directory -Path $Sources.patterns -Pattern $pattern
    }
    "runbooks" {
        $allResults += Search-Directory -Path $Sources.runbooks -Pattern $pattern
    }
    "all" {
        $allResults += Search-File -Path $Sources.reflections -Pattern $pattern
        $allResults += Search-File -Path $Sources.problems -Pattern $pattern
        $allResults += Search-Directory -Path $Sources.patterns -Pattern $pattern
        $allResults += Search-Directory -Path $Sources.runbooks -Pattern $pattern
    }
}

# Sort by match count (most relevant first)
$allResults = $allResults | Sort-Object -Property matchCount -Descending

# Output results
Write-Host ""
Write-Host "=== PATTERN SEARCH: '$Query' ===" -ForegroundColor Cyan
Write-Host "Type: $Type" -ForegroundColor DarkGray
Write-Host ""

if ($allResults.Count -eq 0) {
    Write-Host "No matches found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Try:" -ForegroundColor DarkGray
    Write-Host "  - Different keywords" -ForegroundColor DarkGray
    Write-Host "  - Broader search type (-Type all)" -ForegroundColor DarkGray
    Write-Host "  - Check problem-solution-index.md directly" -ForegroundColor DarkGray
} else {
    Write-Host "Found $($allResults.Count) matches:" -ForegroundColor Green
    Write-Host ""

    $index = 1
    foreach ($result in $allResults) {
        Write-Host "$index. [$($result.source)] $($result.header)" -ForegroundColor Yellow
        Write-Host "   $($result.preview)..." -ForegroundColor DarkGray
        Write-Host ""
        $index++
    }
}

Write-Host ""
