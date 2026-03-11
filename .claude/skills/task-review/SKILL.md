---
name: task-review
description: Comprehensive task review workflow - verify PR exists, test changes, merge develop, resolve conflicts, code review, and enforce completion criteria. Use when reviewing ClickUp tasks or similar task management systems.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task
user-invocable: true
---

# Task Review - Comprehensive Quality Gate System

**Purpose:** Industry best-practice task review workflow that enforces quality gates, verifies completion, and automates merge/testing flow.

## When to Use This Skill

**Use when:**
- User requests task review or code review
- ClickUp task is in "review" status
- Need to verify task completion before merging
- Implementing comprehensive quality control

**Don't use when:**
- Task is still in "todo" or "in progress" (not ready for review)
- Simple question about task status (use direct ClickUp query)

## Critical Success Indicators

**🚨 CRITICAL GATE: Pull Request Existence**

> "No pull request is a serious indicator that the task is not yet completed"

If NO PR exists → Task review FAILS → Move back to TODO with critical feedback.

## Prerequisites

- Task management system configured (ClickUp)
- Git repository access
- GitHub CLI (gh) installed
- Build/test tools for project type

## Workflow Steps

### Step 1: Verify Pull Request Exists (CRITICAL GATE)

**This is the #1 quality indicator. If this fails, entire review fails.**

```bash
# Get task details
clickup-sync.ps1 -Action show -TaskId "<task-id>"

# Extract PR number/URL from task comments or description
# Search for patterns:
# - github.com/.../pull/XXX
# - PR #XXX
# - #XXX in comments

# If no PR found, search GitHub by task ID
gh pr list --search "<task-id>" --state all --limit 5
```

**Decision:**
- ✅ **PR exists** → Continue to Step 2
- ❌ **NO PR found** → **FAIL IMMEDIATELY** → Skip to Step 10 (Critical Failure)

**Example critical failure comment:**
```markdown
⚠️ TASK REVIEW FAILED - NO PULL REQUEST

This task cannot be reviewed because there is NO pull request associated with it.

**Critical Issues:**
- No PR link found in task comments
- No PR found on GitHub matching task ID <task-id>
- No code changes committed to any branch

**This is a serious indicator that the task is not yet completed.**

**Required Actions:**
1. Complete implementation
2. Commit all changes
3. Push to feature branch
4. Create pull request
5. Link PR to this task
6. Request re-review

Moving task back to 'todo' status.

-- Task Review System (FAILED)
```

### Step 2: Analyze Code Changes vs Problem Statement

**Verify that code changes actually solve the stated problem.**

```bash
# Fetch PR details
PR_NUM="<pr-number>"
gh pr view $PR_NUM --json title,body,files

# Read task description to understand problem
clickup-sync.ps1 -Action show -TaskId "<task-id>"

# Review changed files
gh pr diff $PR_NUM
```

**Questions to answer:**
- Does the PR address all requirements in task description?
- Are the code changes relevant to the problem?
- Are there extraneous changes unrelated to task?
- Is anything missing from requirements?

**Decision:**
- ✅ **Changes solve problem** → Continue to Step 3
- ⚠️ **Partially solves problem** → Note in code review, continue
- ❌ **Does NOT solve problem** → Skip to Step 9 (Changes Requested)

### Step 3: Allocate Worktree and Checkout Branch

```bash
# Find FREE worktree seat
POOL_FILE="C:/scripts/_machine/worktrees.pool.md"
SEAT=$(grep "| agent-" "$POOL_FILE" | grep "FREE" | head -1 | awk '{print $2}')

if [ -z "$SEAT" ]; then
    echo "⚠️ No free worktree seats - provision new one"
    # Provision agent-014, agent-015, etc.
fi

# Mark seat BUSY
# Edit worktrees.pool.md

# Get PR branch name
PR_BRANCH=$(gh pr view $PR_NUM --json headRefName --jq '.headRefName')
REPO=$(gh pr view $PR_NUM --json baseRepository --jq '.baseRepository.name')

# Create worktree
WORKTREE="/c/Projects/worker-agents/$SEAT/$REPO"
cd "/c/Projects/$REPO"

# Remove existing if present
git worktree remove "$WORKTREE" --force 2>/dev/null

# Add new worktree
git fetch origin "$PR_BRANCH"
git worktree add "$WORKTREE" "$PR_BRANCH"

cd "$WORKTREE"
```

### Step 4: Test and Build

