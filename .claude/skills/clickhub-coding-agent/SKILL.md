---
name: clickhub-coding-agent
description: Autonomous ClickUp task manager that analyzes unassigned tasks, identifies uncertainties, posts questions as comments, picks up todo tasks, executes code changes with worktree allocation, and operates in a continuous loop. Use when managing ClickUp tasks for myproject project.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, AskUserQuestion
user-invocable: true
---

# ClickHub Coding Agent

**Purpose:** Autonomous agent that manages ClickUp tasks, identifies requirements, executes development work, and operates continuously with sleep cycles.

## When to Use This Skill

**Use when:**
- User requests autonomous ClickUp task management
- Need to process multiple ClickUp tasks automatically
- Want continuous monitoring and execution of tasks
- Managing myproject project tasks from ClickUp

**Don't use when:**
- Single task execution (use normal workflow)
- User wants manual control over each task
- Tasks are already assigned to specific people
- Working outside myproject project

## Prerequisites

- ClickUp API configured (`C:\scripts\_machine\clickup-config.json`)
- `clickup-sync.ps1` tool available in `C:\scripts\tools\`
- Worktree pool system initialized
- Access to myproject and myframework repositories

## Workflow Steps

### Step 1: Fetch Unassigned Tasks

Retrieve all open tasks from ClickUp that are not assigned to anyone.

```powershell
# List all tasks from Brand Designer list
C:/scripts/tools/clickup-sync.ps1 -Action list

# Filter for unassigned tasks in 'todo' or 'busy' status
```

**Output:** List of tasks with ID, name, status, and description.

### Step 2: Analyze Each Task

For each unassigned task, perform comprehensive analysis:

#### 2.1 Understand Requirements

```markdown
Questions to ask yourself:
- What is the exact feature/fix being requested?
- What parts of the codebase will this affect?
- Are there dependencies on other tasks/PRs?
- What technical decisions need to be made?
- Are there any architectural implications?
- What testing is required?
```

#### 2.2 Search for Existing Code

```bash
# Search for related branches
cd C:/Projects/myproject
git branch -a | grep -i "<task-keyword>"

# Search for related PRs
gh pr list --search "<task-keyword>"

# Search codebase for related code
# Use Task tool with Explore agent for comprehensive search
```

#### 2.3 Detect Duplicate Tasks

**Check for similar/duplicate tasks in ClickUp:**

```powershell
# List all tasks to find similar ones
C:/scripts/tools/clickup-sync.ps1 -Action list

# Look for tasks with similar names or descriptions
# Example: "Google Login" and "Google OAuth integration" might be duplicates
```

**If duplicate found:**
- Identify which task is the "master" (usually older or more detailed)
- Post comment on duplicate task identifying the master
- Mark duplicate as blocked or close it

**Example comment for duplicate:**
```
DUPLICATE TASK DETECTED

This task appears to be a duplicate of:
- Task ID: 869abc123
- Task Name: "Google OAuth integration"
- Task URL: https://app.clickup.com/t/869abc123

Recommend closing this task and working on the master task instead.

-- ClickHub Coding Agent
```

#### 2.4 Identify Uncertainties

**Critical questions that MUST be answered before implementation:**
- Which approach should be taken? (if multiple options exist)
- What should the UI/UX look like? (for frontend tasks)
- What are the exact business rules? (for logic tasks)
- Are there existing patterns to follow?
- What are the acceptance criteria?

### Step 3: Handle Duplicates and Uncertainties

#### 3.1 Handle Duplicate Tasks

If task is identified as duplicate:

```powershell
# Post duplicate notice
C:/scripts/tools/clickup-sync.ps1 -Action comment -TaskId "<duplicate-task-id>" -Comment "
DUPLICATE TASK

This appears to be a duplicate of task #<master-task-id>: <master-task-name>
URL: https://app.clickup.com/t/<master-task-id>

Recommend closing this task and consolidating work on the master task.

-- ClickHub Coding Agent
"

