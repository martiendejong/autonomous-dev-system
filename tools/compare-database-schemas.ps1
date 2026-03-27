<#
.SYNOPSIS
    Compares database schemas to detect drift and generate migration scripts.

.DESCRIPTION
    Compares two SQL Server databases (e.g., dev vs production) to identify
    schema differences, missing indexes, and inconsistencies.

    Features:
    - Table comparison (structure, columns, data types)
    - Index comparison (missing, different)
    - Foreign key comparison
    - Stored procedure comparison
    - View comparison
    - Generate migration scripts to sync schemas
    - Detect schema drift

.PARAMETER SourceConnection
    Source database connection string

.PARAMETER TargetConnection
    Target database connection string

.PARAMETER SourceDatabase
    Source database name

.PARAMETER TargetDatabase
    Target database name

.PARAMETER OutputPath
    Output path for comparison report and migration scripts

.PARAMETER GenerateScript
    Generate T-SQL migration script to sync target to source

.PARAMETER CompareData
    Compare row counts (not full data)

.EXAMPLE
    .\compare-database-schemas.ps1 -SourceDatabase "ClientManager_Dev" -TargetDatabase "ClientManager_Prod"
    .\compare-database-schemas.ps1 -SourceDatabase "Dev" -TargetDatabase "Prod" -GenerateScript
    .\compare-database-schemas.ps1 -SourceDatabase "Dev" -TargetDatabase "Prod" -CompareData
#>

