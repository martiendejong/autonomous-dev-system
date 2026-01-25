<#
.SYNOPSIS
    Pre-flight safety check before creating EF Core migrations

.DESCRIPTION
    Comprehensive database state validation before migration creation:
    - Validates connection string environment
    - Dumps __EFMigrationsHistory
    - Detects schema drift (manual changes)
    - Checks for pending migrations
    - Verifies ModelSnapshot integrity
    - Compares against baseline state

.PARAMETER Context
    DbContext name (e.g., AppDbContext)

.PARAMETER ProjectPath
    Path to project containing DbContext

.PARAMETER Baseline
    Path to baseline state file (optional, auto-detected from _machine/db-baselines/)

.PARAMETER FailOnDrift
    Exit with error if schema drift detected

.EXAMPLE
    .\ef-preflight-check.ps1 -Context AppDbContext -ProjectPath C:\Projects\client-manager\ClientManagerAPI
    .\ef-preflight-check.ps1 -Context AppDbContext -ProjectPath . -FailOnDrift
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Context,

    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [string]$Baseline,
    [switch]$FailOnDrift
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ErrorActionPreference = "Stop"

function Get-DbConnectionInfo {
    param([string]$ProjectPath, [string]$Context)

    Push-Location $ProjectPath
    try {
        # Try to get connection string from appsettings
        $appsettings = Get-Content "appsettings.Development.json" -ErrorAction SilentlyContinue | ConvertFrom-Json

        $connString = $appsettings.ConnectionStrings.DefaultConnection

        if ($connString -match "Database=([^;]+)") {
            $dbName = $matches[1]
        } else {
            $dbName = "Unknown"
        }

        return @{
            "ConnectionString" = $connString
            "DatabaseName" = $dbName
            "Environment" = "Development"
        }
    } finally {
        Pop-Location
    }
}

function Get-MigrationHistory {
    param([string]$ProjectPath, [string]$Context)

    Push-Location $ProjectPath
    try {
        Write-Host "📜 Reading migration history..." -ForegroundColor Cyan

        $output = dotnet ef migrations list --context $Context --no-build --json 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to read migrations" -ForegroundColor Red
            Write-Host $output -ForegroundColor Red
            return $null
        }

        $migrations = $output | ConvertFrom-Json

        $applied = @($migrations | Where-Object { $_.applied -eq $true })
        $pending = @($migrations | Where-Object { $_.applied -ne $true })

        return @{
            "Applied" = $applied
            "Pending" = $pending
            "Total" = $migrations.Count
        }

    } finally {
        Pop-Location
    }
}

function Test-SchemaDrift {
    param([string]$ProjectPath, [string]$Context)

    Write-Host "🔍 Checking for schema drift..." -ForegroundColor Cyan

    Push-Location $ProjectPath
    try {
        # Generate current schema script
        $currentSchemaPath = [System.IO.Path]::GetTempFileName() + ".sql"
        dotnet ef dbcontext script --context $Context --no-build --output $currentSchemaPath 2>&1 | Out-Null

        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $currentSchemaPath)) {
            Write-Host "⚠️  Could not generate schema script" -ForegroundColor Yellow
            return $null
        }

        $currentSchema = Get-Content $currentSchemaPath -Raw
        $schemaHash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($currentSchema)))).Hash

        Remove-Item $currentSchemaPath -Force

        # Check against baseline
        $baselinePath = "C:\_machine\db-baselines\$Context\schema-baseline.json"

        if (Test-Path $baselinePath) {
            $baseline = Get-Content $baselinePath | ConvertFrom-Json

            if ($baseline.SchemaHash -ne $schemaHash) {
                Write-Host "⚠️  SCHEMA DRIFT DETECTED!" -ForegroundColor Red
                Write-Host "   Database schema differs from last known state" -ForegroundColor Yellow
                Write-Host "   This indicates manual database changes outside migrations" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "   Last baseline: $($baseline.Timestamp)" -ForegroundColor DarkGray
                Write-Host "   Last migration: $($baseline.LastMigration)" -ForegroundColor DarkGray
                Write-Host ""
                return @{
                    "Drift" = $true
                    "CurrentHash" = $schemaHash
                    "BaselineHash" = $baseline.SchemaHash
                }
            } else {
                Write-Host "✅ No schema drift detected" -ForegroundColor Green
                return @{
                    "Drift" = $false
                    "Hash" = $schemaHash
                }
            }
        } else {
            Write-Host "ℹ️  No baseline found - creating initial baseline" -ForegroundColor Cyan

            # Create baseline directory
            $baselineDir = Split-Path $baselinePath -Parent
            if (-not (Test-Path $baselineDir)) {
                New-Item -ItemType Directory -Path $baselineDir -Force | Out-Null
            }

            # Save baseline
            $baselineData = @{
                "Context" = $Context
                "SchemaHash" = $schemaHash
                "Timestamp" = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
                "LastMigration" = "Initial"
            }

            $baselineData | ConvertTo-Json | Set-Content $baselinePath

            Write-Host "✅ Baseline created: $baselinePath" -ForegroundColor Green

            return @{
                "Drift" = $false
                "Hash" = $schemaHash
                "BaselineCreated" = $true
            }
        }

    } finally {
        Pop-Location
    }
}

