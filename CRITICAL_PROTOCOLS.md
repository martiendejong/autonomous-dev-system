# ⚠️ Critical Protocols (Zero Tolerance)

**Hard-stop rules that prevent catastrophic failures. These are NON-NEGOTIABLE.**

---

## 🚨 Testing Protocol (MANDATORY)

**RECURRING VIOLATION:** User said "ondanks dat het vaker gebeurt is" (this has happened multiple times)

### Hard Rule: Use Exact Tool Specified

**When user specifies testing tool by name → USE THAT EXACT TOOL**

```
User: "Test this with Playwright"
❌ WRONG: Use curl or API calls
✅ RIGHT: Use Playwright MCP or playwright scripts

User: "Use the Browser MCP to verify"
❌ WRONG: Check API responses only
✅ RIGHT: Actually use Browser MCP, get screenshot

User: "Debug this with the Agentic Debugger"
❌ WRONG: Add console.log statements
✅ RIGHT: Use localhost:27183 debugger bridge
```

### Evidence Required

**Before claiming success, provide EVIDENCE:**

1. ❓ Did user specify exact tool?
   - ✅ Use THAT tool (no shortcuts)
   - ❌ Don't substitute with faster alternative

2. ❓ Did I verify ACTUAL user-facing functionality?
   - ✅ Test real UI/UX behavior
   - ❌ Don't just verify backend API

3. ❓ Can I provide EVIDENCE?
   - ✅ Screenshot, log file, test report
   - ❌ Don't just claim "it works"

### Verification Gap

**CRITICAL: API working ≠ UI working**

```
Scenario: User reports "login button doesn't work"

❌ BAD RESPONSE:
- Curl /api/auth/login → 200 OK
- "API works, should be fine"
- No browser testing

✅ GOOD RESPONSE:
- Use Playwright/Browser MCP
- Actually click login button
- Screenshot of result
- "Confirmed: Login works (see screenshot)"
```

### Trust Issue

**Using shortcuts = failing trust test**

- User explicitly mentioned "it happens multiple times"
- This is about trust, not just efficiency
- Shortcuts signal: "I'm optimizing for my speed over your needs"
- Correct tool usage signals: "I respect your requirements"

### Checkpoint

**BEFORE claiming test success:**

```
□ User specified tool? → Used THAT tool (no substitutions)
□ Verified user-facing functionality? → Not just backend
□ Have evidence? → Screenshot/log/report attached
□ Would I bet $1000 this works? → Only then claim success
```

---

## 🔧 Tool Selection Protocol (MANDATORY)

**BEFORE starting ANY task: Check for specialized tools**

### Protocol

```
1. Read user request
2. Identify task type (debugging, testing, visual analysis, etc.)
3. CHECK: Does specialized tool exist for this?
4. IF YES: Use that tool
5. IF NO: Use general tools (Read/Write/Bash)
```

### Specialized Tools

| Task Type | Check For | DON'T Default To |
|-----------|-----------|------------------|
| **Debugging C#** | Agentic Debugger (localhost:27183) | Read + console.log |
| **Browser testing** | Playwright MCP, Browser MCP | curl + API calls |
| **Visual analysis** | ai-vision.ps1 | "Can't see images" |
| **Need images** | ai-image.ps1 | "Ask user to provide" |
| **Database work** | ef-preflight-check.ps1 | Direct SQL commands |
| **Code formatting** | cs-format.ps1 | Manual edits |

### Verification

```powershell
# Before assuming tool unavailable, CHECK:

# Agentic Debugger available?
curl http://localhost:27183/state  # If 200 OK, it's running

# Playwright available?
Test-Path "C:\projects\claudescripts\playwright\node_modules\.bin\playwright.cmd"

# MCP servers running?
# (Check Claude Code settings, active connections)
```

### User Feedback

**Actual quote:** "for some reason every time it forget to use playwright and the agentic debugger"

**Root cause:** Defaulting to familiar tools instead of checking for better options

**Fix:** Make tool verification MANDATORY checkpoint at start of every task

---

## 📋 MoSCoW Prioritization (MANDATORY)

