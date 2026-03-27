<#
.SYNOPSIS
    Read and display reflection log entries with filtering.

.DESCRIPTION
    Provides easy access to reflection log entries with:
    - Recent N entries
    - Filter by tag
    - Filter by date range
    - Search by content

.PARAMETER Recent
    Show most recent N entries (default: 5)

.PARAMETER Tag
    Filter by tag (e.g., "BUG-FIX", "PATTERN")

.PARAMETER Since
    Show entries since date (yyyy-MM-dd)

.PARAMETER Search
    Search entry content

.PARAMETER List
    Just list entry headers without content

.EXAMPLE
    .\read-reflections.ps1 -Recent 10
    .\read-reflections.ps1 -Tag "CROSS-REPO"
    .\read-reflections.ps1 -Since "2026-01-14"
    .\read-reflections.ps1 -Search "worktree"
    .\read-reflections.ps1 -List
#>

param(
    [int]$Recent = 5,
    [string]$Tag,
    [string]$Since,
    [string]$Search,
    [switch]$List
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ReflectionPath = "C:\scripts\_machine\reflection.log.md"

function Parse-Entries {
    param([string]$Content)

    $parts = $Content -split '(?=^## \d{4}-\d{2}-\d{2})' | Where-Object { $_ -match '^## \d{4}' }

    $entries = @()
    foreach ($part in $parts) {
        if ($part -match '^## (\d{4}-\d{2}-\d{2}) \[([^\]]+)\]([^\n]*)') {
            $entries += @{
                date = $matches[1]
                tag = $matches[2]
                title = $matches[3].Trim(' - ')
                content = $part
            }
        }
    }

    return $entries
}

function Format-Entry {
    param($Entry, [switch]$HeaderOnly)

    Write-Host ""
    Write-Host "## $($Entry.date) [$($Entry.tag)] - $($Entry.title)" -ForegroundColor Cyan

    if (-not $HeaderOnly) {
        # Show first few lines of content
        $lines = $Entry.content -split "`n" | Select-Object -Skip 1 -First 15
        foreach ($line in $lines) {
            if ($line -match '^\*\*') {
                Write-Host $line -ForegroundColor Yellow
            } elseif ($line -match '^###') {
                Write-Host $line -ForegroundColor DarkCyan
            } else {
                Write-Host $line -ForegroundColor DarkGray
            }
        }

        if (($Entry.content -split "`n").Count -gt 16) {
            Write-Host "  ..." -ForegroundColor DarkGray
            Write-Host "  (truncated - $((($Entry.content -split "`n").Count - 1)) total lines)" -ForegroundColor DarkGray
        }
    }
}

# Main execution
if (-not (Test-Path $ReflectionPath)) {
    Write-Host "ERROR: $ReflectionPath not found" -ForegroundColor Red
    exit 1
}

$content = Get-Content $ReflectionPath -Raw
$entries = Parse-Entries -Content $content

Write-Host ""
Write-Host "=== REFLECTION LOG ===" -ForegroundColor Cyan
Write-Host "Total entries: $($entries.Count)" -ForegroundColor DarkGray

# Apply filters
$filtered = $entries

if ($Tag) {
    $filtered = $filtered | Where-Object { $_.tag -like "*$Tag*" }
    Write-Host "Filtered by tag: $Tag" -ForegroundColor DarkGray
}

if ($Since) {
    $sinceDate = [DateTime]::ParseExact($Since, "yyyy-MM-dd", $null)
    $filtered = $filtered | Where-Object {
        $entryDate = [DateTime]::ParseExact($_.date, "yyyy-MM-dd", $null)
        $entryDate -ge $sinceDate
    }
    Write-Host "Filtered since: $Since" -ForegroundColor DarkGray
}

if ($Search) {
    $filtered = $filtered | Where-Object { $_.content -match "(?i)$Search" }
    Write-Host "Search: $Search" -ForegroundColor DarkGray
}

# Apply recent limit
$filtered = $filtered | Select-Object -First $Recent

Write-Host "Showing: $($filtered.Count) entries" -ForegroundColor DarkGray

if ($filtered.Count -eq 0) {
    Write-Host ""
    Write-Host "No matching entries found." -ForegroundColor Yellow
    exit 0
}

# Display
foreach ($entry in $filtered) {
    Format-Entry -Entry $entry -HeaderOnly:$List
}

Write-Host ""