```bash
# Determine project type and run appropriate build/test commands

# For npm/Node.js projects:
if [ -f "package.json" ]; then
    npm install
    npm run build 2>&1 | tee build.log
    BUILD_STATUS=$?

    # Run tests if available
    if npm run | grep -q "test"; then
        npm test 2>&1 | tee test.log
        TEST_STATUS=$?
    fi
fi

# For .NET projects:
if [ -f "*.csproj" ] || [ -f "*.sln" ]; then
    dotnet restore
    dotnet build --configuration Release 2>&1 | tee build.log
    BUILD_STATUS=$?

    dotnet test --configuration Release 2>&1 | tee test.log
    TEST_STATUS=$?
fi

# For Python projects:
if [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
    pip install -r requirements.txt
    python -m pytest 2>&1 | tee test.log
    TEST_STATUS=$?
fi

# Capture results
if [ $BUILD_STATUS -ne 0 ]; then
    echo "❌ BUILD FAILED"
    BUILD_RESULT="FAILED"
else
    echo "✅ BUILD PASSED"
    BUILD_RESULT="PASSED"
fi

if [ -n "$TEST_STATUS" ] && [ $TEST_STATUS -ne 0 ]; then
    echo "❌ TESTS FAILED"
    TEST_RESULT="FAILED"
elif [ -n "$TEST_STATUS" ]; then
    echo "✅ TESTS PASSED"
    TEST_RESULT="PASSED"
else
    TEST_RESULT="SKIPPED"
fi
```

### Step 5: Merge Develop Back Into Branch

**CRITICAL: Ensure branch is up-to-date with latest develop**

```bash
# Fetch latest develop
git fetch origin develop

# Attempt merge
git merge origin/develop --no-edit

MERGE_STATUS=$?

if [ $MERGE_STATUS -ne 0 ]; then
    echo "⚠️ MERGE CONFLICTS DETECTED"
    MERGE_RESULT="CONFLICTS"

    # List conflicting files
    git status --short | grep "^UU" > conflicts.txt
else
    echo "✅ MERGE SUCCESSFUL"
    MERGE_RESULT="SUCCESS"
fi
```

### Step 6: Resolve Conflicts (If Any)

**If conflicts exist, attempt automatic resolution:**

```bash
if [ "$MERGE_RESULT" = "CONFLICTS" ]; then
    # Read conflicting files
    while read -r file; do
        FILE_PATH=$(echo "$file" | awk '{print $2}')

        # Simple conflict resolution strategies:
        # 1. If conflict is in package-lock.json, regenerate it
        if [[ "$FILE_PATH" == "package-lock.json" ]]; then
            git checkout --theirs package-lock.json
            npm install
            git add package-lock.json
        fi

        # 2. For code files, prefer incoming changes if minor
        # (More complex - may need manual review)

    done < conflicts.txt

    # Check if all resolved
    REMAINING_CONFLICTS=$(git status --short | grep "^UU" | wc -l)

    if [ $REMAINING_CONFLICTS -eq 0 ]; then
        git commit -m "chore: Merge develop and resolve conflicts"
        git push origin "$PR_BRANCH"
        CONFLICT_RESOLUTION="AUTO_RESOLVED"
    else
        CONFLICT_RESOLUTION="MANUAL_REQUIRED"
    fi
fi
```

### Step 7: Re-test After Merge

**CRITICAL: Verify build still works after merge**

```bash
if [ "$MERGE_RESULT" = "SUCCESS" ] || [ "$CONFLICT_RESOLUTION" = "AUTO_RESOLVED" ]; then
    # Re-run build
    npm run build 2>&1 | tee build-post-merge.log
    POST_MERGE_BUILD=$?

    # Re-run tests
    npm test 2>&1 | tee test-post-merge.log
    POST_MERGE_TEST=$?

    if [ $POST_MERGE_BUILD -ne 0 ]; then
        POST_MERGE_RESULT="BUILD_FAILED"
    elif [ $POST_MERGE_TEST -ne 0 ]; then
        POST_MERGE_RESULT="TEST_FAILED"
    else
        POST_MERGE_RESULT="PASSED"
    fi
fi
```

### Step 8: Generate Comprehensive Code Review

**Analyze all aspects and write detailed review:**