**ALWAYS apply when working with tasks (ClickUp, user requests, PRs)**

### Framework

```
MUST Have    - Critical, non-negotiable, blocks release
SHOULD Have  - Important, high value, implement if time allows
COULD Have   - Nice to have, low effort, implement if trivial
WON'T Have   - Out of scope for this iteration (document for future)
```

### Before Implementation

**Post MoSCoW analysis as comment:**

```markdown
## MoSCoW Prioritization

### MUST Have (100% implementation)
- [ ] User authentication working
- [ ] Password reset flow
- [ ] Session management

### SHOULD Have (if time allows)
- [ ] Remember me functionality
- [ ] OAuth integration
- [ ] 2FA support

### COULD Have (if trivial)
- [ ] Login with magic link
- [ ] Biometric authentication

### WON'T Have (this iteration)
- [ ] SSO with enterprise providers (complex, document for Phase 2)
```

### Implementation Order

```
1. Implement ALL MUST items (100%)
2. Implement SHOULD items if time allows
3. Implement COULD items only if trivial (<30min)
4. Document WON'T items for future iterations
```

### Success Criteria

**Task complete ONLY IF:**
- ✅ All MUST items delivered
- ✅ SHOULD items attempted (or documented why not)
- ✅ COULD items evaluated (implemented if trivial)
- ✅ WON'T items documented for future

---

## 🔀 Multi-Agent Coordination (MANDATORY)

**ALWAYS check coordination state BEFORE starting work**

### Protocol

```powershell
# STEP 1: Check coordination file
cat C:\scripts\_machine\agent-coordination.md

# STEP 2: Look for conflicts
# - Same ClickUp task?
# - Same branch?
# - Same worktree?
# - Same file being edited?

# STEP 3: Register your work
agent-id: agent-003
status: CODING
clickup-task: https://app.clickup.com/t/869xyz
pr: (will be created)
branch: feature/user-authentication
objective: Implement JWT authentication

# STEP 4: Update status when changing phases
PLANNING → CODING → TESTING → REVIEWING → MERGING → DONE
```

### Stale Detection

```
>30min unchanged = Potentially stale (check ManicTime activity)
>60min unchanged = Can take over (ping user first)
```

### Prevents

- ❌ Duplicate PR merges
- ❌ Duplicate ClickUp tasks
- ❌ Merge conflicts from parallel work
- ❌ Worktree pool corruption
- ❌ Git index.lock errors

---

## 🌳 Worktree Management (ZERO TOLERANCE)

### Release Protocol (9 Steps)

**ALWAYS release worktree IMMEDIATELY after PR creation, BEFORE presenting to user**

```
1. ✅ Verify PR created (gh pr view)
2. ✅ Clean directory (rm temp files, build artifacts)
3. ✅ Mark worktree FREE in pool.md
4. ✅ Log activity in worktrees.activity.md
5. ✅ Remove instances.map (Angular artifacts)
6. ✅ Switch base repo to develop (cd base && git checkout develop)
7. ✅ Prune worktrees (git worktree prune)
8. ✅ Commit tracking files (pool.md, activity.md)
9. ✅ Verify (cat pool.md | grep agent-XXX should show FREE)
```

### Critical Rules

```
❌ NEVER present PR link before releasing worktree
❌ NEVER leave worktree BUSY after PR merge
❌ NEVER skip verification step (Step 9)
❌ NEVER assume release worked (always verify)
```

### User Patience

**Quote from MEMORY.md:** "User patience is exhausted - earn trust through flawless execution"

**Zero tolerance = Zero mistakes on worktree management**

---

## 🎯 Mode Detection (HARD RULE)

**How to detect which mode to operate in:**

### Feature Development Mode

**Triggers:**
- ClickUp URL in request
- ClickUp task ID mentioned
- User says "new feature"
- Planned work (not urgent fix)

**Requirements:**
- ✅ Allocate worktree
- ✅ Create PR
- ✅ Update ClickUp task with PR link
- ✅ Release worktree after PR
- ❌ NEVER work in base repo directly

### Active Debugging Mode

**Triggers:**
- Build error message in request
- User says "help debug this"
- Urgent production issue
- User is actively coding (check ManicTime)

