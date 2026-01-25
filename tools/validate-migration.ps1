<#
.SYNOPSIS
    Validates Entity Framework Core migrations before applying to database.

.DESCRIPTION
    Analyzes EF Core migrations for potential issues, breaking changes, and data loss.
    Generates rollback scripts and validates against development database.

    Features:
    - Detects breaking changes (column drops, renames, data loss)
    - Generates rollback scripts automatically
    - Tests migrations against development database
    - Validates migration naming conventions
    - Checks for pending migrations
    - SQL script generation and review

.PARAMETER ProjectPath
    Path to project containing DbContext (.csproj)

.PARAMETER MigrationName
    Specific migration to validate (optional, validates latest if not specified)

.PARAMETER ConnectionString
    Database connection string for validation (optional, uses appsettings.Development.json)

.PARAMETER GenerateRollback
    Generate rollback script for migration

.PARAMETER TestApply
    Test applying migration to development database

.PARAMETER DryRun
    Show what would happen without making changes

.EXAMPLE
    .\validate-migration.ps1 -ProjectPath "C:\Projects\client-manager\ClientManagerApi"
    .\validate-migration.ps1 -ProjectPath "." -MigrationName "AddUserTable" -GenerateRollback
    .\validate-migration.ps1 -ProjectPath "." -TestApply -DryRun
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [string]$MigrationName,
    [string]$ConnectionString,
    [switch]$GenerateRollback,
    [switch]$TestApply,
    [switch]$DryRun
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Get-Migrations {
    param([string]$ProjectPath)

    Push-Location $ProjectPath
    try {
        $output = dotnet ef migrations list --json 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to list migrations" -ForegroundColor Red
            Write-Host "Make sure Entity Framework tools are installed:" -ForegroundColor Yellow
            Write-Host "  dotnet tool install --global dotnet-ef" -ForegroundColor DarkGray
            return @()
        }

        try {
            $migrations = $output | ConvertFrom-Json
            return $migrations
        } catch {
            return @()
        }

    } finally {
        Pop-Location
    }
}

function Get-MigrationFile {
    param([string]$ProjectPath, [string]$MigrationName)

    $migrationsPath = Join-Path $ProjectPath "Migrations"

    if (-not (Test-Path $migrationsPath)) {
        return $null
    }

    $migrationFile = Get-ChildItem $migrationsPath -Filter "*_$MigrationName.cs" | Select-Object -First 1

    return $migrationFile
}

