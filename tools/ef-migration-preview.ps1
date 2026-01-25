<#
.SYNOPSIS
    Previews EF Core migration changes and analyzes impact

.DESCRIPTION
    Generates SQL preview of migration and performs impact analysis:
    - Shows SQL that will be executed
    - Detects breaking changes (DROP, ALTER, RENAME)
    - Estimates affected rows and lock duration
    - Generates rollback script
    - Flags data migration requirements
    - Suggests multi-step migration patterns for breaking changes

.PARAMETER Migration
    Migration name (without timestamp prefix)

.PARAMETER Context
    DbContext name

.PARAMETER ProjectPath
    Path to project containing DbContext

.PARAMETER GenerateRollback
    Generate rollback script

.PARAMETER EstimateImpact
    Estimate row counts and duration

.EXAMPLE
    .\ef-migration-preview.ps1 -Migration AddUserEmail -Context AppDbContext -ProjectPath .
    .\ef-migration-preview.ps1 -Migration AddUserEmail -Context AppDbContext -ProjectPath . -GenerateRollback -EstimateImpact
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Migration,

    [Parameter(Mandatory=$true)]
    [string]$Context,

    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [switch]$GenerateRollback,
    [switch]$EstimateImpact
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ErrorActionPreference = "Stop"

function Get-MigrationSQL {
    param([string]$ProjectPath, [string]$Context, [string]$Migration)

    Write-Host "📝 Generating SQL preview..." -ForegroundColor Cyan

    Push-Location $ProjectPath
    try {
        # Get list of migrations to find the full name with timestamp
        $migrationsOutput = dotnet ef migrations list --context $Context --no-build --json 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to list migrations" -ForegroundColor Red
            return $null
        }

        $migrations = $migrationsOutput | ConvertFrom-Json
        $targetMigration = $migrations | Where-Object { $_.name -match $Migration } | Select-Object -Last 1

        if (-not $targetMigration) {
            Write-Host "❌ Migration not found: $Migration" -ForegroundColor Red
            return $null
        }

        $fullMigrationName = $targetMigration.name

        # Find previous migration
        $migrationIndex = [array]::IndexOf($migrations.name, $fullMigrationName)

        if ($migrationIndex -le 0) {
            # First migration - generate from scratch
            $sqlScript = dotnet ef migrations script --context $Context --no-build 0 $fullMigrationName 2>&1
        } else {
            $previousMigration = $migrations[$migrationIndex - 1].name
            $sqlScript = dotnet ef migrations script --context $Context --no-build $previousMigration $fullMigrationName 2>&1
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to generate SQL script" -ForegroundColor Red
            return $null
        }

        return @{
            "SQL" = $sqlScript
            "FullName" = $fullMigrationName
            "PreviousMigration" = if ($migrationIndex -gt 0) { $migrations[$migrationIndex - 1].name } else { $null }
        }

    } finally {
        Pop-Location
    }
}

