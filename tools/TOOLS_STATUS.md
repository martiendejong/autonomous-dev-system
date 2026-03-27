# Tools Status Tracker

**Last Updated:** 2026-01-11 04:50
**Total Tools:** 10 built, 40 planned
**Status:** Active development paused - use existing tools as appropriate

---

## Built Tools (1-10)

### Tool 1: Stale Branch Cleaner ✅
**File:** `clean-stale-branches.sh`
**Status:** Built, not tested
**ROI:** 8.0
**When to Use:**
- After multiple PRs have been merged
- Weekly cleanup routine
- When branch list gets cluttered
**Testing:** Not yet tested in production

---

### Tool 2: Bulk PR Status ✅
**File:** `pr-status.sh`
**Status:** Built, not tested
**ROI:** 7.0
**When to Use:**
- Start of work session (see all PRs at once)
- Before creating new PR (check current state)
- When user asks "what PRs are open?"
- When checking CI status across repos
**Testing:** Not yet tested in production

---

### Tool 3: Multi-Repo Dashboard ✅
**File:** `repo-dashboard.sh`
**Status:** Built, tested, bugs fixed
**ROI:** 4.5
**When to Use:**
- **STARTUP PROTOCOL:** Run at beginning of EVERY session
- When user asks for environment status
- Before allocating worktrees (check agent pool)
- Morning routine / status check
**Testing:** ✅ Tested successfully, jq fallback working
**Known Issues:** None - all bugs fixed

---

### Tool 4: Worktree Health Checker ✅
**File:** `check-worktree-health.sh`
**Status:** Built, not tested
**ROI:** 4.5
**When to Use:**
- When worktree operations fail unexpectedly
- When pool shows BUSY but directories missing
- Weekly maintenance routine
- After finding stale allocations
- When user reports resource issues
**Testing:** Not yet tested in production

---

### Tool 5: Pre-commit Hook Manager ✅
**File:** `install-hooks.sh`
**Status:** Built, not tested
**ROI:** 4.0
**When to Use:**
- First-time setup of new repo
- After user experiences commit mistakes (conflict markers, debugger statements)
- When setting up new worktree (optional)
**Testing:** Not yet tested in production

---

### Tool 6: TODO Tracker ✅
**File:** `find-todos.sh`
**Status:** Built, not tested
**ROI:** 5.3
**When to Use:**
- When planning refactoring work
- When user asks "what needs to be done?"
- Before release (check for unresolved TODOs)
- When generating task lists
**Testing:** Not yet tested in production

---

### Tool 7: Config Sync ✅
**File:** `sync-configs.sh`
**Status:** Built, not tested
**ROI:** 4.0
**When to Use:**
- After updating appsettings.json in base repo
- When worktree has config issues
- After environment variable changes
- When user reports "config not working in worktree"
**Testing:** Not yet tested in production

---

### Tool 8: Agent Activity Report ✅
**File:** `agent-activity.sh`
**Status:** Built, not tested
**ROI:** 3.8
**When to Use:**
- When multiple agents are BUSY (check what they're doing)
- When user asks "what's happening with my PRs?"
- To identify inactive agents (>2hr)
- Resource management reviews
**Testing:** Not yet tested in production

---

### Tool 9: Test Coverage Reporter ✅
**File:** `coverage-report.sh`
**Status:** Built, not tested
**ROI:** 3.5
**When to Use:**
- After writing new code/features
- When user asks about test coverage
- Before creating PR (check coverage quality)
- When identifying untested code
**Testing:** Not yet tested in production

---

### Tool 10: Changelog Generator ✅
**File:** `generate-changelog.sh`
**Status:** Built, not tested
**ROI:** 3.2
**When to Use:**
- Before creating release tag
- When user asks "what changed?"
- Monthly/weekly status reports
- Documentation updates
**Testing:** Not yet tested in production

---

## Planned Tools (11-50)

See `C:\scripts\docs\TOOLS_INVENTORY.md` for complete list.

**Next highest ROI:**
- Tool 11: Dependency Update Checker (ROI 3.0)
- Tool 12: Port Conflict Resolver (ROI 3.0)
- Tool 13: Environment Validator (ROI 2.8)

**Status:** Development paused - will build when needed or requested

---

## Usage Guidelines for Claude

### CRITICAL: Use These Tools Proactively

**Do NOT wait for user to ask** - use tools automatically when appropriate:

1. **EVERY session start:**
   - Run `repo-dashboard.sh` to check environment state
   - Review output before starting work

2. **Before allocating worktree:**
   - Dashboard shows agent pool status
   - Check for stale allocations if needed with `check-worktree-health.sh`

3. **When user asks status questions:**
   - "What PRs are open?" → `pr-status.sh`
   - "What's the current state?" → `repo-dashboard.sh`
   - "What needs to be done?" → `find-todos.sh`

4. **Weekly maintenance:**
   - `clean-stale-branches.sh` after merging multiple PRs
   - `check-worktree-health.sh` to catch resource leaks

5. **When tools fail:**
   - Test the tool immediately
   - Fix bugs proactively
   - Update this status file
   - Log pattern in reflection.log.md

### Testing Protocol

When testing a tool for the first time:
1. Run with --dry-run if available
2. Verify output format
3. Check error handling
4. Test edge cases (no data, missing dependencies)
5. Update status file with results
6. Fix any bugs immediately

### Bug Reporting Format

When a tool has issues:
```markdown
**Tool:** [name]
**Issue:** [description]
**Fix Applied:** [solution]
**Status:** Fixed / Needs Work
```

---

## Maintenance Log

### 2026-01-11 04:50
- Created TOOLS_STATUS.md
- All 10 tools built and documented
- Only repo-dashboard.sh tested so far
- Development paused per user directive

---

**Next Review:** When tools are used in production or issues arise
