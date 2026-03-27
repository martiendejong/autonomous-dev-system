---
name: clickup-reviewer
description: Review ClickUp tasks in 'review' status by analyzing linked PRs and providing code review. Works with ANY ClickUp board - internal projects, client projects, or specific boards by list ID.
tags: [clickup, code-review, pr-review, quality-assurance]
version: 2.0.0
created: 2026-02-07
updated: 2026-02-28
---

# ClickUp Reviewer Skill

## Purpose

Automatically review ClickUp tasks in "review" status by:
1. Finding tasks in review status across all configured boards
2. Locating linked Pull Requests
3. Analyzing code changes
4. Providing comprehensive code review
5. Posting review as ClickUp comment
6. Moving tasks through workflow based on review outcome

## 🚨 CRITICAL: Automated vs Manual Review Modes

**THIS SKILL = AUTOMATED MODE**
- Invoked by: "run automated reviewer", "run clickup reviewer skill"
- Auto-merge allowed: YES (after successful review)
- User opted in: YES (by invoking this skill)
- Workflow: Review → Post comments → Merge → Move to testing

**MANUAL REVIEW MODE (User command "ga reviewen")**
- Invoked by: "ga reviewen", "review de PRs", "check deze PRs"
- Auto-merge allowed: NO (user retains merge authority)
- User opted in: NO (user asks for review only, not automation)
- Workflow: Review → Post comments → **STOP** → Wait for user to say "merge"

**NEVER confuse these modes:**
- If user says "ga reviewen" → DO NOT auto-merge, DO NOT invoke this skill
- If user invokes this skill → Auto-merge is permitted after review
- Default assumption: MANUAL mode unless skill explicitly invoked

**Reference:** C:\scripts\_machine\PR_REVIEW_PROTOCOL.md (complete workflow)
**Zero Tolerance:** C:\scripts\ZERO_TOLERANCE_RULES.md Rule 3J

## ⚠️ CRITICAL: ClickUp Workflow (Swimlanes)

**Review Agent's Role in Workflow:**

```
┌─────────┐
│ REVIEW  │ ← Review agent operates here
└────┬────┘
     │
     ├─────────────────────┐
     │                     │
     │ APPROVED            │ CHANGES REQUESTED
     ▼                     ▼
┌─────────┐           ┌─────────┐
│ TESTING │           │  TODO   │
└─────────┘           └─────────┘
     │                  (rework)
     │ PR MERGED
     │ to develop
     │
     ▼
   (User validates)
```

### Status Transition Rules for Reviewer

**REVIEW → TESTING (Approval Path)**
- When: PR approved AND merged to develop
- Required Actions:
  1. ✅ Check merge conflicts (must be CLEAN)
  2. ✅ Build & test in worktree (all pass)
  3. ✅ Code quality acceptable
  4. ✅ Post approval comment
  5. ✅ Merge PR to develop
  6. ✅ Move task to TESTING (ONLY after merge!)
  7. ✅ Post comment with merge confirmation + PR URL

