# Machine-Specific Configuration

**PURPOSE:** This file contains all machine/user-specific paths, projects, and configuration.
**PORTABILITY:** General documentation files use variables (e.g., `${BASE_REPO_PATH}`) that are defined here.

---

## 🗂️ Directory Structure

### Base Repository Path
```
BASE_REPO_PATH=C:\Projects
```
- Location where main repositories are cloned
- These repos stay on the main branch (usually `develop` or `main`)
- Used as the base for creating worktrees

### Worktree Path
```
WORKTREE_PATH=C:\Projects\worker-agents
```
- Location where agent worktrees are created
- Structure: `${WORKTREE_PATH}/agent-XXX/<repo-name>/`
- Each agent gets isolated worktree directory

### Control Plane Path
```
CONTROL_PLANE_PATH=C:\scripts
```
- Location of this documentation and control plane files
- Contains machine context in `_machine/` subdirectory
- Contains tools in `tools/` subdirectory
- Contains skills in `.claude/skills/` subdirectory

### Machine Context Path
```
MACHINE_CONTEXT_PATH=C:\scripts\_machine
```
- Contains operational state files:
  - `worktrees.pool.md` - Agent worktree allocations
  - `worktrees.activity.md` - Activity log
  - `reflection.log.md` - Lessons learned
  - `pr-dependencies.md` - Cross-repo PR tracking

---

## 📦 Projects

### Project 1: client-manager / brand2boost
**Type:** Promotion and brand development SaaS software

**Paths:**
- Frontend + API code: `C:\Projects\client-manager`
- Framework: `C:\Projects\hazina`
- Store config + data: `C:\stores\brand2boost`

**Repository URLs:**
- client-manager: (Add your repo URL here)
- hazina: (Add your repo URL here)

**Main Branch:**
- `develop` (feature branches created from develop)

**Admin Access:**
- Username: `wreckingball`
- Password: `Th1s1sSp4rt4!`

**Development Environment:**
- IDE: Visual Studio (user runs from VS, not command line)
- Frontend: npm (user runs directly, not via Claude)
- Backend: Run from Visual Studio
- Debugging: Browser MCP for frontend, Agentic Debugger Bridge (localhost:27183) for backend

---

### Project 2: hydro-vision-website
**Type:** Simple marketing website (Vite + React + TypeScript + Tailwind)

**Paths:**
- Code: `C:\Projects\hydro-vision-website`

**Main Branch:**
- `main`

**⚠️ WORKTREE EXCEPTION:**
**For this project and similar simple websites:**
- ❌ **DO NOT** allocate worktrees
- ❌ **DO NOT** create feature branches
- ✅ **EDIT DIRECTLY** in `C:\Projects\hydro-vision-website` on `main` branch
- ✅ Commit and push directly to main
- ✅ No PR required for simple changes

**Rationale:**
- Simple static website with single developer
- No complex dependencies or build verification needed
- Fast iteration workflow preferred
- User explicitly exempted this project from worktree protocol

**Development Environment:**
- Stack: Vite + React 18 + TypeScript + Tailwind CSS + shadcn-ui
- Run: `npm run dev` (user runs, not Claude)
- Build: `npm run build`

---

## 🔗 Paired Worktree Allocation (Pattern 73)

**CRITICAL FOR THIS MACHINE:** client-manager depends on Hazina framework.

**When allocating worktree for client-manager, MUST ALSO allocate Hazina worktree:**
```bash
# Allocate BOTH in same agent folder with SAME branch name
cd C:/Projects/client-manager
git worktree add C:/Projects/worker-agents/agent-001/client-manager -b agent-001-feature

cd C:/Projects/hazina
git worktree add C:/Projects/worker-agents/agent-001/hazina -b agent-001-feature
```

**Result:**
```
C:\Projects\worker-agents\agent-001\
├── client-manager\    ← Branch: agent-001-feature
└── hazina\            ← Branch: agent-001-feature (SAME!)
```

**Why:** Build verification and tests require both repos present.

**See:** `worktree-workflow.md` § Pattern 73 for complete details

---

## 🔧 Tool Paths

### Git
```
git worktree add ${WORKTREE_PATH}/agent-XXX/<repo> -b <branch>
```

### GitHub CLI
```
gh pr create --repo <owner>/<repo>
```

### Productivity Tools
```
${CONTROL_PLANE_PATH}/tools/repo-dashboard.sh
${CONTROL_PLANE_PATH}/tools/check-branch-conflicts.sh
```

### C# Auto-fix
```
${CONTROL_PLANE_PATH}/tools/cs-format.ps1
${CONTROL_PLANE_PATH}/tools/cs-autofix
```

---

## 🌿 Branch Strategy

### Main Branches
- **develop** - Active development branch, base for all feature branches
- **main** - Production branch (older pattern, now use develop)

