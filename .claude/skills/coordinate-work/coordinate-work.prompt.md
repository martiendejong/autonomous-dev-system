---
name: coordinate-work
description: Register, update, or complete work in the agent coordination registry to prevent conflicts between multiple agents
auto_invoke: false
---

# Agent Work Coordination

**Purpose:** Manage entries in the shared agent coordination registry (`agent-coordination.md`) to prevent duplicate work and enable multi-agent coordination.

---

## Available Actions

### 1. CHECK - Check for Conflicts

**Before starting ANY work**, check if someone else is already working on it.

```bash
# Read coordination file
cat C:/scripts/_machine/agent-coordination.md

# Check for specific conflicts:
# - Is anyone working on the same ClickUp task?
# - Is anyone working on the same GitHub PR?
# - Is anyone already merging what I want to merge?
```

**Output:**
- ✅ No conflicts detected → Safe to proceed
- ⚠️ Conflict detected → Coordinate or pick different work

---

### 2. REGISTER - Register New Work

When starting new work, immediately register it in the Active Work table.

**Format:**
```markdown
| {agent-id} | PLANNING | {clickup-task-id or -} | {pr-number or -} | {branch or -} | {objective} | {phase} | {timestamp} |
```

**Example:**
```markdown
| agent-003 | PLANNING | 869c1xyz | - | - | Implement auth system | Investigation | 2026-02-05T18:00:00Z |
```

**Steps:**
1. Read current coordination file
2. Add new row to Active Work table
3. Write updated file
4. Verify entry added

---

### 3. UPDATE - Update Work Status

When changing phases or making progress, update your entry.

**Common updates:**
- Status change: PLANNING → CODING → TESTING → REVIEWING → MERGING
- Branch added: When worktree allocated
- PR number added: When PR created
- Phase updated: Development → Build/Test → PR Merge

**Example:**
```markdown
# Before:
| agent-003 | PLANNING | 869c1xyz | - | - | Implement auth | Investigation | 2026-02-05T18:00:00Z |

# After:
| agent-003 | CODING | 869c1xyz | - | agent-003-auth | Implement auth | Development | 2026-02-05T18:15:00Z |
```

**Steps:**
1. Read coordination file
2. Find your entry (search by agent-id)
3. Update status, PR, branch, phase, or timestamp
4. Write updated file

---

### 4. COMPLETE - Mark Work Done

When work is complete, move entry from Active Work to Completed Today.

**Format:**
```markdown
| {agent-id} | {clickup-task} | {pr-number} | {objective} | {outcome} | {timestamp} |
```

**Example:**
```markdown
| agent-003 | 869c1xyz | #506 | Implement auth system | ✅ PR #506 created | 2026-02-05T19:00:00Z |
```

**Steps:**
1. Read coordination file
2. Find and remove your entry from Active Work table
3. Add entry to Completed Today table with outcome
4. Write updated file

---

### 5. DETECT-STALE - Find Stale Work

Check for entries with Updated > 30 minutes ago and status unchanged.

**Detection Logic:**
```bash
# Get current UTC time
current_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# For each Active Work entry:
# - Parse Updated timestamp
# - Calculate time difference
# - If diff > 30 min → Mark as potentially stale
```

**Actions:**
- Check worktree exists
- Check ManicTime for agent activity
- If truly stale after 60 min → Mark as STALE or takeover

---

## Usage Examples

### Example 1: Starting to Merge a PR

```markdown
User: "Merge PR #476"

1. CHECK for conflicts:
   cat C:/scripts/_machine/agent-coordination.md
   # Verify no one else is working on #476

2. REGISTER work:
   | agent-007 | REVIEWING | - | #476 | - | Review SVG fix PR | Code Review | 2026-02-05T18:00:00Z |

3. Do the work (allocate worktree, merge develop, test)

4. UPDATE status when merging:
   | agent-007 | MERGING | - | #476 | feature/svg-fix | Merge SVG fix | PR Merge | 2026-02-05T18:25:00Z |

5. COMPLETE when done:
   | agent-007 | - | #476 | SVG fix PR | ✅ Merged to develop | 2026-02-05T18:30:00Z |
```

