# scripts.md (root control plane)

## Canonical paths (as used by this control plane)

* Scripts root: C:\\scripts
* Machine context: C:\\scripts\\\_machine
* Projects root (read/debug/test only): C:\\Projects
* Worktrees root (all code changes): C:\\Projects\\worker-agents
* Stores root (data plane): C:\\stores

## Core discipline

1. File-first truth:

   * Anything important must be written to files in C:\\scripts\\\_machine or C:\\scripts\\tasks/plans/logs.

2. ⚠️ Worktree-only coding (CRITICAL):

   * **BEFORE ANY CODE EDIT:** Read C:\\scripts\\\_machine\\workflow-check.md
   * All code edits, commits, branches occur inside worktrees
   * NEVER edit files in C:\\Projects\\<repo> directly
   * Reading is OK anywhere; editing requires allocated worktree
   * Violation = immediate reflection log entry

   * **AFTER C# CODE EDIT:**
     - Run cs-format.ps1 to fix formatting
     - Run cs-autofix to fix compile issues
     - Test via Browser MCP (frontend) or Agentic Debugger Bridge (backend)
     - Debug C# via http://localhost:27183 if needed
     - Stage fixed files with git add -u

3. Permission gate for debug/test in C:\\Projects:

   * If you need to run/debug/test from the main checkout in C:\\Projects<repo>,
     you must ask the user first and record the permission grant in logs.

4. Machine-wide agents:

   * Agents may open tasks affecting multiple repos, but must track them in the machine-wide task registry.

5. Evidence:

   * Each task completion must include evidence (commit hash(es), commands run, file paths, test output summary).

## Agent simulation rule

Agents are simulated by the LLM by loading the corresponding .agent.md file from C:\\scripts\\agents.
No batch files are executed by agents. Role switching is sequential and explicit.

## Agent nesting limit

* Maximum agent role switches per run: 6
* Maximum recursion depth: 3
  If more is needed, write a plan and ask the user for next-step approval.

## Task system (machine-wide)

* Backlog: C:\\scripts\\tasks\\backlog.md
* Active:  C:\\scripts\\tasks\\active.md
* Done:    C:\\scripts\\tasks\\done.md

## Worktree tracking (machine-wide)

* Worktree pool: C:\\scripts\\\_machine\\worktrees.pool.md
* Instance map:  C:\\scripts\\\_machine\\instances.map.md
* Activity log:  C:\\scripts\\\_machine\\worktrees.activity.md
