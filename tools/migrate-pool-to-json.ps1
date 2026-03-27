<#
.SYNOPSIS
    Migrates worktrees.pool.md to JSON format for better queryability.

.DESCRIPTION
    Converts the markdown pool file to JSON while maintaining backward compatibility.
    Creates worktrees.pool.json alongside the existing .md file.

.PARAMETER DryRun
    Show what would be converted without making changes

.PARAMETER Validate
    Validate existing JSON against markdown

.EXAMPLE
    .\migrate-pool-to-json.ps1 -DryRun
    .\migrate-pool-to-json.ps1
    .\migrate-pool-to-json.ps1 -Validate
#>

param(
    [switch]$DryRun,
    [switch]$Validate
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$PoolMdPath = "C:\scripts\_machine\worktrees.pool.md"
$PoolJsonPath = "C:\scripts\_machine\worktrees.pool.json"

function Parse-PoolMarkdown {
    param([string]$Content)

    $seats = @()
    $lines = $Content -split "`n" | Where-Object { $_ -match '^\| agent-' }

    foreach ($line in $lines) {
        # Parse: | agent-001 | agent001 | C:\Projects | C:\Projects\worker-agents\agent-001 | BUSY | client-manager | allitemslist | 2026-01-14T22:00:00Z | Notes |
        if ($line -match '\| (agent-\d+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| (FREE|BUSY|STALE|BROKEN) \| ([^|]*) \| ([^|]*) \| ([^|]*) \| ([^|]*) \|') {
            $seats += @{
                id = $matches[1].Trim()
                startBranch = $matches[2].Trim()
                basePath = $matches[3].Trim()
                worktreePath = $matches[4].Trim()
                status = $matches[5].Trim()
                currentRepo = $matches[6].Trim()
                branch = $matches[7].Trim()
                lastActivity = $matches[8].Trim()
                notes = $matches[9].Trim()
            }
        }
    }

    return $seats
}

function Convert-ToJson {
    param([array]$Seats)

    $pool = @{
        version = "1.0"
        generated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        seats = $Seats
        meta = @{
            freeCount = ($Seats | Where-Object { $_.status -eq "FREE" }).Count
            busyCount = ($Seats | Where-Object { $_.status -eq "BUSY" }).Count
            totalCount = $Seats.Count
        }
    }

    return $pool | ConvertTo-Json -Depth 5
}

function Validate-Pool {
    if (-not (Test-Path $PoolMdPath)) {
        Write-Host "ERROR: $PoolMdPath not found" -ForegroundColor Red
        return $false
    }

    if (-not (Test-Path $PoolJsonPath)) {
        Write-Host "WARNING: $PoolJsonPath not found - run migration first" -ForegroundColor Yellow
        return $false
    }

    $mdContent = Get-Content $PoolMdPath -Raw
    $mdSeats = Parse-PoolMarkdown -Content $mdContent

    $jsonContent = Get-Content $PoolJsonPath -Raw | ConvertFrom-Json
    $jsonSeats = $jsonContent.seats

    $mismatches = @()

    foreach ($mdSeat in $mdSeats) {
        $jsonSeat = $jsonSeats | Where-Object { $_.id -eq $mdSeat.id }
        if (-not $jsonSeat) {
            $mismatches += "Seat $($mdSeat.id) in MD but not in JSON"
        } elseif ($jsonSeat.status -ne $mdSeat.status) {
            $mismatches += "Seat $($mdSeat.id) status mismatch: MD=$($mdSeat.status), JSON=$($jsonSeat.status)"
        }
    }

    if ($mismatches.Count -eq 0) {
        Write-Host "VALID: JSON and MD are in sync" -ForegroundColor Green
        return $true
    } else {
        Write-Host "MISMATCHES FOUND:" -ForegroundColor Red
        $mismatches | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
        return $false
    }
}

# Main execution
Write-Host ""
Write-Host "=== POOL MIGRATION ===" -ForegroundColor Cyan

if ($Validate) {
    Validate-Pool
    exit
}

if (-not (Test-Path $PoolMdPath)) {
    Write-Host "ERROR: $PoolMdPath not found" -ForegroundColor Red
    exit 1
}

$content = Get-Content $PoolMdPath -Raw
$seats = Parse-PoolMarkdown -Content $content
$json = Convert-ToJson -Seats $seats

Write-Host "Parsed $($seats.Count) seats from markdown" -ForegroundColor Green
Write-Host "  FREE: $(($seats | Where-Object { $_.status -eq 'FREE' }).Count)"
Write-Host "  BUSY: $(($seats | Where-Object { $_.status -eq 'BUSY' }).Count)"

if ($DryRun) {
    Write-Host ""
    Write-Host "[DRY RUN] Would write to: $PoolJsonPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Preview:" -ForegroundColor DarkGray
    Write-Host $json
} else {
    $json | Set-Content $PoolJsonPath -Encoding UTF8
    Write-Host ""
    Write-Host "JSON pool written to: $PoolJsonPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: The .md file is still the source of truth." -ForegroundColor DarkGray
    Write-Host "Run with -Validate to check sync between formats." -ForegroundColor DarkGray
}
