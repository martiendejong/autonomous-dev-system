# Capability Taxonomy

**Classification of Claude Agent capabilities, tools, and knowledge.**

---

## Overview

```
CLAUDE AGENT CAPABILITIES
│
├── OPERATIONAL (day-to-day work)
│   ├── Worktree Management
│   ├── Git Operations
│   ├── Code Editing
│   └── PR Workflow
│
├── DIAGNOSTIC (understanding state)
│   ├── Health Checks
│   ├── Status Reports
│   └── Activity Analysis
│
├── KNOWLEDGE (accumulated wisdom)
│   ├── Reflection Log
│   ├── Problem-Solution Index
│   └── Pattern Library
│
├── AUTOMATION (reducing manual work)
│   ├── CLI Tools
│   ├── Batch Operations
│   └── Scheduled Tasks
│
└── META (self-improvement)
    ├── Documentation
    ├── Skill Creation
    └── Tool Development
```

---

## Detailed Classification

### 1. OPERATIONAL Capabilities

Things the agent does to accomplish user tasks.

#### 1.1 Worktree Management
| Capability | Tool/Skill | Description |
|------------|------------|-------------|
| Allocate seat | `worktree-allocate.ps1`, `allocate-worktree` skill | Reserve worktree for feature work |
| Release seat | `worktree-release-all.ps1`, `release-worktree` skill | Clean up after PR creation |
| Check status | `worktree-status.ps1`, `worktree-status` skill | View current allocations |
| Conflict detection | `multi-agent-conflict` skill | Prevent multi-agent collisions |

#### 1.2 Git Operations
| Capability | Tool/Skill | Description |
|------------|------------|-------------|
| Branch management | `prune-branches.ps1` | Clean up old branches |
| Commit workflow | Built-in git | Stage, commit, push |
| Merge tracking | `pr-dependencies` skill | Cross-repo PR ordering |

#### 1.3 Code Editing
| Capability | Tool/Skill | Description |
|------------|------------|-------------|
| Read files | Read tool | View code |
| Edit files | Edit tool | Modify code |
| Format C# | `cs-format.ps1` | Code formatting |
| Auto-fix | `cs-autofix/` | Automated fixes |

#### 1.4 PR Workflow
| Capability | Tool/Skill | Description |
|------------|------------|-------------|
| Create PR | `gh pr create`, `github-workflow` skill | Open pull request |
| Review PR | `gh pr view`, `github-workflow` skill | View PR details |
| Track dependencies | `pr-dependencies` skill | Cross-repo awareness |

---

### 2. DIAGNOSTIC Capabilities

Things the agent does to understand current state.

#### 2.1 Health Checks
| Capability | Tool | Description |
|------------|------|-------------|
| System health | `system-health.ps1` | Comprehensive health check |
| Solution integrity | `detect-missing-projects.ps1` | .csproj validation |
| Branch conflicts | `check-branch-conflicts.sh` | Detect conflicts |

#### 2.2 Status Reports
| Capability | Tool | Description |
|------------|------|-------------|
| Bootstrap snapshot | `bootstrap-snapshot.ps1` | Fast state summary |
| Repo dashboard | `repo-dashboard.sh` | Multi-repo overview |
| PR status | `pr-status.sh` | Open PRs summary |

#### 2.3 Activity Analysis
| Capability | Tool | Description |
|------------|------|-------------|
| Daily summary | `daily-summary.ps1` | Day's activity digest |
| Agent activity | `agent-activity.sh` | Per-agent history |

---

### 3. KNOWLEDGE Capabilities

Accumulated wisdom and learnings.

#### 3.1 Reflection Log
| Type | Location | Description |
|------|----------|-------------|
| Lessons learned | `_machine/reflection.log.md` | Past mistakes & fixes |
| Patterns | Tagged entries | Reusable solutions |

#### 3.2 Problem-Solution Index
| Type | Location | Description |
|------|----------|-------------|
| Build errors | `_machine/problem-solution-index.md` | Common fixes |
| Git issues | Same | Worktree/branch fixes |
| API patterns | Same | Development gotchas |

#### 3.3 Pattern Library
| Type | Location | Description |
|------|----------|-------------|
| Best practices | `_machine/best-practices/` | Documented patterns |
| Skills | `.claude/skills/` | Auto-discoverable workflows |

---

### 4. AUTOMATION Capabilities

Tools that reduce manual work.

#### 4.1 CLI Tools
| Tool | Purpose |
|------|---------|
| `claude-ctl.ps1` | Unified CLI entry point |
| `clickup-sync.ps1` | ClickUp integration |
| IMAP tools | Email management |

#### 4.2 Batch Operations
| Tool | Purpose |
|------|---------|
| `check-all-solutions.ps1` | Multi-repo validation |
| `worktree-release-all.ps1` | Release all seats |
| `prune-branches.ps1` | Clean all repos |

#### 4.3 Integrations
| Integration | Tool/Config |
|-------------|-------------|
| GitHub | `gh` CLI |
| ClickUp | `clickup-sync.ps1` |
| Google Drive | MCP server |
| Email | IMAP tools |

---

### 5. META Capabilities

Self-improvement and documentation.

#### 5.1 Documentation
| Type | Location |
|------|----------|
| Main manual | `CLAUDE.md` |
| Quick start | `QUICKSTART.md` |
| Navigation | `NAVIGATION.md` |
| Taxonomy | This file |

#### 5.2 Skill Creation
| Capability | Skill |
|------------|-------|
| Create new skill | `skill-creator` |
| Update docs | `self-improvement` |
| Log learnings | `session-reflection` |

#### 5.3 Tool Development
| Guideline | Description |
|-----------|-------------|
| Use PowerShell | Cross-platform |
| Add -DryRun | Preview mode |
| Update README | Document usage |
| Log activity | Track actions |

---

## Capability Matrix

### By Task Type

| Task | Primary Capability | Supporting |
|------|-------------------|------------|
| New feature | Worktree Management | Code Editing, PR Workflow |
| Bug fix | Code Editing | Git Operations |
| Code review | PR Workflow | Diagnostic |
| System check | Diagnostic | Knowledge |
| Learn pattern | Knowledge | Meta |
| Create tool | Meta | Automation |

### By Trigger

| Trigger | Capabilities Activated |
|---------|----------------------|
| "Add feature X" | Allocate worktree → Edit → PR |
| "Fix this error" | Diagnostic → Knowledge → Edit |
| "Check system health" | Diagnostic tools |
| "What happened today?" | Activity Analysis |
| "Document this pattern" | Meta capabilities |

---

## Evolution Roadmap

### Current Strengths
- Worktree management
- Git workflow
- Self-documentation

### Planned Improvements
- Real-time seat reservation (file locking)
- Automated testing of tools
- Predictive pattern matching
- Cost tracking per session

### Future Vision
- Multi-machine coordination
- Automated deployment
- Performance optimization suggestions
- Proactive maintenance alerts

---

**Last Updated:** 2026-01-15
**Classification Version:** 1.0
