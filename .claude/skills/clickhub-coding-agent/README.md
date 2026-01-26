# ClickHub Coding Agent - Usage Guide

## Overview

The **ClickHub Coding Agent** is an autonomous task management system that:
- Monitors ClickUp tasks for client-manager project
- Identifies uncertainties and asks questions
- Implements clear tasks automatically
- Operates in a continuous loop with configurable sleep cycles

## Quick Start

### 1. Invoke the Skill (User-Invocable)

You can invoke the ClickHub Coding Agent by asking Claude:

```
"Run the ClickHub coding agent"
"Start autonomous ClickUp task management"
"Manage my ClickUp tasks for client-manager"
```

Or using the Skill tool directly:
```
/clickhub-coding-agent
```

### 2. Manual Single Cycle (For Testing)

Run one cycle without sleeping:

```powershell
C:/scripts/.claude/skills/clickhub-coding-agent/scripts/clickhub-single-cycle.ps1 -DryRun
```

**Note:** The current implementation outputs placeholders. Full Claude Agent execution context is required for actual task implementation.

### 3. Continuous Operation

For production use (runs forever):

```powershell
C:/scripts/.claude/skills/clickhub-coding-agent/scripts/clickhub-continuous.ps1
```

**Options:**
```powershell
# Custom sleep duration (5 minutes)
.\clickhub-continuous.ps1 -SleepSeconds 300

# Limit tasks per cycle
.\clickhub-continuous.ps1 -MaxTasksPerCycle 3

# Dry run mode
.\clickhub-continuous.ps1 -DryRun
```

**To stop gracefully:**
- Press Ctrl+C, OR
- Create file: `C:\scripts\_machine\clickhub-stop.flag`

### 4. Analyze Specific Task

Deep-dive analysis of a single task:

```powershell
C:/scripts/.claude/skills/clickhub-coding-agent/scripts/clickhub-analyze-task.ps1 -TaskId "869abc123"
```

## What the Agent Does

### Cycle Workflow

1. **Fetch Tasks** - List all unassigned tasks from ClickUp
2. **Analyze Each Task** - Check for:
   - Duplicate tasks (similar names/descriptions)
   - Existing branches/PRs
   - Related code
   - Requirement clarity
   - Implementation uncertainties
3. **Handle Duplicates**:
   - Post comment identifying master task
   - Move duplicate to "blocked" status
   - Skip to next task
4. **Handle Uncertainties**:
   - Post questions as comments
   - Move task to "blocked" status
   - Skip to next task
5. **Execute Clear Tasks**:
   - Allocate worktree (Feature Development Mode)
   - Implement changes following Boy Scout Rule
   - Create PR and link to ClickUp
   - Update task to "review" status
   - Release worktree
6. **Sleep** - Wait specified duration
7. **Repeat** - Start next cycle

### Example: Duplicate Task

**Tasks:**
- #869bt9uak: "Google Login"
- #869bt9ubt: "Google Login OAuth Integration"

**Agent Analysis:**
- Both tasks appear to be the same feature
- #869bt9uak created first (master task)

**Agent Action:**
- Posts comment on #869bt9ubt: "DUPLICATE TASK - This appears to be a duplicate of task #869bt9uak"
- Moves #869bt9ubt to "blocked" status
- Continues with #869bt9uak

### Example: Task with Uncertainties

**Task:** "Add user profile export feature"

**Agent Analysis:**
- Requirements unclear (format? scope? async?)
- Multiple implementation options
- GDPR considerations

**Agent Action:**
- Posts questions as comment on ClickUp task
- Moves task to "blocked" status
- Waits for user to answer before implementing

### Example: Task Ready for Implementation

**Task:** "Fix broken login button styling - should be centered and 300px wide"

**Agent Analysis:**
- Requirements clear and specific
- No architectural decisions needed
- Simple CSS fix

**Agent Action:**
- Allocates worktree (agent-002)
- Updates ClickUp to "busy"
- Fixes styling in Login.tsx
- Creates PR #157
- Links PR to ClickUp task
- Updates task to "review"
- Releases worktree

## ClickUp Task Statuses

The agent manages these statuses:

| Status | Meaning | Agent Action |
|--------|---------|--------------|
| **todo** | Not started, clear requirements | Execute implementation |
| **busy** | Agent working, branch/PR created | Skip (already in progress) |
| **blocked** | Has unanswered questions | Skip until answered |
| **review** | PR created, awaiting testing | Skip (user responsibility) |
| **done** | Acceptance test passed | Skip (completed) |

## Configuration

### ClickUp Config

**Location:** `C:\scripts\_machine\clickup-config.json`

```json
{
  "api_key": "pk_...",
  "api_base": "https://api.clickup.com/api/v2",
  "default_list_id": "901214097647"
}
```

### Agent Config (Optional)

**Location:** `C:\scripts\_machine\clickhub-agent-config.json`

```json
{
  "enabled": true,
  "sleep_duration_seconds": 600,
  "max_tasks_per_cycle": 5,
  "priority_filter": ["urgent", "high", "normal"],
  "skip_assigned_tasks": true,
  "auto_block_uncertain": true,
  "dry_run": false
}
```

## Monitoring