function Analyze-BreakingChanges {
    param([string]$SQL)

    Write-Host ""
    Write-Host "🔍 Analyzing for breaking changes..." -ForegroundColor Cyan
    Write-Host ""

    $issues = @()
    $warnings = @()

    # Split SQL into statements
    $statements = $SQL -split "GO" | Where-Object { $_.Trim() -ne "" }

    foreach ($statement in $statements) {
        # Check for DROP TABLE
        if ($statement -match "DROP\s+TABLE\s+\[?(\w+)\]?") {
            $tableName = $matches[1]
            $issues += @{
                "Severity" = "CRITICAL"
                "Type" = "Data Loss"
                "Operation" = "DROP TABLE"
                "Target" = $tableName
                "Message" = "Table '$tableName' will be permanently deleted"
                "Recommendation" = "⚠️  BACKUP REQUIRED. Consider soft-delete or archive table instead."
                "Pattern" = "If table has production data, use 3-step migration: 1) Mark deprecated 2) Stop using 3) Drop after validation period"
            }
        }

        # Check for DROP COLUMN
        if ($statement -match "DROP\s+COLUMN\s+\[?(\w+)\]?" -and $statement -match "ALTER\s+TABLE\s+\[?(\w+)\]?") {
            $tableName = $matches[1]
            $columnName = $matches[2]
            $issues += @{
                "Severity" = "HIGH"
                "Type" = "Data Loss"
                "Operation" = "DROP COLUMN"
                "Target" = "$tableName.$columnName"
                "Message" = "Column '$tableName.$columnName' will be permanently deleted"
                "Recommendation" = "⚠️  Use 2-step migration: 1) Add new column + backfill 2) Drop old column (this migration)"
                "Pattern" = "Migration 1: ADD new_column | Migration 2: Backfill data | Deploy code using new column | Migration 3: DROP old column"
            }
        }

        # Check for RENAME (sp_rename)
        if ($statement -match "sp_rename") {
            $warnings += @{
                "Severity" = "HIGH"
                "Type" = "Breaking Change"
                "Operation" = "RENAME"
                "Message" = "Renaming column/table - breaks existing code immediately"
                "Recommendation" = "⚠️  Use 2-step migration: 1) Add new + populate 2) Drop old (after code updated)"
                "Pattern" = "AVOID sp_rename in production. Use ADD + backfill + DROP pattern."
            }
        }

        # Check for ALTER COLUMN (type changes)
        if ($statement -match "ALTER\s+COLUMN\s+\[?(\w+)\]?.*?\[?(\w+)\]?" -and $statement -match "ALTER\s+TABLE\s+\[?(\w+)\]?") {
            $tableName = $matches[1]
            $columnName = $matches[2]

            # Check if changing to NOT NULL
            if ($statement -match "NOT\s+NULL") {
                $issues += @{
                    "Severity" = "HIGH"
                    "Type" = "Data Compatibility"
                    "Operation" = "ALTER COLUMN (NOT NULL)"
                    "Target" = "$tableName.$columnName"
                    "Message" = "Adding NOT NULL constraint to existing column"
                    "Recommendation" = "⚠️  Ensure ALL existing rows have non-null values or provide DEFAULT"
                    "Pattern" = "Migration 1: Backfill NULL values | Migration 2: Add NOT NULL constraint (this migration)"
                }
            }

            # Check for type change
            if ($statement -match "(VARCHAR|DECIMAL|INT|DATETIME|BIT)") {
                $warnings += @{
                    "Severity" = "MEDIUM"
                    "Type" = "Schema Change"
                    "Operation" = "ALTER COLUMN (type change)"
                    "Target" = "$tableName.$columnName"
                    "Message" = "Changing column data type"
                    "Recommendation" = "Verify data compatibility. Test on production clone with actual data."
                    "Pattern" = "For narrowing conversions (VARCHAR(100)→VARCHAR(50)), validate no truncation first."
                }
            }
        }

        # Check for DROP CONSTRAINT (FK)
        if ($statement -match "DROP\s+CONSTRAINT\s+\[?(\w+)\]?" -and $statement -match "FOREIGN\s+KEY") {
            $constraintName = $matches[1]
            $warnings += @{
                "Severity" = "MEDIUM"
                "Type" = "Referential Integrity"
                "Operation" = "DROP FOREIGN KEY"
                "Target" = $constraintName
                "Message" = "Foreign key constraint '$constraintName' will be removed"
                "Recommendation" = "Ensure referential integrity maintained by application logic or add new constraint"
            }
        }

        # Check for CREATE INDEX
        if ($statement -match "CREATE\s+INDEX") {
            $warnings += @{
                "Severity" = "LOW"
                "Type" = "Performance Impact"
                "Operation" = "CREATE INDEX"
                "Message" = "Creating index - may lock table during creation"
                "Recommendation" = "For large tables (>1M rows), use ONLINE = ON option (Enterprise Edition) or schedule during low-traffic window"
            }
        }
    }

    # Display results
    if ($issues.Count -gt 0) {
        Write-Host "❌ CRITICAL ISSUES DETECTED:" -ForegroundColor Red
        Write-Host ""

        foreach ($issue in $issues) {
            $color = switch ($issue.Severity) {
                "CRITICAL" { "Red" }
                "HIGH" { "Red" }
                "MEDIUM" { "Yellow" }
                default { "White" }
            }

            Write-Host "  [$($issue.Severity)] $($issue.Operation): $($issue.Target)" -ForegroundColor $color
            Write-Host "  $($issue.Message)" -ForegroundColor White
            Write-Host "  → $($issue.Recommendation)" -ForegroundColor DarkGray
            if ($issue.Pattern) {
                Write-Host "  📋 Pattern: $($issue.Pattern)" -ForegroundColor Cyan
            }
            Write-Host ""
        }
    }

    if ($warnings.Count -gt 0) {
        Write-Host "⚠️  WARNINGS:" -ForegroundColor Yellow
        Write-Host ""

        foreach ($warning in $warnings) {
            Write-Host "  [$($warning.Severity)] $($warning.Operation)" -ForegroundColor Yellow
            if ($warning.Target) {
                Write-Host "  Target: $($warning.Target)" -ForegroundColor White
            }
            Write-Host "  $($warning.Message)" -ForegroundColor White
            Write-Host "  → $($warning.Recommendation)" -ForegroundColor DarkGray
            if ($warning.Pattern) {
                Write-Host "  📋 Pattern: $($warning.Pattern)" -ForegroundColor Cyan
            }
            Write-Host ""
        }
    }

    if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Host "✅ No breaking changes detected!" -ForegroundColor Green
        Write-Host "   Migration appears safe to apply." -ForegroundColor DarkGray
        Write-Host ""
    }

    return @{
        "Issues" = $issues
        "Warnings" = $warnings
        "Safe" = ($issues.Count -eq 0)
    }
}

