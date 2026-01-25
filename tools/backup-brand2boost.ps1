#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Nightly backup of brand2boost store data with 5-day retention
.DESCRIPTION
    Creates timestamped backups of C:\stores\brand2boost\data and maintains
    only the 5 most recent backups (rotating deletion of older backups)
.EXAMPLE
    .\backup-brand2boost.ps1
    .\backup-brand2boost.ps1 -DryRun
#>

param(
    [string]$SourcePath = "C:\stores\brand2boost",
    [string]$BackupRoot = "C:\backups\brand2boost",
    [int]$MaxBackups = 5,
    [switch]$DryRun,
    [string[]]$ExcludeDirs = @(".git", "bin", "obj", "logs", "model-usage-stats", ".hazina")

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Ensure backup root exists for log file
if (-not (Test-Path $BackupRoot)) {
    New-Item -Path $BackupRoot -ItemType Directory -Force | Out-Null
}
$logFile = Join-Path $BackupRoot "backup.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $logMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Write-Host $logMessage
    if (-not $DryRun) {
        Add-Content -Path $logFile -Value $logMessage
    }
}

try {
    Write-Log "=== BRAND2BOOST BACKUP STARTED ===" "INFO"
    Write-Log "Source: $SourcePath"
    Write-Log "Backup Root: $BackupRoot"
    Write-Log "Max Backups: $MaxBackups"

    if ($DryRun) {
        Write-Log "DRY RUN MODE - No changes will be made" "WARN"
    }

    # Verify source exists
    if (-not (Test-Path $SourcePath)) {
        Write-Log "Source path does not exist: $SourcePath" "ERROR"
        exit 1
    }

    # Create backup root if it doesn't exist
    if (-not (Test-Path $BackupRoot)) {
        Write-Log "Creating backup root directory: $BackupRoot"
        if (-not $DryRun) {
            New-Item -Path $BackupRoot -ItemType Directory -Force | Out-Null
        }
    }

    # Create backup directory with timestamp
    $backupName = "backup_$timestamp"
    $backupPath = Join-Path $BackupRoot $backupName

    Write-Log "Creating backup: $backupName"
    if ($ExcludeDirs.Count -gt 0) {
        Write-Log "Excluding directories: $($ExcludeDirs -join ', ')"
    }

    if (-not $DryRun) {
        # Create backup directory
        New-Item -Path $backupPath -ItemType Directory -Force | Out-Null

        # Copy all items except excluded directories
        Get-ChildItem -Path $SourcePath | ForEach-Object {
            $item = $_
            $shouldExclude = $false

            # Check if this item should be excluded
            if ($item.PSIsContainer) {
                foreach ($exclude in $ExcludeDirs) {
                    if ($item.Name -eq $exclude) {
                        $shouldExclude = $true
                        Write-Log "Skipping excluded directory: $($item.Name)" "DEBUG"
                        break
                    }
                }
            }

            if (-not $shouldExclude) {
                $destPath = Join-Path $backupPath $item.Name
                Copy-Item -Path $item.FullName -Destination $destPath -Recurse -Force
            }
        }

        # Get backup size
        $backupSize = (Get-ChildItem -Path $backupPath -Recurse | Measure-Object -Property Length -Sum).Sum
        $backupSizeMB = [math]::Round($backupSize / 1MB, 2)
        Write-Log "Backup created successfully: $backupSizeMB MB"
    } else {
        Write-Log "[DRY RUN] Would create backup at: $backupPath"
        Write-Log "[DRY RUN] Would exclude: $($ExcludeDirs -join ', ')"
    }

    # Get all existing backups (sorted by creation time, oldest first)
    $existingBackups = Get-ChildItem -Path $BackupRoot -Directory -Filter "backup_*" |
                       Sort-Object CreationTime

    Write-Log "Found $($existingBackups.Count) existing backups"

    # Delete old backups if we exceed the limit
    if ($existingBackups.Count -gt $MaxBackups) {
        $backupsToDelete = $existingBackups | Select-Object -First ($existingBackups.Count - $MaxBackups)

        Write-Log "Removing $($backupsToDelete.Count) old backup(s) to maintain $MaxBackups limit"

        foreach ($backup in $backupsToDelete) {
            Write-Log "Deleting old backup: $($backup.Name)"
            if (-not $DryRun) {
                Remove-Item -Path $backup.FullName -Recurse -Force
            } else {
                Write-Log "[DRY RUN] Would delete: $($backup.FullName)"
            }
        }
    }

    # List current backups
    $currentBackups = Get-ChildItem -Path $BackupRoot -Directory -Filter "backup_*" |
                      Sort-Object CreationTime -Descending

    Write-Log "Current backups ($($currentBackups.Count)):"
    foreach ($backup in $currentBackups) {
        $size = (Get-ChildItem -Path $backup.FullName -Recurse | Measure-Object -Property Length -Sum).Sum
        $sizeMB = [math]::Round($size / 1MB, 2)
        Write-Log "  - $($backup.Name): $sizeMB MB ($(Get-Date $backup.CreationTime -Format 'yyyy-MM-dd HH:mm'))"
    }

    Write-Log "=== BACKUP COMPLETED SUCCESSFULLY ===" "INFO"
    exit 0

} catch {
    Write-Log "BACKUP FAILED: $_" "ERROR"
    Write-Log $_.ScriptStackTrace "ERROR"
    exit 1
}
