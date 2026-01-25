# Automation Tools Index

**Last Updated:** 2026-01-11
**Total Tools:** 12
**Location:** C:\scripts\tools\

## Quick Start

```bash
# Session Start (MANDATORY)
bash C:/scripts/tools/check-base-repos.sh    # Verify base repos on develop
bash C:/scripts/tools/repo-dashboard.sh      # Check environment state

# After Completing Work (MANDATORY)
bash C:/scripts/tools/complete-release.sh agent-XXX   # Full release with verification
```

---

## Tool Categories

### 🚨 Critical (Use Every Session)

| Tool | Purpose | When to Use | Exit Code |
|------|---------|-------------|-----------|
| **check-base-repos.sh** | Verify all base repos on `develop` (RULE 3B) | Session start, before worktree allocation | 0=healthy, 1=violation |
| **repo-dashboard.sh** | Environment overview (repos, PRs, CI, agent pool) | Session start, status checks | - |
| **complete-release.sh** | Full worktree release (clean + prune + verify) | After creating PR, fixing incomplete releases | 0=success, 1=error |

### 📊 Status & Monitoring

| Tool | Purpose | Output | Notes |
|------|---------|--------|-------|
| **pr-status.sh** | All open PRs with CI status | Table: PR#, Title, State, Mergeable, CI | ROI 7.0 |
| **agent-activity.sh** | Recent agent activity report | Last 10 allocations/releases | ROI 3.8 |
| **find-todos.sh** | All TODO/FIXME comments | File paths with line numbers | ROI 5.3 |

### 🔧 Maintenance

| Tool | Purpose | When to Use | ROI |
|------|---------|-------------|-----|
| **clean-stale-branches.sh** | Delete merged branches | After merging multiple PRs, weekly | 8.0 |
| **check-worktree-health.sh** | Detect stale allocations (BUSY > 2hr) | Before allocation, resource issues | 4.5 |
| **sync-configs.sh** | Sync config files across repos | After config changes | 4.0 |

### 🧪 Development

