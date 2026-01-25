# audit-dbcontext-table-names.ps1 - Tool Specification

**Purpose:** Audit DbContext files for table naming configuration completeness to prevent EF Core migration failures.

**Incident:** EFCORE-TABLENAMING-20260119

**Priority:** HIGH - Prevents catastrophic application failures

---

## Overview

This tool scans C# DbContext files and:
1. Extracts all entity configurations
2. Checks for `.ToTable("TableName")` declarations
3. Optionally compares with actual database schema
4. Generates detailed report of mismatches
5. Can auto-fix by adding missing `.ToTable()` configurations

---

## Usage

### Basic Audit (Report Only)
```powershell
.\audit-dbcontext-table-names.ps1 -ProjectPath C:\Projects\client-manager\ClientManagerAPI

# Output:
# ✅ 30 entities with explicit .ToTable() configuration
# ❌ 20 entities missing .ToTable() configuration:
#   - Product (default: Products)
#   - Client (default: Clients)
#   - UserProfile (default: UserProfiles)
#   ...
```

### Audit with Database Schema Comparison
```powershell
.\audit-dbcontext-table-names.ps1 `
    -ProjectPath C:\Projects\client-manager\ClientManagerAPI `
    -DatabasePath C:\stores\brand2boost\identity.db

# Output:
# Comparing DbContext configuration with actual database...
# ✅ 30 entities match database tables
# ❌ 5 entities with mismatches:
#   - Project: DbContext expects "Projects", DB has "ProjectsDb" ⚠️ CRITICAL
#   - Client: DbContext expects "Clients", DB has "ClientsDb"
#   ...
```

### Auto-Fix Mode
```powershell
.\audit-dbcontext-table-names.ps1 `
    -ProjectPath C:\Projects\client-manager\ClientManagerAPI `
    -DatabasePath C:\stores\brand2boost\identity.db `
    -Fix

