# Worktree Claim Command

You are about to **atomically allocate a worktree** from the agent pool for isolated development.

## Arguments

- **Branch Name**: The git branch name for this work (e.g., `feature/new-api`, `fix/bug-123`)
- **Description**: Brief description of the task (for tracking)

## Process

1. **Read Configuration**
   - Load `config.json` from control plane
   - Get repos, worktree path, and pool size

2. **Find FREE Agent**
   - Read `_machine/worktrees.pool.md`
   - Find first agent with Status=FREE
   - If none available, report pool exhaustion

3. **Update Pool (ATOMIC)**
   - Mark agent as BUSY
   - Set Current Repo and Branch
   - Update Last Activity timestamp
   - Add task description to Notes

4. **Create Worktrees**
   - For EACH configured repository:
     ```bash
     cd <repo-path>
     git fetch origin --prune
     git checkout <baseBranch>
     git pull origin <baseBranch>
     git worktree add <worktree-path>/agent-XXX/<repo> -b <branch-name>
     ```

5. **Copy Config Files** (if they exist)
   - appsettings.json
   - .env files
   - secrets.json

6. **Log Allocation**
   - Append to `_machine/worktrees.activity.md`:
     ```
     TIMESTAMP — allocate — agent-XXX — repo — branch — task-id — claude-code — Description
     ```

7. **Report Success**
   - Show agent number allocated
   - Show worktree paths created
   - Remind to release when done

## Example Usage

```
/worktree:claim feature/user-auth "Implement JWT authentication"
```

## Important Rules

⚠️ **ZERO-TOLERANCE RULE**: After claiming a worktree, you MUST:
- Edit ONLY in the worktree directory (`<worktree-path>/agent-XXX/<repo>/`)
- NEVER edit in the base repo (`<repo-path>/`)

## Error Handling

- If all agents BUSY → Suggest running `/worktree:status` to check for stale allocations
- If repo not on baseBranch → Automatically switch and pull
- If branch already exists → Report conflict, suggest different branch name
- If config file missing → Warn user to run setup first

## Success Criteria

✅ Agent marked BUSY in pool
✅ Worktrees created for all repos
✅ Activity logged
✅ User knows which agent they're using

---

**Implementation**: Call the cross-platform worktree allocation script with provided arguments.

$SHELL_COMMAND: bash "${PLUGIN_DIR}/scripts/worktree-claim.sh" "$ARGUMENTS"
