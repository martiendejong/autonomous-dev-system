---
name: clickhub-coding-agent
description: Autonomous ClickUp task manager that analyzes unassigned tasks, identifies uncertainties, posts questions as comments, picks up todo tasks, executes code changes with worktree allocation, and operates in a continuous loop. Works with ANY ClickUp board - internal projects, client projects, or specific boards by list ID.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, AskUserQuestion
user-invocable: true
---

# ClickHub Coding Agent

**Purpose:** Autonomous agent that manages ClickUp tasks from any ClickUp board, identifies requirements, executes development work, and operates continuously with sleep cycles.

## Supported Project Scopes

**Configuration source:** `C:\scripts\_machine\clickup-config.json`

### Internal Projects (Default Scope)
| Project | List ID | Type | Repos | Environment |
|---------|---------|------|-------|-------------|
| Brand Designer (client-manager) | 901214097647 | Fullstack | client-manager, hazina | Visual Studio |
| Hazina Framework | 901215559249 | Framework | hazina | Visual Studio |
| Brand2Boost Birdseye | 901215573347 | Strategic | client-manager | Visual Studio |
| LearningTool | 901215905273 | Fullstack | learningtool | VSCode |
| General & Meta Tasks | 901215818012 | Meta | various | Mixed |

### Client Projects
| Project | List ID | Type | Repos | Environment |
|---------|---------|------|-------|-------------|
| Art Revisionist | 901211612245 | WordPress | - | XAMPP |
| Vera AI | 901211218614 | Client | - | Mixed |
| wreckingball.ai | 901211218756 | Client | - | Mixed |
| CloudGrafo | 901213168637 | Client | - | Mixed |
| Vloerenhuis | 901213305955 | Client | - | Mixed |

### Personal Projects
| Project | List ID | Type | Environment |
|---------|---------|------|-------------|
| Nijeveen Household | 901519266250 | Household | Mixed |
| SocraNext | 901511986511 | Project | Mixed |

## Invocation Modes

### Mode 1: All Internal + Client Projects (Default)
```
"Run the clickup coding agent"
"Start clickhub autonomous mode"
```
**Scope:** All internal projects (Brand Designer, Hazina, LearningTool, Meta) + all client projects (Art Revisionist, Vera AI, etc.)

### Mode 2: Specific Project by Name
```
"Run the clickup coding agent for art-revisionist"
"Start clickhub for learningtool"
"Run clickhub agent on hazina framework"
```
**Scope:** Only tasks from specified project

### Mode 3: Specific Board by List ID
```
"Run the clickup coding agent for list 901211612245"
"Start clickhub on board 901519266250"
```
**Scope:** Only tasks from specified list ID (useful for unlisted boards)

### Mode 4: Multiple Specific Projects
```
"Run clickhub for client-manager and hazina"
"Start clickhub on art-revisionist and vera-ai"
```
**Scope:** Only specified projects

### Mode 5: Category Filter
```
"Run clickhub for internal projects only"
"Run clickhub for client projects only"
"Run clickhub for all projects including household"
```
**Scope:** Internal-only, client-only, or all (including personal)

## When to Use This Skill

**Use when:**
- User requests autonomous ClickUp task management
- Need to process multiple ClickUp tasks automatically
- Want continuous monitoring and execution of tasks
- Managing tasks from any configured ClickUp project

**Don't use when:**
- Single task execution (use normal workflow)
- User wants manual control over each task
- Tasks are already assigned to specific people

## ⚠️ CRITICAL: ClickUp Workflow (Swimlanes)

**MANDATORY workflow - NEVER deviate from this:**

```
┌─────────┐
│  TODO   │ ← Start here (pick up unassigned tasks)
└────┬────┘
     │ Agent starts work
     ▼
┌─────────────┐
│IN PROGRESS/ │ ← Working on task (agent assigned)
│   BUSY      │
└────┬────────┘
     │ Work complete, PR created
     ▼
┌─────────┐
│ REVIEW  │ ← Waiting for code review
└────┬────┘
     │
     ├─────────────┐
     │             │
     ▼             ▼
┌─────────┐   ┌─────────┐
│  TODO   │   │ TESTING │ ← Code merged to develop (ONLY THEN)
└─────────┘   └────┬────┘
  (rework)         │ User validates
                   ▼
              ┌─────────┐
              │  DONE   │ ← User sets to done
              └─────────┘

┌──────────────────┐
│ NEEDS INFO /     │ ← ONLY when truly blocked (use sparingly!)
│ BLOCKED          │
└──────────────────┘
```

