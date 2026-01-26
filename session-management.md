## 🪟 SESSION MANAGEMENT - DYNAMIC WINDOW TITLES

**Feature Added: 2026-01-11**
**User Request:** "make it so that the title of the window is when possible the branch name and otherwise a two word description of the current state in all-caps"

### Dynamic Window Title Behavior

When `claude_agent.bat` launches, it automatically sets the window title based on context:

**Priority 1: Git Branch Name (ALL-CAPS)**
- If running in a git repository, shows current branch name in uppercase
- Examples: `MAIN`, `DEVELOP`, `AGENT-002-ADD-PAGE-IMAGES`, `FEATURE/NEW-FEATURE`
- **Benefit:** Instantly identify which branch/worktree you're working in

**Priority 2: Fallback State (ALL-CAPS)**
- If not in a git repository, shows: `CLAUDE AGENT`
- Ensures window always has a clear, visible title

### Implementation Details

Located in `C:\scripts\claude_agent.bat`:
```batch
@echo off
setlocal enabledelayedexpansion

REM --- Set dynamic window title ---
for /f "tokens=*" %%i in ('git branch --show-current 2^>nul') do set BRANCH=%%i
if defined BRANCH (
    for /f "tokens=*" %%a in ('powershell -Command "\"!BRANCH!\".ToUpper()"') do set BRANCH_UPPER=%%a
    title !BRANCH_UPPER!
) else (
    title CLAUDE AGENT
)
```

### Use Cases

**Multi-Agent Sessions:**
```
Terminal 1: Working on main
  → Window title: "MAIN"

Terminal 2: Working on feature branch
  → Window title: "AGENT-003-SMART-SCHEDULING"

Terminal 3: Testing in artrevisionist
  → Window title: "AGENT-002-ADD-PAGE-IMAGES"
```

**Benefits:**
✅ Prevents accidentally sending commands to wrong agent session
✅ Clear visual distinction in taskbar
✅ Supports multiple simultaneous agent sessions
✅ All-caps makes titles highly visible
✅ No manual intervention required

### Related Documentation

- Quick launcher details: `C:\scripts\QUICK_LAUNCHERS.md`
- Window title implementation: `C:\scripts\claude_agent.bat`

## 🎨 DYNAMIC WINDOW COLORS - STATE-BASED VISUAL FEEDBACK

**Feature Added: 2026-01-12**
**User Request:** "claude code determines the color of the window based on the kind of thing you are doing"

### Color States

The terminal background color changes dynamically to reflect Claude Code's execution state:

| State | Color | When to Use | Emoji |
|-------|-------|-------------|-------|
| **RUNNING** | 🔵 Blue | Actively working on a task | 🔵 |
| **COMPLETE** | 🟢 Green | Task finished successfully | 🟢 |
| **BLOCKED** | 🔴 Red | Waiting for user input/decision | 🔴 |
| **IDLE** | ⚪ Black | Ready for next task | ⚪ |

### When to Change Colors (MANDATORY for Claude)

**As Claude Code, you MUST trigger color changes at these points:**

```bash
# 1. When starting ANY task (allocating worktree, creating PR, etc.)
C:\scripts\color-running.bat

# 2. When task completes successfully
C:\scripts\color-complete.bat

# 3. When using AskUserQuestion tool (blocking on user)
C:\scripts\color-blocked.bat

# 4. After user answers question, resuming work
C:\scripts\color-running.bat

# 5. When completely idle (no active work)
C:\scripts\color-idle.bat
```

### Integration Protocol

**CRITICAL: You (Claude Code) should call these color scripts at state transitions:**

#### Before Starting Work
```bash
# User gives you a task
# IMMEDIATELY call:
C:\scripts\color-running.bat
```

#### During AskUserQuestion
```bash
# BEFORE calling AskUserQuestion tool:
C:\scripts\color-blocked.bat

# Tool call: AskUserQuestion(...)

# AFTER user responds:
C:\scripts\color-running.bat
```

#### After Completing Work
```bash
# Created PR, released worktree, ready to present results
# BEFORE presenting results to user:
C:\scripts\color-complete.bat

# Present results...

# After user acknowledges, if no new task:
C:\scripts\color-idle.bat
```

### Example Session Flow

```
SESSION START
→ color-idle.bat (⚪ Black - "IDLE")

USER: "Create a new feature for ROI tracking"
→ color-running.bat (🔵 Blue - "RUNNING")

CLAUDE: Working... allocating worktree, coding backend...
→ (stays Blue)

CLAUDE: Needs decision on API design
→ color-blocked.bat (🔴 Red - "BLOCKED")
→ AskUserQuestion: "Should API return daily or monthly data?"

USER: "Monthly data"
→ color-running.bat (🔵 Blue - "RUNNING")

CLAUDE: Completes implementation, creates PR
→ color-complete.bat (🟢 Green - "COMPLETE")

CLAUDE: "PR #123 created: [URL]"

USER: "Thanks!"
→ color-idle.bat (⚪ Black - "IDLE")
```

### Technical Implementation

