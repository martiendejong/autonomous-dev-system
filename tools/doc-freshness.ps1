<#
.SYNOPSIS
    Documentation Freshness Checker
    50-Expert Council V2 Improvement #26 | Priority: 2.33

.DESCRIPTION
    Flags outdated documentation by comparing doc dates vs code changes.

.PARAMETER Check
    Check documentation freshness.

.PARAMETER Path
    Path to check.

.PARAMETER Days
    Days threshold for staleness (default: 30).

.EXAMPLE
    doc-freshness.ps1 -Check -Path "docs/"
#>

param(
    [switch]$Check,
    [string]$Path = ".",
    [int]$Days = 30,
    [switch]$Report
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


if ($Check) {
    Write-Host "=== DOCUMENTATION FRESHNESS CHECK ===" -ForegroundColor Cyan
    Write-Host ""

    $docFiles = Get-ChildItem -Path $Path -Recurse -Include "*.md", "README*" -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -notmatch 'node_modules|bin|obj' }

    $results = @{
        fresh = @()
        stale = @()
        veryStale = @()
    }

    foreach ($doc in $docFiles) {
        $lastModified = $doc.LastWriteTime
        $daysSince = ((Get-Date) - $lastModified).Days

        $entry = @{
            file = $doc.FullName
            name = $doc.Name
            lastModified = $lastModified.ToString("yyyy-MM-dd")
            daysSince = $daysSince
        }

        if ($daysSince -gt ($Days * 2)) {
            $results.veryStale += $entry
        }
        elseif ($daysSince -gt $Days) {
            $results.stale += $entry
        }
        else {
            $results.fresh += $entry
        }
    }

    Write-Host "SUMMARY:" -ForegroundColor Magenta
    Write-Host "  Total docs: $($docFiles.Count)" -ForegroundColor White
    Write-Host "  Fresh (<$Days days): $($results.fresh.Count)" -ForegroundColor Green
    Write-Host "  Stale ($Days-$($Days*2) days): $($results.stale.Count)" -ForegroundColor Yellow
    Write-Host "  Very stale (>$($Days*2) days): $($results.veryStale.Count)" -ForegroundColor Red
    Write-Host ""

    if ($results.veryStale.Count -gt 0) {
        Write-Host "VERY STALE (needs review):" -ForegroundColor Red
        foreach ($d in $results.veryStale | Sort-Object { $_.daysSince } -Descending | Select-Object -First 10) {
            Write-Host "  ⚠ $($d.name) ($($d.daysSince) days old)" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    if ($results.stale.Count -gt 0) {
        Write-Host "STALE:" -ForegroundColor Yellow
        foreach ($d in $results.stale | Sort-Object { $_.daysSince } -Descending | Select-Object -First 10) {
            Write-Host "  ⏰ $($d.name) ($($d.daysSince) days)" -ForegroundColor Gray
        }
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Check -Path 'x'    Check freshness" -ForegroundColor White
    Write-Host "  -Days n             Staleness threshold" -ForegroundColor White
}