### Status Transition Rules

**1. TODO → IN PROGRESS/BUSY**
- When: Agent starts working on task
- Required: Assign task to agent/user
- Action: Post "🤖 AGENT WORKING" comment with agent ID + branch name

**2. IN PROGRESS/BUSY → REVIEW**
- When: PR created and pushed
- Required: PR link in comment + "✅ AGENT COMPLETED" comment
- Action: Move to REVIEW, keep assignee (reviewer)

**3. REVIEW → TESTING**
- When: PR merged to develop (ONLY THEN!)
- Who: clickup-reviewer agent or human reviewer
- Required: PR must be merged first, then move status
- ⚠️ NEVER move to testing before merge!

**4. REVIEW → TODO**
- When: Review rejected, changes requested
- Required: Clear comment explaining what needs rework
- Action: Unassign or reassign to original implementer

**5. TESTING → DONE**
- When: User validates feature works in develop
- Who: ONLY user can do this (not agent)
- Action: Agent NEVER moves tasks to done

**6. ANY → NEEDS INFO / BLOCKED**
- When: Genuinely cannot proceed (missing requirements, external dependency)
- ⚠️ Use SPARINGLY - prefer asking in comments and continuing with assumptions
- Required: MUST explain exactly what's blocking and what's needed
- Action: Post detailed comment, try to unblock yourself first

### ❌ FORBIDDEN Transitions

- ❌ IN PROGRESS → TESTING (skipping review)
- ❌ TODO → TESTING (skipping implementation + review)
- ❌ REVIEW → DONE (skipping testing)
- ❌ Any status → DONE by agent (only user sets done)
- ❌ Moving to BLOCKED without clear explanation
- ❌ Moving to TESTING before PR merged

### Comment Guidelines (MANDATORY)

**When posting comments, ALWAYS:**

✅ **Keep it short and simple** (max 10 lines for routine updates)
✅ **Show ALL URLs** - PR links, branch links, documentation links
✅ **Use clear formatting** - headers, bullets, code blocks
✅ **Read existing comments FIRST** - avoid repeating questions
✅ **Be specific** - "PR #123 has merge conflicts" not "there's a problem"

**Comment Format:**
```markdown
🤖 [ACTION TAKEN]

[Brief description]

Links:
- PR: https://github.com/org/repo/pull/123
- Branch: feature/task-869abc123-description

[Next steps or blockers if any]

-- Claude Code Agent (agent-XXX)
```

**Examples:**

✅ **GOOD:**
```
🤖 AGENT WORKING

Agent: agent-003
Branch: feature/task-869abc-add-login
PR: Will create when ready

Working on Google OAuth integration.
```

✅ **GOOD:**
```
✅ AGENT COMPLETED

PR: https://github.com/martiendejong/client-manager/pull/157
Branch: feature/task-869abc-add-login
Files: 8 changed, 245 additions

Ready for review. All MUST HAVE items complete.
```

❌ **BAD:**
```
I've been working on this task and I think I've implemented most of the requirements that were described in the task description. I created a pull request but I'm not entirely sure if everything is correct. Let me know if you have any questions or if I should change anything. The branch name is quite long but hopefully that's okay.
```

❌ **BAD (no URLs):**
```
PR created, ready for review
```

## Prerequisites

- ClickUp API configured (`C:\scripts\_machine\clickup-config.json`)
- `clickup-sync.ps1` tool available in `C:\scripts\tools\`
- Worktree pool system initialized
- Access to client-manager and hazina repositories
- **MoSCoW prioritization framework** (`C:\scripts\MOSCOW_PRIORITIZATION.md`) ⭐ MANDATORY

## Workflow Steps

### Step 0: Determine Scope & Load Project Configuration

**ALWAYS load full project configuration first:**

```powershell
# Load ClickUp configuration
$config = Get-Content "C:\scripts\_machine\clickup-config.json" | ConvertFrom-Json

