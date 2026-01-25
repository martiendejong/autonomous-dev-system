---
name: terminology-migration
description: Comprehensive codebase-wide terminology refactoring when field names, method names, or concepts need to be migrated. Use when discovering misleading names, migrating from old to new terminology, or ensuring consistency across backend and frontend.
allowed-tools: Bash, Read, Write, Edit, Grep
user-invocable: true
---

# Comprehensive Terminology Migration

**Purpose:** Systematically migrate terminology across entire codebase to eliminate confusion and ensure consistency.

## When to Use This Pattern

**Indicators terminology migration needed:**
- ❌ Field names don't match business logic (e.g., "dailyAllowance" but system uses monthly)
- ❌ Database uses different names than API (e.g., `MonthlyAllowance` vs `dailyAllowance`)
- ❌ Frontend and backend have naming mismatches
- ❌ Comments say "this should be X" but code says "Y"
- ❌ Users confused by UI labels that don't match functionality
- ❌ New developers use wrong terminology in new code

**Examples:**
```
daily → monthly (token allowances)
user → customer (business terminology change)
document → file (system-wide naming)
project → workspace (product rebranding)
```

## Migration Process

### Phase 1: Audit - Find ALL Occurrences

**Use Grep to find every instance:**

```bash
# Search backend
grep -r "dailyAllowance\|dailyUsed\|dailyRemaining\|DailyAllowance" \
  --include="*.cs" \
  C:/Projects/<repo>/

# Search frontend
grep -r "dailyAllowance\|dailyUsed\|dailyRemaining" \
  --include="*.ts" --include="*.tsx" \
  C:/Projects/<repo>/ClientManagerFrontend/

# Count occurrences
grep -r "dailyAllowance" --include="*.cs" | wc -l
```

**Document findings:**
```
TERMINOLOGY AUDIT: daily → monthly

Backend (24 files):
- Models: TokenStatistics.cs, UserTokenBalance.cs
- Services: TokenManagementService.cs
- Controllers: TokenManagementController.cs, UserController.cs

Frontend (6 files):
- Services: tokenService.ts
- Components: UsersManagement.tsx, TokenDisplay.tsx
- Views: UsersManagementView.tsx
```

### Phase 2: Create TodoWrite Checklist

Break migration into phases:

```
TODO:
1. Backend models (domain layer)
2. Backend services (business logic)
3. Backend controllers (API layer)
4. Backend method names
5. Frontend TypeScript interfaces
6. Frontend component properties
7. Frontend UI labels (user-facing text)
8. Database migration scripts (if needed)
9. API documentation
10. Tests
```

### Phase 3: Backend Refactor

#### Step 1: Models (Domain Layer)

```csharp
// BEFORE
public class TokenStatistics
{
    public int DailyAllowance { get; set; }
    public int DailyUsed { get; set; }
    public int DailyRemaining { get; set; }
}

// AFTER
public class TokenStatistics
{
    public int MonthlyAllowance { get; set; }
    public int MonthlyUsed { get; set; }
    public int MonthlyRemaining { get; set; }
}
```

#### Step 2: Services (Business Logic)

**Use sed for consistent patterns:**

```bash
# Replace property names
sed -i 's/stats\.DailyAllowance/stats.MonthlyAllowance/g' TokenManagementService.cs
sed -i 's/stats\.DailyUsed/stats.MonthlyUsed/g' TokenManagementService.cs
sed -i 's/balance\.DailyAllowance/balance.MonthlyAllowance/g' TokenManagementService.cs
```

**Why sed instead of Edit:**
- ✅ Atomic updates (no partial changes)
- ✅ Avoids linter interference
- ✅ Fast for many similar changes
- ✅ Consistent pattern application

#### Step 3: Controllers (API Layer)

**Update API response field names:**

```csharp
// BEFORE
return Ok(new
{
    userId = user.Id,
    dailyAllowance = stats.DailyAllowance,
    tokensUsedToday = stats.DailyUsed
});

// AFTER
return Ok(new
{
    userId = user.Id,
    monthlyAllowance = stats.MonthlyAllowance,
    tokensUsedThisMonth = stats.MonthlyUsed
});
```

#### Step 4: Method Names

**Rename methods with deprecation:**