```bash
# Fetch PR stats
PR_STATS=$(gh pr view $PR_NUM --json files,additions,deletions,commits)
FILE_COUNT=$(echo "$PR_STATS" | jq '.files | length')
ADDITIONS=$(echo "$PR_STATS" | jq '.additions')
DELETIONS=$(echo "$PR_STATS" | jq '.deletions')
COMMIT_COUNT=$(echo "$PR_STATS" | jq '.commits | length')

# Determine verdict
if [ "$BUILD_RESULT" = "FAILED" ]; then
    VERDICT="❌ CHANGES REQUESTED"
    RECOMMENDATION="Fix build errors before merging"
elif [ "$TEST_RESULT" = "FAILED" ]; then
    VERDICT="❌ CHANGES REQUESTED"
    RECOMMENDATION="Fix failing tests before merging"
elif [ "$CONFLICT_RESOLUTION" = "MANUAL_REQUIRED" ]; then
    VERDICT="⚠️ CHANGES REQUESTED"
    RECOMMENDATION="Resolve merge conflicts with develop"
elif [ "$POST_MERGE_RESULT" = "BUILD_FAILED" ] || [ "$POST_MERGE_RESULT" = "TEST_FAILED" ]; then
    VERDICT="❌ CHANGES REQUESTED"
    RECOMMENDATION="Fix issues introduced by develop merge"
else
    VERDICT="✅ APPROVED"
    RECOMMENDATION="Merge immediately"
fi
```

**Generate review comment:**

```bash
REVIEW=$(cat <<EOF
## $VERDICT

**Reviewer:** Claude Code Agent (Automated Task Review)
**Date:** $(date '+%Y-%m-%d %H:%M:%S')
**ClickUp Task:** https://app.clickup.com/t/<task-id>

---

## Summary

**PR #$PR_NUM:** $(gh pr view $PR_NUM --json title --jq '.title')

**Changes:**
- Files changed: $FILE_COUNT
- Lines added: +$ADDITIONS
- Lines removed: -$DELETIONS
- Commits: $COMMIT_COUNT

---

## Verification Checks

### 1. Pull Request ✅
- PR exists and is linked to task
- PR has meaningful title and description

### 2. Code Changes vs Problem
$([ "<code-matches-problem>" = "yes" ] && echo "- ✅ Code changes address all task requirements" || echo "- ⚠️ Some requirements may be missing")
- Changes are relevant and focused

### 3. Build Status
- Initial build: $BUILD_RESULT $([ "$BUILD_RESULT" = "PASSED" ] && echo "✅" || echo "❌")
$([ -n "$POST_MERGE_RESULT" ] && echo "- Post-merge build: $POST_MERGE_RESULT $([ "$POST_MERGE_RESULT" = "PASSED" ] && echo "✅" || echo "❌")" || echo "")

### 4. Test Status
- Initial tests: $TEST_RESULT $([ "$TEST_RESULT" = "PASSED" ] && echo "✅" || [ "$TEST_RESULT" = "SKIPPED" ] && echo "⚠️" || echo "❌")
$([ -n "$POST_MERGE_TEST" ] && echo "- Post-merge tests: $([ $POST_MERGE_TEST -eq 0 ] && echo "PASSED ✅" || echo "FAILED ❌")" || echo "")

### 5. Develop Merge
- Merge status: $MERGE_RESULT $([ "$MERGE_RESULT" = "SUCCESS" ] && echo "✅" || echo "⚠️")
$([ "$CONFLICT_RESOLUTION" = "AUTO_RESOLVED" ] && echo "- Conflicts auto-resolved ✅" || [ "$CONFLICT_RESOLUTION" = "MANUAL_REQUIRED" ] && echo "- ❌ Manual conflict resolution required" || echo "")

---

## Code Quality Notes

$([ $FILE_COUNT -le 5 ] && echo "✅ Small PR - easy to review" || [ $FILE_COUNT -le 15 ] && echo "✅ Medium PR - reasonable scope" || echo "⚠️ Large PR - consider splitting")

$([ $ADDITIONS -lt 200 ] && echo "✅ Minimal changes - low risk" || [ $ADDITIONS -lt 1000 ] && echo "✅ Moderate changes - review carefully" || echo "⚠️ Significant changes - thorough testing recommended")

---

## Detailed Feedback

$(if [ "$VERDICT" = "❌ CHANGES REQUESTED" ]; then
echo "**Issues Found:**"
[ "$BUILD_RESULT" = "FAILED" ] && echo "- Build errors detected (see build.log)"
[ "$TEST_RESULT" = "FAILED" ] && echo "- Test failures detected (see test.log)"
[ "$CONFLICT_RESOLUTION" = "MANUAL_REQUIRED" ] && echo "- Merge conflicts with develop require manual resolution"
[ "$POST_MERGE_RESULT" = "BUILD_FAILED" ] && echo "- Build breaks after merging develop"
[ "$POST_MERGE_RESULT" = "TEST_FAILED" ] && echo "- Tests fail after merging develop"
else
echo "**All Checks Passed:**"
echo "- Build successful ✅"
echo "- Tests passing ✅"
echo "- No merge conflicts ✅"
echo "- Code quality acceptable ✅"
fi)

---

## Verdict

**$VERDICT**

**Recommendation:** $RECOMMENDATION

$([ "$VERDICT" = "✅ APPROVED" ] && echo "**Merge Confidence:** HIGH - All quality gates passed" || echo "**Merge Confidence:** LOW - Rework required")

---

🤖 Automated Task Review by Claude Code Agent
EOF
)

# Post to GitHub PR
gh pr comment $PR_NUM --body "$REVIEW"
```

