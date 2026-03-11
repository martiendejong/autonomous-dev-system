<#
.SYNOPSIS
    Creates Art Revisionist case folder structure from pages.json

.DESCRIPTION
    Reads pages.json and creates the corresponding folder structure with
    details.json and evidence.json index files.

.PARAMETER CaseName
    Name of the case (folder name in C:\stores\artrevisionist\)

.PARAMETER DryRun
    Show what would be created without actually creating

.EXAMPLE
    .\create-case-structure.ps1 -CaseName "Valsuani"
    .\create-case-structure.ps1 -CaseName "NewCase" -DryRun
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$CaseName,

    [switch]$DryRun
)

$BaseDir = "C:\stores\artrevisionist\$CaseName"
$PagesJson = "$BaseDir\pages.json"
$PagesDir = "$BaseDir\pages"

# Check if pages.json exists
if (-not (Test-Path $PagesJson)) {
    Write-Host "ERROR: $PagesJson not found!" -ForegroundColor Red
    Write-Host "Create pages.json first, then run this script." -ForegroundColor Yellow
    exit 1
}

Write-Host "Reading $PagesJson..." -ForegroundColor Cyan
$content = Get-Content $PagesJson -Raw | ConvertFrom-Json

# Create main.json index
$mainIndex = @()
foreach ($page in $content.pages) {
    $mainIndex += @{
        id = $page.id
        title = $page.title
        summary = $page.summary
    }
}

$mainJsonPath = "$PagesDir\main.json"
if ($DryRun) {
    Write-Host "[DRY RUN] Would create: $mainJsonPath" -ForegroundColor Yellow
} else {
    New-Item -ItemType Directory -Path $PagesDir -Force | Out-Null
    $mainIndex | ConvertTo-Json -Depth 10 | Set-Content $mainJsonPath -Encoding UTF8
    Write-Host "Created: $mainJsonPath" -ForegroundColor Green
}

# Process each page
foreach ($page in $content.pages) {
    $pageDir = "$PagesDir\$($page.id)"

    if ($DryRun) {
        Write-Host "[DRY RUN] Would create directory: $pageDir" -ForegroundColor Yellow
    } else {
        New-Item -ItemType Directory -Path $pageDir -Force | Out-Null
    }

    # Create details.json
    $detailsIndex = @()
    foreach ($detail in $page.details) {
        $detailsIndex += @{
            id = $detail.id
            title = $detail.title
            summary = $detail.summary
        }
    }

    $detailsJsonPath = "$pageDir\details.json"
    if ($DryRun) {
        Write-Host "[DRY RUN] Would create: $detailsJsonPath ($(($page.details).Count) details)" -ForegroundColor Yellow
    } else {
        $detailsIndex | ConvertTo-Json -Depth 10 | Set-Content $detailsJsonPath -Encoding UTF8
        Write-Host "Created: $detailsJsonPath ($(($page.details).Count) details)" -ForegroundColor Green
    }

    # Process each detail
    foreach ($detail in $page.details) {
        $detailDir = "$pageDir\$($detail.id)"

        if ($DryRun) {
            Write-Host "[DRY RUN] Would create directory: $detailDir" -ForegroundColor Yellow
        } else {
            New-Item -ItemType Directory -Path $detailDir -Force | Out-Null
        }

        # Create evidence.json
        $evidenceIndex = @()
        if ($detail.evidence -and $detail.evidence.Count -gt 0) {
            foreach ($evidence in $detail.evidence) {
                $evidenceIndex += @{
                    id = $evidence.id
                    title = $evidence.title
                    summary = $evidence.summary
                }
            }
        }

        $evidenceJsonPath = "$detailDir\evidence.json"
        $evidenceCount = if ($detail.evidence) { $detail.evidence.Count } else { 0 }

        if ($DryRun) {
            Write-Host "[DRY RUN] Would create: $evidenceJsonPath ($evidenceCount evidence items)" -ForegroundColor Yellow
        } else {
            $evidenceIndex | ConvertTo-Json -Depth 10 | Set-Content $evidenceJsonPath -Encoding UTF8
            Write-Host "Created: $evidenceJsonPath ($evidenceCount evidence items)" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Case: $CaseName" -ForegroundColor White
Write-Host "Pages: $(($content.pages).Count)" -ForegroundColor White
$totalDetails = ($content.pages | ForEach-Object { $_.details.Count } | Measure-Object -Sum).Sum
Write-Host "Details: $totalDetails" -ForegroundColor White
$totalEvidence = 0
foreach ($page in $content.pages) {
    foreach ($detail in $page.details) {
        if ($detail.evidence) {
            $totalEvidence += $detail.evidence.Count
        }
    }
}
Write-Host "Evidence items: $totalEvidence" -ForegroundColor White

if ($DryRun) {
    Write-Host ""
    Write-Host "This was a dry run. Run without -DryRun to create files." -ForegroundColor Yellow
}