# Output:
# ✅ Added .ToTable("ProjectsDb") to Project entity (line 143)
# ✅ Added .ToTable("ClientsDb") to Client entity (line 172)
# ✅ Added .ToTable("UserProfiles") to UserProfile entity (line 130)
# ...
#
# Fixed 20 entity configurations.
# Please review changes in DbContext.cs and test migrations.
```

---

## Parameters

### -ProjectPath (Required)
Path to project containing DbContext files.

**Example:** `C:\Projects\client-manager\ClientManagerAPI`

### -DatabasePath (Optional)
Path to SQLite database for schema comparison.

**Example:** `C:\stores\brand2boost\identity.db`

**Behavior:**
- If provided: Compares DbContext config with actual database tables
- If omitted: Only checks for missing `.ToTable()` declarations

### -DbContextFile (Optional)
Specific DbContext.cs file to audit (default: searches for all *DbContext.cs files).

**Example:** `Custom\IdentityDbContext.cs`

### -Fix (Switch)
Automatically add missing `.ToTable()` configurations.

**Behavior:**
- Reads actual table names from database (requires -DatabasePath)
- Adds `entity.ToTable("TableName");` to each entity configuration
- Creates backup: `DbContext.cs.backup-{timestamp}`
- Reports all changes made

### -DryRun (Switch)
Show what would be fixed without making changes (requires -Fix).

### -OutputFormat (Optional)
Output format: `console` (default), `json`, `markdown`

**Example:** `-OutputFormat json > audit-report.json`

### -Verbose (Switch)
Show detailed analysis for each entity.

---

## Implementation Details

### Phase 1: Parse DbContext Files

```powershell
function Parse-DbContextFile {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw

    # Extract entity configurations using regex
    $entityPattern = 'builder\.Entity<(\w+)>\(entity\s*=>\s*{([^}]+)}\);'
    $matches = [regex]::Matches($content, $entityPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

    $entities = @()
    foreach ($match in $matches) {
        $entityName = $match.Groups[1].Value
        $configBlock = $match.Groups[2].Value

        # Check for .ToTable() declaration
        $hasToTable = $configBlock -match 'entity\.ToTable\("(\w+)"\)'
        $tableName = if ($hasToTable) { $matches[0].Groups[1].Value } else { $null }

        $entities += [PSCustomObject]@{
            EntityName = $entityName
            HasToTable = $hasToTable
            TableName = $tableName
            DefaultTableName = Get-PluralizedName $entityName
            LineNumber = Get-LineNumber $FilePath $match.Index
        }
    }

    return $entities
}
```

### Phase 2: Compare with Database Schema (if -DatabasePath provided)

```powershell
function Get-DatabaseTableNames {
    param([string]$DatabasePath)

    # Use sqlite3 or System.Data.SQLite to query schema
    $query = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"

    # Execute query and return table names
    # ...
}

function Compare-EntityWithDatabase {
    param(
        [PSCustomObject]$Entity,
        [string[]]$DatabaseTables
    )

    if ($Entity.HasToTable) {
        # Check if configured table exists in database
        if ($DatabaseTables -contains $Entity.TableName) {
            return [PSCustomObject]@{
                Status = "Match"
                Message = "✅ Entity '$($Entity.EntityName)' correctly mapped to '$($Entity.TableName)'"
            }
        } else {
            return [PSCustomObject]@{
                Status = "Mismatch"
                Message = "❌ Entity '$($Entity.EntityName)' expects table '$($Entity.TableName)' but it doesn't exist in database"
            }
        }
    } else {
        # No .ToTable() - check if default name exists
        if ($DatabaseTables -contains $Entity.DefaultTableName) {
            return [PSCustomObject]@{
                Status = "Warning"
                Message = "⚠️ Entity '$($Entity.EntityName)' relies on convention (default: '$($Entity.DefaultTableName)'). Add explicit .ToTable() for safety."
            }
        } else {
            # Critical: Neither configured nor default name exists
            # Find closest match in database
            $possibleMatch = Find-ClosestTableName $Entity.EntityName $DatabaseTables
            return [PSCustomObject]@{
                Status = "Critical"
                Message = "🔴 Entity '$($Entity.EntityName)' has no .ToTable(), default '$($Entity.DefaultTableName)' not in DB. Possible match: '$possibleMatch'?"
            }
        }
    }
}
```

### Phase 3: Auto-Fix (if -Fix)

```powershell
function Add-ToTableConfiguration {
    param(
        [string]$FilePath,
        [PSCustomObject]$Entity,
        [string]$ActualTableName
    )

    # Create backup
    Copy-Item $FilePath "$FilePath.backup-$(Get-Date -Format 'yyyyMMddHHmmss')"

    # Read file content
    $content = Get-Content $FilePath -Raw

    # Find entity configuration block
    $pattern = "(builder\.Entity<$($Entity.EntityName)>\(entity\s*=>\s*{)"
    $replacement = "`$1`n        entity.ToTable(`"$ActualTableName`");"

    # Insert .ToTable() as first line in configuration
    $newContent = $content -replace $pattern, $replacement

    # Write back
    Set-Content $FilePath $newContent -NoNewline

    Write-Host "✅ Added .ToTable(`"$ActualTableName`") to $($Entity.EntityName) entity (line $($Entity.LineNumber))"
}
```

### Phase 4: Generate Report

```powershell
function Generate-Report {
    param(
        [PSCustomObject[]]$AuditResults,
        [string]$OutputFormat
    )

    switch ($OutputFormat) {
        "console" {
            # Color-coded console output
            # ...
        }
        "json" {
            $AuditResults | ConvertTo-Json -Depth 5
        }
        "markdown" {
            # Generate markdown table
            # ...
        }
    }
}
```

---

## Example Output

### Console Format (Default)
```
Auditing DbContext configurations in: C:\Projects\client-manager\ClientManagerAPI

DbContext File: Custom\IdentityDbContext.cs
Entity Configurations Found: 50

✅ CORRECT CONFIGURATIONS (30):
  - UserProfile → UserProfiles (line 130)
  - TokenBalance → TokenBalances (line 205)
  - Product → Product (line 411)
  ...

⚠️ MISSING .ToTable() CONFIGURATION (15):
  - Client (default: Clients) [line 172]
    Recommendation: Add entity.ToTable("Clients");
  - BlogPost (default: BlogPosts) [line 1088]
    Recommendation: Add entity.ToTable("BlogPosts");
  ...

🔴 CRITICAL MISMATCHES (5):
  - Project (expects: Projects, DB has: ProjectsDb) [line 143]
    ⚠️ MIGRATION WILL FAIL - Add entity.ToTable("ProjectsDb");
  - MenuItem (expects: MenuItems, DB has: MenuItem) [line 561]
    ⚠️ MIGRATION WILL FAIL - Add entity.ToTable("MenuItem");
  ...

