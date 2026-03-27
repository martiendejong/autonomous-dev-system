<#
.SYNOPSIS
    Archives old reflection log entries to reduce file size.

.DESCRIPTION
    Moves entries older than specified days to an archive file.
    Keeps recent entries in the main reflection.log.md for quick access.

.PARAMETER DaysToKeep
    Number of days of entries to keep in main file (default: 30)

.PARAMETER DryRun
    Show what would be archived without making changes

.PARAMETER Force
    Archive without confirmation

.EXAMPLE
    .\archive-reflections.ps1 -DryRun
    .\archive-reflections.ps1 -DaysToKeep 14
    .\archive-reflections.ps1 -Force
#>

param(
    [int]$DaysToKeep = 30,
    [switch]$DryRun,
    [switch]$Force
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ReflectionPath = "C:\scripts\_machine\reflection.log.md"
$ArchiveDir = "C:\scripts\_machine\reflection-archive"
$CutoffDate = (Get-Date).AddDays(-$DaysToKeep)

function Get-EntryDate {
    param([string]$Entry)

    if ($Entry -match '^## (\d{4}-\d{2}-\d{2})') {
        try {
            return [DateTime]::ParseExact($matches[1], "yyyy-MM-dd", $null)
        } catch {
            return $null
        }
    }
    return $null
}

function Split-Entries {
    param([string]$Content)

    # Split by entry headers (## 2026-...)
    $parts = $Content -split '(?=^## \d{4}-\d{2}-\d{2})' | Where-Object { $_ -match '\S' }

    # First part is the header
    $header = $parts[0]
    $entries = $parts | Select-Object -Skip 1

    return @{
        header = $header
        entries = $entries
    }
}

# Main execution
Write-Host ""
Write-Host "=== REFLECTION ARCHIVAL ===" -ForegroundColor Cyan
Write-Host "Cutoff date: $($CutoffDate.ToString('yyyy-MM-dd'))" -ForegroundColor DarkGray
Write-Host "Keeping entries from last $DaysToKeep days" -ForegroundColor DarkGray
Write-Host ""

if (-not (Test-Path $ReflectionPath)) {
    Write-Host "ERROR: $ReflectionPath not found" -ForegroundColor Red
    exit 1
}

$content = Get-Content $ReflectionPath -Raw
$parsed = Split-Entries -Content $content

Write-Host "Total entries: $($parsed.entries.Count)"

$toKeep = @()
$toArchive = @()

foreach ($entry in $parsed.entries) {
    $entryDate = Get-EntryDate -Entry $entry
    if ($entryDate -and $entryDate -lt $CutoffDate) {
        $toArchive += $entry
    } else {
        $toKeep += $entry
    }
}

Write-Host "  To keep: $($toKeep.Count)"
Write-Host "  To archive: $($toArchive.Count)"
Write-Host ""

if ($toArchive.Count -eq 0) {
    Write-Host "Nothing to archive." -ForegroundColor Green
    exit 0
}

# Show what will be archived
Write-Host "Entries to archive:" -ForegroundColor Yellow
foreach ($entry in $toArchive) {
    if ($entry -match '^## (\d{4}-\d{2}-\d{2}) \[([^\]]+)\]') {
        Write-Host "  - $($matches[1]) [$($matches[2])]" -ForegroundColor DarkGray
    }
}
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] Would archive $($toArchive.Count) entries" -ForegroundColor Yellow
    exit 0
}

if (-not $Force) {
    $confirm = Read-Host "Archive $($toArchive.Count) entries? (y/N)"
    if ($confirm -ne 'y') {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Create archive directory
if (-not (Test-Path $ArchiveDir)) {
    New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null
}

# Get archive year-month
$archiveDate = (Get-Date).ToString("yyyy-MM")
$archivePath = Join-Path $ArchiveDir "reflection-archive-$archiveDate.md"

# Append to archive file
$archiveContent = if (Test-Path $archivePath) {
    Get-Content $archivePath -Raw
} else {
    "# Reflection Archive - $archiveDate`n`nArchived entries from reflection.log.md`n`n---`n"
}

$archiveContent += ($toArchive -join "`n")
$archiveContent | Set-Content $archivePath -Encoding UTF8
Write-Host "Archived to: $archivePath" -ForegroundColor Green

# Update main file with kept entries
$newContent = $parsed.header + ($toKeep -join "")
$newContent | Set-Content $ReflectionPath -Encoding UTF8
Write-Host "Updated: $ReflectionPath" -ForegroundColor Green

Write-Host ""
Write-Host "Archival complete." -ForegroundColor Green
Write-Host "  Main file: $($toKeep.Count) entries"
Write-Host "  Archive: $($toArchive.Count) entries added"