| Tool | Purpose | Language | Notes |
|------|---------|----------|-------|
| **cs-format.ps1** | C# code formatting (dotnet format wrapper) | PowerShell | Run after editing .cs files |
| **cs-autofix/** | Automatic compile error fixes | .NET 9.0 | Removes unused usings, fixes formatting |
| **coverage-report.sh** | Test coverage analysis | Bash | ROI 3.5 |

### 📝 Project Management

| Tool | Purpose | Output Format | ROI |
|------|---------|---------------|-----|
| **generate-changelog.sh** | PR changelog | Markdown | 3.2 |
| **install-hooks.sh** | Pre-commit checks | Git hooks | 4.0 |

---

## 🆕 New Tools (2026-01-11)

### complete-release.sh
- **Problem:** Incomplete releases (pool says FREE but worktree locked)
- **Solution:** Automated cleanup: `rm -rf` + `git worktree prune` + verification
- **Pattern:** 79 (Two-Phase Release Verification)

### check-base-repos.sh
- **Problem:** Base repos on wrong branch → cascading worktree failures
- **Solution:** Enforce RULE 3B (base repos MUST be on develop)
- **Pattern:** 80 (Mandatory Base Repo Verification)
- **Impact:** Prevented hours of debugging in first use

---

## Usage Examples

### Session Start Protocol
```bash
# 1. Check base repo health
bash C:/scripts/tools/check-base-repos.sh
# If violations found, fix before proceeding

# 2. Get environment overview
bash C:/scripts/tools/repo-dashboard.sh
# Shows: branch status, open PRs, CI status, agent pool
```

### Before Allocating Worktree
```bash
# Verify base repos are on develop
bash C:/scripts/tools/check-base-repos.sh

# Check for stale allocations
bash C:/scripts/tools/check-worktree-health.sh
```

### After Completing Work
```bash
# 1. Create PR (gh pr create ...)

# 2. Fully release worktree
bash C:/scripts/tools/complete-release.sh agent-002

# 3. Verify environment is clean
bash C:/scripts/tools/repo-dashboard.sh
```

### Weekly Maintenance
```bash
# Clean merged branches
bash C:/scripts/tools/clean-stale-branches.sh

# Check for stale worktrees
bash C:/scripts/tools/check-worktree-health.sh

# Find TODOs to address
bash C:/scripts/tools/find-todos.sh
```

---

## Tool Output Examples

### check-base-repos.sh (Healthy)
```
=== Base Repo Health Check ===

✅ client-manager on develop
✅ hazina on develop
✅ artrevisionist on develop

✅ All base repos are healthy
```

### check-base-repos.sh (Violation Detected)
```
=== Base Repo Health Check ===

❌ client-manager on 'agent-001-logo-variation-enhancement' (should be develop)
   ✅ No uncommitted changes - safe to fix
   Fix: git -C client-manager checkout develop && git -C client-manager pull origin develop
✅ hazina on develop
✅ artrevisionist on develop

❌ Fix required: Restore affected repos to develop branch
```

### complete-release.sh
```
=== Completing release for agent-002 ===
Step 1: Cleaning worktree directory...
✅ Directory cleaned

Step 2: Pruning git worktree references...
  Pruning client-manager...
  Pruning hazina...
  Pruning artrevisionist...
✅ Git references pruned

Step 3: Verification...
✅ Directory is empty

Step 4: Checking pool status...
  Pool status: FREE

✅ Release complete for agent-002
```

---

## ROI Rankings

| Rank | Tool | ROI Score | Primary Benefit |
|------|------|-----------|-----------------|
| 1 | clean-stale-branches.sh | 8.0 | Prevents branch clutter |
| 2 | pr-status.sh | 7.0 | Single source of PR truth |
| 3 | find-todos.sh | 5.3 | Surfaces forgotten work |
| 4 | repo-dashboard.sh | 4.5 | Environment overview |
| 4 | check-worktree-health.sh | 4.5 | Detects stuck agents |
| 6 | sync-configs.sh | 4.0 | Config consistency |
| 6 | install-hooks.sh | 4.0 | Pre-commit quality |
| 8 | agent-activity.sh | 3.8 | Activity tracking |
| 9 | coverage-report.sh | 3.5 | Test quality insights |
| 10 | generate-changelog.sh | 3.2 | Release notes automation |
| - | check-base-repos.sh | NEW | RULE 3B enforcement |
| - | complete-release.sh | NEW | Prevents incomplete releases |

---

## Documentation Locations

- **Quick Reference:** C:\scripts\claude_info.txt (lines 4-42)
- **Full Details:** C:\scripts\tools\README.md
- **New Scripts:** C:\scripts\claude_info.txt (lines 2253-2375)
- **Patterns:** C:\scripts\claude_info.txt (Pattern 79, Pattern 80)
- **This Index:** C:\scripts\tools\TOOLS_INDEX.md

---

## Related Patterns

- **Pattern 79:** Two-Phase Release Verification (complete-release.sh)
- **Pattern 80:** Mandatory Base Repo Verification (check-base-repos.sh)
- **Pattern 63:** Agent Release Protocol
- **Pattern 59:** Post-Compaction Verification (Tier 1 = base repo check)
- **RULE 3B:** Base repos MUST ALWAYS be on develop

---

## Testing Status

| Tool | Status | Last Tested | Notes |
|------|--------|-------------|-------|
| repo-dashboard.sh | ✅ Tested | 2026-01-10 | Fully functional |
| check-base-repos.sh | ✅ Tested | 2026-01-11 | Caught real violation |
| complete-release.sh | ✅ Tested | 2026-01-11 | Successful release |
| pr-status.sh | ⏳ Needs testing | - | Build but not executed |
| Others | ⏳ Needs testing | - | Use and verify as needed |

---

**Maintained by:** Autonomous agents
**Update frequency:** After each new tool or significant enhancement
**Feedback:** Log issues in C:\scripts\_machine\reflection.log.md