# Determine scope based on user request
$SCOPE = @{
    Mode = "default"  # default | specific | listid | multiple | category
    Projects = @()     # Project keys to process
    ListIds = @()      # Direct list IDs
}

# Parse user request:
# "for art-revisionist" → Mode=specific, Projects=@("art-revisionist")
# "for list 901211612245" → Mode=listid, ListIds=@("901211612245")
# "for client-manager and hazina" → Mode=multiple, Projects=@("client-manager","hazina")
# "for internal projects only" → Mode=category, Projects=@(all internal)
# "for client projects only" → Mode=category, Projects=@(all client)
# No specification → Mode=default, Projects=@(all internal + all client)
```

**Default scope (no user specification):**
```powershell
# Internal projects folder (901266650982)
$internalProjects = @(
    "client-manager",      # 901214097647
    "hazina",              # 901215559249
    "brand2boost-birdseye", # 901215573347
    "learningtool",        # 901215905273
    "general-meta"         # 901215818012
)

# Client projects folder (90126651004)
$clientProjects = @(
    "art-revisionist",     # 901211612245
    "vera-ai",             # 901211218614
    "wreckingball",        # 901211218756
    "cloudgrafo",          # 901213168637
    "vloerenhuis"          # 901213305955
)

# Default = internal + client (NOT household/personal unless explicitly requested)
$SCOPE.Projects = $internalProjects + $clientProjects
```

**Build list of list IDs to query:**
```powershell
$listIdsToQuery = @()

switch ($SCOPE.Mode) {
    "default" {
        # Map all internal + client projects to list IDs
        foreach ($project in $SCOPE.Projects) {
            $listIdsToQuery += $config.projects.$project.list_id
        }
    }
    "specific" {
        # Map specified project(s) to list IDs
        foreach ($project in $SCOPE.Projects) {
            $listIdsToQuery += $config.projects.$project.list_id
        }
    }
    "listid" {
        # Direct list IDs
        $listIdsToQuery = $SCOPE.ListIds
    }
    "multiple" {
        # Map multiple projects
        foreach ($project in $SCOPE.Projects) {
            $listIdsToQuery += $config.projects.$project.list_id
        }
    }
    "category" {
        # Already populated in $SCOPE.Projects
        foreach ($project in $SCOPE.Projects) {
            $listIdsToQuery += $config.projects.$project.list_id
        }
    }
}

Write-Host "ClickHub Scope: $($SCOPE.Mode)"
Write-Host "Projects: $($SCOPE.Projects -join ', ')"
Write-Host "List IDs: $($listIdsToQuery -join ', ')"
```

### Step 1: Fetch Unassigned Tasks Across All Boards

Retrieve all open tasks from ClickUp across all boards in scope:

```powershell
$allTasks = @()

foreach ($listId in $listIdsToQuery) {
    # Fetch tasks from this list
    $tasks = C:/scripts/tools/clickup-sync.ps1 -Action list -ListId $listId

    # Filter for unassigned tasks in 'todo' or 'blocked' status
    $unassigned = $tasks | Where-Object {
        $_.assignees.Count -eq 0 -and
        ($_.status.status -in @("todo", "to do", "blocked", "backlog", "refined"))
    }

    # Add project context to each task
    foreach ($task in $unassigned) {
        $task | Add-Member -NotePropertyName "ProjectContext" -NotePropertyValue (
            $config.projects.GetEnumerator() |
            Where-Object { $_.Value.list_id -eq $listId } |
            Select-Object -First 1 -ExpandProperty Key
        )
    }

    $allTasks += $unassigned
}

Write-Host "Found $($allTasks.Count) unassigned tasks across $($listIdsToQuery.Count) boards"
```

### Step 1.5: Prioritize Tasks Using Learning Engine ⭐ NEW

**MANDATORY: Use learning engine to prioritize tasks before working on them**

```powershell
# Load learning engine
$learningEngine = "C:\scripts\tools\clickhub-learning-engine.ps1"

