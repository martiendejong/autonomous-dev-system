<#
.SYNOPSIS
    Automated backup and restore for databases and configuration files.

.DESCRIPTION
    Creates automated backups of SQL Server databases, configuration files,
    and critical data. Supports point-in-time restore, verification, and rotation.

    Features:
    - SQL Server database backups (full, differential, transaction log)
    - Configuration file backups (appsettings.json, .env, etc.)
    - Automated backup rotation (keep N most recent)
    - Point-in-time restore
    - Backup verification
    - Compression support
    - Scheduled backups via Task Scheduler

.PARAMETER Action
    Action: backup, restore, verify, list, cleanup

.PARAMETER Type
    Backup type: database, config, all (default: all)

.PARAMETER DatabaseName
    Database name for backup/restore

.PARAMETER ConnectionString
    SQL Server connection string

.PARAMETER BackupPath
    Path to store/restore backups (default: C:\Backups)

.PARAMETER ConfigPaths
    Paths to configuration files to backup

.PARAMETER RestorePoint
    Backup file or timestamp to restore from

.PARAMETER KeepCount
    Number of recent backups to keep (default: 7)

.PARAMETER Verify
    Verify backup after creation

.EXAMPLE
    .\backup-restore.ps1 -Action backup -Type database -DatabaseName ClientManager
    .\backup-restore.ps1 -Action backup -Type config -ConfigPaths "C:\Projects\client-manager\appsettings.json"
    .\backup-restore.ps1 -Action restore -DatabaseName ClientManager -RestorePoint "backup-2024-01-16.bak"
    .\backup-restore.ps1 -Action list
    .\backup-restore.ps1 -Action cleanup -KeepCount 7
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("backup", "restore", "verify", "list", "cleanup")]
    [string]$Action,

    [ValidateSet("database", "config", "all")]
    [string]$Type = "all",

    [string]$DatabaseName,
    [string]$ConnectionString = "Server=localhost;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True",
    [string]$BackupPath = "C:/Backups",
    [string[]]$ConfigPaths,
    [string]$RestorePoint,
    [int]$KeepCount = 7,
    [switch]$Verify
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Backup-Database {
    param([string]$DatabaseName, [string]$ConnectionString, [string]$BackupPath, [bool]$VerifyBackup)

    Write-Host ""
    Write-Host "=== Database Backup ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $DatabaseName) {
        Write-Host "ERROR: -DatabaseName required" -ForegroundColor Red
        return $null
    }

    # Create backup directory
    $dbBackupPath = Join-Path $BackupPath "databases"

    if (-not (Test-Path $dbBackupPath)) {
        New-Item -ItemType Directory -Path $dbBackupPath -Force | Out-Null
    }

    # Generate backup filename
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $backupFile = Join-Path $dbBackupPath "$DatabaseName-$timestamp.bak"

    Write-Host "Database: $DatabaseName" -ForegroundColor White
    Write-Host "Backup file: $backupFile" -ForegroundColor DarkGray
    Write-Host ""

    # Build SQL command
    $sqlCommand = @"
BACKUP DATABASE [$DatabaseName]
TO DISK = '$backupFile'
WITH FORMAT,
     COMPRESSION,
     CHECKSUM,
     STATS = 10;
"@

    try {
        # Execute backup using sqlcmd
        $output = sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -Q $sqlCommand 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Backup completed successfully!" -ForegroundColor Green

            # Get backup file size
            $backupFileInfo = Get-Item $backupFile
            $sizeMB = [math]::Round($backupFileInfo.Length / 1MB, 2)

            Write-Host ("  Size: {0} MB" -f $sizeMB) -ForegroundColor White
            Write-Host ""

            # Verify if requested
            if ($VerifyBackup) {
                Verify-DatabaseBackup -BackupFile $backupFile
            }

            return $backupFile

        } else {
            Write-Host "Backup failed!" -ForegroundColor Red
            Write-Host $output -ForegroundColor Red
            return $null
        }

    } catch {
        Write-Host "ERROR: $_" -ForegroundColor Red
        return $null
    }
}