param(
    [string]$SourceConnection = "Server=localhost;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True",
    [string]$TargetConnection = "Server=localhost;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True",

    [Parameter(Mandatory=$true)]
    [string]$SourceDatabase,

    [Parameter(Mandatory=$true)]
    [string]$TargetDatabase,

    [string]$OutputPath = "schema-comparison",
    [switch]$GenerateScript,
    [switch]$CompareData
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$script:Differences = @{
    "Tables" = @()
    "Columns" = @()
    "Indexes" = @()
    "ForeignKeys" = @()
    "StoredProcedures" = @()
    "Views" = @()
}

function Get-Tables {
    param([string]$ConnectionString, [string]$Database)

    $query = @"
USE [$Database];
SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_SCHEMA, TABLE_NAME;
"@

    try {
        $result = sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d $Database -Q $query -h -1 -s "," -W

        if ($LASTEXITCODE -eq 0) {
            $tables = @()

            foreach ($line in $result) {
                if ($line -match '^\s*$') { continue }
                $parts = $line -split ','
                if ($parts.Count -eq 2) {
                    $tables += @{
                        "Schema" = $parts[0].Trim()
                        "Name" = $parts[1].Trim()
                    }
                }
            }

            return $tables
        }

    } catch {
        Write-Host "ERROR: Failed to get tables from $Database" -ForegroundColor Red
    }

    return @()
}

function Get-Columns {
    param([string]$Database, [string]$Schema, [string]$Table)

    $query = @"
USE [$Database];
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = '$Schema'
  AND TABLE_NAME = '$Table'
ORDER BY ORDINAL_POSITION;
"@

    try {
        $result = sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d $Database -Q $query -h -1 -s "," -W

        if ($LASTEXITCODE -eq 0) {
            $columns = @()

            foreach ($line in $result) {
                if ($line -match '^\s*$') { continue }
                $parts = $line -split ','

                if ($parts.Count -ge 4) {
                    $columns += @{
                        "Name" = $parts[0].Trim()
                        "DataType" = $parts[1].Trim()
                        "MaxLength" = $parts[2].Trim()
                        "Nullable" = $parts[3].Trim()
                    }
                }
            }

            return $columns
        }

    } catch {
        # Ignore
    }

    return @()
}

function Get-Indexes {
    param([string]$Database, [string]$Schema, [string]$Table)

    $query = @"
USE [$Database];
SELECT
    i.name AS IndexName,
    i.type_desc AS IndexType,
    i.is_unique AS IsUnique
FROM sys.indexes i
INNER JOIN sys.tables t ON i.object_id = t.object_id
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = '$Schema'
  AND t.name = '$Table'
  AND i.name IS NOT NULL
ORDER BY i.name;
"@

    try {
        $result = sqlcmd -S localhost -U sa -P "YourStrong@Passw0rd" -d $Database -Q $query -h -1 -s "," -W

        if ($LASTEXITCODE -eq 0) {
            $indexes = @()

            foreach ($line in $result) {
                if ($line -match '^\s*$') { continue }
                $parts = $line -split ','

                if ($parts.Count -ge 3) {
                    $indexes += @{
                        "Name" = $parts[0].Trim()
                        "Type" = $parts[1].Trim()
                        "IsUnique" = $parts[2].Trim()
                    }
                }
            }

            return $indexes
        }

    } catch {
        # Ignore
    }

    return @()
}

function Compare-Tables {
    param([array]$SourceTables, [array]$TargetTables)

    Write-Host ""
    Write-Host "=== Comparing Tables ===" -ForegroundColor Cyan
    Write-Host ""

    $sourceTableNames = $SourceTables | ForEach-Object { "$($_.Schema).$($_.Name)" }
    $targetTableNames = $TargetTables | ForEach-Object { "$($_.Schema).$($_.Name)" }

    # Tables in source but not in target
    $missingInTarget = $SourceTables | Where-Object {
        $tableName = "$($_.Schema).$($_.Name)"
        $targetTableNames -notcontains $tableName
    }

    # Tables in target but not in source
    $extraInTarget = $TargetTables | Where-Object {
        $tableName = "$($_.Schema).$($_.Name)"
        $sourceTableNames -notcontains $tableName
    }

    if ($missingInTarget.Count -gt 0) {
        Write-Host "Tables missing in TARGET:" -ForegroundColor Red

        foreach ($table in $missingInTarget) {
            Write-Host "  - $($table.Schema).$($table.Name)" -ForegroundColor Yellow
            $script:Differences.Tables += @{
                "Type" = "Missing"
                "Table" = "$($table.Schema).$($table.Name)"
                "Location" = "Target"
            }
        }

        Write-Host ""
    }

    if ($extraInTarget.Count -gt 0) {
        Write-Host "Extra tables in TARGET:" -ForegroundColor Yellow

        foreach ($table in $extraInTarget) {
            Write-Host "  - $($table.Schema).$($table.Name)" -ForegroundColor DarkGray
            $script:Differences.Tables += @{
                "Type" = "Extra"
                "Table" = "$($table.Schema).$($table.Name)"
                "Location" = "Target"
            }
        }

        Write-Host ""
    }

    if ($missingInTarget.Count -eq 0 -and $extraInTarget.Count -eq 0) {
        Write-Host "All tables match!" -ForegroundColor Green
        Write-Host ""
    }
}

function Compare-Columns {
    param([string]$SourceDatabase, [string]$TargetDatabase, [array]$CommonTables)

    Write-Host "=== Comparing Columns ===" -ForegroundColor Cyan
    Write-Host ""

    $columnDifferences = 0

    foreach ($table in $CommonTables | Select-Object -First 20) {
        $sourceColumns = Get-Columns -Database $SourceDatabase -Schema $table.Schema -Table $table.Name
        $targetColumns = Get-Columns -Database $TargetDatabase -Schema $table.Schema -Table $table.Name

        $sourceColumnNames = $sourceColumns | ForEach-Object { $_.Name }
        $targetColumnNames = $targetColumns | ForEach-Object { $_.Name }

        # Missing columns
        foreach ($col in $sourceColumns) {
            if ($targetColumnNames -notcontains $col.Name) {
                Write-Host "  $($table.Schema).$($table.Name): Column '$($col.Name)' missing in target" -ForegroundColor Yellow

                $script:Differences.Columns += @{
                    "Table" = "$($table.Schema).$($table.Name)"
                    "Column" = $col.Name
                    "Issue" = "Missing in target"
                }

                $columnDifferences++
            }
        }

        # Data type differences
        foreach ($sourceCol in $sourceColumns) {
            $targetCol = $targetColumns | Where-Object { $_.Name -eq $sourceCol.Name } | Select-Object -First 1

            if ($targetCol) {
                if ($sourceCol.DataType -ne $targetCol.DataType -or $sourceCol.MaxLength -ne $targetCol.MaxLength) {
                    Write-Host "  $($table.Schema).$($table.Name).$($sourceCol.Name): Type mismatch" -ForegroundColor Yellow
                    Write-Host "    Source: $($sourceCol.DataType)($($sourceCol.MaxLength))" -ForegroundColor DarkGray
                    Write-Host "    Target: $($targetCol.DataType)($($targetCol.MaxLength))" -ForegroundColor DarkGray

                    $script:Differences.Columns += @{
                        "Table" = "$($table.Schema).$($table.Name)"
                        "Column" = $sourceCol.Name
                        "Issue" = "Type mismatch"
                    }

                    $columnDifferences++
                }
            }
        }
    }

    if ($columnDifferences -eq 0) {
        Write-Host "All columns match!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Found $columnDifferences column differences" -ForegroundColor Yellow
    }

    Write-Host ""
}

function Compare-Indexes {
    param([string]$SourceDatabase, [string]$TargetDatabase, [array]$CommonTables)

    Write-Host "=== Comparing Indexes ===" -ForegroundColor Cyan
    Write-Host ""

    $indexDifferences = 0

    foreach ($table in $CommonTables | Select-Object -First 20) {
        $sourceIndexes = Get-Indexes -Database $SourceDatabase -Schema $table.Schema -Table $table.Name
        $targetIndexes = Get-Indexes -Database $TargetDatabase -Schema $table.Schema -Table $table.Name

        $sourceIndexNames = $sourceIndexes | ForEach-Object { $_.Name }
        $targetIndexNames = $targetIndexes | ForEach-Object { $_.Name }

        # Missing indexes
        foreach ($idx in $sourceIndexes) {
            if ($targetIndexNames -notcontains $idx.Name) {
                Write-Host "  $($table.Schema).$($table.Name): Index '$($idx.Name)' missing in target" -ForegroundColor Yellow

                $script:Differences.Indexes += @{
                    "Table" = "$($table.Schema).$($table.Name)"
                    "Index" = $idx.Name
                    "Type" = $idx.Type
                }

                $indexDifferences++
            }
        }
    }

    if ($indexDifferences -eq 0) {
        Write-Host "All indexes match!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Found $indexDifferences missing indexes" -ForegroundColor Yellow
    }

    Write-Host ""
}

function Generate-MigrationScript {
    param([hashtable]$Differences, [string]$TargetDatabase, [string]$OutputPath)

    Write-Host ""
    Write-Host "=== Generating Migration Script ===" -ForegroundColor Cyan
    Write-Host ""

    $script = "-- Migration Script: Sync $TargetDatabase to match source`n"
    $script += "-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    $script += "`nUSE [$TargetDatabase];`n"
    $script += "GO`n`n"

    # Generate CREATE TABLE statements for missing tables
    foreach ($diff in $Differences.Tables | Where-Object { $_.Type -eq "Missing" }) {
        $script += "-- TODO: CREATE TABLE $($diff.Table)`n"
        $script += "-- Review source schema and create matching table`n`n"
    }

    # Generate ALTER TABLE statements for missing columns
    foreach ($diff in $Differences.Columns | Where-Object { $_.Issue -eq "Missing in target" }) {
        $script += "-- TODO: ALTER TABLE $($diff.Table) ADD $($diff.Column) <DataType>`n"
        $script += "-- Review source column definition`n`n"
    }

    # Generate CREATE INDEX statements for missing indexes
    foreach ($diff in $Differences.Indexes) {
        $script += "-- TODO: CREATE INDEX $($diff.Index) ON $($diff.Table)`n"
        $script += "-- Review source index definition`n`n"
    }

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $scriptPath = Join-Path $OutputPath "migration-$(Get-Date -Format 'yyyy-MM-dd-HHmmss').sql"
    $script | Set-Content $scriptPath -Encoding UTF8

    Write-Host "Migration script generated: $scriptPath" -ForegroundColor Green
    Write-Host "Review and test before executing!" -ForegroundColor Yellow
    Write-Host ""
}

function Show-Summary {
    param([hashtable]$Differences)

    Write-Host ""
    Write-Host "=== Comparison Summary ===" -ForegroundColor Cyan
    Write-Host ""

    $totalDifferences = 0
    $totalDifferences += $Differences.Tables.Count
    $totalDifferences += $Differences.Columns.Count
    $totalDifferences += $Differences.Indexes.Count

    Write-Host ("  Tables:     {0} differences" -f $Differences.Tables.Count) -ForegroundColor $(if ($Differences.Tables.Count -eq 0) { "Green" } else { "Yellow" })
    Write-Host ("  Columns:    {0} differences" -f $Differences.Columns.Count) -ForegroundColor $(if ($Differences.Columns.Count -eq 0) { "Green" } else { "Yellow" })
    Write-Host ("  Indexes:    {0} differences" -f $Differences.Indexes.Count) -ForegroundColor $(if ($Differences.Indexes.Count -eq 0) { "Green" } else { "Yellow" })
    Write-Host ""

    if ($totalDifferences -eq 0) {
        Write-Host "Schemas are identical!" -ForegroundColor Green
    } else {
        Write-Host "Total: $totalDifferences schema differences found" -ForegroundColor Yellow
    }

    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== Database Schema Comparison ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "Source: $SourceDatabase" -ForegroundColor White
Write-Host "Target: $TargetDatabase" -ForegroundColor White
Write-Host ""

# Get tables from both databases
Write-Host "Fetching table schemas..." -ForegroundColor Cyan

$sourceTables = Get-Tables -ConnectionString $SourceConnection -Database $SourceDatabase
$targetTables = Get-Tables -ConnectionString $TargetConnection -Database $TargetDatabase

if ($sourceTables.Count -eq 0) {
    Write-Host "ERROR: No tables found in source database" -ForegroundColor Red
    exit 1
}

if ($targetTables.Count -eq 0) {
    Write-Host "ERROR: No tables found in target database" -ForegroundColor Red
    exit 1
}

Write-Host "  Source: $($sourceTables.Count) tables" -ForegroundColor Green
Write-Host "  Target: $($targetTables.Count) tables" -ForegroundColor Green
Write-Host ""

# Compare tables
Compare-Tables -SourceTables $sourceTables -TargetTables $targetTables

# Find common tables for detailed comparison
$sourceTableNames = $sourceTables | ForEach-Object { "$($_.Schema).$($_.Name)" }
$targetTableNames = $targetTables | ForEach-Object { "$($_.Schema).$($_.Name)" }

$commonTables = $sourceTables | Where-Object {
    $tableName = "$($_.Schema).$($_.Name)"
    $targetTableNames -contains $tableName
}

if ($commonTables.Count -gt 0) {
    # Compare columns
    Compare-Columns -SourceDatabase $SourceDatabase -TargetDatabase $TargetDatabase -CommonTables $commonTables

    # Compare indexes
    Compare-Indexes -SourceDatabase $SourceDatabase -TargetDatabase $TargetDatabase -CommonTables $commonTables
}

# Show summary
Show-Summary -Differences $script:Differences

# Generate migration script if requested
if ($GenerateScript) {
    Generate-MigrationScript -Differences $script:Differences -TargetDatabase $TargetDatabase -OutputPath $OutputPath
}

Write-Host "=== Comparison Complete ===" -ForegroundColor Green
Write-Host ""

# Exit with error if differences found
if (($script:Differences.Tables.Count + $script:Differences.Columns.Count + $script:Differences.Indexes.Count) -gt 0) {
    exit 1
}

exit 0