# Check for previous crash recovery opportunities
$crashRecovery = "C:\scripts\tools\clickhub-crash-recovery.ps1"
& $crashRecovery -Action List | Out-Null

# Prioritize tasks based on:
# - ClickUp priority (urgent > high > normal > low)
# - Historical difficulty (tasks that failed before)
# - Age (how long in todo)
# - Deadlines (urgent if <24hrs)
# - Blocks other tasks
$prioritizedTasks = & $learningEngine -Action PrioritizeTasks -Tasks $allTasks -Verbose

# Work on highest priority tasks first
Write-Host "`nTop 10 Priority Tasks:" -ForegroundColor Cyan
foreach ($task in $prioritizedTasks | Select-Object -First 10) {
    Write-Host "  [$($task.PriorityScore)] $($task.name)" -ForegroundColor White
    Write-Host "    Project: $($task.ProjectContext) | Difficulty: $($task.DifficultyEstimate)" -ForegroundColor Gray
}

# Use prioritized list for all subsequent operations
$allTasks = $prioritizedTasks
```

**Output:** List of tasks sorted by priority score, with difficulty estimates.

### Step 2: Analyze Each Task

For each unassigned task, perform comprehensive analysis:

#### 2.1 Understand Requirements & Apply MoSCoW Prioritization ⭐ MANDATORY

**CRITICAL (2026-02-07): MoSCoW prioritization is REQUIRED for all ClickUp tasks**
**Reference:** `C:\scripts\MOSCOW_PRIORITIZATION.md` (User mandate from task #869bu91e5)

```markdown
Questions to ask yourself:
- What is the exact feature/fix being requested?
- **What are the MUST HAVE requirements? (Critical - cannot skip)**
- **What are SHOULD HAVE requirements? (Important but can defer)**
- **What are COULD HAVE requirements? (Nice-to-have only)**
- **What are WON'T HAVE requirements? (Explicitly out of scope)**
- What parts of the codebase will this affect?
- Are there dependencies on other tasks/PRs?
- What technical decisions need to be made?
- Are there any architectural implications?
- What testing is required?
```

**MoSCoW Analysis Template:**

```
MUST HAVE (Critical - Will implement):
- [Core requirement 1]
- [Core requirement 2]

SHOULD HAVE (Important - Include if time allows):
- [Enhanced feature 1]

COULD HAVE (Nice-to-have - Lower priority):
- [Optional improvement 1]

WON'T HAVE (Out of scope for this iteration):
- [Future consideration 1]
```

#### 2.2 Search for Existing Code

```bash
# Search for related branches
cd C:/Projects/client-manager
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

#### 2.4 Verify Bug Reproduction (For Bug Reports)

**CRITICAL - Added 2026-02-04:**

Before implementing bug fixes, verify the bug actually exists:

```powershell
# For bug reports, ALWAYS check:
# 1. Is the feature already implemented?
# 2. Can I reproduce the issue?
# 3. Is this a user misunderstanding vs actual bug?

# Example: "Chat streaming not working"
# - Check: Is streaming code already in place?
# - Test: Run app and observe actual behavior
# - Verify: Confirm bug vs investigate first
```

**Decision Tree for Bug Reports:**

```
Bug reported in ClickUp
  ↓
Search codebase for related code
  ↓
Feature already implemented?
  ↓
├─ YES → Test actual behavior
     ↓
     Bug confirmed?
       ↓
       ├─ YES → Proceed to implementation
       ↓
       ├─ NO → Ask user for clarification (move to blocked)
  ↓
├─ NO → Feature not implemented, proceed
```

**Protocol:**
1. **Investigate FIRST** - Search codebase before allocating worktree
2. **Verify SECOND** - Test behavior if possible
3. **Clarify THIRD** - Ask user if unclear
4. **Allocate LAST** - Only allocate worktree after confirming work needed

**Anti-Pattern:**
❌ Allocate worktree → Investigate → Discover no work needed
✅ Investigate → Verify → Clarify → Allocate → Implement

#### 2.5 Identify Uncertainties

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