function Analyze-Migration {
    param([string]$MigrationFilePath)

    Write-Host ""
    Write-Host "=== Migration Analysis ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $MigrationFilePath)) {
        Write-Host "ERROR: Migration file not found" -ForegroundColor Red
        return
    }

    $content = Get-Content $MigrationFilePath -Raw

    $issues = @()
    $warnings = @()

    # Check for DROP COLUMN
    if ($content -match 'DropColumn') {
        $issues += @{
            "Severity" = "HIGH"
            "Type" = "Data Loss"
            "Message" = "Migration drops columns - potential data loss"
            "Recommendation" = "Ensure data is backed up or migrated before applying"
        }
    }

    # Check for DROP TABLE
    if ($content -match 'DropTable') {
        $issues += @{
            "Severity" = "CRITICAL"
            "Type" = "Data Loss"
            "Message" = "Migration drops tables - data will be permanently lost"
            "Recommendation" = "Create backup before applying. Consider soft delete instead."
        }
    }

    # Check for RENAME COLUMN
    if ($content -match 'RenameColumn') {
        $warnings += @{
            "Severity" = "MEDIUM"
            "Type" = "Breaking Change"
            "Message" = "Migration renames columns - may break existing code"
            "Recommendation" = "Update all code references before deploying"
        }
    }

    # Check for ALTER COLUMN (type changes)
    if ($content -match 'AlterColumn') {
        $warnings += @{
            "Severity" = "MEDIUM"
            "Type" = "Schema Change"
            "Message" = "Migration alters column definitions"
            "Recommendation" = "Verify data compatibility with new column type"
        }
    }

    # Check for FOREIGN KEY drops
    if ($content -match 'DropForeignKey') {
        $warnings += @{
            "Severity" = "MEDIUM"
            "Type" = "Referential Integrity"
            "Message" = "Migration drops foreign keys"
            "Recommendation" = "Ensure referential integrity is maintained"
        }
    }

    # Check for NOT NULL constraints on existing columns
    if ($content -match 'nullable:\s*false' -and $content -match 'AlterColumn') {
        $issues += @{
            "Severity" = "HIGH"
            "Type" = "Data Compatibility"
            "Message" = "Adding NOT NULL constraint to existing column"
            "Recommendation" = "Ensure all existing rows have non-null values or provide default"
        }
    }

    # Display results
    if ($issues.Count -gt 0) {
        Write-Host "ISSUES FOUND:" -ForegroundColor Red
        Write-Host ""

        foreach ($issue in $issues) {
            $color = switch ($issue.Severity) {
                "CRITICAL" { "Red" }
                "HIGH" { "Red" }
                "MEDIUM" { "Yellow" }
                default { "White" }
            }

            Write-Host ("  [{0}] {1}: {2}" -f $issue.Severity, $issue.Type, $issue.Message) -ForegroundColor $color
            Write-Host ("    -> {0}" -f $issue.Recommendation) -ForegroundColor DarkGray
            Write-Host ""
        }
    }

    if ($warnings.Count -gt 0) {
        Write-Host "WARNINGS:" -ForegroundColor Yellow
        Write-Host ""

        foreach ($warning in $warnings) {
            Write-Host ("  [{0}] {1}: {2}" -f $warning.Severity, $warning.Type, $warning.Message) -ForegroundColor Yellow
            Write-Host ("    -> {0}" -f $warning.Recommendation) -ForegroundColor DarkGray
            Write-Host ""
        }
    }

    if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
        Write-Host "No issues detected!" -ForegroundColor Green
        Write-Host "Migration appears safe to apply." -ForegroundColor DarkGray
        Write-Host ""
    }

    return @{
        "Issues" = $issues
        "Warnings" = $warnings
    }
}

function Generate-RollbackScript {
    param([string]$ProjectPath, [string]$MigrationName)

    Write-Host ""
    Write-Host "=== Generating Rollback Script ===" -ForegroundColor Cyan
    Write-Host ""

    Push-Location $ProjectPath
    try {
        # Get previous migration
        $migrations = Get-Migrations -ProjectPath $ProjectPath
        $currentIndex = 0

        for ($i = 0; $i -lt $migrations.Count; $i++) {
            if ($migrations[$i].name -eq $MigrationName) {
                $currentIndex = $i
                break
            }
        }

        if ($currentIndex -eq 0) {
            Write-Host "This is the first migration, cannot generate rollback" -ForegroundColor Yellow
            return
        }

        $previousMigration = $migrations[$currentIndex - 1].name

        # Generate rollback SQL script
        $rollbackPath = "rollback_$MigrationName.sql"

        dotnet ef migrations script $MigrationName $previousMigration --output $rollbackPath 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0 -and (Test-Path $rollbackPath)) {
            Write-Host "Rollback script generated: $rollbackPath" -ForegroundColor Green
            Write-Host ""
            Write-Host "To rollback, run:" -ForegroundColor Cyan
            Write-Host "  dotnet ef database update $previousMigration" -ForegroundColor White
            Write-Host ""
        } else {
            Write-Host "Failed to generate rollback script" -ForegroundColor Red
        }

    } finally {
        Pop-Location
    }
}

function Test-MigrationApply {
    param([string]$ProjectPath, [string]$MigrationName, [bool]$DryRunMode)

    Write-Host ""
    Write-Host "=== Testing Migration Apply ===" -ForegroundColor Cyan
    Write-Host ""

    if ($DryRunMode) {
        Write-Host "[DRY RUN] Would apply migration: $MigrationName" -ForegroundColor Cyan
        Write-Host ""
        return
    }

    Write-Host "WARNING: This will apply migration to the database!" -ForegroundColor Yellow
    Write-Host "Make sure you're using a development/test database." -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Continue? (yes/no)"

    if ($confirm -ne "yes") {
        Write-Host "Cancelled" -ForegroundColor Yellow
        return
    }

    Push-Location $ProjectPath
    try {
        if ($MigrationName) {
            dotnet ef database update $MigrationName
        } else {
            dotnet ef database update
        }

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "Migration applied successfully!" -ForegroundColor Green
            Write-Host ""
        } else {
            Write-Host ""
            Write-Host "Migration failed!" -ForegroundColor Red
            Write-Host ""
        }

    } finally {
        Pop-Location
    }
}