**REVIEW → TODO (Rejection Path)**
- When: Changes requested, conflicts found, or build/test failures
- Required Actions:
  1. ❌ Post detailed rejection comment
  2. ❌ Explain exactly what needs fixing
  3. ❌ Move task to TODO
  4. ❌ Keep PR open (don't merge!)
  5. ❌ Optionally reassign to original implementer

**⚠️ CRITICAL RULES:**
- ❌ NEVER move to TESTING before PR is merged to develop
- ❌ NEVER merge PR if conflicts exist
- ❌ NEVER merge PR if build/tests fail
- ❌ NEVER move to DONE (only user does this from testing)
- ✅ ALWAYS post clear comments with URLs
- ✅ ALWAYS read existing comments before reviewing

### Comment Guidelines for Reviews (MANDATORY)

**When posting review comments, ALWAYS:**

✅ **Keep it clear and actionable** (focus on what needs doing)
✅ **Show ALL URLs** - PR link, merge commit link, develop branch link
✅ **Read task comments first** - understand context and history
✅ **Be specific about issues** - line numbers, file names, exact problems
✅ **Use structured format** - sections for different review aspects

**Approval Comment Format:**
```markdown
✅ CODE REVIEW - APPROVED

PR: https://github.com/org/repo/pull/123
Merge Commit: https://github.com/org/repo/commit/abc123

Review Summary:
- Build: ✅ Success
- Tests: ✅ All passing
- Code Quality: ✅ Good
- MUST HAVE items: ✅ Complete

Merged to develop. Moving to TESTING.

-- Claude Code Reviewer
```

**Rejection Comment Format:**
```markdown
❌ CODE REVIEW - CHANGES REQUESTED

PR: https://github.com/org/repo/pull/123

Issues Found:
1. Build error in UserService.cs line 45
2. Missing unit tests for new endpoint
3. Merge conflicts with develop branch

Required Actions:
- Fix compilation error
- Add tests for POST /api/users
- Merge develop and resolve conflicts

Moving to TODO for rework.

-- Claude Code Reviewer
```

## Usage & Scope

### Mode 1: All Internal + Client Projects (Default)
```
"run the clickup reviewer"
"review clickup tasks"
"check tasks in review"
```
**Scope:** All internal projects (Brand Designer, Hazina, LearningTool, Meta) + all client projects (Art Revisionist, Vera AI, etc.)

### Mode 2: Specific Project
```
"review clickup tasks for art-revisionist"
"run clickup reviewer for client-manager"
"check hazina tasks in review"
```
**Scope:** Only tasks from specified project

### Mode 3: Specific Board by List ID
```
"review tasks in list 901211612245"
"run reviewer for board 901215559249"
```
**Scope:** Only tasks from specified list ID

### Mode 4: Category Filter
```
"review internal projects only"
"review client projects only"
```
**Scope:** Internal-only or client-only projects

**Configuration source:** `C:\scripts\_machine\clickup-config.json`

## Step 0: Consciousness Bridge

Before starting the review cycle, activate the bridge:

```bash
powershell.exe -File "C:/scripts/tools/consciousness-bridge.ps1" -Action OnTaskStart -TaskDescription "ClickUp review cycle" -Project "client-manager" -Silent
```

Read `C:/scripts/agentidentity/state/consciousness-context.json` for project-specific warnings.

After completing all reviews:

```bash
powershell.exe -File "C:/scripts/tools/consciousness-bridge.ps1" -Action OnTaskEnd -Outcome "success" -LessonsLearned "<summary of review findings>" -Silent
```

## Workflow

### Step 0: Determine Scope & Load Configuration

**ALWAYS load full project configuration first:**

```powershell
# Load ClickUp configuration
$config = Get-Content "C:\scripts\_machine\clickup-config.json" | ConvertFrom-Json

# Determine scope based on user request (same logic as clickhub-coding-agent)
$SCOPE = @{
    Mode = "default"  # default | specific | listid | category
    Projects = @()
    ListIds = @()
}

# Default = internal + client (NOT household/personal unless explicitly requested)
if ($SCOPE.Mode -eq "default") {
    $internalProjects = @("client-manager", "hazina", "brand2boost-birdseye", "learningtool", "general-meta")
    $clientProjects = @("art-revisionist", "vera-ai", "wreckingball", "cloudgrafo", "vloerenhuis")
    $SCOPE.Projects = $internalProjects + $clientProjects
}

# Build list of list IDs to query
$listIdsToQuery = @()
foreach ($project in $SCOPE.Projects) {
    if ($config.projects.$project.list_id) {
        $listIdsToQuery += $config.projects.$project.list_id
    }
}

Write-Host "ClickUp Reviewer Scope: $($SCOPE.Mode)"
Write-Host "Projects: $($SCOPE.Projects -join ', ')"
Write-Host "List IDs: $($listIdsToQuery -join ', ')"
```

### Step 1: Find Tasks in Review Across All Boards

```powershell
$allReviewTasks = @()

foreach ($listId in $listIdsToQuery) {
    # Fetch tasks from this list
    $tasks = C:\scripts\tools\clickup-sync.ps1 -Action list -ListId $listId

    # Filter for tasks in 'review' status (case-insensitive, matches various review statuses)
    $reviewTasks = $tasks | Where-Object {
        $_.status.status -match "review"
    }

    # Add project context to each task
    foreach ($task in $reviewTasks) {
        $task | Add-Member -NotePropertyName "ProjectContext" -NotePropertyValue (
            $config.projects.GetEnumerator() |
            Where-Object { $_.Value.list_id -eq $listId } |
            Select-Object -First 1 -ExpandProperty Key
        )
    }

    $allReviewTasks += $reviewTasks
}

Write-Host "Found $($allReviewTasks.Count) tasks in review status across $($listIdsToQuery.Count) boards"
```

### Step 2: For Each Task

1. **Get Task Details**
   ```powershell
   C:\scripts\tools\clickup-sync.ps1 -Action show -TaskId "<task-id>"
   ```

2. **Find Linked PR**
   - Check task description for PR links
   - Search GitHub for PRs mentioning task ID
   - Check PR body for ClickUp task references

3. **Fetch PR Details**
   ```bash
   gh pr view <pr-number> --json number,title,body,state,files,commits
   ```

4. **🚨 CRITICAL: Check Merge Status**
   ```bash
   gh pr view <pr-number> --json mergeable,mergeStateStatus
   ```

   **REQUIRED CHECK BEFORE APPROVAL:**
   - `mergeStateStatus` must be `"CLEAN"` (not `"DIRTY"`, `"BEHIND"`, or `"UNSTABLE"`)
   - `mergeable` must be `"MERGEABLE"` (not `"CONFLICTING"`)

   **If conflicts detected:**
   1. ❌ REJECT the PR (post comment explaining)
   2. ❌ Move ClickUp task back to "to do" status
   3. ❌ Comment on task: "PR rejected - merge conflicts with develop branch"
   4. ✅ Explain how to resolve: merge develop into feature branch, resolve conflicts, push
   5. ⏸️ STOP review process - do not proceed to code analysis

   **Example rejection comment:**
   ```markdown
   ## ⚠️ REVIEW FAILED - Merge Conflicts Detected

   **Merge Status:** CONFLICTING ❌
   **State:** DIRTY ❌

   This PR cannot be merged because it has conflicts with the `develop` branch.

   **Required Actions:**
   1. Merge latest `develop` into your feature branch
   2. Resolve all merge conflicts
   3. Test that application builds and runs
   4. Push resolved changes
   5. Request re-review

   **Resolution Commands:**
   ```bash
   git checkout <feature-branch>
   git pull origin develop
   # Resolve conflicts
   git add .
   git commit -m "chore: Merge develop and resolve conflicts"
   git push origin <feature-branch>
   ```

   Moving task back to 'to do' status.
   ```

5. **🚨 CRITICAL: Build & Test Before Approval**

   **MANDATORY: Pull latest develop, build, and test BEFORE approval**

   ```bash
   # Allocate worktree
   # Use allocate-worktree skill or manual allocation

   # For projects requiring paired worktrees (client-manager, artrevisionist):
   # - client-manager requires hazina worktree
   # - artrevisionist requires hazina worktree

   cd /c/Projects/worker-agents/agent-XXX/<repo>

   # Pull latest develop into branch
   git fetch origin develop
   git merge origin/develop --no-edit

   # If conflicts arise:
   # - Resolve conflicts
   # - Commit resolution
   # - Push to branch
   # - Continue testing

   # Build backend (if applicable)
   dotnet build --configuration Release

   # Build frontend (if applicable)
   cd frontend-dir
   npm install  # If node_modules missing
   npm run build

   # Run Playwright tests (if they exist)
   npx playwright test

   # Fix any errors found
   # - Build errors: Fix code issues
   # - Test failures: Fix failing tests or update tests if behavior intentionally changed
   # - Commit and push fixes
   ```

   **If build or tests fail:**
   1. ❌ DO NOT approve PR
   2. ❌ Comment on PR explaining failures
   3. ❌ Move ClickUp task to "blocked" or keep in "review"
   4. ✅ Provide specific error messages and fix suggestions
   5. ⏸️ Wait for developer to fix issues

   **Only proceed to approval if:**
   - ✅ Latest develop merged successfully
   - ✅ Backend builds without errors
   - ✅ Frontend builds without errors
   - ✅ All Playwright tests pass (if tests exist)
   - ✅ No new errors introduced

6. **Analyze Code Quality**
   - Review file changes
   - Check for code quality issues
   - Verify MoSCoW requirements met
   - Ensure tests included (or acknowledge if no tests exist yet)
   - Check documentation updates

5. **Generate Review**
   Create comprehensive review covering:
   - **Functionality**: Does it meet requirements?
   - **Code Quality**: Clean, maintainable, follows patterns?
   - **Testing**: Are tests adequate?
   - **Documentation**: Is it documented?
   - **MoSCoW Compliance**: MUST/SHOULD items delivered?
   - **Issues Found**: Any bugs or concerns?
   - **Recommendations**: Suggestions for improvement

6. **Post Review Comment & Update Status**

   **If APPROVED and merged:**
   ```powershell
   # Post approval comment
   C:\scripts\tools\clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
   ✅ CODE REVIEW - APPROVED

   PR: https://github.com/org/repo/pull/<number>
   Merge Commit: https://github.com/org/repo/commit/<sha>

   Review Summary:
   - Build: ✅ Success
   - Tests: ✅ All passing
   - Code Quality: ✅ Good
   - MUST HAVE items: ✅ Complete

   Merged to develop. Moving to TESTING.

   -- Claude Code Reviewer
   "

   # Move to TESTING (only after merge!)
   C:\scripts\tools\clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "testing"
   ```

   **If REJECTED (conflicts, build failures, quality issues):**
   ```powershell
   # Post rejection comment
   C:\scripts\tools\clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
   ❌ CODE REVIEW - CHANGES REQUESTED

   PR: https://github.com/org/repo/pull/<number>

   Issues Found:
   1. [Specific issue with file/line reference]
   2. [Another specific issue]

   Required Actions:
   - [Actionable fix 1]
   - [Actionable fix 2]

   Moving to TODO for rework.

   -- Claude Code Reviewer
   "

   # Move back to TODO
   C:\scripts\tools\clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "todo"

   # Optionally reassign to original implementer
   C:\scripts\tools\clickup-sync.ps1 -Action update -TaskId "<task-id>" -Assignee "<original-assignee-id>"
   ```

### Step 3: Summary Report

Generate summary of all reviewed tasks with recommendations.

## Review Template

```markdown
📝 CODE REVIEW (Automated by Claude Code Agent)

## PR Analysis
- **PR #**: {number}
- **Title**: {title}
- **Status**: {state}
- **Files Changed**: {count}
- **Commits**: {count}

## Functionality Review ✅/❌
{Analysis of whether PR meets task requirements}

## Code Quality Assessment ✅/⚠️/❌
{Analysis of code quality, patterns, maintainability}

## Testing Coverage ✅/⚠️/❌
{Analysis of test coverage and quality}

## Documentation ✅/⚠️/❌
{Analysis of code comments, README updates, etc.}

## MoSCoW Compliance ✅/⚠️
- MUST HAVE: {status}
- SHOULD HAVE: {status}
- COULD HAVE: {status}

## Issues Found
{List of concerns, bugs, or problems}

## Recommendations
1. {Recommendation 1}
2. {Recommendation 2}

## Verdict
✅ APPROVED - Ready to merge
⚠️ APPROVED WITH COMMENTS - Merge but address comments in follow-up
❌ CHANGES REQUESTED - Needs fixes before merge

---
Review conducted by Claude Code Agent
Date: {timestamp}
```

## No PR Found?

If task is in review but has no PR:

```markdown
📝 CODE REVIEW (Automated by Claude Code Agent)

## Status
⚠️ Task is in REVIEW status but no linked PR was found.

## Possible Reasons
1. PR not yet created
2. PR link not added to task description
3. Task waiting for requirements review (not code review)
4. PR in different repository

## Recommendations
- If code is complete: Create PR and link it to task
- If waiting for requirements: Move to "planned" or "blocked"
- If PR exists: Add link to task description

## Next Steps
Please clarify the review status:
- Is code ready for review? → Create PR
- Is this requirements review? → Update status
- Is PR elsewhere? → Link it

---
Review conducted by Claude Code Agent
Date: {timestamp}
```

## Integration with Existing Workflow

### Before Merging PR

1. ClickUp task MUST be in "review" status
2. Run `clickup-reviewer` skill
3. Address any concerns raised
4. Get approval from reviewer
5. Merge PR
6. Update task to "done"

### Quality Gates

**MUST HAVE for approval:**
- ✅ **PR merge status is CLEAN (no conflicts with develop)** ⚠️ CRITICAL
- ✅ All MUST HAVE requirements implemented
- ✅ No critical bugs found
- ✅ Basic tests present
- ✅ Code compiles/builds successfully

**SHOULD HAVE for approval:**
- ✅ SHOULD HAVE requirements mostly implemented
- ✅ Good code quality
- ✅ Comprehensive tests
- ✅ Documentation updated

**COULD DEFER:**
- ⚠️ COULD HAVE features (can be deferred)
- ⚠️ Minor code style issues
- ⚠️ Additional tests (if basic coverage exists)

## Examples

### Example 1: Full PR Review

```
Task: 869bz901c - Topics need featured image
PR: #XX - feat: Add featured image support for topics

Review:
✅ APPROVED - All MUST HAVE items complete
- Topics now display featured images ✅
- Fallback image handling ✅
- Upload UI functional ✅

⚠️ Minor improvements suggested:
- Add image optimization
- Add alt text field

Recommendation: MERGE and create follow-up task for improvements.
```

### Example 2: Missing PR

```
Task: 869bz901c - Topics need featured image
PR: NOT FOUND

⚠️ Task in review but no PR linked.
Recommendation: Create PR or clarify review status.
```

## Files

**Main Skill**: `C:\scripts\.claude\skills\clickup-reviewer\SKILL.md`
**Helper Script**: `C:\scripts\tools\clickup-review-automation.ps1` (to be created)

## Related Skills

- `clickhub-coding-agent` - For implementing ClickUp tasks
- `github-workflow` - For PR management
- `multi-agent-conflict` - For coordination

## Configuration

**Project Mapping** (from `clickup-config.json`):
- art-revisionist: List ID `901211612245`
- client-manager: List ID `901214097647`
- hazina: List ID `901215559249`

## Notes

- Review is automated but should be supplemented with human judgment
- Focus on objective criteria (functionality, tests, documentation)
- Be constructive in feedback
- Recommend specific improvements, not just criticism
- If uncertain, flag for human review

---

**Created**: 2026-02-07
**Author**: Claude Code Agent
**Status**: ACTIVE
**Invocation**: "run the clickup reviewer" or "review clickup tasks"