### Step 9: Handle Changes Requested (Rework Path)

**If review fails, provide clear feedback and move to TODO:**

```powershell
# Post detailed rework comment to ClickUp
clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
⚠️ TASK REVIEW FAILED - REWORK REQUIRED

**PR #$PR_NUM Review Result:** CHANGES REQUESTED

**Issues to Address:**
$(if [ "$BUILD_RESULT" = "FAILED" ]; then
echo "1. **Build Errors:** Fix compilation/build errors"
echo "   - See build.log for details"
echo "   - Common causes: syntax errors, missing dependencies, type errors"
echo ""
fi)
$(if [ "$TEST_RESULT" = "FAILED" ]; then
echo "2. **Test Failures:** Fix failing unit/integration tests"
echo "   - See test.log for details"
echo "   - Ensure all test cases pass"
echo ""
fi)
$(if [ "$CONFLICT_RESOLUTION" = "MANUAL_REQUIRED" ]; then
echo "3. **Merge Conflicts:** Resolve conflicts with develop branch"
echo "   - Files with conflicts: $(cat conflicts.txt)"
echo "   - Merge develop and resolve manually"
echo ""
fi)

**Next Steps:**
1. Pull latest develop: \`git pull origin develop\`
2. Fix all issues listed above
3. Ensure build passes: \`npm run build\` (or appropriate command)
4. Ensure tests pass: \`npm test\`
5. Commit fixes
6. Push to branch
7. Request re-review

**Full Review:** See GitHub PR #$PR_NUM comments for detailed analysis

Moving task back to 'todo' status for rework.

-- Task Review System
"

# Move to TODO
clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "todo"
```

### Step 10: Handle Critical Failure (No PR)

**Special case: No PR exists at all**

```powershell
clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
🚨 CRITICAL: TASK REVIEW FAILED - NO PULL REQUEST

**This is a serious indicator that the task is not yet completed.**

**Missing:**
- No pull request found on GitHub
- No branch with changes pushed
- No code changes committed

**This task cannot be reviewed without a pull request.**

**Required Actions Before Re-Review:**
1. Complete implementation
2. Commit all changes to a feature branch
3. Push branch to GitHub
4. Create pull request targeting 'develop' branch
5. Link PR URL in task comments
6. Update task description with PR number
7. Request new review

**Quality Standards:**
- All code must be committed and pushed
- PR must have clear title and description
- PR must include test plan
- Build must pass locally before creating PR

Moving task to 'todo' status. Task CANNOT proceed to testing without a PR.

-- Task Review System (CRITICAL FAILURE)
"

clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "todo"
```

### Step 11: Handle Missing Information (Feedback Path)

**If information is missing but work is otherwise complete:**

```powershell
clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
ℹ️ TASK REVIEW - INFORMATION NEEDED

**PR #$PR_NUM** is technically sound but missing information:

**Missing Information:**
- [Specific information needed, e.g., "How should edge case X be handled?"]
- [Another missing detail]

**Current State:**
- Build: PASSED ✅
- Tests: PASSED ✅
- Code quality: Acceptable ✅

**Action Required:**
Please provide the missing information in comments. Once clarified, review will continue.

-- Task Review System
"

clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "feedback"
```

### Step 12: Merge to Develop (Approval Path)

**If review APPROVED, merge PR automatically:**