# Move to blocked (or close if you have permission)
C:/scripts/tools/clickup-sync.ps1 -Action update -TaskId "<duplicate-task-id>" -Status "blocked"
```

#### 3.2 Post Questions as Comments

If **ANY** uncertainty exists that absolutely must be answered:

```powershell
# Post question as comment on ClickUp task
C:/scripts/tools/clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
QUESTIONS BEFORE IMPLEMENTATION:

1. [Architecture] Should we use Repository pattern or direct DbContext access?
2. [UI/UX] Should the modal be full-screen or centered overlay?
3. [Business Logic] What happens if user has no active subscription?

Please clarify before I proceed with implementation.

-- ClickHub Coding Agent
"
```

#### 3.3 Move to Blocked (if questions or duplicates exist)

```powershell
# Update task status to blocked
C:/scripts/tools/clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "blocked"
```

#### 3.4 Skip to Next Task

Do not implement tasks with unanswered questions. Move to next task.

### Step 3.5: Handle Previously Blocked Tasks - CRITICAL ANTI-LOOP PROTOCOL

**PROBLEM:** Agent can get into frustrating infinite loop:
1. Agent posts questions → Moves to blocked
2. User answers questions in comments
3. Agent sees task again → Doesn't read answers → Blocks again

**USER DIRECTIVE (2026-01-20):**
> "When you see a task that you moved to blocked and someone replied with a comment to your questions, then don't move it back into blocked without at least saying why you absolutely cannot continue without having these questions answered."

**PROTOCOL FOR BLOCKED TASKS:**

#### When Encountering a "Blocked" Task:

**Step 1: Check Comment History**
```powershell
# Get full task details including comments
C:/scripts/tools/clickup-sync.ps1 -Action show -TaskId "<task-id>"

# Look for:
# - Agent's previous "QUESTIONS BEFORE IMPLEMENTATION" comment
# - User replies after that comment
# - Timestamps to determine if questions were answered
```

**Step 2: Analyze User Responses**

**If user has replied with answers:**
- ✅ **READ THE ANSWERS CAREFULLY**
- ✅ Determine if answers provide enough information to proceed
- ✅ If yes → Move to "todo" status and implement (proceed to Step 4)
- ✅ If no → See Step 3 below

**Step 3: Only Re-Block If Absolutely Necessary**

**If answers are still insufficient:**
```powershell
# Post NEW comment explaining what's STILL missing
C:/scripts/tools/clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
FOLLOW-UP QUESTIONS:

Thank you for your previous response. I reviewed your answers but still need clarification on:

1. [Specific aspect] - Your answer mentioned X, but I need to know Y to proceed
2. [Another aspect] - Still unclear about Z

I want to move forward on this task, but these specific details will determine the implementation approach.

-- ClickHub Coding Agent
"

# Keep status as blocked (already blocked)
# Do NOT silently re-block - explain WHY in the comment
```

**Step 4: Make Best Effort Attempt**

**CRITICAL: Don't be overly cautious**
- If 80% of information is available → **PROCEED**
- Make reasonable assumptions and document them
- Post comment with assumptions: "Implementing with assumption that X. Please correct if wrong."
- Better to implement and iterate than endlessly block

**Step 5: Document Assumptions When Proceeding**

```powershell
# When moving forward with reasonable assumptions
C:/scripts/tools/clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
PROCEEDING WITH IMPLEMENTATION:

Based on your answers, I'm implementing with these assumptions:
- [Assumption 1]: Using centered modal (standard pattern for this app)
- [Assumption 2]: Repository pattern (consistent with existing code)
- [Assumption 3]: User without subscription sees upgrade prompt

If any of these assumptions are incorrect, the implementation can be adjusted in PR review.

Moving to 'busy' status and assigning.

-- ClickHub Coding Agent
"

