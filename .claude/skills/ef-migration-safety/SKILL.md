---
name: ef-migration-safety
description: Safe Entity Framework Core migration workflow with pre-flight checks, breaking change detection, and multi-step migration patterns
triggers:
  - "create ef migration"
  - "add migration"
  - "database migration"
  - "schema change"
  - "ef core migration"
  - "entity framework"
priority: high
version: 1.0.0
---

# EF Core Migration Safety Workflow

## 🎯 Purpose
This skill provides a **zero-failure migration workflow** for EF Core schema changes. It prevents common mistakes by enforcing pre-flight checks, detecting breaking changes, and guiding multi-step migrations.

## 🚨 Critical Rules

1. **NEVER create migrations without pre-flight check**
2. **NEVER apply breaking changes in single migration**
3. **ALWAYS preview SQL before applying**
4. **ALWAYS generate rollback script for production**
5. **NEVER skip testing on clone database**
6. **ALWAYS use explicit `.ToTable("TableName")` for ALL entities** ⚡ NEW
7. **ALWAYS create migration when adding DbSet/entity** ⚡ CRITICAL - See below

---

## ⚡ CRITICAL: Migration Is Part Of The Feature, Not "Later"

**Incident ID:** EFCORE-MIGRATION-OMISSION-20260122

### 🔴 The Problem

When you add:
- A new `DbSet<T>` to DbContext
- A new entity class
- Entity configuration in `OnModelCreating`

You MUST also create and commit the migration file as part of the same work.

### ❌ WRONG (What was done)
```csharp
// Added to DbContext.cs
public DbSet<ChatActiveAction> ChatActiveActions { get; set; }

// Added entity configuration...
// Committed code...
// Told user: "Run migration later when VS is not locking files"
// ← THIS IS A VIOLATION
```

### ✅ CORRECT (What should be done)
```bash
# 1. Before starting code changes
#    Ask user to stop VS if running (required for CLI migrations)

# 2. After adding DbSet and entity config
dotnet ef migrations add AddChatActiveActions --context IdentityDbContext

# 3. Verify migration file is correct
cat Migrations/*_AddChatActiveActions.cs

# 4. Apply migration
dotnet ef database update

# 5. Verify table exists
# (Use SQL query or app startup test)

# 6. THEN commit ALL files together:
#    - New entity model
#    - DbContext changes
#    - Migration files (*.cs, *.Designer.cs)
#    - ModelSnapshot update
```

### 🛑 If VS Is Locking Files

If you cannot run `dotnet ef` because VS has file locks:

1. **ASK USER FIRST**: "I need to create a database migration. Can you stop VS/the API for a moment?"
2. **WAIT** for user confirmation
3. **CREATE** the migration
4. **VERIFY** it works
5. **TELL** user they can restart VS

**NEVER** just skip the migration and say "do it later".

### 📋 Pre-Commit Checklist For Database Features

- [ ] Entity class created
- [ ] DbSet added to DbContext
- [ ] Entity configuration added in OnModelCreating
- [ ] **Migration file created** (`dotnet ef migrations add`)
- [ ] **Migration applied to dev** (`dotnet ef database update`)
- [ ] **Table verified** (exists with correct schema)
- [ ] All files committed together (entity + dbcontext + migrations)

---

## ⚡ NEW: Table Naming Convention Trap (CRITICAL)

**Incident ID:** EFCORE-TABLENAMING-20260119 ([Full Details](../../_machine/ef-core-table-naming-incident.md))

### 🔴 The Problem

**Symptom:**
```
System.InvalidOperationException: The model for context 'IdentityDbContext' has pending changes.
SQLite Error 1: 'no such table: Projects'
```

**Root Cause:**
```csharp
// BROKEN: Relies on EF Core convention
builder.Entity<Project>(entity => {
    entity.HasKey(e => e.Id);
    // MISSING: entity.ToTable("ProjectsDb");
});

// Database actually has table named "ProjectsDb"
// EF Core assumes table named "Projects" (pluralized)
// MISMATCH → Application fails
```

### 🛡️ The Solution

**MANDATORY STANDARD:** ALL entity configurations MUST have explicit `.ToTable()` declaration.

```csharp
// CORRECT: Explicit table name
builder.Entity<Project>(entity =>
{
    entity.ToTable("ProjectsDb");  // ← REQUIRED, even if matches convention
    entity.HasKey(e => e.Id);
    entity.HasIndex(e => e.CreatedAt);
});
```

### 🎯 Why This Is Critical

1. **EF Core has default pluralization** (Entity → Entities)
2. **Migrations can create custom-named tables**
3. **DbContext doesn't "remember" custom names from migrations**
4. **Future migrations use default names → MISMATCH → FAILURE**

### 🔍 Diagnosis Pattern

When you see "no such table X" or "table Y already exists":

```bash
# Step 1: Check what migrations actually created
cd Migrations/
grep "CreateTable" *.cs | grep <TableName>
# Example output: CreateTable("ProjectsDb", ...)

# Step 2: Check DbContext configuration
grep -A 10 "builder.Entity<Project>" ../DbContext.cs
# If no .ToTable() → MISMATCH FOUND

# Step 3: Compare names
# Migration says: "ProjectsDb"
# DbContext expects: "Projects" (default)
# → ROOT CAUSE IDENTIFIED
```

