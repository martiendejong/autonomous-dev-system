# Documentation Navigation

**Visual guide to Claude Agent documentation**

---

## Quick Links

| I need to... | Go to... |
|--------------|----------|
| Start quickly | [QUICKSTART.md](./QUICKSTART.md) |
| Know the rules | [ZERO_TOLERANCE_RULES.md](./ZERO_TOLERANCE_RULES.md) |
| Understand modes | [GENERAL_DUAL_MODE_WORKFLOW.md](./GENERAL_DUAL_MODE_WORKFLOW.md) |
| Allocate worktree | [GENERAL_WORKTREE_PROTOCOL.md](./GENERAL_WORKTREE_PROTOCOL.md) |
| Find a tool | [tools/README.md](./tools/README.md) |
| Learn from past | [_machine/reflection.log.md](./_machine/reflection.log.md) |
| Check seat status | [_machine/worktrees.pool.md](./_machine/worktrees.pool.md) |

---

## Documentation Map

```
C:\scripts\
│
├── QUICKSTART.md .............. 2-min onboarding (START HERE)
├── CLAUDE.md .................. Full operational manual
├── NAVIGATION.md .............. This file - doc index
│
├── CONFIGURATION
│   ├── MACHINE_CONFIG.md ...... Local paths, projects, machine-specific
│   └── PORTABILITY_GUIDE.md ... How to adapt for other machines
│
├── RULES & WORKFLOWS
│   ├── ZERO_TOLERANCE_RULES.md ...... The 4 hard-stop rules
│   ├── GENERAL_ZERO_TOLERANCE_RULES.md .. Portable version
│   ├── GENERAL_DUAL_MODE_WORKFLOW.md .... Feature vs Debug modes
│   ├── GENERAL_WORKTREE_PROTOCOL.md ..... Worktree lifecycle
│   ├── dual-mode-workflow.md ............ Legacy (has hardcoded paths)
│   └── worktree-workflow.md ............. Legacy (has hardcoded paths)
│
├── DEVELOPMENT
│   ├── git-workflow.md .......... Git-flow, cross-repo PRs
│   ├── ci-cd-troubleshooting.md . Build failures, CI fixes
│   └── development-patterns.md .. Feature implementation patterns
│
├── OPERATIONS
│   ├── continuous-improvement.md  Self-learning protocols
│   ├── session-management.md .... Window colors, notifications
│   └── tools-and-productivity.md  Tool usage, debugging
│
├── _machine/ ................... Machine state (gitignored sensitive)
│   ├── worktrees.pool.md ....... Seat allocations
│   ├── worktrees.activity.md ... Activity log
│   ├── reflection.log.md ....... Lessons learned
│   ├── pr-dependencies.md ...... Cross-repo PR tracking
│   └── bootstrap-snapshot.json . Cached startup state
│
├── tools/ ...................... Productivity scripts
│   ├── bootstrap-snapshot.ps1 .. Fast startup state
│   ├── worktree-status.ps1 ..... Check seat status
│   ├── worktree-release-all.ps1  Release all worktrees
│   ├── repo-dashboard.sh ....... Environment overview
│   └── [many more...]
│
├── .claude/skills/ ............. Auto-discoverable workflows
│   ├── allocate-worktree/ ...... Worktree allocation
│   ├── release-worktree/ ....... Worktree release
│   ├── github-workflow/ ........ PR management
│   ├── api-patterns/ ........... Common API pitfalls
│   └── [12 total skills]
│
└── agents/ ..................... Agent role definitions
    ├── architect.agent.md
    ├── meta.agent.md
    └── [5 more agents]
```

---

## Dependency Graph

```
                    ┌─────────────────┐
                    │  QUICKSTART.md  │ ← Start here
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
    ┌─────────────────┐          ┌──────────────────┐
    │ MACHINE_CONFIG  │          │ ZERO_TOLERANCE   │
    │ (local paths)   │          │ (the 4 rules)    │
    └────────┬────────┘          └────────┬─────────┘
             │                            │
             └──────────────┬─────────────┘
                            ▼
              ┌─────────────────────────┐
              │   GENERAL_DUAL_MODE     │
              │   (Feature vs Debug)    │
              └─────────────┬───────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
┌─────────────┐   ┌─────────────────┐   ┌──────────────┐
│ WORKTREE    │   │ git-workflow.md │   │ ci-cd-       │
│ PROTOCOL    │   │ (git-flow, PRs) │   │ troubleshoot │
└─────────────┘   └─────────────────┘   └──────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│              _machine/ (STATE FILES)                │
│  worktrees.pool.md │ reflection.log.md │ activity   │
└─────────────────────────────────────────────────────┘
```

---

## Skills Index

Skills are auto-discovered based on context. No need to invoke manually.

| Category | Skills | Auto-triggers on... |
|----------|--------|---------------------|
| Worktree | `allocate-worktree`, `release-worktree`, `worktree-status` | "allocate", "release", "check seats" |
| GitHub | `github-workflow`, `pr-dependencies` | "create PR", "review", "dependencies" |
| Development | `api-patterns`, `terminology-migration` | API errors, renaming across codebase |
| Meta | `session-reflection`, `self-improvement`, `skill-creator` | "log learnings", "update docs", "create skill" |
| Setup | `mcp-setup`, `multi-agent-conflict` | MCP servers, multi-agent scenarios |

---

## Tools Quick Reference

| Tool | Purpose | Usage |
|------|---------|-------|
| `bootstrap-snapshot.ps1` | Fast startup state | `.\tools\bootstrap-snapshot.ps1 -Generate` |
| `worktree-status.ps1` | Check all seats | `.\tools\worktree-status.ps1 -Compact` |
| `worktree-release-all.ps1` | Release worktrees | `.\tools\worktree-release-all.ps1 -AutoCommit` |
| `repo-dashboard.sh` | Environment overview | `bash tools/repo-dashboard.sh` |
| `cs-format.ps1` | Format C# code | `.\tools\cs-format.ps1 -Path <file>` |
| `clickup-sync.ps1` | ClickUp tasks | `.\tools\clickup-sync.ps1 -Action list` |

---

## File Relationships

```
CLAUDE.md ──references──► All other docs
    │
    └──imports──► MACHINE_CONFIG.md (paths)
                  ZERO_TOLERANCE_RULES.md (rules)

Skills ──read──► _machine/worktrees.pool.md
                 _machine/reflection.log.md

Tools ──update──► _machine/*.md files
```

---

**Last Updated:** 2026-01-15
**Auto-generate:** Consider creating `generate-navigation.ps1`