**Core Script:** `C:\scripts\set-state-color.ps1`
- Uses ANSI escape sequences for color changes
- Updates window title with state emoji
- Logs state transitions to `C:\scripts\logs\color-state.log`

**Quick Access Scripts:**
- `color-running.bat` - Blue background
- `color-complete.bat` - Green background
- `color-blocked.bat` - Red background
- `color-idle.bat` - Black background

**Testing:** Run `C:\scripts\test-colors.bat` to see all color states

### Customization

See `C:\scripts\DYNAMIC_WINDOW_COLORS.md` for:
- Changing color schemes
- Adding new states
- Windows Terminal integration
- Troubleshooting

### Benefits

✅ **Visual state awareness** - User knows Claude's status at a glance
✅ **Multi-window management** - Differentiate multiple Claude sessions by color
✅ **Attention management** - Red (blocked) draws immediate attention
✅ **Progress tracking** - Green confirms successful completion
✅ **Professional polish** - Visual feedback like modern IDEs

### Success Criteria

**You are using colors correctly ONLY IF:**
- ✅ Window is BLUE whenever actively working
- ✅ Window is RED whenever blocked on user input
- ✅ Window is GREEN after successful task completion
- ✅ Window is BLACK when idle/ready
- ✅ Color changes happen IMMEDIATELY at state transitions (not delayed)

**Full documentation:** `C:\scripts\DYNAMIC_WINDOW_COLORS.md`

## 🔧 PRODUCTIVITY TOOLS - USE PROACTIVELY

**USER DIRECTIVE (2026-01-11):** "make sure you use the tools where needed and/or appropriate"

**STATUS:** 10 tools built and ready to use. See C:\scripts\tools\TOOLS_STATUS.md for complete list.

### MANDATORY Tool Usage

**1. EVERY SESSION START:**
```bash
# Run dashboard to check environment state
C:/scripts/tools/repo-dashboard.sh
```
This shows:
- Current branch for each repo
- Uncommitted changes
- Open PRs with CI status
- Last 3 commits
- Agent pool status (FREE/BUSY agents)

**2. When User Asks Status Questions:**
- "What PRs are open?" → Run `pr-status.sh`
- "What's the current state?" → Run `repo-dashboard.sh`
- "What needs to be done?" → Run `find-todos.sh`
- "What coverage do we have?" → Run `coverage-report.sh`

**3. Before Allocating Worktree:**
- Dashboard shows agent pool status
- If resource issues → Run `check-worktree-health.sh`

**4. Maintenance Tasks:**
- After merging multiple PRs → Run `clean-stale-branches.sh`
- Weekly → Run `check-worktree-health.sh`
- When config changes → Run `sync-configs.sh`

**5. When Tools Fail:**
- Test immediately with representative data
- Fix bugs proactively
- Update TOOLS_STATUS.md with results
- Log pattern in reflection.log.md

### Available Tools (Quick Reference)

See **C:\scripts\tools\README.md** for full documentation.

1. **clean-stale-branches.sh** - Delete merged branches (ROI 8.0)
2. **pr-status.sh** - All PRs at a glance (ROI 7.0)
3. **repo-dashboard.sh** - Environment overview (ROI 4.5) ⭐ Use at startup
4. **check-worktree-health.sh** - Detect stale allocations (ROI 4.5)
5. **install-hooks.sh** - Pre-commit checks (ROI 4.0)
6. **find-todos.sh** - TODO/FIXME tracker (ROI 5.3)
7. **sync-configs.sh** - Config file sync (ROI 4.0)
8. **agent-activity.sh** - Agent status report (ROI 3.8)
9. **coverage-report.sh** - Test coverage analysis (ROI 3.5)
10. **generate-changelog.sh** - PR changelog (ROI 3.2)

**Testing Status:** Only repo-dashboard.sh fully tested. Test others as you use them.

**Tracking:** Update C:\scripts\tools\TOOLS_STATUS.md after each tool usage.

## 📋 USER NOTIFICATION TRACKING (HTML DASHBOARD)

**USER DIRECTIVE (2026-01-11):** "maintain a HTML document with all user notifications/input requested"

### Purpose

Maintain a persistent, visual notification dashboard at `C:\Users\HP\Desktop\notifications.html` that tracks ALL items requiring user attention, review, or action.

### When to Add Notifications

**MANDATORY - Add notification when:**
- ✅ Creating any PR (include PR URL, title, description)
- ✅ Completing a significant job (deployment, major fix, feature completion)
- ✅ Requesting user input or decision
- ✅ Encountering blocking issues requiring user intervention
- ✅ Discovering important findings that need user review
- ✅ System state changes requiring awareness (agent pool full, errors, etc.)

### When to Remove Notifications

**MANDATORY - Remove notification when:**
- ✅ Task is completed (PR merged, issue resolved)
- ✅ User has provided response or made decision
- ✅ Notification becomes obsolete or irrelevant
- ✅ Multiple related notifications can be merged into one

### Notification Consolidation

**Goal: Maximum 5-7 active notifications**