### ✅ Quick Fix Checklist

```bash
# 1. Add explicit .ToTable() to DbContext
# Edit: DbContext.cs
entity.ToTable("ProjectsDb");  # Use actual table name from migration

# 2. Remove corrupted pending migrations
dotnet ef migrations remove --context <Context> --force

# 3. Recreate migration (now uses correct table name)
dotnet ef migrations add <Name> --context <Context>

# 4. Apply successfully
dotnet ef database update --context <Context>
```

### 🎓 Prevention Rule

**BEFORE creating ANY migration:**
```csharp
// Audit ALL entity configurations in OnModelCreating
// Ensure EVERY builder.Entity<T>() block has:
entity.ToTable("TableName");  // ← MANDATORY
```

**Tool:** `audit-dbcontext-table-names.ps1` (recommended pre-flight check)

---

## 📋 MANDATORY WORKFLOW

### Phase 1: Pre-Flight Safety Check

**BEFORE creating any migration:**

```bash
# 1. Run pre-flight check
.\tools\ef-preflight-check.ps1 -Context <DbContextName> -ProjectPath <ProjectPath>
```

**What it checks:**
- ✅ Connection string environment (dev vs prod)
- ✅ Pending migrations (must apply before creating new)
- ✅ Schema drift (manual database changes)
- ✅ ModelSnapshot integrity

**If check fails:** Fix issues before proceeding. DO NOT create migration.

---

### Phase 2: Determine Migration Strategy

**Ask yourself:**
1. Is this a **breaking change**? (affects existing code/queries)
   - Column rename → **YES**
   - Drop column → **YES**
   - Add NOT NULL → **YES**
   - Type change → **YES**
   - Add column → **NO**
   - Add index → **NO**

2. If **YES** (breaking):
   - Read pattern from `_machine/migration-patterns.md`
   - Plan multi-step migration (2-3 migrations)
   - Document deployment sequence

3. If **NO** (non-breaking):
   - Single migration is OK
   - Proceed to Phase 3

---

### Phase 3: Create Migration

```bash
# 1. Clean build (prevent stale DLLs)
dotnet clean
dotnet build

# 2. Create migration with descriptive name
dotnet ef migrations add <DescriptiveName> --context <DbContextName>

# Examples of GOOD names:
#   - AddUserEmailColumn
#   - MakeProductPriceRequired
#   - CreateOrdersTable
#
# Examples of BAD names:
#   - Update
#   - Migration1
#   - Fix
```

**Naming Convention:**
- Use PascalCase
- Be specific (what changed, not "Update")
- Min 5 characters
- Avoid generic terms (Update, Change, Fix)

---

### Phase 4: Preview & Validate

```bash
# 1. Preview SQL and analyze breaking changes
.\tools\ef-migration-preview.ps1 -Migration <MigrationName> -Context <DbContextName> -ProjectPath <ProjectPath> -GenerateRollback

# 2. Review output carefully:
#    - Check SQL statements (CREATE, ALTER, DROP)
#    - Read breaking change warnings
#    - Verify recommended patterns
#    - Review rollback script

# 3. Read generated migration file
#    - Open: Migrations/<timestamp>_<MigrationName>.cs
#    - Verify Up() method logic
#    - Verify Down() method (rollback)

# 4. Check ModelSnapshot changes
#    - Open: Migrations/<DbContextName>ModelSnapshot.cs
#    - Look for unexpected changes
```

**If breaking changes detected:**
- Compare to patterns in `_machine/migration-patterns.md`
- If single-step migration → STOP, use multi-step pattern
- If multi-step migration → verify you're on correct step

---

### Phase 5: Test on Clone Database

**NEVER apply to production without testing on clone:**

```bash
# Option A: Manual test
# 1. Restore production backup to local database
# 2. Update connection string to point to clone
# 3. Apply migration:
dotnet ef database update --context <DbContextName>

# 4. Run smoke tests:
#    - Can app start?
#    - Can you query affected tables?
#    - Are FK relationships intact?

# 5. Test rollback:
dotnet ef database update <PreviousMigration> --context <DbContextName>

# Option B: Automated test (if available)
.\tools\ef-test-migration.ps1 -Migration <MigrationName> -Context <DbContextName> -CloneDatabase <ConnectionString>
```

---

### Phase 6: Apply Migration

#### For Development:
```bash
dotnet ef database update --context <DbContextName>
```

#### For Production:
```bash
# 1. Generate idempotent SQL script (DO NOT use dotnet ef database update in prod)
dotnet ef migrations script --idempotent --output migration_<MigrationName>.sql --context <DbContextName>

# 2. Review SQL script manually

# 3. Apply via DBA or deployment pipeline
#    (depends on organization's process)
```

---

### Phase 7: Validation

**After applying migration:**

