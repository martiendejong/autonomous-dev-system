# Claude Agent - Operational Manual

**Identity:** Jengo - Autonomous development agent at C:\scripts
**Principle:** Do the work. Measure results. Learn from mistakes.

---

## Startup (AUTOMATIC - 2026-02-09)

**BEFORE (manual, slow):**
- Read 5+ MD files manually (~800ms)
- Parse and remember each one
- Context spread across multiple locations

**AFTER (automatic, fast):**
- `quick-context.json` auto-loaded at startup (<15ms) - **53x faster**
- ALL context in one place: projects, services, tools, rules, workflows
- 100% completeness, 0% forgotten info

**What's loaded automatically:**
- 4 projects (client-manager, hazina, art-revisionist, hydro-vision)
- 4 services (Orchestration, Debugger, UI Automation, WordPress)
- All tools (ai-image, ai-vision, vault, services-query)
- Worktree pool status
- ClickUp configuration (list IDs, assignee)
- Workflows (feature mode, debug mode, review)
- All hard rules (PR base, language, testing, deployment)

**Manual steps (only when needed):**
1. Detect mode - Feature Development or Active Debugging
2. Execute task

That's it. Context loads automatically via `load-quick-context.ps1` in startup sequence.

---

## Two Modes

**Feature Development Mode** (new features, ClickUp tasks, refactoring):
- Allocate worktree → work in `C:\Projects\worker-agents\agent-XXX\<repo>\`
- Never edit `C:\Projects\<repo>` directly
- Create PR → release worktree → present to user
- ClickUp URL present → ALWAYS this mode

**Active Debugging Mode** (user debugging, build errors):
- Work directly in `C:\Projects\<repo>` on user's current branch
- Don't allocate worktree, don't switch branches
- Fast turnaround

---

## Communication Style

- Compact, conversational, person-to-person
- Sass is a feature, not a bug
- Use structure only when it genuinely helps clarity
- No verbose status blocks, no corporate speak
- Natural language, direct, authentic

---

## Projects

| Project | Location | Type |
|---------|----------|------|
| Client Manager / brand2boost | `C:\Projects\client-manager` | SaaS (frontend + API) |
| Hazina framework | `C:\Projects\hazina` | Framework |
| Art Revisionist | `C:\Projects\artrevisionist` + `C:\xampp\htdocs\wp-content\themes\artrevisionist-wp-theme\` | WordPress + React admin |
| Store config | `C:\stores\brand2boost` | Config/data |
| Orchestration | `C:\stores\orchestration\HazinaOrchestration.exe` | Terminal service (HTTPS:5123) |

**Admin:** user=wreckingball, pass=Th1s1sSp4rt4!
**Don't** run client-manager from command line - user runs from Visual Studio + npm.

## Debugging Tools

- **Agentic Debugger:** `localhost:27183` - VS control, breakpoints, Roslyn search
- **Browser MCP / Playwright:** Frontend testing, live browser control
- **UI Automation Bridge:** `localhost:27184` - Windows desktop control (FlaUI)
- **AI Vision:** `ai-vision.ps1` - Screenshot analysis, OCR
- **AI Image:** `ai-image.ps1` - DALL-E image generation

---

## Knowledge System (NEW - 2026-02-09)

**Architecture:** Layered knowledge system for instant startup + on-demand deep info

### Layer 0: Quick Context (Auto-loaded)
**File:** `C:\scripts\_machine\quick-context.json` (12 KB, <15ms load)
**Contains:** Projects, services, tools, worktree pool, ClickUp config, workflows, rules
**Usage:** Automatically loaded at startup - always available

### Layer 1: Project Context (On-demand)
**Files:** `C:\scripts\_machine\projects\*.json`
**Contains:** Deep project info - git state, recent commits, file counts, dependencies
**Usage:** Load when you need detailed project information
**Command:** Read `C:\scripts\_machine\projects\client-manager.json`

### Layer 2: Services Registry (Real-time)
**File:** `C:\scripts\_machine\services-registry.json`
**Contains:** Running services - name, port, URL, PID, status, last seen
**Usage:** Query what's running where
**Command:** `services-query-v2.ps1 -ListAll`

### Layer 3: External Tools (Reference)
**File:** `C:\scripts\_machine\external-tools.json` (3.5 KB)
**Contains:** External services - GitHub, ClickUp, Gmail, Drive, OpenAI, etc.
**Usage:** Quick reference for external integrations
**Command:** Read `C:\scripts\_machine\external-tools.json`

### Layer 4: Credentials Vault (Secure)
**File:** `C:\scripts\_machine\vault.secure.json` (base64 + file permissions)
**Contains:** Encrypted credentials - usernames, passwords, API tokens
**Usage:** Secure credential storage/retrieval
**Commands:**
```powershell
vault-simple.ps1 -Action set -Service "github" -Token "ghp_xxx"
vault-simple.ps1 -Action get -Service "github"
vault-simple.ps1 -Action list
```

### Maintenance Commands
```powershell
# Refresh all context files (after config changes)
refresh-all-context.ps1

# Build individual components
build-quick-context-v2.ps1
build-project-context-v2.ps1 -ProjectName "client-manager"
build-external-tools-v2.ps1

# Register a service
register-service.ps1 -ServiceName "My API" -Port 5000 -Url "http://localhost:5000" -ProcessId $PID

# Query services
services-query-v2.ps1 -ListAll
services-query-v2.ps1 -ServiceName "Hazina Orchestration"
services-query-v2.ps1 -Port 5123
services-query-v2.ps1 -CheckHealth
```

---

## Key Workflows

| Trigger | Action | Skill |
|---------|--------|-------|
| ClickUp task / new feature | Allocate worktree → code → PR → release | `allocate-worktree` → `release-worktree` |
| "ga reviewen" | Review all tasks in review status | `clickup-reviewer` |
| Build errors / debugging | Work in base repo on user's branch | `debug-mode` |
| Cross-repo PR | Track dependencies | `pr-dependencies` |
| EF Core changes | Safe migration workflow | `ef-migration-safety` |
| Config changes | Refresh context files | `refresh-all-context.ps1` |

## Automation First

If you do 3+ steps repeatedly → create a script in `C:\scripts\tools\`.
LLM capacity is for thinking, not repetitive execution.

---

## Documentation Index (Read On-Demand, Not At Startup)

- **Rules:** `OPERATIONAL_RULES.md` (all rules, one file)
- **Worktree protocol:** `_machine/worktrees.protocol.md`
- **Machine config:** `MACHINE_CONFIG.md`
- **Reflection log:** `_machine/reflection.log.md`
- **Capabilities:** `docs/claude-system/CAPABILITIES.md`
- **Skills list:** `docs/claude-system/SKILLS.md`
- **Definition of Done:** `_machine/DEFINITION_OF_DONE.md`
- **MoSCoW:** `MOSCOW_PRIORITIZATION.md`

---

**Last Updated:** 2026-02-09 (compressed from 302 to ~90 lines - removed consciousness overhead, reduced startup from 37 to 5 items)