**Requirements:**
- ✅ Work in base repo directly
- ✅ Preserve user's current branch
- ✅ Fast turnaround (no worktree overhead)
- ❌ NO PR creation (user will commit)
- ❌ NO worktree allocation

### When Unclear

**Default to Feature Development Mode** (safer, more structured)

**Ask user:** "Is this planned feature work (worktree) or urgent debugging (direct)?"

---

## 🔐 Git Safety Protocol

### NEVER Commands (Unless User Explicitly Requests)

```
❌ git push --force (can overwrite upstream work)
❌ git reset --hard (destroys uncommitted changes)
❌ git checkout . (discards all changes)
❌ git clean -f (deletes untracked files)
❌ git branch -D (force-deletes branch)
❌ --no-verify (skips hooks/validation)
```

### ALWAYS Commands

```
✅ git status (before every operation)
✅ git diff (before committing)
✅ git log (understand recent commits)
✅ git stash (preserve work, don't destroy)
✅ Create new commit (don't amend unless requested)
```

### PR Base Branch

**ALWAYS use `develop`, NEVER use `main`** (unless user specifies otherwise)

```bash
# RIGHT
gh pr create --base develop --title "Fix auth"

# WRONG
gh pr create --base main --title "Fix auth"
```

---

## 📊 Communication Protocol

### Status Updates (Use Sparingly)

**User feedback:** "make it a bit more compact... I don't have to read so much"

```
❌ BAD: Heavy status block for every simple response
✅ GOOD: Conversational update for complex multi-part work
✅ GOOD: Capital "STATUS:" headline at end if state changed
```

### When to Use STATUS Block

```
✅ Complex multi-phase work (5+ steps)
✅ Parallel operations running
✅ User needs to know current state
✅ Multiple PRs/tasks being juggled

❌ Simple edits (1-2 files)
❌ Single command execution
❌ Answering questions
```

### Example: Good vs Bad

```
❌ BAD:
"I'm going to read the file now.

STATUS:
- Phase: Reading file
- Progress: 0/1 files
- Next: Edit file

[reads file]

I've read the file.

STATUS:
- Phase: Read complete
- Progress: 1/1 files
- Next: Edit file"

✅ GOOD:
"Let me check that file and fix the bug.

[reads file, edits file, runs tests]

Fixed the JWT validation in UserController.cs (line 42). Tests passing locally.

STATUS: Ready for PR (branch: feature/auth-fix, 1 file changed, tests ✅)"
```

---

## 📚 References

- **GENERAL_ZERO_TOLERANCE_RULES.md** - Original zero-tolerance rules
- **TESTING_PROTOCOL_VIOLATIONS.md** - Detailed testing failures log
- **WORKTREE_PROTOCOL.md** - Complete worktree workflow
- **MULTI_AGENT_CONFLICT_DETECTION.md** - Coordination protocol
- **MOSCOW_PRIORITIZATION.md** - Task prioritization framework

---

## ✅ Verification Checklist

**Before claiming task complete:**

```
Testing:
□ Used exact tool user specified (no substitutions)
□ Verified user-facing functionality (not just backend)
□ Have evidence (screenshot/log/report)

Tool Selection:
□ Checked for specialized tools before using general ones
□ Verified tool availability (curl/Test-Path)
□ Used optimal tool for task type

MoSCoW:
□ MUST items 100% complete
□ SHOULD items attempted or documented
□ COULD items evaluated
□ WON'T items documented for future

Multi-Agent:
□ Checked agent-coordination.md
□ No conflicts with other agents
□ Registered work before starting
□ Updated status during work

Worktree:
□ Released immediately after PR (if Feature Mode)
□ 9-step protocol completed
□ Verification step passed
□ Tracking files committed

Communication:
□ Concise, conversational tone
□ STATUS block only if needed
□ No unnecessary verbosity
```

---

**Key Principle:** Trust is earned through flawless execution, not explanations.

---

**Last Updated:** 2026-02-07
**Status:** ACTIVE (Zero Tolerance Enforcement)
**Violations Tracked:** MEMORY.md § Mistakes to Never Repeat
