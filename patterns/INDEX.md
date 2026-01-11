# Pattern Library Index

**Last Updated:** 2026-01-11

This library contains 75+ documented solutions to common development issues. Patterns are organized by category for quick reference.

## 📋 How to Use

**Search by keyword:**
```bash
/patterns:search <keyword>
# Example: /patterns:search merge
```

**Browse by category:**
- Build & CI/CD Issues: Patterns 1-10
- Framework & Dependencies: Patterns 13-16
- Development Workflow: Patterns 17-26
- VS & Debugging: Patterns 27-37
- Frontend & Testing: Patterns 46-59
- Worktree Management: Patterns 63-67
- WordPress: Patterns 73-75

---

## 🔧 Build & CI/CD Issues

### Pattern 1: Missing Gitignored Config (MSB3030)
**Error:** `Could not copy appsettings.json because it was not found`
**Solution:** Use conditional MSBuild includes with template fallback
**File:** `build/pattern-001-missing-config.md`

### Pattern 2: Windows Project on Linux CI (NETSDK1100)
**Error:** `set EnableWindowsTargeting property to true`
**Solution:** Add `<EnableWindowsTargeting>true</EnableWindowsTargeting>`
**File:** `build/pattern-002-windows-targeting.md`

### Pattern 3: NuGet Package Downgrade (NU1605)
**Error:** `Detected package downgrade: Package from 9.0.0 to 8.0.5`
**Solution:** Upgrade to highest version in dependency chain
**File:** `build/pattern-003-nuget-downgrade.md`

### Pattern 8: Docker Tag Invalid Format
**Error:** `invalid tag "...:branch/-sha"`
**Solution:** Use static prefix `type=sha,prefix=sha-` instead of `{{branch}}`
**File:** `devops/pattern-008-docker-tag.md`

### Pattern 9: docker-compose Exit 127
**Error:** `Process completed with exit code 127`
**Solution:** Use `docker compose` (space) not `docker-compose` (hyphen)
**File:** `devops/pattern-009-docker-compose-v2.md`

---

## 🔀 Git & Workflow

### Pattern 4: Large File Merge Conflicts
**When:** 500+ line files with conflicts
**Solution:** `git checkout --theirs` + manual re-insertion
**File:** `git/pattern-004-large-merge-conflicts.md`

### Pattern 52: Merge Develop Before PR
**Critical:** ALWAYS merge origin/develop into feature branch BEFORE creating PR
**Why:** Prevents conflicts, ensures tests run against current code
**File:** `git/pattern-052-merge-develop-first.md`

### Pattern 56: PR Base Branch Validation
**Critical:** ALWAYS use `gh pr create --base develop`
**Why:** gh CLI defaults to main if not specified
**File:** `git/pattern-056-pr-base-validation.md`

### Pattern 57: Strategic --theirs Conflict Resolution
**When:** Multiple conflicts, develop has accumulated fixes
**Solution:** Use `git checkout --theirs <files>` for files where develop is superior
**File:** `git/pattern-057-strategic-theirs.md`

---

## 🎨 Frontend & Testing

### Pattern 58: Frontend Test Mock Patterns (Vitest)
**Problem:** Tests fail with "Cannot read properties of undefined"
**Solution:** Complete axios mock with interceptors, explicit mock variables
**File:** `frontend/pattern-058-vitest-mocks.md`

### Pattern 59: Post-Compaction Verification
**When:** Session resumes after conversation compaction
**Solution:** 3-tier verification (base repos, PRs, docs)
**File:** `devops/pattern-059-session-verification.md`

---

## 🔨 Backend & Dependencies

### Pattern 10: CS0111 Duplicate Method (Merge Conflict Artifact)
**Error:** Type already defines member with same parameter types
**Solution:** Rename one method semantically, update all call sites
**File:** `backend/pattern-010-duplicate-method.md`

### Pattern 11: CS0246 Namespace Not Found (After Refactor)
**Error:** Type or namespace name could not be found
**Solution:** Update using statements in ALL consumers
**File:** `backend/pattern-011-namespace-change.md`

