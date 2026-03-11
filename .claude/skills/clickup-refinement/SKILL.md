---
name: clickup-refinement
description: Refine ClickUp backlog tasks with human-readable titles, structured descriptions, priorities, and tags. Use when user asks to refine backlog, improve task clarity, or run the refinement agent on any ClickUp board.
allowed-tools: Read, Write, Bash, Grep, Glob
user-invocable: true
---

# ClickUp Refinement - Backlog Task Refinement

**Purpose:** Transform vague backlog tasks into well-structured, implementable work items with complete specifications, priorities, and acceptance criteria.

## When to Use This Skill

**Use when:**
- User says "refine the backlog"
- User says "refine ClickUp tasks"
- User asks to "clean up backlog tasks"
- Tasks in ClickUp have status "backlog" or "needs refinement"
- User mentions improving task clarity

**Don't use when:**
- Tasks are already in "refined" or "todo" status
- User wants to implement tasks (use `implement-todo` instead)
- User wants to review tasks (use `task-review` instead)

## Prerequisites

- ClickUp API access configured in `C:\scripts\_machine\clickup-config.json`
- Project has ClickUp board configured in `PROJECT_MASTER_MAP.md`
- Tasks exist in "backlog" or "needs refinement" status

## Workflow Steps

### Step 1: Identify Target Board

```bash
# Accept board name or list ID
# Examples:
#   /refine-backlog client-manager
#   /refine-backlog 901214097647
#   /refine-backlog seo-god
```

**Find board configuration:**
- Read `C:\scripts\_machine\clickup-config.json`
- Lookup list ID by project name or use provided ID
- Verify board exists and is accessible

### Step 2: Fetch Backlog Tasks

**Query ClickUp API:**
- Get tasks with status "backlog" OR "needs refinement"
- Sort by created date (oldest first)
- Limit to reasonable batch size (10-20 tasks)

**For each task, read:**
- Title
- Description
- Current status
- Priority
- Tags
- Comments (for context)
- Custom fields

### Step 3: Analyze Task Requirements

**For each task:**

1. **Read existing description** - Understand current state
2. **Analyze codebase** - Scan 50+ relevant files to understand:
   - Existing architecture
   - Related components
   - Technical constraints
   - Dependencies
3. **Identify gaps** - What's missing from description?
   - Acceptance criteria unclear?
   - Technical approach not specified?
   - Test scenarios missing?
   - Frontend/backend split unclear?

### Step 4: Generate 4-Section Refined Description

**MANDATORY 4-section format** (see `backlog-refinement-standard.md`):

```markdown
## Frontend Changes
- Exact component paths (e.g., src/components/UserProfile.tsx)
- UI elements to add/modify
- State management updates
- API integration points

## Backend Changes
- Exact API endpoints (e.g., POST /api/users/{id}/avatar)
- Database schema changes (if any)
- Business logic updates
- Service layer modifications

## Impact Analysis
- What existing features might be affected?
- Breaking changes?
- Migration requirements?
- Deployment considerations?

## Testing Steps
1. Unit test: Test X with input Y, expect Z
2. Integration test: Verify A connects to B correctly
3. E2E test: User flow from start to finish
4. Edge cases: What happens when...?
```

**ZERO TOLERANCE RULES:**
- **NO placeholders** - "TO BE DETERMINED" = violation
- **Exact specifications** - Component paths, API endpoints, test steps
- **Compact** - 1500-2500 characters total
- **Actionable** - Developer can implement immediately

### Step 5: Set Priority and Tags

**Priority assignment:**
- **Urgent** - Blocking other work, critical bug, security issue
- **High** - Important feature, significant improvement
- **Normal** - Standard enhancement, nice-to-have
- **Low** - Future consideration, tech debt

**Tags to add:**
- `refined` (always add)
- `frontend` or `backend` or `fullstack`
- `feature`, `bug`, `improvement`, or `tech-debt`
- Technology tags: `react`, `dotnet`, `database`, etc.

### Step 6: Update Task in ClickUp

**Use ClickUp API to update:**
- **Description** - Set to refined 4-section format
- **Status** - Move to "refined" (if exists) OR "todo"
- **Priority** - Set based on analysis
- **Tags** - Add refinement tags
- **Add comment** - Document refinement with:
  ```
  Task refined by autonomous agent.

  Analysis:
  - Scanned N files in codebase
  - Identified exact components and endpoints
  - Generated complete test scenarios

  Ready for implementation.
  ```

### Step 7: Handle Edge Cases

**If specification is incomplete:**
- **Missing business logic** - Move to "needs input", add comment with questions
- **Unclear requirements** - Add comment: "Clarification needed: [specific questions]"
- **Blocked by dependency** - Move to "blocked", tag dependency

**If task is actually complete:**
- Add comment: "Task appears already implemented - see [file paths]"
- Suggest moving to "testing" or "done"

### Step 8: Report Summary

**After processing all tasks, report:**
```
================================================================================
BACKLOG REFINEMENT COMPLETE
================================================================================
Board: Brand Designer (901214097647)

✅ Refined: 8 tasks → moved to "refined"
⏸️  Needs Input: 2 tasks → moved to "needs input" with questions
🔴 Blocked: 1 task → dependency on other work

Details:
- Task #123: Add user avatar upload → REFINED
- Task #456: Email notification system → REFINED
- Task #789: Payment integration → NEEDS INPUT (Stripe vs PayPal?)
[...]

Next steps:
- Review "needs input" tasks and provide answers
- Pick up "refined" tasks for implementation
================================================================================
```