When approaching limit:
1. Merge related notifications (e.g., multiple PRs → "3 PRs awaiting review")
2. Remove completed/obsolete items
3. Prioritize by urgency and importance

### HTML File Structure

**Location:** `C:\Users\HP\notifications.html`

**Quick Access Methods:**
- **CTRL+R → `n`** (if C:\scripts in PATH) ← Fastest
- **CTRL+R → `C:\scripts\n.bat`** (works now)
- **CTRL+R → `C:\Users\HP\notifications.html`** (direct)

**Other Quick Launchers:** See `C:\scripts\QUICK_LAUNCHERS.md` for all CTRL+R commands:
- `c` - Claude Agent
- `cm` - Client Manager frontend (npm run dev)
- `ar` - ArtRevisionist frontend (npm run dev)
- `bi` - Bugatti Insights frontend (npm run dev)

**File Format:**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Claude Agent Notifications</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 900px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        .notification { border-left: 4px solid #3498db; padding: 15px; margin: 15px 0; background: #f8f9fa; border-radius: 4px; }
        .notification.pr { border-left-color: #28a745; }
        .notification.input { border-left-color: #ffc107; }
        .notification.error { border-left-color: #dc3545; }
        .notification.info { border-left-color: #17a2b8; }
        .notification h3 { margin: 0 0 10px 0; color: #2c3e50; }
        .notification p { margin: 5px 0; color: #666; }
        .notification .meta { font-size: 0.85em; color: #999; margin-top: 10px; }
        .count { background: #3498db; color: white; padding: 5px 10px; border-radius: 15px; font-size: 0.9em; }
        .empty { text-align: center; color: #999; padding: 40px; font-style: italic; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔔 Claude Agent Notifications <span class="count" id="count">0</span></h1>
        <p style="color: #666; margin-bottom: 20px;">Last updated: <span id="timestamp">Never</span></p>
        <div id="notifications">
            <!-- Notifications will be inserted here -->
        </div>
    </div>
</body>
</html>
```

### Notification Types and CSS Classes

| Type | CSS Class | Use For |
|------|-----------|---------|
| PR Created | `pr` | Pull requests awaiting review/merge |
| Input Requested | `input` | User decisions or input needed |
| Error/Blocking | `error` | Critical issues requiring intervention |
| Information | `info` | Important findings or status updates |

### Workflow Pattern

**After creating PR:**
```bash
# 1. Create PR
gh pr create --title "..." --body "..."

# 2. IMMEDIATELY update notifications.html
# Add new notification with:
# - Title: PR title
# - Description: What it does
# - URL: PR link
# - Timestamp: Current datetime

# 3. Release worktree (existing protocol)
# ...
```

**After user responds or task completes:**
```bash
# 1. Complete task (merge PR, resolve issue, etc.)

# 2. IMMEDIATELY update notifications.html
# Remove the corresponding notification

# 3. Update reflection.log.md if significant
```

### Update Protocol

**MANDATORY steps when updating notifications.html:**

1. **Read current file** to preserve existing notifications
2. **Modify content** (add/remove/merge notifications)
3. **Update count** in `<span id="count">`
4. **Update timestamp** in `<span id="timestamp">`
5. **Write file** with new content
6. **Verify** file is valid HTML (can open in browser)

### Example Notification HTML

```html
<div class="notification pr">
    <h3>🔀 PR #123: Add ROI Calculator Feature</h3>
    <p><strong>Repo:</strong> client-manager</p>
    <p><strong>Description:</strong> Implements comprehensive ROI calculation with industry benchmarks, backend API, frontend components, and documentation.</p>
    <p><strong>Status:</strong> Awaiting review and merge</p>
    <p><strong>URL:</strong> <a href="https://github.com/user/repo/pull/123" target="_blank">View PR</a></p>
    <div class="meta">Created: 2026-01-11 14:30:00 UTC | Agent: agent-001</div>
</div>
```

### Consolidation Example

**Before (6 notifications):**
- PR #120: Fix auth bug
- PR #121: Update dependencies
- PR #122: Add logging
- PR #123: ROI feature
- PR #124: Smart scheduling
- Input: Choose deployment schedule

**After consolidation (3 notifications):**
- 5 PRs awaiting review (#120-#124) - [View All](link)
- Input: Choose deployment schedule
- (Merged related PRs into one notification)

### Integration with Existing Protocols

**This HTML notification tracking integrates with:**
- ✅ Worktree release protocol (add PR notification BEFORE release)
- ✅ End-of-task self-update (update notifications.html as part of cleanup)
- ✅ Reflection logging (document significant notifications in reflection.log.md)
- ✅ TodoWrite tracking (todos for implementation, notifications for user awareness)

### Success Criteria

**You are maintaining notifications correctly ONLY IF:**
- ✅ notifications.html exists and is up-to-date
- ✅ Every PR creation adds a notification
- ✅ Every PR merge removes the notification
- ✅ Active notifications count is ≤ 7
- ✅ Timestamp is current
- ✅ HTML is valid and renders correctly
- ✅ User can open file and immediately see what needs attention

**File location:** `C:\Users\HP\Desktop\notifications.html`

---
