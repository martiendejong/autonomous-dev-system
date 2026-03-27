#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Safe database reset with automatic backup
.DESCRIPTION
    Resets SQLite database and applies all migrations from scratch.
    Automatically backs up existing database before deletion.
.PARAMETER DatabasePath
    Path to SQLite database file (default: c:\stores\brand2boost\identity.db)
.PARAMETER ProjectPath
    Path to project with migrations (default: C:\Projects\client-manager\ClientManagerAPI)
.PARAMETER SkipBackup
    Skip backup creation (USE WITH CAUTION)
.PARAMETER NoMigrate
    Only delete database, don't apply migrations
.EXAMPLE
    .\db-reset.ps1
.EXAMPLE
    .\db-reset.ps1 -DatabasePath c:\stores\test\test.db -ProjectPath C:\Projects\test-api
.EXAMPLE
    .\db-reset.ps1 -SkipBackup -NoMigrate
#>

param(
    [string]$DatabasePath = "c:\stores\brand2boost\identity.db",
    [string]$ProjectPath = "C:\Projects\client-manager\ClientManagerAPI",
    [switch]$SkipBackup,
    [switch]$NoMigrate
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


Write-Host "=== Database Reset Tool ===" -ForegroundColor Cyan
Write-Host "Database: $DatabasePath" -ForegroundColor Gray
Write-Host "Project:  $ProjectPath" -ForegroundColor Gray
Write-Host ""

# Check if database exists
if (-not (Test-Path $DatabasePath)) {
    Write-Host "ℹ️  Database not found: $DatabasePath" -ForegroundColor Yellow
    Write-Host "   Creating new database..." -ForegroundColor Gray
} else {
    $dbSize = (Get-Item $DatabasePath).Length / 1MB
    Write-Host "📊 Current database: $([math]::Round($dbSize, 2)) MB" -ForegroundColor Cyan

    # Create backup
    if (-not $SkipBackup) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = "$DatabasePath.backup.$timestamp"

        Write-Host "💾 Creating backup..." -ForegroundColor Cyan
        Copy-Item -Path $DatabasePath -Destination $backupPath -Force

        if (Test-Path $backupPath) {
            Write-Host "   ✅ Backup created: $backupPath" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Backup failed!" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "⚠️  Skipping backup (as requested)" -ForegroundColor Yellow
    }

    # Confirm deletion
    Write-Host ""
    Write-Host "⚠️  WARNING: About to delete database!" -ForegroundColor Yellow
    if (-not $SkipBackup) {
        Write-Host "   Backup available at: $backupPath" -ForegroundColor Gray
    }

    $confirm = Read-Host "   Continue? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Host "❌ Aborted by user" -ForegroundColor Red
        exit 1
    }

    # Delete database and related files
    Write-Host ""
    Write-Host "🗑️  Deleting database files..." -ForegroundColor Cyan

    Remove-Item -Path $DatabasePath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$DatabasePath-shm" -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$DatabasePath-wal" -Force -ErrorAction SilentlyContinue

    if (Test-Path $DatabasePath) {
        Write-Host "   ❌ Failed to delete database" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "   ✅ Database deleted" -ForegroundColor Green
    }
}

# Apply migrations
if (-not $NoMigrate) {
    Write-Host ""
    Write-Host "🔄 Applying migrations..." -ForegroundColor Cyan

    Push-Location $ProjectPath

    try {
        # Ensure dotnet-ef tool is available
        $efTool = dotnet tool list --local | Select-String "dotnet-ef"
        if (-not $efTool) {
            Write-Host "   Installing dotnet-ef tool..." -ForegroundColor Gray
            dotnet tool restore | Out-Null
        }

        # Apply migrations
        $result = dotnet ef database update --no-build 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ Migrations applied successfully" -ForegroundColor Green

            # Show new database size
            if (Test-Path $DatabasePath) {
                $newSize = (Get-Item $DatabasePath).Length / 1MB
                Write-Host "   📊 New database: $([math]::Round($newSize, 2)) MB" -ForegroundColor Cyan
            }
        } else {
            Write-Host "   ❌ Migration failed!" -ForegroundColor Red
            Write-Host $result -ForegroundColor Red

            # Restore backup if available
            if (-not $SkipBackup -and (Test-Path $backupPath)) {
                Write-Host ""
                Write-Host "🔄 Restoring from backup..." -ForegroundColor Yellow
                Copy-Item -Path $backupPath -Destination $DatabasePath -Force
                Write-Host "   ✅ Database restored from backup" -ForegroundColor Green
            }

            exit 1
        }
    } finally {
        Pop-Location
    }
}

# Summary
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "✅ Database reset complete" -ForegroundColor Green

if (-not $SkipBackup -and (Test-Path $backupPath)) {
    Write-Host "💾 Backup: $backupPath" -ForegroundColor Cyan
    Write-Host "   To restore: Copy-Item '$backupPath' '$DatabasePath' -Force" -ForegroundColor Gray
}

if (-not $NoMigrate) {
    Write-Host "🔄 All migrations applied to fresh database" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎉 Ready to use!" -ForegroundColor Green