```csharp
// New method
public async Task<bool> SetMonthlyAllowanceAsync(string userId, int allowance)
{
    // Implementation
}

// Deprecated old method
[Obsolete("Use SetMonthlyAllowanceAsync for proper monthly token allocation")]
public async Task<bool> SetDailyAllowanceAsync(string userId, int allowance)
{
    return await SetMonthlyAllowanceAsync(userId, allowance);
}
```

**Why deprecate instead of delete:**
- ✅ Prevents breaking external consumers
- ✅ Provides migration path
- ✅ Compiler warnings guide developers
- ✅ Can safely remove in next major version

#### Step 5: Build Verification

```bash
# Test backend compilation
cd C:/Projects/worker-agents/agent-XXX/<repo>
dotnet build <solution>.sln --no-restore

# Expected: 0 errors
```

### Phase 4: Frontend Refactor

#### Step 1: TypeScript Interfaces

```typescript
// BEFORE
interface User {
  id: string;
  dailyAllowance: number;
  tokensUsedToday: number;
  tokensRemainingToday: number;
}

// AFTER
interface User {
  id: string;
  monthlyAllowance: number;
  tokensUsedThisMonth: number;
  tokensRemainingThisMonth: number;
}
```

#### Step 2: Service API Calls

```typescript
// Update property access
const response = await api.get<User>('/users');
// response.dailyAllowance → response.monthlyAllowance
```

#### Step 3: Component Props and State

**Use sed for batch updates:**

```bash
# Update all files in directory
sed -i 's/dailyAllowance/monthlyAllowance/g' ClientManagerFrontend/src/**/*.tsx
sed -i 's/tokensUsedToday/tokensUsedThisMonth/g' ClientManagerFrontend/src/**/*.tsx
```

**Or use Edit for complex logic:**

```typescript
// Component with conditional logic
const allowanceText = user.monthlyAllowance > 1000
  ? `${user.monthlyAllowance} tokens/month (premium)`
  : `${user.monthlyAllowance} tokens/month (free)`;
```

#### Step 4: UI Labels (User-Facing)

**Critical: Update all text users see:**

```tsx
// BEFORE
<label>Daily Allowance:</label>
<span>{user.dailyAllowance} tokens per day</span>

// AFTER
<label>Monthly Allowance:</label>
<span>{user.monthlyAllowance} tokens per month</span>
```

**Search for all UI text:**
```bash
grep -r "Daily Allowance\|daily allowance\|per day" \
  --include="*.tsx" --include="*.ts" \
  ClientManagerFrontend/src/
```

#### Step 5: Build Verification

```bash
cd C:/Projects/worker-agents/agent-XXX/<repo>/ClientManagerFrontend
npm run build

# Expected: Success, no errors
```

### Phase 5: Database Migration (If Needed)

**If database columns need renaming:**

```csharp
// Create migration
public partial class RenameDailyToMonthly : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.RenameColumn(
            name: "DailyAllowance",
            table: "UserTokenBalances",
            newName: "MonthlyAllowance");

        migrationBuilder.RenameColumn(
            name: "DailyUsage",
            table: "UserTokenBalances",
            newName: "MonthlyUsage");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.RenameColumn(
            name: "MonthlyAllowance",
            table: "UserTokenBalances",
            newName: "DailyAllowance");

        migrationBuilder.RenameColumn(
            name: "MonthlyUsage",
            table: "UserTokenBalances",
            newName: "DailyUsage");
    }
}
```

**In this case study:** Database already had correct names (`MonthlyAllowance`), only API/UI needed updates.

### Phase 6: Documentation Updates

**Update all documentation:**

```bash
# Find documentation references
grep -r "daily allowance\|daily tokens" \
  --include="*.md" --include="*.txt" \
  C:/Projects/<repo>/
```

**Update:**
- README.md
- API documentation
- User guides
- Code comments
- Architecture diagrams

### Phase 7: Commit Strategy

**Two-commit pattern:**

