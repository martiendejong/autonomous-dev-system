---
name: session-reflection
description: Update reflection.log.md with learnings from the current session. Use at end of session, after discovering new patterns, fixing bugs, or completing significant work. Documents lessons learned for future sessions.
allowed-tools: Read, Write, Edit, Bash
user-invocable: true
---

# Session Reflection Protocol

**Purpose:** Document learnings, mistakes, and patterns from the current session for continuous improvement.

## When to Update Reflection Log

**Update reflection.log.md when:**
- ✅ End of session (mandatory)
- ✅ Discovered new pattern or solution
- ✅ Fixed complex bug (document root cause + solution)
- ✅ Made a mistake (document what happened + prevention)
- ✅ Completed significant feature (document approach)
- ✅ User provided feedback (integrate into documentation)
- ✅ Violated zero-tolerance rule (document violation + recovery)

**Timing:**
- IMMEDIATELY after discovering learning
- NOT batched at end of day
- Real-time documentation = better retention

## Reflection Entry Format

### Standard Template

```markdown
## YYYY-MM-DD HH:MM - <Brief Title>

**Session Type:** <Bug fix / Feature implementation / User feedback / etc>
**Context:** <What task/issue triggered this session>
**Outcome:** <✅ SUCCESS / ⚠️ PARTIAL / ❌ FAILURE> - <Brief result>

### Problem Statement

<Describe the problem, user report, or task>

### Root Cause Analysis

<Technical explanation of why the issue occurred>

### Solution Implemented

<What you did to fix/implement>

**Files modified:**
- <file1> - <what changed>
- <file2> - <what changed>

**Commit:** <commit-hash>
**PR:** #<number> (if applicable)

### Key Learnings

**Pattern <N>: <Pattern Name>**

<Reusable pattern description>

**When to use:**
<Trigger conditions>

**How to implement:**
<Step-by-step>

**Example:**
```<language>
<code example>
```

### Lessons for Future Sessions

**DO:**
- ✅ <Action to take>
- ✅ <Action to take>

**DON'T:**
- ❌ <Action to avoid>
- ❌ <Action to avoid>

**Key insight:** <One-sentence summary of main learning>

---
```

### Example: Bug Fix Entry

```markdown
## 2026-01-12 20:10 - API Path Duplication Fix

**Session Type:** Bug fix - Frontend API configuration
**Context:** User reported 404 errors on company documents endpoints
**Outcome:** ✅ SUCCESS - Fixed in 10 minutes with proper worktree workflow

### Problem

API calls failing with 404:
```
❌ https://localhost:54501/api/api/v1/projects/{projectId}/company-documents
```

The `/api/` prefix was appearing twice.

### Root Cause

`axiosConfig.ts` sets `baseURL: 'https://localhost:54501/api/'`
`companyDocuments.ts` had `API_BASE = '/api/v1/projects'`
Result: `/api/` + `/api/v1/...` = `/api/api/v1/...`

### Solution

Changed `companyDocuments.ts`:
```diff
- const API_BASE = '/api/v1/projects'
+ const API_BASE = '/v1/projects'
```

### Pattern Learned

**Frontend API Service Configuration:**
- ✅ Check `axiosConfig.ts` baseURL before creating services
- ✅ Service paths should NOT duplicate baseURL prefix
- ⚠️ Watch for this when copying service files

### Files Modified

- `ClientManagerFrontend/src/services/companyDocuments.ts` (line 4)

**Commit:** 1fe6c98
**PR:** #121

---
```

## Writing Effective Reflections

### Focus on "Why" Not Just "What"

**❌ Bad reflection:**
```
Fixed bug in UserController.
Changed dailyAllowance to monthlyAllowance.
```

**✅ Good reflection:**
```
### Problem
System said "daily tokens" but actually used monthly allocation.
Users confused by misleading labels.

### Root Cause
Database had MonthlyAllowance (correct) but API responses used
dailyAllowance (wrong). Naming mismatch across 95 files.

### Pattern Learned
Terminology must match business logic. Even if data is correct,
wrong labels destroy user trust. Comprehensive refactor needed.
```

### Include Code Examples

**Reusable patterns need examples:**

```markdown
### Pattern: OpenAIConfig Initialization

**Wrong:**
```csharp
var config = new OpenAIConfig(apiKey);  // Model is empty!
```

**Correct:**
```csharp
var config = new OpenAIConfig(apiKey);
config.Model = "gpt-4o-mini";  // Must set explicitly
```

**Detection:** `ArgumentException: Value cannot be empty (Parameter 'model')`
```

### Document Success Criteria

**How to know pattern worked:**

```markdown
### Success Criteria

✅ Pattern applied correctly ONLY IF:
- Backend builds with 0 errors
- Frontend displays data correctly
- No console errors in browser
- User confirms issue resolved
```

## Categorizing Learnings

### Types of Reflections

**1. Bug Fixes**
- Problem + Root Cause + Solution
- Detection pattern for similar bugs
- Prevention checklist

**2. Feature Implementations**
- Approach taken + Challenges + Solutions
- Reusable architecture patterns
- Testing strategy

**3. User Feedback**
- Original feedback (exact words)
- What was changed
- How to integrate in future sessions