#### 3.2 Post MoSCoW Analysis & Questions as Comments ⭐ MANDATORY

**ALWAYS post MoSCoW analysis BEFORE starting implementation:**

```powershell
# Post MoSCoW analysis as comment on ClickUp task
C:/scripts/tools/clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
📊 MOSCOW PRIORITIZATION ANALYSIS

MUST HAVE (Critical - Will implement):
- [Core feature/requirement]
- [Critical functionality]

SHOULD HAVE (Important - Will implement if time allows):
- [Enhanced feature]
- [Important improvement]

COULD HAVE (Nice-to-have - Lower priority):
- [Optional enhancement]

WON'T HAVE (Out of scope for this iteration):
- [Future consideration]

If you disagree with this prioritization, please clarify before I continue.

-- ClickHub Coding Agent
"
```

**If uncertainties exist about MUST HAVE scope:**

```powershell
# Post questions as comment on ClickUp task
C:/scripts/tools/clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
QUESTIONS BEFORE IMPLEMENTATION:

MoSCoW Analysis Questions:
1. [Must Have?] Is [feature X] critical for this iteration?
2. [Architecture] Should we use Repository pattern or direct DbContext access?
3. [UI/UX] Should the modal be full-screen or centered overlay?

Please clarify the MUST HAVE scope before I proceed with implementation.

-- ClickHub Coding Agent
"
```

#### 3.3 Move to Blocked/Needs Info (USE SPARINGLY!)

**⚠️ CRITICAL: Only use BLOCKED/NEEDS INFO when TRULY stuck**

**Use BLOCKED/NEEDS INFO when:**
- Truly cannot proceed without critical information
- External dependency is genuinely blocking progress
- Requirements are fundamentally unclear or contradictory

**DO NOT use BLOCKED/NEEDS INFO when:**
- Minor details are unclear (make reasonable assumptions)
- You can continue with 80%+ of the information
- It's just a preference question (pick the sensible default)
- You can ask in comment and continue working

**If you MUST block:**

```powershell
# Post DETAILED explanation of what's blocking
C:/scripts/tools/clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
⚠️ BLOCKED - Need Critical Information

Blocking Issue:
[Exactly what's blocking and why you can't proceed]

Information Needed:
1. [Specific question 1]
2. [Specific question 2]

Why This Blocks Progress:
[Explain what you would implement differently based on the answer]

I cannot make reasonable assumptions here because:
[Explain why 80% solution isn't acceptable]

-- ClickHub Coding Agent
"

# Update task status to blocked OR needs info
C:/scripts/tools/clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "blocked"
# OR
C:/scripts/tools/clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "needs input"
```

**Better alternatives to blocking:**
- Post questions in comment, continue with reasonable assumptions
- Implement MUST HAVE items, defer SHOULD/COULD items pending clarification
- Create PR with comment explaining assumptions made
- Pick the most sensible default and document it

#### 3.4 Skip to Next Task

Only skip tasks that are truly blocked. Prefer making assumptions and continuing.

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

#### 4.1 Check for Existing Work (MANDATORY - Prevents Duplicate Effort)

**STEP 1: Check if another agent is already working on this task**

```powershell
# Get task details including comments
$taskDetails = C:/scripts/tools/clickup-sync.ps1 -Action show -TaskId "<task-id>"

# Look for recent "AGENT WORKING" comment without "COMPLETED" or "HANDOFF"
# If found and recent (within 2 hours), SKIP this task - another agent is on it!
if ($taskDetails -match "🤖 AGENT WORKING" -and $taskDetails -notmatch "✅ AGENT COMPLETED") {
    Write-Host "WARNING: Another agent is already working on this task!" -ForegroundColor Yellow
    Write-Host "Check ClickUp comments for agent ID and status" -ForegroundColor Yellow
    # SKIP to next task
    return
}
```

**STEP 2: Check for existing branch**

```bash
cd C:/Projects/client-manager
git fetch --all

# Check if branch already exists
BRANCH_NAME="feature/<task-id>-<description>"
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" || git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
    echo "Branch exists - will checkout existing"
else
    echo "No branch - will create new"
fi
```