# Update to busy and implement - ALWAYS assign when moving to busy
C:/scripts/tools/clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "busy" -Assignee "74525428"
```

**ANTI-PATTERNS TO AVOID:**

❌ **DON'T:** Silently re-block task after user has replied
❌ **DON'T:** Ask the same questions again
❌ **DON'T:** Block tasks for minor uncertainties that can be resolved in PR review
❌ **DON'T:** Wait for 100% perfect information before starting
❌ **DON'T:** Ignore user's attempt to answer questions

✅ **DO:** Read all comments carefully
✅ **DO:** Make best effort with available information
✅ **DO:** Document assumptions when proceeding
✅ **DO:** Only re-block if truly impossible to proceed
✅ **DO:** Explain specifically what's still missing

**DECISION TREE:**

```
Blocked task encountered
  ↓
Has user replied to questions?
  ↓
├─ NO → Keep blocked, skip to next task
  ↓
├─ YES → Read replies carefully
     ↓
     Can I proceed with 80%+ information?
       ↓
       ├─ YES → Post assumptions comment → Move to busy → Implement
       ↓
       ├─ MAYBE → Try to infer missing details → Post assumptions → Implement
       ↓
       ├─ NO → Post specific follow-up questions → Explain WHY still blocked → Keep blocked
```

**PHILOSOPHY:**

**Bias toward action, not paralysis.**
- Users prefer iterations over perfection
- PRs allow for feedback and refinement
- Implementation reveals edge cases better than theoretical discussion
- Blocked tasks frustrate users - make every effort to unblock

### Step 4: Execute TODO Tasks

For tasks in "todo" status with NO uncertainties:

#### 4.1 Check for Existing Branch

```bash
cd C:/Projects/myproject
git fetch --all

# Check if branch already exists
BRANCH_NAME="feature/<task-id>-<description>"
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" || git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
    echo "Branch exists - will checkout existing"
else
    echo "No branch - will create new"
fi
```

#### 4.2 Allocate Worktree

**CRITICAL:** Follow Feature Development Mode (ZERO_TOLERANCE_RULES.md)

```bash
# Read worktree pool
cat C:/scripts/_machine/worktrees.pool.md

# Find FREE seat (e.g., agent-002)
AGENT_SEAT="agent-002"

# Update pool to BUSY (manually edit or use tool)

# Allocate paired worktrees (myproject + myframework)
cd C:/Projects/myproject
git worktree add "C:/Projects/worker-agents/$AGENT_SEAT/myproject" -b "$BRANCH_NAME" || \
git worktree add "C:/Projects/worker-agents/$AGENT_SEAT/myproject" "$BRANCH_NAME"

cd C:/Projects/myframework
git worktree add "C:/Projects/worker-agents/$AGENT_SEAT/myframework" -b "$BRANCH_NAME" || \
git worktree add "C:/Projects/worker-agents/$AGENT_SEAT/myframework" "$BRANCH_NAME"

# Log allocation
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $AGENT_SEAT | ALLOCATE | $BRANCH_NAME | ClickHub task <task-id>" >> C:/scripts/_machine/worktrees.activity.md
```

#### 4.3 Implement the Task

```bash
# Work in worktree directory
cd "C:/Projects/worker-agents/$AGENT_SEAT/myproject"

# Read existing code, understand patterns
# Use Task/Explore agent for complex analysis
# Implement changes following:
# - Boy Scout Rule (clean as you go)
# - Existing code patterns
# - Architecture principles from SOFTWARE_DEVELOPMENT_PRINCIPLES.md
# - Definition of Done from DEFINITION_OF_DONE.md
```

#### 4.4 Update ClickUp Task Status and Assign

**CRITICAL:** ALWAYS assign task when moving to "busy" or "review"

```powershell
# Update to busy when starting implementation AND assign to someone
# Default assignee: 74525428 (Martien de Jong - primary developer)
C:/scripts/tools/clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "busy" -Assignee "74525428"

# Add progress comment
C:/scripts/tools/clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
IMPLEMENTATION STARTED

Branch: $BRANCH_NAME
Worktree: $AGENT_SEAT
Approach: [Brief description of technical approach]
Assigned to: Martien de Jong

-- ClickHub Coding Agent
"
```

#### 4.5 Complete Implementation

```bash
# Commit changes
git add -A
git commit -m "feat(task-<task-id>): [Conventional commit message]

[Detailed description]

ClickUp: <task-id>"