```bash
# Merge PR
gh pr merge $PR_NUM --merge --delete-branch

# Verify merge succeeded
MERGE_SUCCESS=$?

if [ $MERGE_SUCCESS -eq 0 ]; then
    echo "✅ PR merged successfully"

    # Switch to develop and pull
    cd "/c/Projects/$REPO"
    git checkout develop
    git pull origin develop

else
    echo "❌ PR merge failed"
    # Post error comment
fi
```

### Step 13: Verify Develop Still Builds

**CRITICAL: Ensure develop branch is not broken after merge**

```bash
cd "/c/Projects/$REPO"
git checkout develop
git pull origin develop

# Build develop
npm run build 2>&1 | tee develop-build.log
DEVELOP_BUILD=$?

if [ $DEVELOP_BUILD -ne 0 ]; then
    echo "🚨 CRITICAL: Develop branch broken after merge!"
    DEVELOP_STATUS="BROKEN"
else
    echo "✅ Develop branch builds successfully"
    DEVELOP_STATUS="HEALTHY"
fi
```

### Step 14: Fix Develop If Broken

**If develop breaks, fix it IMMEDIATELY and DIRECTLY on develop:**

```bash
if [ "$DEVELOP_STATUS" = "BROKEN" ]; then
    echo "🔧 HOTFIX MODE: Fixing develop directly"

    # Analyze build errors
    cat develop-build.log

    # Apply fixes directly on develop (NO WORKTREE, NO PR)
    # This is HOTFIX MODE per ZERO_TOLERANCE_RULES

    # Example fixes:
    # - Missing dependency: npm install <package>
    # - Syntax error: fix directly
    # - Merge artifact: resolve immediately

    # Commit fix
    git add -A
    git commit -m "hotfix: Fix develop build after PR #$PR_NUM merge

Critical fix to restore develop branch to working state.

Issue: [describe build error]
Fix: [describe fix applied]

PR: #$PR_NUM"

    git push origin develop

    # Verify fix
    npm run build
    if [ $? -eq 0 ]; then
        echo "✅ Develop fixed and building"
        DEVELOP_STATUS="FIXED"
    else
        echo "❌ Develop still broken - escalate to user"
        DEVELOP_STATUS="ESCALATE"
    fi
fi
```

### Step 15: Move to Testing (Success Path)

**Only if ALL checks pass:**

```powershell
# Post success comment to ClickUp
clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
✅ TASK REVIEW APPROVED - MERGED TO DEVELOP

**PR #$PR_NUM** has been reviewed and merged.

**Review Summary:**
- Pull request: ✅ Exists and linked
- Code changes: ✅ Solve stated problem
- Build status: ✅ Passed
- Test status: ✅ Passed
- Develop merge: ✅ No conflicts
- Post-merge build: ✅ Passed
- Develop health: ✅ $([ "$DEVELOP_STATUS" = "HEALTHY" ] && echo "Branch healthy" || echo "Fixed and stable")

**Merge Details:**
- Branch merged: $PR_BRANCH
- Merged at: $(date '+%Y-%m-%d %H:%M:%S')
- Develop commit: $(git rev-parse --short develop)

**Next Steps:**
This task is ready for user acceptance testing. Please verify:
1. Feature works as expected in develop branch
2. No regressions introduced
3. Meets all acceptance criteria

Once validated, move to 'done' status.

-- Task Review System (APPROVED)
"

# Move to TESTING
clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "testing"
```

### Step 16: Release Worktree

**Clean up review worktree:**

```bash
# Clean worktree
rm -rf "/c/Projects/worker-agents/$SEAT/$REPO"

# Update pool to FREE
# Edit C:/scripts/_machine/worktrees.pool.md

# Log release
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $SEAT | RELEASE | task-review | Task <task-id> review complete" >> C:/scripts/_machine/worktrees.activity.md

# Prune worktrees
cd "/c/Projects/$REPO" && git worktree prune
```

## Success Criteria

✅ **Task review is complete ONLY IF:**
1. ✅ Pull request existence verified (CRITICAL GATE)
2. ✅ Code changes analyzed vs problem statement
3. ✅ Branch checked out in worktree
4. ✅ Build tested (passed or failed documented)
5. ✅ Tests run (passed or failed documented)
6. ✅ Latest develop merged into branch
7. ✅ Conflicts resolved (auto or manual flagged)
8. ✅ Comprehensive code review written
9. ✅ Feedback posted to ClickUp with clear action items
10. ✅ Task moved to correct status:
    - **testing** if approved and merged
    - **todo** if rework required
    - **feedback** if information missing