function Show-PendingMigrations {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Pending Migrations ===" -ForegroundColor Cyan
    Write-Host ""

    Push-Location $ProjectPath
    try {
        $output = dotnet ef migrations list 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "Failed to check migrations" -ForegroundColor Red
            return
        }

        $lines = $output -split "`n"
        $pendingFound = $false

        foreach ($line in $lines) {
            if ($line -match '^\s*\d+_') {
                if ($line -notmatch '\(Pending\)') {
                    continue
                }

                if (-not $pendingFound) {
                    Write-Host "Pending migrations:" -ForegroundColor Yellow
                    $pendingFound = $true
                }

                Write-Host "  $line" -ForegroundColor White
            }
        }

        if (-not $pendingFound) {
            Write-Host "No pending migrations" -ForegroundColor Green
        }

        Write-Host ""

    } finally {
        Pop-Location
    }
}

function Validate-NamingConvention {
    param([string]$MigrationName)

    Write-Host ""
    Write-Host "=== Naming Convention Check ===" -ForegroundColor Cyan
    Write-Host ""

    $valid = $true

    # Check PascalCase
    if ($MigrationName -notmatch '^[A-Z][a-zA-Z0-9]*$') {
        Write-Host "WARNING: Migration name should be PascalCase" -ForegroundColor Yellow
        Write-Host "  Current: $MigrationName" -ForegroundColor White
        Write-Host "  Example: AddUserEmailColumn" -ForegroundColor DarkGray
        $valid = $false
    }

    # Check descriptive name
    if ($MigrationName.Length -lt 5) {
        Write-Host "WARNING: Migration name is too short" -ForegroundColor Yellow
        Write-Host "  Use descriptive names that explain the change" -ForegroundColor DarkGray
        $valid = $false
    }

    # Check for common bad patterns
    $badPatterns = @("Migration1", "Update", "Change", "Fix", "Test")
    foreach ($pattern in $badPatterns) {
        if ($MigrationName -match $pattern) {
            Write-Host "WARNING: Avoid generic names like '$pattern'" -ForegroundColor Yellow
            Write-Host "  Be specific about what changed" -ForegroundColor DarkGray
            $valid = $false
        }
    }

    if ($valid) {
        Write-Host "Migration name follows conventions" -ForegroundColor Green
    }

    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== EF Core Migration Validator ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Check for .csproj
$csproj = Get-ChildItem $ProjectPath -Filter "*.csproj" | Select-Object -First 1

if (-not $csproj) {
    Write-Host "ERROR: No .csproj file found" -ForegroundColor Red
    exit 1
}

# Get migrations
$migrations = Get-Migrations -ProjectPath $ProjectPath

if ($migrations.Count -eq 0) {
    Write-Host "No migrations found" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($migrations.Count) migrations" -ForegroundColor Green
Write-Host ""

# Determine which migration to validate
$targetMigration = if ($MigrationName) {
    $migrations | Where-Object { $_.name -eq $MigrationName } | Select-Object -First 1
} else {
    $migrations | Select-Object -Last 1
}

if (-not $targetMigration) {
    Write-Host "ERROR: Migration not found: $MigrationName" -ForegroundColor Red
    exit 1
}

Write-Host "Validating migration: $($targetMigration.name)" -ForegroundColor Cyan
Write-Host ""

# Validate naming convention
Validate-NamingConvention -MigrationName $targetMigration.name

# Get migration file
$migrationFile = Get-MigrationFile -ProjectPath $ProjectPath -MigrationName $targetMigration.name

if ($migrationFile) {
    # Analyze migration
    $analysis = Analyze-Migration -MigrationFilePath $migrationFile.FullName

    # Generate rollback if requested
    if ($GenerateRollback) {
        Generate-RollbackScript -ProjectPath $ProjectPath -MigrationName $targetMigration.name
    }
}

# Show pending migrations
Show-PendingMigrations -ProjectPath $ProjectPath

# Test apply if requested
if ($TestApply) {
    Test-MigrationApply -ProjectPath $ProjectPath -MigrationName $targetMigration.name -DryRunMode:$DryRun
}

Write-Host "=== Validation Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