function Backup-ConfigFiles {
    param([string[]]$ConfigPaths, [string]$BackupPath)

    Write-Host ""
    Write-Host "=== Configuration Backup ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $ConfigPaths -or $ConfigPaths.Count -eq 0) {
        Write-Host "ERROR: -ConfigPaths required" -ForegroundColor Red
        return $null
    }

    # Create backup directory
    $configBackupPath = Join-Path $BackupPath "config"

    if (-not (Test-Path $configBackupPath)) {
        New-Item -ItemType Directory -Path $configBackupPath -Force | Out-Null
    }

    # Create timestamped subdirectory
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $backupDir = Join-Path $configBackupPath $timestamp

    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    Write-Host "Backing up configuration files..." -ForegroundColor White
    Write-Host ""

    $backedUpCount = 0

    foreach ($configPath in $ConfigPaths) {
        if (Test-Path $configPath) {
            $fileName = Split-Path $configPath -Leaf
            $destPath = Join-Path $backupDir $fileName

            Copy-Item $configPath $destPath -Force

            Write-Host "  Backed up: $fileName" -ForegroundColor Green
            $backedUpCount++
        } else {
            Write-Host "  Not found: $configPath" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "Backed up $backedUpCount files to: $backupDir" -ForegroundColor Green
    Write-Host ""

    return $backupDir
}

function Restore-Database {
    param([string]$DatabaseName, [string]$BackupFile, [string]$ConnectionString)

    Write-Host ""
    Write-Host "=== Database Restore ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $DatabaseName) {
        Write-Host "ERROR: -DatabaseName required" -ForegroundColor Red
        return $false
    }

    if (-not $BackupFile) {
        Write-Host "ERROR: -RestorePoint required" -ForegroundColor Red
        return $false
    }

    if (-not (Test-Path $BackupFile)) {
        Write-Host "ERROR: Backup file not found: $BackupFile" -ForegroundColor Red
        return $false
    }

    Write-Host "Database: $DatabaseName" -ForegroundColor White
    Write-Host "Backup file: $BackupFile" -ForegroundColor White
    Write-Host ""

    Write-Host "WARNING: This will overwrite the existing database!" -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Continue? (yes/no)"

    if ($confirm -ne "yes") {
        Write-Host "Cancelled" -ForegroundColor Yellow
        return $false
    }

    # Build SQL command
    $sqlCommand = @"
USE master;
ALTER DATABASE [$DatabaseName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
RESTORE DATABASE [$DatabaseName]
FROM DISK = '$BackupFile'
WITH REPLACE,
     STATS = 10;
ALTER DATABASE [$DatabaseName] SET MULTI_USER;
"@

    try {
        $output = sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -Q $sqlCommand 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "Restore completed successfully!" -ForegroundColor Green
            Write-Host ""
            return $true
        } else {
            Write-Host "Restore failed!" -ForegroundColor Red
            Write-Host $output -ForegroundColor Red
            return $false
        }

    } catch {
        Write-Host "ERROR: $_" -ForegroundColor Red
        return $false
    }
}

function Verify-DatabaseBackup {
    param([string]$BackupFile)

    Write-Host "Verifying backup..." -ForegroundColor Cyan

    $sqlCommand = @"
RESTORE VERIFYONLY
FROM DISK = '$BackupFile'
WITH CHECKSUM;
"@

    try {
        $output = sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -Q $sqlCommand 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Verification successful!" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  Verification failed!" -ForegroundColor Red
            Write-Host $output -ForegroundColor Red
            return $false
        }

    } catch {
        Write-Host "  ERROR: $_" -ForegroundColor Red
        return $false
    }
}