#### 4.2 Create Checkpoint - Starting Analysis ⭐ NEW

**MANDATORY: Checkpoint before starting work**

```powershell
$AGENT_ID = "agent-007"  # Your agent seat
$TASK_ID = $task.id
$PROJECT = $task.ProjectContext

# Create checkpoint for crash recovery
& $crashRecovery -Action Checkpoint `
    -AgentId $AGENT_ID `
    -TaskId $TASK_ID `
    -Project $PROJECT `
    -Phase "analysis" `
    -Metadata @{ task_name = $task.name } `
    -Verbose
```

#### 4.3 Allocate Worktree

**CRITICAL:** Follow Feature Development Mode (ZERO_TOLERANCE_RULES.md)

```bash
# Read worktree pool
cat C:/scripts/_machine/worktrees.pool.md

# Find FREE seat (e.g., agent-002)
AGENT_SEAT="agent-002"

# Update pool to BUSY (manually edit or use tool)

# Allocate paired worktrees (client-manager + hazina)
cd C:/Projects/client-manager
git worktree add "C:/Projects/worker-agents/$AGENT_SEAT/client-manager" -b "$BRANCH_NAME" || \
git worktree add "C:/Projects/worker-agents/$AGENT_SEAT/client-manager" "$BRANCH_NAME"

cd C:/Projects/hazina
git worktree add "C:/Projects/worker-agents/$AGENT_SEAT/hazina" -b "$BRANCH_NAME" || \
git worktree add "C:/Projects/worker-agents/$AGENT_SEAT/hazina" "$BRANCH_NAME"

# Log allocation
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $AGENT_SEAT | ALLOCATE | $BRANCH_NAME | ClickHub task <task-id>" >> C:/scripts/_machine/worktrees.activity.md
```

#### 4.4 Checkpoint - Starting Implementation ⭐ NEW

```powershell
# Checkpoint before implementation starts
& $crashRecovery -Action Checkpoint `
    -AgentId $AGENT_ID `
    -TaskId $TASK_ID `
    -Project $PROJECT `
    -Phase "implementation" `
    -Metadata @{
        branch = $BRANCH_NAME
        worktree = "C:/Projects/worker-agents/$AGENT_SEAT/$PROJECT"
    } `
    -Verbose
```

#### 4.5 Implement the Task (MoSCoW-Guided) ⭐

```bash
# Work in worktree directory
cd "C:/Projects/worker-agents/$AGENT_SEAT/client-manager"

# Read existing code, understand patterns
# Use Task/Explore agent for complex analysis

# Implement changes following:
# - **MoSCoW Priority Order: MUST → SHOULD → COULD (skip WON'T)** ⭐
# - Boy Scout Rule (clean as you go)
# - Existing code patterns
# - Architecture principles from SOFTWARE_DEVELOPMENT_PRINCIPLES.md
# - Definition of Done from DEFINITION_OF_DONE.md

# Implementation Phases:
# Phase 1: All MUST HAVE items (100% complete)
# Phase 2: SHOULD HAVE items (if time/complexity allows)
# Phase 3: COULD HAVE items (only if trivial to add)
# Phase 4: Document WON'T HAVE as TODOs for future work
```

#### 4.4 Update ClickUp Task Status and Assign

**CRITICAL WORKFLOW RULES:**
- ✅ TODO → IN PROGRESS/BUSY when starting work (assign to agent/user)
- ✅ IN PROGRESS/BUSY → REVIEW when PR created (keep assigned to reviewer)
- ❌ NEVER move to TESTING (only reviewer does this after merge to develop)
- ❌ NEVER move to DONE (only user does this from testing)
- ⚠️ Only use BLOCKED/NEEDS INFO if truly stuck (use sparingly!)

**MANDATORY (2026-01-28): Post Agent ID Comment FIRST**

Before doing any work, post a comment identifying which agent is working:

```powershell
# STEP 1: Post agent identification comment (MANDATORY - so other agents can see who's working)
$AGENT_ID = "agent-003"  # Your agent seat number
$SESSION_TIME = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
C:/scripts/tools/clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
🤖 AGENT WORKING

Agent ID: $AGENT_ID
Session Start: $SESSION_TIME
Branch: $BRANCH_NAME
Worktree: C:/Projects/worker-agents/$AGENT_ID/client-manager

This task is now being actively worked on.
Other agents: Please do not pick up this task.

-- Claude Code Agent ($AGENT_ID)
"

# STEP 2: Update to busy when starting implementation AND assign to someone
# Default assignee: 74525428 (Martien de Jong - primary developer)
C:/scripts/tools/clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "busy" -Assignee "74525428"

# STEP 3: Add progress comment with technical details
C:/scripts/tools/clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
IMPLEMENTATION STARTED

Branch: $BRANCH_NAME
Worktree: $AGENT_SEAT
Approach: [Brief description of technical approach]
Assigned to: Martien de Jong

-- ClickHub Coding Agent ($AGENT_ID)
"
```

**WHY AGENT ID COMMENT?**
- Multiple agents may run simultaneously
- Prevents duplicate work on same task
- Creates audit trail of who worked on what
- Enables agent coordination and handoffs

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

# Calculate completion time
$completionTime = ((Get-Date) - $taskStartTime).TotalMinutes

# Link PR to task
C:/scripts/tools/clickup-sync.ps1 -Action link-pr -TaskId "<task-id>" -PrNumber $PR_NUMBER

# Post AGENT COMPLETED comment (closes the AGENT WORKING lifecycle)
$AGENT_ID = "agent-003"  # Your agent seat number
C:/scripts/tools/clickup-sync.ps1 -Action comment -TaskId "<task-id>" -Comment "
✅ AGENT COMPLETED

Agent ID: $AGENT_ID
PR Created: #$PR_NUMBER
PR URL: https://github.com/martiendejong/client-manager/pull/$PR_NUMBER
Session Duration: $([math]::Round($completionTime, 1)) minutes
Files Changed: [count]
Commits: [count]

This task is ready for review. Worktree will be released.
Other agents: Task is available for pickup if review changes needed.

-- Claude Code Agent ($AGENT_ID)
"

# Update task to review status AND assign to reviewer
# Default assignee: 74525428 (Martien de Jong - primary reviewer)
C:/scripts/tools/clickup-sync.ps1 -Action update -TaskId "<task-id>" -Status "review" -Assignee "74525428"
```

#### 4.6.5 Record Success in Learning Engine ⭐ NEW

**MANDATORY: Record successful completion for pattern learning**

```powershell
# Record success
& $learningEngine -Action RecordSuccess `
    -TaskId $TASK_ID `
    -Project $PROJECT `
    -AgentId $AGENT_ID `
    -CompletionMinutes ([math]::Round($completionTime)) `
    -Verbose

Write-Host "[LEARNING] Success recorded - agent gets smarter!" -ForegroundColor Green
```

**If implementation failed (before PR creation):**

```powershell
# Record failure with specific reason
& $learningEngine -Action RecordFailure `
    -TaskId $TASK_ID `
    -Project $PROJECT `
    -AgentId $AGENT_ID `
    -FailureReason "merge conflicts with develop" `  # Or actual reason
    -Verbose

Write-Host "[LEARNING] Failure recorded - pattern detected for future avoidance" -ForegroundColor Yellow
```

#### 4.7 Release Worktree

**CRITICAL:** Follow Release Protocol (ZERO_TOLERANCE_RULES.md)

```bash
# Clean worktree
rm -rf "C:/Projects/worker-agents/$AGENT_SEAT/client-manager"
rm -rf "C:/Projects/worker-agents/$AGENT_SEAT/hazina"

# Update pool to FREE
# Edit C:/scripts/_machine/worktrees.pool.md

# Log release
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) | $AGENT_SEAT | RELEASE | $BRANCH_NAME | PR #$PR_NUMBER created" >> C:/scripts/_machine/worktrees.activity.md

# Prune worktrees
cd C:/Projects/client-manager && git worktree prune
cd C:/Projects/hazina && git worktree prune

# Switch base repos to develop
cd C:/Projects/client-manager && git checkout develop && git pull
cd C:/Projects/hazina && git checkout develop && git pull
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