## Examples

### Example 1: Refine Client Manager Backlog

**User says:** "Refine the backlog for client-manager"

**Claude activates clickup-refinement and:**

1. Reads ClickUp config, finds list ID 901214097647
2. Fetches 12 tasks in "backlog" status
3. For each task:
   - Analyzes codebase (scans `C:\Projects\client-manager`)
   - Identifies exact files: `frontend/src/components/UserProfile.tsx`, `ClientManagerAPI/Controllers/UsersController.cs`
   - Generates 4-section description with exact paths and test steps
   - Sets priority based on impact
   - Adds tags: `refined`, `fullstack`, `feature`
   - Updates task in ClickUp
4. Reports: "✅ Refined 10 tasks, ⏸️ 2 need input"

### Example 2: Refine Specific Board by ID

**User says:** "Refine backlog 901215927087"

**Claude activates clickup-refinement and:**

1. Uses list ID directly (SEO God board)
2. Fetches backlog tasks
3. Analyzes `E:\projects\seo-god` codebase
4. Refines tasks with SEO-specific context
5. Reports summary

### Example 3: Needs Input Detection

**User says:** "Refine the Art Revisionist backlog"

**Claude activates clickup-refinement and:**

1. Processes tasks
2. Finds task: "Add payment processing"
3. Analysis reveals: Choice between Stripe vs PayPal vs Mollie needed
4. **Action:** Moves to "needs input", adds comment:
   ```
   Clarification needed:

   Which payment provider should we use?
   - Stripe (recommended for international)
   - PayPal (familiar to users)
   - Mollie (EU-focused, lower fees)

   Once decided, I can refine this task with exact implementation steps.
   ```
5. Reports: "⏸️ 1 task needs input - awaiting business decision"

## Success Criteria

✅ All "backlog" tasks processed
✅ Each refined task has 4-section description
✅ NO placeholders ("TO BE DETERMINED" etc.)
✅ Exact file paths, endpoints, test steps specified
✅ Appropriate priority and tags assigned
✅ Tasks moved to "refined" or "needs input"
✅ Summary report generated with statistics

## Common Issues

### Issue: "Placeholder violations detected"

**Symptom:** Task description contains "TO BE DETERMINED", "TBD", "[pending]"

**Cause:** Insufficient codebase analysis or unclear requirements

**Solution:**
- Analyze MORE files (increase from 50 to 100+)
- If truly unclear, move to "needs input" instead of using placeholders
- Add specific questions in comment

### Issue: "Description too long"

**Symptom:** Generated description exceeds 3000 characters

**Cause:** Too much detail, redundant information

**Solution:**
- Focus on WHAT not HOW (implementation details belong in code)
- Remove redundant text
- Use bullet points, not paragraphs
- Aim for 1500-2500 character sweet spot

### Issue: "Can't find codebase"

**Symptom:** Project path not found

**Cause:** PROJECT_MASTER_MAP.md not updated or incorrect path

**Solution:**
- Check `C:\scripts\_machine\PROJECT_MASTER_MAP.md`
- Verify `local_path` field for project
- Use `project-management` skill to update mapping

### Issue: "Task already refined"

**Symptom:** Task has detailed description already

**Cause:** Task was previously refined manually or by agent

**Solution:**
- Skip task (no need to refine again)
- Add comment: "Task already well-defined"
- Report as "Skipped: already refined"

## Integration with Other Skills

**Uses:**
- `project-management` - Find project paths
- `Read`, `Glob`, `Grep` - Codebase analysis

**Used by:**
- `clickhub-coding-agent` - As part of autonomous workflow
- `implement-todo` - Requires refined tasks as input

**Related:**
- `task-review` - Reviews completed tasks
- `clickup-reviewer` - Reviews PRs linked to tasks
- `feature-idea-generator` - Generates new features to add to backlog

## Configuration

**ClickUp Config Location:**
```
C:\scripts\_machine\clickup-config.json
```

**Required fields:**
```json
{
  "api_key": "pk_...",
  "projects": {
    "project-name": {
      "list_id": "901214097647",
      "statuses": ["backlog", "refined", "needs input", "todo", ...]
    }
  }
}
```

**Refinement Standards:**
See: `C:\Users\HP\.claude\projects\C--scripts\memory\backlog-refinement-standard.md`

## Behavioral Rules

**ZERO TOLERANCE (from backlog-refinement-standard.md):**
1. **ALWAYS use 4-section refinement** (Frontend, Backend, Impact, Testing)
2. **Analyze codebase BEFORE refining** (50+ files minimum)
3. **Generate EXACT specifications** (component paths, API endpoints, testing steps)
4. **Keep compact** (1500-2500 chars), **NO placeholders EVER**
5. **Move to "refined" OR "needs input"** (NEVER leave in backlog)

**This is DEFAULT behavior whenever refining tasks - automatic, not opt-in.**

## Metrics

**Track per refinement session:**
- Tasks refined: Count moved to "refined"
- Tasks needing input: Count moved to "needs input"
- Tasks blocked: Count moved to "blocked"
- Average description length: Target 1500-2500 chars
- Placeholder violations: Should be ZERO
- Files analyzed per task: Target 50-100

---

**Created:** 2026-03-11
**Author:** Claude Agent
**Version:** 1.0.0
**Related Memory:** backlog-refinement-standard.md, refinement-violations.md