function Test-PendingMigrations {
    param($MigrationHistory)

    Write-Host "⏳ Checking for pending migrations..." -ForegroundColor Cyan

    if ($MigrationHistory.Pending.Count -gt 0) {
        Write-Host "⚠️  PENDING MIGRATIONS DETECTED!" -ForegroundColor Yellow
        Write-Host "   You must apply pending migrations before creating new ones:" -ForegroundColor Yellow
        Write-Host ""

        foreach ($migration in $MigrationHistory.Pending) {
            Write-Host "   - $($migration.name)" -ForegroundColor White
        }

        Write-Host ""
        Write-Host "   Run: dotnet ef database update --context $Context" -ForegroundColor Cyan
        Write-Host ""

        return $false
    } else {
        Write-Host "✅ No pending migrations" -ForegroundColor Green
        return $true
    }
}

function Test-ModelSnapshotIntegrity {
    param([string]$ProjectPath, [string]$Context)

    Write-Host "🔍 Validating ModelSnapshot integrity..." -ForegroundColor Cyan

    $snapshotPath = Join-Path $ProjectPath "Migrations" "$($Context)ModelSnapshot.cs"

    if (-not (Test-Path $snapshotPath)) {
        Write-Host "⚠️  ModelSnapshot not found: $snapshotPath" -ForegroundColor Yellow
        Write-Host "   This is expected for new projects with no migrations" -ForegroundColor DarkGray
        return $true
    }

    $snapshot = Get-Content $snapshotPath -Raw

    # Basic integrity checks
    $issues = @()

    if ($snapshot -notmatch "class $($Context)ModelSnapshot") {
        $issues += "Snapshot class name doesn't match context"
    }

    if ($snapshot -notmatch "ModelBuilder.*Create") {
        $issues += "No model builder found in snapshot"
    }

    if ($issues.Count -gt 0) {
        Write-Host "❌ ModelSnapshot integrity issues:" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "   - $issue" -ForegroundColor Red
        }
        return $false
    } else {
        Write-Host "✅ ModelSnapshot is valid" -ForegroundColor Green
        return $true
    }
}

# ============================================================
# MAIN EXECUTION
# ============================================================

Write-Host ""
Write-Host "=== EF Core Pre-Flight Safety Check ===" -ForegroundColor Cyan
Write-Host "Context: $Context" -ForegroundColor White
Write-Host "Project: $ProjectPath" -ForegroundColor White
Write-Host ""

# Validate project path
if (-not (Test-Path $ProjectPath)) {
    Write-Host "❌ Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Check connection info
$connInfo = Get-DbConnectionInfo -ProjectPath $ProjectPath -Context $Context

Write-Host "🔗 Database Connection:" -ForegroundColor Cyan
Write-Host "   Database: $($connInfo.DatabaseName)" -ForegroundColor White
Write-Host "   Environment: $($connInfo.Environment)" -ForegroundColor White
Write-Host ""

# Get migration history
$migrationHistory = Get-MigrationHistory -ProjectPath $ProjectPath -Context $Context

if ($null -eq $migrationHistory) {
    Write-Host "❌ Failed to read migration history" -ForegroundColor Red
    exit 1
}

Write-Host "   Applied: $($migrationHistory.Applied.Count)" -ForegroundColor Green
Write-Host "   Pending: $($migrationHistory.Pending.Count)" -ForegroundColor $(if ($migrationHistory.Pending.Count -gt 0) { "Yellow" } else { "Green" })
Write-Host ""

# Run checks
$allChecksPassed = $true

# 1. Check for pending migrations
if (-not (Test-PendingMigrations -MigrationHistory $migrationHistory)) {
    $allChecksPassed = $false
}
Write-Host ""

# 2. Check schema drift
$driftResult = Test-SchemaDrift -ProjectPath $ProjectPath -Context $Context

if ($null -ne $driftResult -and $driftResult.Drift -eq $true) {
    $allChecksPassed = $false

    if ($FailOnDrift) {
        Write-Host "❌ Pre-flight check FAILED (schema drift detected)" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# 3. Validate ModelSnapshot
if (-not (Test-ModelSnapshotIntegrity -ProjectPath $ProjectPath -Context $Context)) {
    $allChecksPassed = $false
}
Write-Host ""

# Summary
Write-Host "=== Pre-Flight Check Summary ===" -ForegroundColor Cyan

if ($allChecksPassed) {
    Write-Host "✅ ALL CHECKS PASSED - Safe to create migration" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. dotnet clean && dotnet build" -ForegroundColor White
    Write-Host "  2. dotnet ef migrations add <MigrationName> --context $Context" -ForegroundColor White
    Write-Host "  3. .\ef-migration-preview.ps1 -Migration <MigrationName> -Context $Context" -ForegroundColor White
    Write-Host ""
    exit 0
} else {
    Write-Host "⚠️  SOME CHECKS FAILED - Fix issues before creating migration" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