### Pattern 12: InvalidOperationException - Unable to Resolve DI Service
**Error:** Unable to resolve service for type 'IFoo'
**Solution:** Check if there's a factory pattern, inject factory not interface
**File:** `backend/pattern-012-di-factory-pattern.md`

---

## 🚀 Worktree Management

### Pattern 63: Agent Release Protocol (MANDATORY)
**Critical:** Release worktree IMMEDIATELY after PR creation
**Steps:** Clean worktree, update pool, log release, switch base repos to develop
**File:** `devops/pattern-063-release-protocol.md`

### Pattern 64: Stale Agent Detection
**Criteria:** PR merged but BUSY, >2hr no activity, empty worktree, branch deleted
**Action:** Run release protocol for stale agents
**File:** `devops/pattern-064-stale-detection.md`

### Pattern 65: Pool Synchronization Protocol
**When:** Session start, after mass PR merges
**Solution:** Verify BUSY agents have git repos, recent commits, open PRs
**File:** `devops/pattern-065-pool-sync.md`

### Pattern 66: Worktree Lifecycle State Machine
**States:** FREE → BUSY → CLEANUP → FREE (with STALE error state)
**File:** `devops/pattern-066-lifecycle.md`

### Pattern 67: Cross-Repo Transitive Dependency Completeness
**Error:** NU1105 - Unable to find project information
**Solution:** Systematically verify ALL transitive ProjectReferences are in solution
**File:** `backend/pattern-067-transitive-deps.md`

---

## 🌐 WordPress

### Pattern 73: WordPress Rewrite Rules Lifecycle
**Problem:** Custom rewrites break after plugin activation
**Solution:** Register on init hook (every page load), flush only on activation
**File:** `wordpress/pattern-073-rewrite-init-hook.md`

### Pattern 74: Custom Post Type Rewrite Conflicts
**Problem:** CPT auto-rewrites conflict with custom hierarchical rewrites
**Solution:** Disable auto-rewrites for hierarchical types (`'rewrite' => false`)
**File:** `wordpress/pattern-074-cpt-rewrite-conflicts.md`

### Pattern 75: WordPress Permalink Flush Requirements
**When:** After plugin activation, rewrite rule changes, CPT slug changes
**How:** Settings → Permalinks → Save (or `wp rewrite flush`)
**File:** `wordpress/pattern-075-permalink-flush.md`

---

## 📊 Complete Pattern List (Quick Reference)