```bash
# Commit 1: Initial fix (small, focused)
git add <critical files>
git commit -m "fix: Correct token field names from daily to monthly

- UserController.GetUsers response fields
- TokenStatistics model properties
- Core API endpoints

Partial fix to resolve immediate issue."

# Commit 2: Comprehensive refactor (large, complete)
git add -A
git commit -m "refactor: Complete migration from daily to monthly token terminology

- All backend API responses updated (95 files)
- All frontend interfaces and components updated
- Method names clarified
- Legacy methods deprecated with [Obsolete]
- UI labels updated (Daily → Monthly)
- Documentation updated

This ensures consistency between:
- Database (already MonthlyAllowance)
- API responses (now monthlyAllowance)
- Frontend (now monthlyAllowance)
- UI labels (now 'Monthly Allowance')

Fixes confusion where system said 'daily' but used monthly logic.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

## Tools and Techniques

### When to Use sed vs Edit

**Use sed when:**
- ✅ Same pattern across 10+ files
- ✅ Simple string replacement
- ✅ Linter might interfere with Edit tool
- ✅ Need atomic updates

**Use Edit when:**
- ✅ Complex logic changes
- ✅ Need type checking
- ✅ Conditional replacements
- ✅ Few files (< 5)

### Sed Examples

```bash
# Single file, multiple replacements
sed -i 's/oldName/newName/g' file.cs
sed -i 's/OldClass/NewClass/g' file.cs

# Multiple files
find . -name "*.cs" -exec sed -i 's/oldName/newName/g' {} +

# With backup
sed -i.bak 's/oldName/newName/g' file.cs

# Case-insensitive
sed -i 's/oldname/newName/gI' file.cs
```

### Grep for Verification

```bash
# After changes, verify no old terminology remains
grep -r "dailyAllowance" --include="*.cs" --include="*.ts" --include="*.tsx"

# Expected: 0 results (or only in comments/strings)
```

### Build After Each Phase

**Critical: Verify compilation after each phase**

```bash
# Backend
dotnet build --no-restore

# Frontend
npm run build

# If errors: Fix before continuing to next phase
```

## Success Criteria

✅ **Migration successful ONLY IF:**
- All occurrences found and updated (grep verification)
- Backend builds with 0 errors
- Frontend builds with 0 errors
- Database schema matches (if applicable)
- UI labels updated for users
- Documentation updated
- Legacy methods deprecated (not deleted)
- Commits clear and descriptive
- No new warnings introduced

## Common Pitfalls

❌ **DON'T:**
- Change some files and forget others (incomplete migration)
- Use multiline string literals in sed (syntax errors)
- Delete old methods immediately (breaking changes)
- Skip build verification between phases
- Forget to update UI labels
- Miss comments and documentation
- Use Edit tool when linter is running

✅ **DO:**
- Find ALL occurrences first (comprehensive grep)
- Use TodoWrite to track progress
- Build after each phase
- Deprecate old methods with `[Obsolete]`
- Update user-facing text
- Use sed for consistent patterns (10+ files)
- Commit in logical phases
- Update reflection.log.md with pattern

## Real-World Example

**From reflection.log.md (2026-01-12):**

```
Problem: Token system uses monthly allocation but code/UI said "daily"
Files: 95 files affected (24 backend, 6 frontend + propagation)
Phases: Models → Services → Controllers → Frontend → UI labels
Tools: Grep (audit) + sed (batch) + Edit (complex logic)
Result: ✅ 0 errors, consistent terminology
Time: ~45 minutes for 95-file refactor
Commits: 2 (initial fix + comprehensive refactor)
```

**Key insight:** User trust depends on accurate terminology. "Daily" when it's "monthly" destroys credibility, even if data is correct.

## Reference Files

- Pattern origin: `C:/scripts/_machine/reflection.log.md` (2026-01-12 20:00)
- Tools docs: `C:/scripts/tools-and-productivity.md`
- Edit usage: CLAUDE.md § Edit Tool Patterns

## Checklist Template

Copy this for your migration:

```
TERMINOLOGY MIGRATION: <old> → <new>

Phase 1: Audit
[ ] Backend grep completed
[ ] Frontend grep completed
[ ] Count total occurrences
[ ] Document affected files

Phase 2: Planning
[ ] TodoWrite checklist created
[ ] Migration strategy defined
[ ] Deprecation plan for methods

Phase 3: Backend
[ ] Models updated
[ ] Services updated
[ ] Controllers updated
[ ] Method names updated
[ ] Backend builds ✅

Phase 4: Frontend
[ ] Interfaces updated
[ ] Services updated
[ ] Components updated
[ ] UI labels updated
[ ] Frontend builds ✅

Phase 5: Database (if needed)
[ ] Migration script created
[ ] Migration tested
[ ] Rollback plan ready

Phase 6: Documentation
[ ] README updated
[ ] API docs updated
[ ] Comments updated

Phase 7: Commit & Verify
[ ] Initial commit (focused)
[ ] Comprehensive commit
[ ] Grep verification (no old terms)
[ ] Both builds pass
[ ] reflection.log.md updated
```