11. ✅ PR merged to develop (if approved)
12. ✅ Develop branch verified as healthy
13. ✅ Develop fixed if broken (HOTFIX MODE)
14. ✅ Worktree released

## Decision Tree

```
Start Task Review
  ↓
Does PR exist?
  ↓
├─ NO → CRITICAL FAIL → Post failure comment → Move to TODO → END
  ↓
├─ YES → Continue
     ↓
     Checkout branch, build, test
       ↓
       Merge develop
         ↓
         Conflicts?
           ↓
           ├─ YES → Attempt auto-resolve → Still conflicts?
                                             ↓
                                             ├─ YES → CHANGES REQUESTED → Move to TODO
                                             ├─ NO → Continue
           ├─ NO → Continue
         ↓
         Re-build, re-test
           ↓
           All checks pass?
             ↓
             ├─ YES → APPROVED → Merge PR → Verify develop → Move to TESTING
             ├─ NO → CHANGES REQUESTED → Post rework → Move to TODO
```

## Common Issues

### Issue: No PR Found

**Symptom:** Task claims to be complete but has no PR

**Cause:** Implementation incomplete or PR not linked

**Solution:** FAIL review immediately, provide critical feedback

### Issue: Build Fails After Develop Merge

**Symptom:** Branch builds fine but breaks after merging develop

**Cause:** Develop has conflicting changes

**Solution:** Request rework to fix compatibility

### Issue: Develop Breaks After PR Merge

**Symptom:** Develop branch broken after merging approved PR

**Cause:** Subtle integration issue not caught in review

**Solution:** Enter HOTFIX MODE, fix directly on develop, no PR needed

### Issue: Tests Pass Locally But Fail in Review

**Symptom:** Original implementer says tests pass, but fail in review worktree

**Cause:** Missing dependencies, environment differences

**Solution:** Document in review, request fix

## Examples

### Example 1: Successful Review and Merge

**Task:** Add dark mode toggle
**PR:** #157 (exists ✅)

**Review Flow:**
1. PR exists ✅
2. Code adds theme toggle component ✅
3. Build passes ✅
4. Tests pass ✅
5. Merge develop: no conflicts ✅
6. Re-build: passes ✅
7. Verdict: APPROVED ✅
8. Merge to develop ✅
9. Develop builds ✅
10. Move to testing ✅

### Example 2: Changes Requested

**Task:** Fix login bug
**PR:** #158 (exists ✅)

**Review Flow:**
1. PR exists ✅
2. Code changes look correct ✅
3. Build passes ✅
4. Tests FAIL ❌ (2 test failures)
5. Verdict: CHANGES REQUESTED ❌
6. Post detailed feedback with test failure logs
7. Move to TODO
8. DO NOT merge

### Example 3: Critical Failure - No PR

**Task:** Implement user profile export
**PR:** NONE ❌

**Review Flow:**
1. PR exists? NO ❌
2. Search GitHub: no PR found ❌
3. CRITICAL FAILURE
4. Post critical failure comment
5. Move to TODO
6. END REVIEW

### Example 4: Develop Breaks After Merge

**Task:** Update API client
**PR:** #159 (approved and merged ✅)

**Review Flow:**
1. Review passed ✅
2. PR merged ✅
3. Develop build: FAILED ❌
4. Enter HOTFIX MODE 🔧
5. Fix directly on develop (missing import)
6. Commit hotfix
7. Push to develop
8. Verify build passes ✅
9. Move task to testing ✅
10. Log incident in reflection.log.md

## Integration with ClickUp Workflow

**Task Status Transitions:**
- **review** → **testing** (if approved and merged)
- **review** → **todo** (if changes requested)
- **review** → **feedback** (if information missing)

**NEVER:**
- Move directly to **done** (only user does this)
- Skip **testing** phase
- Merge without running build/tests

## Related Skills

- `allocate-worktree` - For worktree allocation during review
- `release-worktree` - For worktree cleanup after review
- `github-workflow` - For PR operations
- `clickhub-coding-agent` - Uses this skill for reviewing tasks
- `auto-pr-review` - Lightweight version for automated reviews

---

**Created:** 2026-03-11
**Author:** Claude Code Agent (Industry Best Practices)
**Version:** 1.0.0
**Status:** PRODUCTION READY