| # | Title | Category | Severity |
|---|-------|----------|----------|
| 1 | Missing Gitignored Config (MSB3030) | Build | High |
| 2 | Windows Targeting (NETSDK1100) | Build | Medium |
| 3 | NuGet Downgrade (NU1605) | Build | Medium |
| 4 | Large File Merge Conflicts | Git | Medium |
| 5 | Test Assertions After Refactoring | Testing | Low |
| 6 | gh CLI PR Debugging | DevOps | Low |
| 7 | Worktree Concurrency | Git | Medium |
| 8 | Docker Tag Invalid Format | DevOps | High |
| 9 | docker-compose V2 | DevOps | High |
| 10 | Duplicate Method (CS0111) | Backend | High |
| 11 | Namespace Not Found (CS0246) | Backend | Medium |
| 12 | DI Service Resolution | Backend | High |
| 13 | Namespace Reorganization | Backend | Medium |
| 14 | Missing Interface Methods | Backend | High |
| 15 | Multi-Phase PR Dependencies | Git | Low |
| 16 | Roadmap PRs for Complex Features | DevOps | Low |
| 17 | Session Compaction Recovery | DevOps | Medium |
| 18 | Complete Feature Implementation | Workflow | Medium |
| 19 | Multi-Feature Discipline | Workflow | Medium |
| 20 | Industry Research Integration | Workflow | Low |
| 21 | Multi-Tenant Architecture | Backend | Medium |
| 22 | Audit Logging for Enterprise | Backend | Medium |
| 23 | Stabilization-First Merging | DevOps | High |
| 24 | PR Base Branch Validation | Git | High |
| 25 | Task Prioritization by ROI | Workflow | Low |
| 26 | Client-Manager PR Merge Order | DevOps | Medium |
| 27 | VS Error List Stale Errors | Tooling | Low |
| 28 | Cross-Repo Project References | Build | High |
| 29 | NU1608 Package Version Constraints | Build | Low |
| 30 | Swashbuckle.AspNetCore Versioning | Build | Medium |
| 31 | NETSDK1022 Duplicate Content Items | Build | Medium |
| 32 | Hazina Project Structure Reference | Reference | Info |
| 33 | Worktree Branch Conflict Resolution | Git | Medium |
| 34 | Windows Process Locking DLL | Build | Medium |
| 35 | Check If Fixes Already Complete | Workflow | Low |
| 36 | Hazina OpenAI Config Migration | Backend | High |
| 37 | Fix Branch Merge Workflow | Git | Medium |
| 38 | GitHub Actions SARIF Permissions | DevOps | High |
| 46 | Entity ID Type Alignment (CS1929) | Backend | Medium |
| 47 | Interface Method Name Disambiguation | Backend | Medium |
| 48 | Named Parameter Mismatch (CS1739) | Backend | Low |
| 49 | Multi-PR Quick-Win Batch | Workflow | Medium |
| 50 | Trivy Template File False Positives | Security | Low |
| 52 | Merge Develop Before PR (CRITICAL) | Git | Critical |
| 53 | Workflow Tests Wrong Project | DevOps | High |
| 54 | False Positive Secret Detection | Security | Low |
| 55 | CodeQL Blocking on Old Code | DevOps | Medium |
| 56 | Strategic Non-blocking CI | DevOps | High |
| 57 | Strategic --theirs Resolution | Git | Medium |
| 58 | Frontend Test Mock Patterns | Frontend | High |
| 59 | Post-Compaction Verification | DevOps | Critical |
| 63 | Agent Release Protocol (MANDATORY) | Worktree | Critical |
| 64 | Stale Agent Detection | Worktree | High |
| 65 | Pool Synchronization Protocol | Worktree | High |
| 66 | Worktree Lifecycle State Machine | Worktree | Medium |
| 67 | Transitive Dependency Completeness | Build | High |
| 73 | WordPress Rewrite Rules Lifecycle | WordPress | High |
| 74 | CPT Rewrite Conflicts | WordPress | High |
| 75 | Permalink Flush Requirements | WordPress | Medium |

---

## 🔍 Quick Search Tips

**By Error Code:**
```bash
/patterns:search MSB3030    # Build errors
/patterns:search NU1605     # NuGet issues
/patterns:search CS0111     # C# compiler errors
```

**By Technology:**
```bash
/patterns:search docker     # Docker/container issues
/patterns:search WordPress  # WordPress patterns
/patterns:search axios      # Frontend/API issues
```

**By Workflow:**
```bash
/patterns:search merge      # Git merge strategies
/patterns:search PR         # Pull request workflows
/patterns:search worktree   # Worktree management
```

---

## 📚 Additional Resources

- **Full Source:** `C:\scripts\claude_info.txt` (2000+ lines)
- **Reflection Log:** `C:\scripts\_machine\reflection.log.md` (lessons learned)
- **Operational Manual:** `C:\scripts\CLAUDE.md` (workflow documentation)
- **Best Practices:** `C:\scripts\_machine\best-practices\*.md`

---

## 🤝 Contributing

When you discover a new pattern:
1. Document in reflection.log.md with datetime signature
2. Add to claude_info.txt with next available pattern number
3. Create pattern-XXX.md file in appropriate category
4. Update this INDEX.md with summary
5. Commit and push updates

**Pattern Template:** Use consistent format (Problem, Root Cause, Solution, When to Use, Examples)