### Example 2: Implementing ClickUp Task

```markdown
User: "Implement ClickUp task 869c1abc"

1. CHECK for conflicts:
   # Verify no one working on 869c1abc

2. REGISTER work:
   | agent-005 | PLANNING | 869c1abc | - | - | Auth feature | Investigation | 2026-02-05T18:00:00Z |

3. UPDATE when coding starts:
   | agent-005 | CODING | 869c1abc | - | agent-005-auth | Auth feature | Development | 2026-02-05T18:15:00Z |

4. UPDATE when PR created:
   | agent-005 | TESTING | 869c1abc | #507 | agent-005-auth | Auth feature | PR Created | 2026-02-05T19:00:00Z |

5. COMPLETE:
   | agent-005 | 869c1abc | #507 | Auth feature | ✅ PR #507 created & ClickUp updated | 2026-02-05T19:30:00Z |
```

### Example 3: Detecting Conflict

```markdown
User: "Merge PR #480"

1. CHECK coordination file:
   cat C:/scripts/_machine/agent-coordination.md

   Found:
   | agent-004 | MERGING | - | #480 | feature/rich-text | Merge TipTap PR | PR Merge | 2026-02-05T18:20:00Z |

2. CONFLICT DETECTED! ⚠️
   - agent-004 is already merging PR #480
   - Updated 5 minutes ago (recent activity)

3. ACTION: Do NOT proceed with merge
   - Report to user: "agent-004 is currently merging PR #480"
   - Suggest alternative: "Pick a different PR or wait for agent-004 to complete"
```

---

## File Operations

### Read Coordination File
```bash
cat C:/scripts/_machine/agent-coordination.md
```

### Update Entry (Safe Method)
```bash
# 1. Read current file
current=$(cat C:/scripts/_machine/agent-coordination.md)

# 2. Find and update your line
# Use sed/awk or Edit tool to replace specific row

# 3. Write updated file
# Use Write tool with updated content
```

### Get Current UTC Timestamp
```bash
date -u '+%Y-%m-%dT%H:%M:%SZ'
# Output: 2026-02-05T18:00:00Z
```

---

## Critical Rules

1. **ALWAYS check coordination file before starting work** - Non-negotiable
2. **Register immediately after deciding to work** - Before allocating worktree
3. **Update timestamps when changing status** - Keep it fresh
4. **Move to completed when done** - Keep active table clean
5. **Respect conflicts** - If someone is working on it, coordinate first

---

## Integration Points

### Worktree Allocation
```bash
# BEFORE allocating worktree:
1. Check coordination file for conflicts
2. Register work with PLANNING status
3. Allocate worktree
4. Update entry with branch name and CODING status
```

### PR Creation
```bash
# AFTER creating PR:
1. Update coordination entry with PR number
2. Update ClickUp task with PR link
3. Update status to DONE or continue with next phase
```

### PR Merge
```bash
# BEFORE merging PR:
1. Check coordination file - anyone else merging this?
2. If clear, register with REVIEWING status
3. After merge, move to completed
```

---

## Error Handling

### Concurrent Edits
If two agents edit simultaneously, last write wins. To minimize:
- Read file immediately before writing
- Keep edit window small (read → modify → write quickly)
- If conflict suspected, re-read and verify

### Stale Entries
If entry shows > 60 min unchanged:
- Verify worktree status
- Check ManicTime for agent activity
- If truly abandoned, mark STALE or take over
- Update reflection.log with incident

---

**File Location:** `C:\scripts\_machine\agent-coordination.md`

**Skill Location:** `C:\scripts\.claude\skills\coordinate-work\`

**Related Files:**
- `worktrees.pool.md` - Physical worktree allocation
- `instances.map.md` - Active agent instances
- `worktrees.activity.md` - Historical activity log

**Maintenance:** Clear "Completed Today" at end of day, archive weekly