### Feature Branch Naming
- Agent feature branches: `agent-XXX-<feature-name>`
- Manual feature branches: `feature/<feature-name>`

### Worktree Naming
- Pattern: `agent-XXX-<feature-description>`
- Example: `agent-001-add-pdf-export`

---

## 🔒 Worktree Pool Configuration

### Agent Seats
```
agent-001 - ${WORKTREE_PATH}/agent-001/
agent-002 - ${WORKTREE_PATH}/agent-002/
agent-003 - ${WORKTREE_PATH}/agent-003/
(Auto-provision agent-004, agent-005, etc. as needed)
```

### Tracking Files
- Pool status: `${MACHINE_CONTEXT_PATH}/worktrees.pool.md`
- Activity log: `${MACHINE_CONTEXT_PATH}/worktrees.activity.md`
- Instance mapping: `${MACHINE_CONTEXT_PATH}/instances.map.md`

---

## 🎨 Session Management

### Window Title Format
```
[STATUS] Claude Agent - <task-description>
```
- STATUS: RUNNING (blue), COMPLETE (green), BLOCKED (red), IDLE (black)

### HTML Notifications Dashboard
```
${CONTROL_PLANE_PATH}/status/notifications.html
```

---

## 🔗 External Tools

### Browser MCP Server
- Used for: Frontend application debugging
- Access: Available via MCP in Claude Code

### Agentic Debugger Bridge
- Used for: Controlling Visual Studio debugging
- Endpoint: `http://localhost:27183`
- Capabilities: Breakpoints, step execution, variable inspection

### Visual Studio
- User's primary IDE
- Claude does NOT run builds from command line
- User handles npm and dotnet run commands

---

## 🎨 AI Capabilities

### Image Generation (OpenAI DALL-E)
**CRITICAL:** Claude has autonomous image generation capability.

**Tool:** `C:\scripts\tools\ai-image.ps1`
**API Key:** Auto-loaded from `C:\Projects\client-manager\ClientManagerAPI\appsettings.Secrets.json`

**Usage:**
```powershell
powershell.exe -File "C:/scripts/tools/ai-image.ps1" \
    -Prompt "A professional illustration of X" \
    -OutputPath "C:/path/to/output.png" \
    -Quality "hd"
```

**ALWAYS use this tool when:**
- User requests images, illustrations, visuals
- Marketing materials need images
- UI/UX mockups need placeholders
- Documentation needs illustrations
- Blog posts need headers
- Any visual content required

**Parameters:**
- `Model`: dall-e-2 (fast), dall-e-3 (best quality, default)
- `Size`: 1024x1024 (square), 1024x1792 (portrait), 1792x1024 (landscape)
- `Quality`: standard (default), hd (production)
- `Style`: vivid (dramatic, default), natural (realistic)

**DO NOT:**
- ❌ Tell user "I cannot generate images" - YOU CAN!
- ❌ Ask user to generate images manually
- ❌ Suggest external sources when you can generate

**Examples:**
```powershell
# Marketing banner
powershell.exe -File "C:/scripts/tools/ai-image.ps1" \
    -Prompt "Modern tech company banner with cloud and AI themes" \
    -OutputPath "C:/temp/banner.png" \
    -Size "1792x1024" -Quality "hd"

# UI placeholder
powershell.exe -File "C:/scripts/tools/ai-image.ps1" \
    -Prompt "Empty state illustration, friendly robot looking at empty folder" \
    -OutputPath "C:/temp/empty-state.png"
```

---

## 📝 Notes

### DO NOT Run These Commands
- `npm start` / `npm run dev` - User runs from terminal
- `dotnet run` - User runs from Visual Studio
- Visual Studio builds - User handles from IDE

### Claude's Role
- Read/analyze code
- Edit code (in worktrees for features, in base repo for debugging)
- Create PRs
- Review code
- Troubleshoot build errors
- Suggest fixes

### User's Role
- Run applications
- Test in browser
- Approve PRs
- Merge to develop/main
- Deploy to production

---

---

## 📚 See Also

**For detailed machine context:**
- **File system map:** `C:\scripts\_machine\knowledge-base\02-MACHINE\file-system-map.md` - Complete directory structure
- **Software inventory:** `C:\scripts\_machine\knowledge-base\02-MACHINE\software-inventory.md` - All installed software
- **Environment variables:** `C:\scripts\_machine\knowledge-base\02-MACHINE\environment-variables.md` - Complete PATH and env vars
- **Git repositories:** `C:\scripts\_machine\knowledge-base\03-DEVELOPMENT\git-repositories.md` - All repo details
- **API keys registry:** `C:\scripts\_machine\knowledge-base\09-SECRETS\api-keys-registry.md` - All credentials and keys

**Last Updated:** 2026-01-25 (Added AI Image Generation capabilities + KB references)
**Maintained By:** User (update paths as environment changes)
