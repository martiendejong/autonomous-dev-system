<#
.SYNOPSIS
    Rename .json to .txt for text-only analysis fields.

.DESCRIPTION
    Migration script to rename analysis field files from .json to .txt
    for fields that contain only plain text content.

.PARAMETER StoresPath
    Path to the stores directory (e.g., C:\stores\brand2boost)

.EXAMPLE
    .\migrate-analysis-fields-to-txt.ps1 -StoresPath "C:\stores\brand2boost"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$StoresPath
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "=== Analysis Fields Migration: Rename JSON to TXT ===" -ForegroundColor Cyan
Write-Host "Stores path: $StoresPath" -ForegroundColor Gray

# Load the analysis fields config
$configPath = Join-Path $StoresPath "analysis-fields.config.json"
if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: Config file not found: $configPath" -ForegroundColor Red
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$textFields = $config.analysisFields | Where-Object {
    $_.fileName -like "*.txt" -and [string]::IsNullOrEmpty($_.genericType)
}

Write-Host "Found $($textFields.Count) text fields in config" -ForegroundColor Green

# Get all project folders
$projectFolders = Get-ChildItem $StoresPath -Directory | Where-Object { $_.Name -like "p-*" }
Write-Host "Found $($projectFolders.Count) project folders" -ForegroundColor Green
Write-Host ""

$migratedCount = 0

foreach ($projectFolder in $projectFolders) {
    $projectId = $projectFolder.Name
    Write-Host "Processing project: $projectId" -ForegroundColor Yellow

    foreach ($field in $textFields) {
        $txtFileName = $field.fileName
        $jsonFileName = $txtFileName -replace "\.txt$", ".json"

        $txtPath = Join-Path $projectFolder.FullName $txtFileName
        $jsonPath = Join-Path $projectFolder.FullName $jsonFileName

        # If .txt already exists, skip
        if (Test-Path $txtPath) {
            continue
        }

        # If .json doesn't exist, skip
        if (-not (Test-Path $jsonPath)) {
            continue
        }

        # Simply rename .json to .txt
        try {
            Rename-Item -Path $jsonPath -NewName $txtFileName -Force
            Write-Host "  [OK] Renamed: $jsonFileName -> $txtFileName" -ForegroundColor Green
            $migratedCount++
        }
        catch {
            Write-Host "  [ERROR] $($field.key): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "=== Migration Complete ===" -ForegroundColor Cyan
Write-Host "Migrated: $migratedCount files" -ForegroundColor Green