### Activity Log

All agent actions logged to: `C:\scripts\_machine\clickhub-activity.log`

Example entries:
```
2026-01-19T12:00:00Z | CYCLE_START | 12 unassigned tasks found
2026-01-19T12:01:30Z | ANALYZE | Task 869abc123 | Questions posted, moved to blocked
2026-01-19T12:03:00Z | IMPLEMENT | Task 869def456 | Worktree allocated: agent-002
2026-01-19T12:15:00Z | PR_CREATED | Task 869def456 | PR #157 | Worktree released
2026-01-19T12:16:00Z | CYCLE_END | 2 tasks processed, sleeping 600s
```

### Real-Time Status

View current ClickUp tasks:
```powershell
C:/scripts/tools/clickup-sync.ps1 -Action list
```

View worktree pool:
```powershell
cat C:/scripts/_machine/worktrees.pool.md
```

## Safety Features

### 1. Dry Run Mode
Test without making changes:
```powershell
.\clickhub-single-cycle.ps1 -DryRun
```

### 2. Max Tasks Per Cycle
Prevent runaway execution:
```powershell
.\clickhub-continuous.ps1 -MaxTasksPerCycle 5
```

### 3. Emergency Stop
Graceful termination:
```powershell
# Create stop flag
New-Item C:/scripts/_machine/clickhub-stop.flag
```

### 4. Stale Task Detection
Skip tasks stuck in "busy" > 24 hours without PR

## Integration with Existing Workflow

### Uses These Skills Automatically:
- `allocate-worktree` - Worktree allocation
- `release-worktree` - Worktree cleanup
- `github-workflow` - PR creation
- `multi-agent-conflict` - Conflict detection

### Follows These Rules:
- Feature Development Mode (ZERO_TOLERANCE_RULES.md)
- Boy Scout Rule (SOFTWARE_DEVELOPMENT_PRINCIPLES.md)
- Definition of Done (DEFINITION_OF_DONE.md)

## Current Limitations

**As of 2026-01-19:**

1. **Helper Scripts Are Stubs** - The PowerShell scripts currently output placeholders. Full implementation requires Claude Agent execution context.

2. **Uncertainty Detection** - Currently uses simple heuristics. Claude's natural language understanding is needed for sophisticated analysis.

3. **Task Execution** - Actual code implementation requires Claude's reasoning and tool usage capabilities.

**Recommended Use:**
- Invoke as a Claude Skill (user-invocable: true)
- Claude will orchestrate the workflow using its full capabilities
- Helper scripts provide structure and logging

## Troubleshooting

### Issue: Agent Blocks Too Many Tasks

**Cause:** Conservative uncertainty detection

**Solution:**
- Review questions posted by agent
- Provide clear answers in ClickUp comments
- Update task descriptions to be more specific

### Issue: Worktree Pool Exhausted

**Cause:** All agent seats BUSY

**Solution:**
- Check `worktrees.pool.md` for stale allocations
- Release finished worktrees manually
- Auto-provision new agent seat (agent-013, etc.)

### Issue: ClickUp API Rate Limiting

**Cause:** Too many API calls

**Solution:**
- Increase sleep duration between cycles
- Reduce max tasks per cycle
- Add delays between API calls

## Example Session

```powershell
# Start continuous operation
PS> .\clickhub-continuous.ps1 -SleepSeconds 600 -MaxTasksPerCycle 5

================================================================
   ClickHub Coding Agent - CONTINUOUS MODE
================================================================

Settings:
  Sleep Duration: 600 seconds
  Max Tasks/Cycle: 5
  Dry Run: False

Press Ctrl+C to stop, or create: C:\scripts\_machine\clickhub-stop.flag

================================================================
  CYCLE #1 - 12:00:00
================================================================

[CYCLE_START] 12 unassigned tasks found

[ANALYZE] Task 869buekwz | Google Ads is missing in the connected accounts
  - Requirements clear
  - No existing branches
  - Ready for implementation

[IMPLEMENT] Task 869buekwz | Allocating worktree: agent-005
[IMPLEMENT] Task 869buekwz | Creating branch: feature/869buekwz-google-ads-integration
[IMPLEMENT] Task 869buekwz | Implementing changes...
[PR_CREATED] Task 869buekwz | PR #158 created
[PR_CREATED] Task 869buekwz | Worktree released: agent-005

[CYCLE_END] 1 task processed, sleeping 600s

────────────────────────────────────────────────────────────
Sleeping for 600 seconds...
Next cycle: 12:10:00
────────────────────────────────────────────────────────────
```

## Next Steps

1. **Test in Dry-Run** - Verify behavior without changes
2. **Run Single Cycle** - Monitor first execution closely
3. **Enable Continuous** - Start autonomous operation
4. **Monitor Logs** - Track activity and identify issues
5. **Iterate** - Refine uncertainty detection based on outcomes

## Support

**Documentation:** See `SKILL.md` for complete workflow details

**Logs:** `C:\scripts\_machine\clickhub-activity.log`

**Questions:** Create ClickUp task or add to reflection.log.md

---

**Created:** 2026-01-19
**Version:** 1.0.0
**Status:** Production Ready (with Claude Agent execution context)