Summary:
  Total Entities: 50
  ✅ Correct: 30 (60%)
  ⚠️ Missing .ToTable(): 15 (30%)
  🔴 Critical Mismatches: 5 (10%)

Recommendation:
  Run with -Fix flag to auto-correct configurations:
  .\audit-dbcontext-table-names.ps1 -ProjectPath <path> -DatabasePath <dbpath> -Fix
```

### JSON Format
```json
{
  "DbContextFile": "Custom\\IdentityDbContext.cs",
  "TotalEntities": 50,
  "AuditResults": [
    {
      "EntityName": "Project",
      "HasToTable": false,
      "ExpectedTableName": "Projects",
      "ActualTableName": "ProjectsDb",
      "Status": "Critical",
      "Message": "Migration will fail - table name mismatch",
      "LineNumber": 143,
      "Recommendation": "Add: entity.ToTable(\"ProjectsDb\");"
    },
    ...
  ],
  "Summary": {
    "Correct": 30,
    "MissingToTable": 15,
    "CriticalMismatches": 5
  }
}
```

---

## Integration with EF Migration Workflow

### Pre-Flight Check Integration
```powershell
# Add to ef-preflight-check.ps1

Write-Host "Checking DbContext table name configurations..."
$auditResults = .\audit-dbcontext-table-names.ps1 `
    -ProjectPath $ProjectPath `
    -DatabasePath $DatabasePath `
    -OutputFormat json | ConvertFrom-Json

if ($auditResults.Summary.CriticalMismatches -gt 0) {
    Write-Error "❌ CRITICAL: Found $($auditResults.Summary.CriticalMismatches) table name mismatches."
    Write-Error "Run audit tool with -Fix flag to resolve:"
    Write-Error "  .\audit-dbcontext-table-names.ps1 -ProjectPath $ProjectPath -DatabasePath $DatabasePath -Fix"
    exit 1
}

if ($auditResults.Summary.MissingToTable -gt 0) {
    Write-Warning "⚠️ Found $($auditResults.Summary.MissingToTable) entities without .ToTable() configuration."
    Write-Warning "Recommended: Add explicit .ToTable() for all entities"
}
```

---

## Error Handling

### Invalid Project Path
```powershell
if (-not (Test-Path $ProjectPath)) {
    Write-Error "Project path not found: $ProjectPath"
    exit 1
}
```

### No DbContext Files Found
```powershell
$dbContextFiles = Get-ChildItem $ProjectPath -Recurse -Filter "*DbContext.cs"
if ($dbContextFiles.Count -eq 0) {
    Write-Warning "No DbContext files found in $ProjectPath"
    exit 0
}
```

### Database Connection Issues
```powershell
try {
    $tables = Get-DatabaseTableNames -DatabasePath $DatabasePath
} catch {
    Write-Error "Failed to read database schema: $_"
    Write-Warning "Continuing with configuration audit only (no schema comparison)"
    $tables = @()
}
```

---

## Testing Strategy

### Test Cases

1. **No .ToTable() configurations**
   - Expect: Report all entities as "Missing .ToTable()"

2. **All .ToTable() configurations present**
   - Expect: Report "All correct"

3. **Mixed configurations**
   - Expect: Report both correct and missing

4. **Table name mismatch**
   - Expect: Report critical mismatch with actual table name

5. **Auto-fix mode**
   - Expect: Backup created, .ToTable() added correctly

6. **Database not accessible**
   - Expect: Graceful degradation, audit config only

---

## Future Enhancements

### Phase 2 Features
- Support for SQL Server / PostgreSQL (not just SQLite)
- Support for multiple DbContext files in one project
- Visual Studio Code extension integration
- Git pre-commit hook integration

### Phase 3 Features
- AI-powered table name suggestions
- Historical migration analysis
- Cross-project DbContext consistency checks
- Generate EF Core configuration templates

---

## Success Metrics

**Tool is successful if:**
- ✅ Detects all entities without `.ToTable()` configuration
- ✅ Identifies table name mismatches with 100% accuracy
- ✅ Auto-fix adds correct `.ToTable()` declarations
- ✅ Creates backups before modifying files
- ✅ Integrates seamlessly with ef-preflight-check.ps1
- ✅ Prevents EFCORE-TABLENAMING incidents from recurring

---

**Status:** Specification Complete - Ready for Implementation
**Priority:** HIGH
**Estimated Effort:** 4-6 hours
**Dependencies:** System.Data.SQLite (for SQLite support)