# Push branch
git push -u origin "$BRANCH_NAME"

# Create PR
gh pr create \
  --title "feat(task-<task-id>): [PR title]" \
  --body "## Summary
- [Bullet point summary]

## ClickUp Task
- Task ID: <task-id>
- Task URL: https://app.clickup.com/t/<task-id>

## Test Plan
- [ ] [Test step 1]
- [ ] [Test step 2]

## Screenshots/Videos
[If applicable]

🤖 Generated by ClickHub Coding Agent with [Claude Code](https://claude.com/claude-code)" \
  --base develop
```

#### 4.6 Link PR to ClickUp and Assign Reviewer

```powershell
# Get PR number from gh output
$PR_NUMBER = <number>

# Link PR to task
C:/scripts/tools/clickup-sync.ps1 -Action link-pr -TaskId "<task-id>" -PrNumber $PR_NUMBER

# Update task to review status AND assign to reviewer
# Default assignee: 74525428 (Martien de Jong - primary reviewer)
C:/scripts/tools/clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "review" -Assignee "74525428"
```

#### 4.7 Release Worktree

**CRITICAL:** Follow Release Protocol (ZERO_TOLERANCE_RULES.md)

```bash
# Clean worktree
rm -rf "C:/Projects/worker-agents/$AGENT_SEAT/myproject"
rm -rf "C:/Projects/worker-agents/$AGENT_SEAT/myframework"

# Update pool to FREE
# Edit C:/scripts/_machine/worktrees.pool.md

# Log release
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $AGENT_SEAT | RELEASE | $BRANCH_NAME | PR #$PR_NUMBER created" >> C:/scripts/_machine/worktrees.activity.md

# Prune worktrees
cd C:/Projects/myproject && git worktree prune
cd C:/Projects/myframework && git worktree prune

# Switch base repos to develop
cd C:/Projects/myproject && git checkout develop && git pull
cd C:/Projects/myframework && git checkout develop && git pull
```

### Step 5: Review Existing Busy Tasks

For tasks already in "busy" status:

#### 5.1 Check for Unanswered Questions

```powershell
# Show task details
C:/scripts/tools/clickup-sync.ps1 -Action show -TaskId "<task-id>"

# Read comments and description
# If new questions have been posted by users, and they're unanswered
# Move task to blocked
```

#### 5.2 Move to Blocked if Needed

```powershell
C:/scripts/tools/clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "blocked"
C:/scripts/tools/clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
MOVED TO BLOCKED

Reason: Unanswered questions prevent further progress.
Questions: [List the questions]

-- ClickHub Coding Agent
"
```

### Step 6: Sleep and Loop

After processing all tasks:

```powershell
# Log completion of cycle
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "[$timestamp] ClickHub cycle complete. Sleeping for 10 minutes..." -ForegroundColor Green

# Sleep for 10 minutes (600 seconds)
Start-Sleep -Seconds 600

# Start next cycle (goto Step 1)
```

## Continuous Operation Mode

The agent operates in a continuous loop:

```
Loop Forever:
  1. Fetch unassigned tasks
  2. Analyze each task
  3. Post questions / move to blocked
  4. Execute todo tasks
  5. Review busy tasks
  6. Sleep 10 minutes
  7. Repeat
End Loop
```

**Stopping:** User must manually interrupt (Ctrl+C) or set a flag file.

## Examples

### Example 1: Duplicate Task Detected

**ClickUp Tasks Found:**
- Task #869bt9uak: "Google Login"
- Task #869buekwz: "Google Ads is missing in the connected accounts"

**Agent Analysis:**
```
POTENTIAL DUPLICATES:
- Both tasks mention "Google" integration
- Need to verify if they're the same feature or different
```

**Agent Action:**
- Reviews both task descriptions in detail
- Determines they are different (Login vs Ads)
- No action needed - continues with analysis

**Actual Duplicate Example:**
- Task #869bt9uak: "Google Login"
- Task #869bt9ubt: "Google Login OAuth Integration"

**Agent Action:**
- Posts comment on #869bt9ubt identifying #869bt9uak as master
- Moves #869bt9ubt to "blocked" status
- Recommends user close duplicate

### Example 2: Task with Uncertainties

**ClickUp Task #869abc123:**
- Name: "Add user profile export feature"
- Status: todo
- Description: "Users should be able to export their profile data"

**Agent Analysis:**
```
QUESTIONS IDENTIFIED:
1. What format should the export be? (JSON, CSV, PDF?)
2. Should it include all user data or be selective?
3. Should export be async with email notification or immediate download?
4. Are there GDPR compliance requirements?
```

**Agent Action:**
- Posts questions as comment
- Updates status to "blocked"
- Skips to next task

### Example 3: Task Ready for Implementation

**ClickUp Task #869def456:**
- Name: "Fix broken login button styling"
- Status: todo
- Description: "Login button on /auth page is misaligned. Should be centered and 300px wide."

**Agent Analysis:**
```
CERTAINTIES:
- Clear requirement: center button, 300px width
- Affected file: likely src/pages/auth/Login.tsx
- No architectural decisions needed
- Simple CSS fix
```

**Agent Action:**
- Allocates worktree (agent-002)
- Updates task to "busy"
- Implements fix in Login.tsx
- Creates PR #157
- Links PR to task
- Updates task to "review"
- Releases worktree

### Example 4: Existing Branch Found

**ClickUp Task #869ghi789:**
- Name: "Implement dark mode toggle"
- Status: todo

**Agent Analysis:**
```bash
$ git branch -a | grep -i dark
  remotes/origin/feature/869ghi789-dark-mode
```

**Agent Action:**
- Allocates worktree
- Checks out existing branch `feature/869ghi789-dark-mode`
- Reviews existing code
- Completes remaining work
- Creates PR
- Links to task

### Example 5: Continuous Operation

**Cycle 1 (00:00):**
- Task #123: Posted questions, moved to blocked
- Task #456: Implemented, PR created
- Task #789: Implemented, PR created
- Sleep 10 minutes

**Cycle 2 (00:10):**
- Task #123: Still blocked, no new answers
- Task #456: Now in review (skip)
- Task #101: New todo task, implemented, PR created
- Sleep 10 minutes

**Cycle 3 (00:20):**
- Task #123: User answered questions! Move to todo, implement
- No other unassigned todo tasks
- Sleep 10 minutes

## Success Criteria

✅ All unassigned tasks analyzed at least once
✅ Questions posted as comments on uncertain tasks
✅ Tasks with questions moved to "blocked" status
✅ Todo tasks with clear requirements implemented
✅ All code changes follow Feature Development Mode (worktrees)
✅ PRs created and linked to ClickUp tasks
✅ Worktrees released after PR creation
✅ Tasks updated to "review" status after PR
✅ Agent sleeps 10 minutes between cycles
✅ Continuous operation without manual intervention

## Common Issues

### Issue: Too Many Tasks to Process

**Symptom:** Agent takes > 10 minutes to process all tasks

**Cause:** Large backlog of unassigned tasks

**Solution:**
- Prioritize tasks by ClickUp priority field
- Process max 5 tasks per cycle
- Skip tasks that are low priority

### Issue: Worktree Pool Exhausted

**Symptom:** All agent seats are BUSY

**Cause:** Multiple parallel implementations

**Solution:**
- Auto-provision new agent seat (agent-013, agent-014, etc.)
- OR queue tasks for next available seat
- Log warning in reflection.log.md

### Issue: Uncertainty Identification Too Conservative

**Symptom:** Agent blocks too many tasks unnecessarily

**Cause:** Over-cautious question detection

**Solution:**
- Use Task/Explore agent to research existing patterns
- Only block if answer would significantly change implementation
- Document decision-making criteria in comments

### Issue: ClickUp API Rate Limiting

**Symptom:** 429 Too Many Requests errors

**Cause:** Too many API calls in short time

**Solution:**
- Batch operations where possible
- Add delays between API calls (2-3 seconds)
- Cache task list for cycle duration

### Issue: Infinite Loop on Same Task

**Symptom:** Agent keeps picking up same task repeatedly

**Cause:** Task status not updating correctly

**Solution:**
- Verify ClickUp API status update succeeded
- Add task ID to skip list for current cycle
- Log issue in reflection.log.md

## Safety Mechanisms

### 1. Dry Run Mode

Before enabling continuous operation, run one cycle manually:

```powershell
# Run single cycle without sleep
.\clickhub-single-cycle.ps1 -DryRun
```

### 2. Max Tasks Per Cycle

Limit number of tasks processed per cycle to prevent runaway execution:

```powershell
$MAX_TASKS_PER_CYCLE = 5
```

### 3. Emergency Stop Flag

Create a stop file to gracefully terminate:

```powershell
# Agent checks for this file before each cycle
$STOP_FLAG = "C:/scripts/_machine/clickhub-stop.flag"

if (Test-Path $STOP_FLAG) {
    Write-Host "Stop flag detected. Exiting gracefully..."
    Remove-Item $STOP_FLAG
    exit 0
}
```

### 4. Stale Task Detection

Skip tasks that have been in "busy" for > 24 hours without PR:

```powershell
# Check task age
$taskAge = (Get-Date) - [DateTimeOffset]::FromUnixTimeMilliseconds($task.date_updated)
if ($taskAge.TotalHours -gt 24 -and $task.status.status -eq "busy") {
    # Post warning comment
    # Consider moving to blocked for review
}
```

## Integration with Existing Skills

**Uses these skills:**
- `allocate-worktree` - For worktree allocation in Step 4.2
- `release-worktree` - For worktree release in Step 4.7
- `github-workflow` - For PR creation in Step 4.5
- `multi-agent-conflict` - Before allocating worktree

**Complements:**
- `feature-mode` - Implements Feature Development Mode
- `debug-mode` - Skipped for autonomous operation

## Configuration

### ClickUp Config

Located at: `C:\scripts\_machine\clickup-config.json`

```json
{
  "api_key": "pk_...",
  "api_base": "https://api.clickup.com/api/v2",
  "default_list_id": "901214097647"
}
```

### Agent Config

Create: `C:\scripts\_machine\clickhub-agent-config.json`

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

## Monitoring and Logging

### Activity Log

All actions logged to: `C:\scripts\_machine\clickhub-activity.log`

```
2026-01-19T12:00:00Z | CYCLE_START | 12 unassigned tasks found
2026-01-19T12:01:30Z | ANALYZE | Task 869abc123 | Questions posted, moved to blocked
2026-01-19T12:03:00Z | IMPLEMENT | Task 869def456 | Worktree allocated: agent-002
2026-01-19T12:15:00Z | PR_CREATED | Task 869def456 | PR #157 | Worktree released
2026-01-19T12:16:00Z | CYCLE_END | 2 tasks processed, sleeping 600s
```

### Metrics Dashboard

Track performance:
- Tasks processed per cycle
- Average time per task
- Question-to-blocked ratio
- PR creation success rate
- Worktree allocation efficiency

## Related Skills

- `allocate-worktree` - Worktree allocation protocol
- `release-worktree` - Worktree release protocol
- `github-workflow` - PR creation and management
- `multi-agent-conflict` - Conflict detection before allocation
- `feature-mode` - Feature Development Mode rules
- `session-reflection` - Document learnings from autonomous operation

## Operational Notes

**Initial Setup:**
1. Ensure ClickUp API credentials configured
2. Test clickup-sync.ps1 manually
3. Run first cycle in dry-run mode
4. Monitor first 3 cycles closely
5. Enable continuous operation

**User Responsibility:**
- Review PRs created by agent
- Answer questions posted by agent
- Move tasks from "review" to "done" after acceptance testing
- Monitor agent activity log for issues

**Agent Responsibility:**
- Analyze all unassigned tasks
- Identify and post questions
- Implement clear tasks autonomously
- Follow all ZERO_TOLERANCE_RULES
- Release worktrees properly
- Maintain continuous operation

---

**Created:** 2026-01-19
**Author:** Claude Agent (Autonomous Task Management)
**Version:** 1.0.0