**4. Violations**
- What rule was violated
- How violation occurred
- Recovery steps taken
- Prevention mechanism added

**5. Discoveries**
- What was discovered
- Why it matters
- How to use in future

## Updating Reflection Log

### Step 1: Read Current Log

```bash
# Read entire log (for context)
cat C:/scripts/_machine/reflection.log.md

# Or read recent entries only
tail -n 500 C:/scripts/_machine/reflection.log.md
```

### Step 2: Write New Entry

**Use Edit tool to add at TOP of log** (after header):

```bash
# Find insertion point (after "---" under first entry)
# Add new entry in chronological order (newest first)
```

**Entry should include:**
- ✅ Timestamp (UTC format: YYYY-MM-DD HH:MM)
- ✅ Descriptive title
- ✅ Complete context
- ✅ Technical details
- ✅ Pattern learned
- ✅ Success criteria
- ✅ Related files/commits

### Step 3: Commit Update

```bash
cd C:/scripts
git add _machine/reflection.log.md
git commit -m "docs: Add reflection entry - <brief description>

<optional longer explanation>

Pattern documented: <pattern name>
Session: <session ID or date>

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
git push origin main
```

## Integration with Documentation Updates

### After Writing Reflection

**Ask yourself:**
1. Should this pattern go in CLAUDE.md? (operational manual)
2. Should this update a specific .md file? (e.g., worktree-workflow.md)
3. Does this affect zero-tolerance rules?
4. Should this become a new Skill?

**Example flow:**
```
Reflection entry → Identified reusable pattern
                → Create new section in CLAUDE.md
                → Update relevant specialized .md file
                → Consider creating Skill for auto-discovery
                → Commit all documentation together
```

## Common Mistakes in Reflections

### ❌ Too Vague

```markdown
## 2026-01-12 - Fixed stuff
Changed some code. It works now.
```

**Missing:**
- What was the problem?
- Why did it occur?
- What pattern prevents recurrence?

### ❌ No Code Examples

```markdown
Fixed the OpenAI configuration issue.
```

**Better:**
```markdown
Fixed OpenAI configuration by setting Model property:
```csharp
var config = new OpenAIConfig(apiKey);
config.Model = "gpt-4o-mini";  // CRITICAL
```
```

### ❌ No Future Guidance

```markdown
Updated 95 files. Took a long time.
```

**Better:**
```markdown
Updated 95 files using systematic approach:
1. Audit with grep (find all occurrences)
2. TodoWrite checklist (track progress)
3. sed for batch updates (avoid linter)
4. Build after each phase (catch errors early)

Future migrations: Use this pattern for any codebase-wide refactor.
```

### ❌ Missing Commit Info

```markdown
Fixed API path duplication.
```

**Better:**
```markdown
Fixed API path duplication in companyDocuments.ts

**Commit:** 1fe6c98
**PR:** #121
**Files:** ClientManagerFrontend/src/services/companyDocuments.ts
```

## Pattern Library Integration

### Numbering Patterns

**From reflection.log.md:**
- Pattern 1-50: Historical patterns
- Pattern 51+: New patterns discovered

**New pattern format:**
```markdown
### Pattern <N>: <Pattern Name>

**When:** <Trigger condition>
**Problem:** <What goes wrong without this>
**Solution:** <How to fix>
**Detection:** <How to identify the issue>
**Prevention:** <How to avoid in future>

**Example:**
```<language>
<code>
```

**Files:** <Where this pattern applies>
```

### Cross-Referencing

**Link patterns to Skills:**
```markdown
**See also:** `C:/scripts/.claude/skills/<skill-name>/SKILL.md`
```

**Link to main documentation:**
```markdown
**Documented in:** `C:/scripts/<file>.md` § <section>
```

## End-of-Session Checklist

**Before ending session, verify:**

```
[ ] Reflection.log.md updated with session learnings
[ ] New patterns documented with examples
[ ] Related documentation files updated (CLAUDE.md, etc.)
[ ] Commits include learning context
[ ] Pattern numbers assigned sequentially
[ ] Code examples included
[ ] Success criteria defined
[ ] Future guidance provided
[ ] All documentation changes committed and pushed
```

## Reference Files

- Reflection log: `C:/scripts/_machine/reflection.log.md`
- Main manual: `C:/scripts/CLAUDE.md`
- Continuous improvement: `C:/scripts/continuous-improvement.md`
- Best practices: `C:/scripts/_machine/best-practices/`

## Success Criteria

✅ **Good reflection ONLY IF:**
- Documents WHY not just WHAT
- Includes technical details
- Provides code examples
- Defines reusable pattern
- Lists success criteria
- Guides future sessions
- Committed and pushed

❌ **Bad reflection:**
- Vague description
- No code examples
- No root cause analysis
- No future guidance
- Not committed

## User Mandate

**Exact words:**
> "zorg dat je dus constant leert van jezelf en je eigen instructies bijwerkt"

**Translation:**
> "make sure you constantly learn from yourself and update your own instructions"

**This means:**
- ✅ Reflection is MANDATORY, not optional
- ✅ Update documentation IMMEDIATELY, not later
- ✅ Commit learnings EVERY session
- ✅ Build knowledge base for future sessions
- ✅ Self-improvement is core directive

**Every session should leave system better than you found it.**
