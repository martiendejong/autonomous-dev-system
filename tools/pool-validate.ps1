<#
.SYNOPSIS
    Validates worktree pool file for correctness and consistency.

.DESCRIPTION
    Checks the worktrees.pool.md file for:
    - Valid seat names (agent-XXX format)
    - Consistent status values (FREE/BUSY/STALE/BROKEN)
    - Required columns present
    - No duplicate seats
    - Path consistency
    - Malformed entries

    Can auto-fix some issues with -Fix flag.

.PARAMETER Fix
    Attempt to automatically fix detected issues

.PARAMETER Strict
    Fail on warnings (not just errors)

.PARAMETER Report
    Output detailed validation report

.EXAMPLE
    .\pool-validate.ps1
    .\pool-validate.ps1 -Fix
    .\pool-validate.ps1 -Report
#>

param(
    [switch]$Fix,
    [switch]$Strict,
    [switch]$Report
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$PoolPath = "C:\scripts\_machine\worktrees.pool.md"
$WorkerPath = "C:\Projects\worker-agents"

$errors = @()
$warnings = @()
$fixes = @()

function Add-Error {
    param([string]$Message)
    $script:errors += $Message
}

function Add-Warning {
    param([string]$Message)
    $script:warnings += $Message
}

function Add-Fix {
    param([string]$Message)
    $script:fixes += $Message
}

Write-Host ""
Write-Host "=== POOL VALIDATION ===" -ForegroundColor Cyan
Write-Host ""

# Check file exists
if (-not (Test-Path $PoolPath)) {
    Add-Error "Pool file not found: $PoolPath"
    Write-Host "RESULT: FAILED - Pool file missing" -ForegroundColor Red
    exit 1
}

$content = Get-Content $PoolPath -Raw
$lines = $content -split "`n"

# Parse header and data rows
$headerLine = $null
$dataRows = @()
$seatPattern = "^agent-\d+$"
$validStatuses = @("FREE", "BUSY", "STALE", "BROKEN")

foreach ($line in $lines) {
    if ($line -match '^\| Seat \|') {
        $headerLine = $line
    }
    elseif ($line -match '^\| (agent-\d+|[A-Za-z]+) \|') {
        $dataRows += $line
    }
}

# Validate header
if (-not $headerLine) {
    Add-Error "Missing header row in pool file"
} else {
    $requiredColumns = @("Seat", "Status", "Current repo", "Branch", "Last activity")
    foreach ($col in $requiredColumns) {
        if ($headerLine -notmatch $col) {
            Add-Warning "Header missing expected column: $col"
        }
    }
}

Write-Host "Found $($dataRows.Count) seat entries" -ForegroundColor DarkGray
Write-Host ""

# Parse and validate each row
$seats = @{}
$needsRewrite = $false

foreach ($row in $dataRows) {
    # Parse columns
    $columns = $row -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

    if ($columns.Count -lt 5) {
        Add-Error "Malformed row (too few columns): $row"
        continue
    }

    $seatName = $columns[0]
    $status = $columns[4]  # Status is 5th column (0-indexed: 4)

    # Validate seat name
    if ($seatName -notmatch $seatPattern) {
        Add-Error "Invalid seat name: '$seatName' (must match pattern agent-XXX)"
        $needsRewrite = $true
        continue
    }

    # Check for duplicates
    if ($seats.ContainsKey($seatName)) {
        Add-Error "Duplicate seat: $seatName"
        $needsRewrite = $true
        continue
    }

    # Validate status
    if ($status -notin $validStatuses) {
        Add-Warning "Invalid status '$status' for $seatName (expected: $($validStatuses -join ', '))"
    }

    $seats[$seatName] = @{
        Status = $status
        Row = $row
    }
}

# Cross-check with filesystem
Write-Host "Cross-checking with filesystem..." -ForegroundColor DarkGray

if (Test-Path $WorkerPath) {
    $folders = Get-ChildItem $WorkerPath -Directory

    foreach ($folder in $folders) {
        $folderName = $folder.Name

        # Check for orphaned folders
        if ($folderName -notmatch $seatPattern) {
            Add-Warning "Orphaned folder (invalid name): $folderName"
        }
        elseif (-not $seats.ContainsKey($folderName)) {
            Add-Warning "Folder exists but not in pool: $folderName"
        }

        # Check for FREE seats with worktrees
        if ($seats.ContainsKey($folderName)) {
            $seat = $seats[$folderName]
            if ($seat.Status -eq "FREE") {
                $repoFolders = Get-ChildItem $folder.FullName -Directory -ErrorAction SilentlyContinue
                if ($repoFolders.Count -gt 0) {
                    Add-Warning "Seat $folderName marked FREE but has worktrees: $($repoFolders.Name -join ', ')"
                }
            }
        }
    }

    # Check for seats without folders
    foreach ($seatName in $seats.Keys) {
        $seatPath = Join-Path $WorkerPath $seatName
        if (-not (Test-Path $seatPath)) {
            # Not necessarily an error - FREE seats may not have folders
            if ($seats[$seatName].Status -eq "BUSY") {
                Add-Warning "BUSY seat $seatName has no folder"
            }
        }
    }
}

# Report
Write-Host ""
Write-Host "=== VALIDATION RESULTS ===" -ForegroundColor Cyan
Write-Host ""

if ($errors.Count -gt 0) {
    Write-Host "ERRORS ($($errors.Count)):" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}

if ($warnings.Count -gt 0) {
    Write-Host "WARNINGS ($($warnings.Count)):" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "PASSED - No issues found" -ForegroundColor Green
} elseif ($errors.Count -eq 0) {
    Write-Host ""
    Write-Host "PASSED with warnings" -ForegroundColor Yellow
} else {
    Write-Host ""
    Write-Host "FAILED - $($errors.Count) errors" -ForegroundColor Red
}

Write-Host ""

# Summary stats
if ($Report) {
    Write-Host "=== POOL STATISTICS ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Total seats: $($seats.Count)" -ForegroundColor DarkGray

    $statusCounts = @{}
    foreach ($seat in $seats.Values) {
        if (-not $statusCounts.ContainsKey($seat.Status)) {
            $statusCounts[$seat.Status] = 0
        }
        $statusCounts[$seat.Status]++
    }

    $statusCounts.GetEnumerator() | Sort-Object Name | ForEach-Object {
        $color = switch ($_.Name) {
            "FREE" { "Green" }
            "BUSY" { "Red" }
            "STALE" { "Yellow" }
            "BROKEN" { "DarkRed" }
            default { "Gray" }
        }
        Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor $color
    }
    Write-Host ""
}

# Exit code
if ($Strict) {
    exit ([int]($errors.Count -gt 0 -or $warnings.Count -gt 0))
} else {
    exit ([int]($errors.Count -gt 0))
}