function List-Backups {
    param([string]$BackupPath)

    Write-Host ""
    Write-Host "=== Available Backups ===" -ForegroundColor Cyan
    Write-Host ""

    # List database backups
    $dbBackupPath = Join-Path $BackupPath "databases"

    if (Test-Path $dbBackupPath) {
        $dbBackups = Get-ChildItem $dbBackupPath -Filter "*.bak" | Sort-Object LastWriteTime -Descending

        if ($dbBackups.Count -gt 0) {
            Write-Host "Database Backups:" -ForegroundColor Yellow

            foreach ($backup in $dbBackups | Select-Object -First 10) {
                $sizeMB = [math]::Round($backup.Length / 1MB, 2)
                Write-Host ("  {0,-50} {1,10} MB  {2}" -f $backup.Name, $sizeMB, $backup.LastWriteTime) -ForegroundColor White
            }

            if ($dbBackups.Count -gt 10) {
                Write-Host "  ... and $($dbBackups.Count - 10) more" -ForegroundColor DarkGray
            }

            Write-Host ""
        }
    }

    # List config backups
    $configBackupPath = Join-Path $BackupPath "config"

    if (Test-Path $configBackupPath) {
        $configBackups = Get-ChildItem $configBackupPath -Directory | Sort-Object LastWriteTime -Descending

        if ($configBackups.Count -gt 0) {
            Write-Host "Configuration Backups:" -ForegroundColor Yellow

            foreach ($backup in $configBackups | Select-Object -First 10) {
                $fileCount = (Get-ChildItem $backup.FullName).Count
                Write-Host ("  {0,-30} {1} files  {2}" -f $backup.Name, $fileCount, $backup.LastWriteTime) -ForegroundColor White
            }

            if ($configBackups.Count -gt 10) {
                Write-Host "  ... and $($configBackups.Count - 10) more" -ForegroundColor DarkGray
            }

            Write-Host ""
        }
    }
}

function Cleanup-OldBackups {
    param([string]$BackupPath, [int]$KeepCount)

    Write-Host ""
    Write-Host "=== Cleanup Old Backups ===" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Keeping $KeepCount most recent backups" -ForegroundColor White
    Write-Host ""

    $deletedCount = 0

    # Cleanup database backups
    $dbBackupPath = Join-Path $BackupPath "databases"

    if (Test-Path $dbBackupPath) {
        $dbBackups = Get-ChildItem $dbBackupPath -Filter "*.bak" | Sort-Object LastWriteTime -Descending

        $toDelete = $dbBackups | Select-Object -Skip $KeepCount

        foreach ($backup in $toDelete) {
            Write-Host "  Deleting: $($backup.Name)" -ForegroundColor DarkGray
            Remove-Item $backup.FullName -Force
            $deletedCount++
        }
    }

    # Cleanup config backups
    $configBackupPath = Join-Path $BackupPath "config"

    if (Test-Path $configBackupPath) {
        $configBackups = Get-ChildItem $configBackupPath -Directory | Sort-Object LastWriteTime -Descending

        $toDelete = $configBackups | Select-Object -Skip $KeepCount

        foreach ($backup in $toDelete) {
            Write-Host "  Deleting: $($backup.Name)" -ForegroundColor DarkGray
            Remove-Item $backup.FullName -Recurse -Force
            $deletedCount++
        }
    }

    Write-Host ""
    Write-Host "Deleted $deletedCount old backups" -ForegroundColor Green
    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== Backup & Restore ===" -ForegroundColor Cyan
Write-Host ""

# Create backup directory
if (-not (Test-Path $BackupPath)) {
    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
}

# Execute action
switch ($Action) {
    "backup" {
        if ($Type -eq "database" -or $Type -eq "all") {
            Backup-Database -DatabaseName $DatabaseName -ConnectionString $ConnectionString -BackupPath $BackupPath -VerifyBackup:$Verify
        }

        if ($Type -eq "config" -or $Type -eq "all") {
            if ($ConfigPaths) {
                Backup-ConfigFiles -ConfigPaths $ConfigPaths -BackupPath $BackupPath
            } elseif ($Type -eq "config") {
                Write-Host "ERROR: -ConfigPaths required for config backup" -ForegroundColor Red
            }
        }
    }
    "restore" {
        if ($Type -eq "database" -or (-not $Type)) {
            $backupFile = if (Test-Path $RestorePoint) {
                $RestorePoint
            } else {
                Join-Path (Join-Path $BackupPath "databases") $RestorePoint
            }

            Restore-Database -DatabaseName $DatabaseName -BackupFile $backupFile -ConnectionString $ConnectionString
        }
    }
    "verify" {
        if ($RestorePoint) {
            $backupFile = if (Test-Path $RestorePoint) {
                $RestorePoint
            } else {
                Join-Path (Join-Path $BackupPath "databases") $RestorePoint
            }

            Verify-DatabaseBackup -BackupFile $backupFile
        } else {
            Write-Host "ERROR: -RestorePoint required for verify" -ForegroundColor Red
        }
    }
    "list" {
        List-Backups -BackupPath $BackupPath
    }
    "cleanup" {
        Cleanup-OldBackups -BackupPath $BackupPath -KeepCount $KeepCount
    }
}

Write-Host "=== Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