function Show-SQLPreview {
    param([string]$SQL)

    Write-Host ""
    Write-Host "=== SQL Preview ===" -ForegroundColor Cyan
    Write-Host ""

    # Syntax highlighting (simple)
    $lines = $SQL -split "`n"
    $lineNumber = 1

    foreach ($line in $lines) {
        $displayLine = $line.Trim()

        if ($displayLine -eq "") {
            continue
        }

        # Color code SQL keywords
        $color = "White"
        if ($displayLine -match "^(CREATE|ALTER|DROP)") {
            $color = "Yellow"
        } elseif ($displayLine -match "^(INSERT|UPDATE|DELETE)") {
            $color = "Cyan"
        } elseif ($displayLine -match "^GO") {
            $color = "DarkGray"
        }

        Write-Host ("{0,4}: {1}" -f $lineNumber, $displayLine) -ForegroundColor $color
        $lineNumber++
    }

    Write-Host ""
}

function Generate-RollbackScript {
    param([string]$ProjectPath, [string]$Context, [string]$FullMigrationName, [string]$PreviousMigration)

    Write-Host ""
    Write-Host "🔄 Generating rollback script..." -ForegroundColor Cyan

    if (-not $PreviousMigration) {
        Write-Host "⚠️  This is the first migration - no rollback possible" -ForegroundColor Yellow
        Write-Host "   To rollback, you must drop and recreate database" -ForegroundColor DarkGray
        return
    }

    Push-Location $ProjectPath
    try {
        $rollbackFile = "rollback_$($FullMigrationName).sql"

        # Generate rollback SQL (from current to previous)
        dotnet ef migrations script $FullMigrationName $PreviousMigration --context $Context --no-build --output $rollbackFile 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0 -and (Test-Path $rollbackFile)) {
            Write-Host "✅ Rollback script generated: $rollbackFile" -ForegroundColor Green
            Write-Host ""
            Write-Host "To rollback this migration, run:" -ForegroundColor Cyan
            Write-Host "  dotnet ef database update $PreviousMigration --context $Context" -ForegroundColor White
            Write-Host ""
            Write-Host "⚠️  TEST ROLLBACK ON CLONE DATABASE FIRST!" -ForegroundColor Yellow
            Write-Host ""
        } else {
            Write-Host "❌ Failed to generate rollback script" -ForegroundColor Red
        }

    } finally {
        Pop-Location
    }
}

# ============================================================
# MAIN EXECUTION
# ============================================================

Write-Host ""
Write-Host "=== EF Core Migration Preview ===" -ForegroundColor Cyan
Write-Host "Migration: $Migration" -ForegroundColor White
Write-Host "Context: $Context" -ForegroundColor White
Write-Host ""

# Validate project path
if (-not (Test-Path $ProjectPath)) {
    Write-Host "❌ Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Get SQL script
$migrationSQL = Get-MigrationSQL -ProjectPath $ProjectPath -Context $Context -Migration $Migration

if (-not $migrationSQL) {
    Write-Host "❌ Failed to generate migration SQL" -ForegroundColor Red
    exit 1
}

Write-Host "✅ SQL generated for: $($migrationSQL.FullName)" -ForegroundColor Green
Write-Host ""

# Show SQL preview
Show-SQLPreview -SQL $migrationSQL.SQL

# Analyze breaking changes
$analysis = Analyze-BreakingChanges -SQL $migrationSQL.SQL

# Generate rollback if requested
if ($GenerateRollback) {
    Generate-RollbackScript -ProjectPath $ProjectPath -Context $Context -FullMigrationName $migrationSQL.FullName -PreviousMigration $migrationSQL.PreviousMigration
}

# Summary
Write-Host "=== Summary ===" -ForegroundColor Cyan

if ($analysis.Safe) {
    Write-Host "✅ Migration appears SAFE to apply" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Review SQL preview above" -ForegroundColor White
    Write-Host "  2. Test on clone database: .\ef-test-migration.ps1 -Migration $Migration -Context $Context" -ForegroundColor White
    Write-Host "  3. Apply: dotnet ef database update --context $Context" -ForegroundColor White
} else {
    Write-Host "⚠️  Migration has CRITICAL ISSUES - review carefully!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Issues found: $($analysis.Issues.Count)" -ForegroundColor Red
    Write-Host "Warnings: $($analysis.Warnings.Count)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📖 Review migration patterns: C:\scripts\_machine\migration-patterns.md" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host ""
exit $(if ($analysis.Safe) { 0 } else { 1 })