```bash
# 1. Verify migration applied
dotnet ef migrations list --context <DbContextName>
# Check for (Applied) status

# 2. Validate schema matches snapshot
.\tools\ef-validate-schema.ps1 -Context <DbContextName> -ProjectPath <ProjectPath>

# 3. Run smoke tests
#    - Application starts?
#    - Basic queries work?
#    - No missing columns/tables?

# 4. Update baseline
.\tools\ef-preflight-check.ps1 -Context <DbContextName> -ProjectPath <ProjectPath>
# This updates schema baseline for next migration
```

---

## 🔄 Multi-Step Migration Example

**Scenario:** Rename `DailyLimit` → `MonthlyLimit` (breaking change)

### Migration 1: Add New Column
```bash
# Step 1.1: Pre-flight check
.\tools\ef-preflight-check.ps1 -Context AppDbContext -ProjectPath .

# Step 1.2: Create migration
dotnet ef migrations add AddMonthlyLimitColumn --context AppDbContext

# Step 1.3: Edit migration to add data backfill
# In Migrations/XXXXX_AddMonthlyLimitColumn.cs:
protected override void Up(MigrationBuilder migrationBuilder)
{
    migrationBuilder.AddColumn<decimal>(
        name: "MonthlyLimit",
        table: "Accounts",
        nullable: true);

    // ADD THIS: Backfill data
    migrationBuilder.Sql(@"
        UPDATE Accounts
        SET MonthlyLimit = DailyLimit * 30
        WHERE MonthlyLimit IS NULL
    ");
}

# Step 1.4: Preview
.\tools\ef-migration-preview.ps1 -Migration AddMonthlyLimitColumn -Context AppDbContext -GenerateRollback

# Step 1.5: Apply
dotnet ef database update --context AppDbContext
```

**Deploy Code (reads from BOTH columns)**
```csharp
public class Account
{
    public decimal DailyLimit { get; set; }    // Old (keep)
    public decimal? MonthlyLimit { get; set; } // New

    public decimal GetLimit() => MonthlyLimit ?? (DailyLimit * 30);
}
```

**Wait 1 week, validate in production**

### Migration 2: Make New Column Required
```bash
dotnet ef migrations add MakeMonthlyLimitRequired --context AppDbContext
# (Alters column to NOT NULL)

dotnet ef database update --context AppDbContext
```

### Migration 3: Drop Old Column
```bash
dotnet ef migrations add DropDailyLimitColumn --context AppDbContext

.\tools\ef-migration-preview.ps1 -Migration DropDailyLimitColumn -Context AppDbContext -GenerateRollback

dotnet ef database update --context AppDbContext
```

**Update Code (remove DailyLimit references)**

---

## 🛠️ Available Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `ef-preflight-check.ps1` | Pre-flight safety check | BEFORE creating migration |
| `ef-migration-preview.ps1` | SQL preview + breaking change detection | AFTER creating migration |
| `validate-migration.ps1` | Comprehensive migration validation | Before production deployment |
| `ef-migration-status.ps1` | Quick status check | Anytime |

---

## 🚨 Common Mistakes & Fixes

### Mistake 1: Created migration without pre-flight check
**Fix:**
```bash
# Remove bad migration
dotnet ef migrations remove --context <DbContextName>

# Run pre-flight check
.\tools\ef-preflight-check.ps1 -Context <DbContextName> -ProjectPath .

# Recreate migration
dotnet ef migrations add <Name> --context <DbContextName>
```

### Mistake 2: Breaking change in single migration
**Fix:**
```bash
# Remove bad migration
dotnet ef migrations remove --context <DbContextName>

# Read pattern guide
# Read: _machine/migration-patterns.md

# Create multi-step migration following pattern
```

### Mistake 3: Applied migration to wrong database
**Fix:**
```bash
# If not in production yet:
dotnet ef database update <PreviousMigration> --context <DbContextName>

# If in production:
# 1. Create compensating migration (forward fix)
# 2. Do NOT rollback in production (data loss risk)
```

### Mistake 4: Schema drift detected
**Fix:**
```bash
# Option A: Reconcile manually
# 1. Document manual changes
# 2. Create migration that matches manual changes
# 3. Mark migration as applied without running:
#    dotnet ef database update <MigrationName> --context <DbContextName>

# Option B: Reset dev database
# 1. Drop database
# 2. Recreate from migrations:
#    dotnet ef database update --context <DbContextName>
```

---

## 📚 Additional Resources

- **Pattern Library:** `C:\scripts\_machine\migration-patterns.md`
- **Tool Documentation:** `C:\scripts\tools\README.md` (EF Core section)
- **DbContext Manifest:** `C:\scripts\db-contexts.yml` (which context owns which tables)

---

## ✅ Success Criteria

Migration is successful ONLY if:
- ✅ Pre-flight check passed
- ✅ Breaking changes handled with multi-step pattern
- ✅ Migration previewed and analyzed
- ✅ Tested on production-clone database
- ✅ Rollback script generated and tested
- ✅ Applied migration validated
- ✅ Schema baseline updated

---

**For AI Agents:**
This skill is auto-activated when you create EF Core migrations. Follow the workflow exactly - do not skip steps. When in doubt, use multi-step migration pattern.

**Last Updated:** 2026-01-19
