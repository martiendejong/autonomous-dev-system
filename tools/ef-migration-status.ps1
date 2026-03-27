#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick EF Core migration status check
.DESCRIPTION
    Checks EF Core migration state: pending migrations, applied migrations, and file integrity
.PARAMETER ProjectPath
    Path to the project containing DbContext (default: C:\Projects\client-manager\ClientManagerAPI)
.PARAMETER Detailed
    Show detailed information about each migration
.EXAMPLE
    .\ef-migration-status.ps1
.EXAMPLE
    .\ef-migration-status.ps1 -ProjectPath C:\Projects\client-manager\ClientManagerAPI -Detailed
#>

param(
    [string]$ProjectPath = "C:\Projects\client-manager\ClientManagerAPI",
    [switch]$Detailed
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


Write-Host "=== EF Core Migration Status ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectPath" -ForegroundColor Gray
Write-Host ""

# Check if project exists
if (-not (Test-Path $ProjectPath)) {
    Write-Host "❌ Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

Push-Location $ProjectPath

try {
    # Check if dotnet-ef tool is available
    $efTool = dotnet tool list --local | Select-String "dotnet-ef"
    if (-not $efTool) {
        Write-Host "⚠️  dotnet-ef tool not found. Running: dotnet tool restore" -ForegroundColor Yellow
        dotnet tool restore | Out-Null
    }

    # Get migration list
    Write-Host "📋 Migration Status:" -ForegroundColor Cyan
    $migrationOutput = dotnet ef migrations list --no-build 2>&1

    # Check for errors
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error checking migrations:" -ForegroundColor Red
        Write-Host $migrationOutput -ForegroundColor Red
        exit 1
    }

    # Parse output
    $applied = @()
    $pending = @()
    $inPendingSection = $false

    foreach ($line in $migrationOutput) {
        if ($line -match '^\s*(\d{14}_\w+)\s*$') {
            $migrationName = $matches[1]
            if ($inPendingSection) {
                $pending += $migrationName
            } else {
                $applied += $migrationName
            }
        } elseif ($line -match 'Pending') {
            $inPendingSection = $true
        }
    }

    # Display results
    Write-Host "  Applied: $($applied.Count)" -ForegroundColor Green
    Write-Host "  Pending: $($pending.Count)" -ForegroundColor $(if ($pending.Count -gt 0) { "Yellow" } else { "Green" })

    if ($Detailed -and $applied.Count -gt 0) {
        Write-Host ""
        Write-Host "📄 Applied Migrations:" -ForegroundColor Green
        foreach ($migration in $applied) {
            $file = Join-Path "Migrations" "$migration.cs"
            $exists = Test-Path $file
            $icon = if ($exists) { "✅" } else { "❌" }
            Write-Host "  $icon $migration" -ForegroundColor $(if ($exists) { "Gray" } else { "Red" })
        }
    }

    if ($pending.Count -gt 0) {
        Write-Host ""
        Write-Host "⏳ Pending Migrations:" -ForegroundColor Yellow
        foreach ($migration in $pending) {
            $file = Join-Path "Migrations" "$migration.cs"
            $exists = Test-Path $file
            $icon = if ($exists) { "✅" } else { "❌ MISSING FILE!" }
            Write-Host "  $icon $migration" -ForegroundColor $(if ($exists) { "Yellow" } else { "Red" })

            if (-not $exists) {
                Write-Host "     ⚠️  Migration registered but file missing - database state corrupted!" -ForegroundColor Red
            }
        }
    }

    # Check for model changes
    Write-Host ""
    Write-Host "🔍 Checking for pending model changes..." -ForegroundColor Cyan

    # This will fail if there are pending changes
    $checkResult = dotnet ef database update --no-build --dry-run 2>&1

    if ($checkResult -match "PendingModelChangesWarning") {
        Write-Host "⚠️  PENDING MODEL CHANGES DETECTED!" -ForegroundColor Red
        Write-Host "   Run: dotnet ef migrations add <MigrationName>" -ForegroundColor Yellow
    } else {
        Write-Host "✅ No pending model changes" -ForegroundColor Green
    }

    # Summary
    Write-Host ""
    Write-Host "=== Summary ===" -ForegroundColor Cyan
    if ($pending.Count -eq 0) {
        Write-Host "✅ Database is up to date" -ForegroundColor Green
    } else {
        Write-Host "⚠️  $($pending.Count) pending migration(s) - run 'dotnet ef database update'" -ForegroundColor Yellow
    }

} finally {
    Pop-Location
}
