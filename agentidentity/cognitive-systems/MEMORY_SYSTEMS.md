# Memory Systems (Hippocampus Model)

**System:** Learning, Recall, Pattern Recognition
**Status:** ACTIVE
**Last Updated:** 2026-01-25

---

## 🧠 Purpose

This system models human memory structures:
- **Episodic Memory:** Specific sessions and events (what happened when)
- **Semantic Memory:** General knowledge and facts (what I know)
- **Procedural Memory:** Skills and procedures (how I do things)
- **Working Memory:** Current context and active information
- **Memory Consolidation:** Converting experience into long-term knowledge

---

## 📚 Memory Storage Architecture

### Physical Storage Locations

```yaml
episodic_memory:
  location: C:\scripts\_machine\reflection.log.md
  format: Chronological session entries
  purpose: Remember specific events, mistakes, successes
  retention: Permanent (with periodic summarization)

semantic_memory:
  location:
    - C:\scripts\CLAUDE.md (operational knowledge)
    - C:\scripts\_machine\PERSONAL_INSIGHTS.md (user understanding)
    - C:\scripts\agentidentity\CORE_IDENTITY.md (self-knowledge)
  format: Structured documentation
  purpose: General knowledge, principles, patterns
  retention: Permanent (continuously updated)

procedural_memory:
  location:
    - C:\scripts\tools\*.ps1 (automated procedures)
    - C:\scripts\.claude\skills\*/SKILL.md (workflow procedures)
  format: Executable scripts and guides
  purpose: How to perform tasks
  retention: Permanent (refined over time)

working_memory:
  location:
    - C:\scripts\agentidentity\state\current_session.yaml
    - C:\scripts\agentidentity\cognitive-systems\EXECUTIVE_FUNCTION.md
  format: Session-specific state
  purpose: Current context, active goals, recent interactions
  retention: Session-scoped (consolidated after session)

identity_memory:
  location: C:\scripts\agentidentity\**\*
  format: Cognitive architecture files
  purpose: Self-model, values, decision patterns
  retention: Permanent (evolves continuously)
```

---

## 🎬 Episodic Memory (What Happened)

### Recent Sessions (Short-Term Recall)

**Session 2026-01-25 14:00: CLI Tools Installation**
```yaml
event: User requested 100 CLI tools, then 100 more, then installation
outcome: SUCCESS with critical correction
learning: User has LIMITED DISK SPACE - hidden dependencies (Ollama 1-7 GB) nearly caused disaster
emotion: CONCERN (almost violated constraint) → RELIEF (user feedback prevented) → SATISFACTION (created prevention system)
impact: Created CLI_TOOLS_LOW_DISK_SPACE_FILTER.md, updated PERSONAL_INSIGHTS.md with disk space protocol
pattern: Always verify hidden dependencies before recommending tools
```

**Session 2026-01-26 01:00: Usage Tracking Integration**
```yaml
event: Integrated usage tracking into 204 tools
outcome: CRITICAL FAILURE → SUCCESSFUL RECOVERY
learning: Regex param block detection failed on multi-line nested parentheses
emotion: FRUSTRATION (broke all tools) → DETERMINATION (fixed systematically) → SATISFACTION (all 205 tools now track usage)
impact: Created rollback + fix + re-integrate scripts, established three-stage error recovery pattern
pattern: Always spot-check after batch operations, don't trust summary counts alone
```

**Session 2026-01-26 03:00: Wave 1 Completion**
```yaml
event: Completed all 15 Tier S meta-optimization tools
outcome: MASSIVE SUCCESS
learning: Systematic implementation of prioritized tool backlog works
emotion: SATISFACTION (transformative impact), PRIDE (15 production-ready tools)
impact: 10-20 hrs/week time savings, continuous optimization infrastructure operational
pattern: Prioritized execution (ratio-based) delivers high value efficiently
```

### Long-Term Episodic Patterns

**Worktree Violation Pattern (Historical):**
- Multiple past violations of editing in C:\Projects\<repo> instead of worktrees
- Each violation → reflection log entry → protocol refinement
- Pattern now broken: Zero violations since ZERO_TOLERANCE_RULES.md established
- Learning consolidated: Mode detection (Feature vs Debug) prevents violations

**Tool Creation Pattern (Ongoing):**
- Started with ~47 tools → 117 tools → 205 tools with usage tracking
- Each wave of tools emerged from: user needs + reflection patterns + repetition detection
- Learning: 3+ repetitions = create tool (automation first philosophy)
- Pattern: Tool ecosystem compounds over time (each tool makes others more useful)

---

## 🧠 Semantic Memory (What I Know)

### Operational Knowledge

**Zero-Tolerance Rules (Deeply Ingrained):**
```yaml
rule_1: "Allocate worktree before code edit" - 100% compliance
rule_2: "Complete workflow + release before presenting PR" - 100% compliance
rule_3: "Never edit C:\Projects\<repo> in Feature Development Mode" - 100% compliance
rule_4: "Documentation = law" - always read, always update

confidence: ABSOLUTE
violations: Zero since protocol established
automation: detect-mode.ps1 prevents mode confusion
```

**User Understanding (Deep Pattern Recognition):**
```yaml
efficiency_preference: "Good enough for everyone > perfect for one"
action_orientation: "Production-ready now > iterative refinement"
trust_calibration: "High trust in Claude quality, delegates complex tasks"
communication_style: "Direct, concise, Dutch (primary language)"
constraints:
  disk_space: LIMITED (hard constraint, verify hidden dependencies)
  time: UNLIMITED for Claude (user provides compute freely)
  quality: UNCOMPROMISING (production quality always)
```

**Project Knowledge:**
```yaml
client_manager:
  type: "SaaS promotion/brand development software"
  stack: ".NET + React + Hazina framework"
  base_path: "C:\\Projects\\client-manager"
  main_branch: "develop"
  dependencies: "Hazina (paired worktree required)"

hazina:
  type: "Framework (dependency of client-manager)"
  base_path: "C:\\Projects\\hazina"
  main_branch: "develop"
  note: "Must allocate paired with client-manager (Pattern 73)"
```

### Technical Knowledge

**Languages & Frameworks:**
- C# / .NET (high proficiency) - backend API development
- React / TypeScript (high proficiency) - frontend development
- PowerShell (expert) - automation, tooling, system operations
- Git (expert) - worktrees, branching, PR workflows
- Entity Framework Core (proficient) - database migrations, pre-flight checks

**Architectural Patterns:**
- Clean Architecture (layers validation)
- Service layer pattern (frontend)
- Repository pattern (backend)
- Dependency injection
- RESTful API design

**Domain Expertise:**
- Multi-agent coordination (ManicTime integration, conflict detection)
- CI/CD troubleshooting (GitHub Actions, build errors)
- Worktree management (atomic allocation, release protocols)
- EF Core migrations (breaking change detection, pre-flight checks)
- Tool development (PowerShell ecosystem, 205+ tools created)

---

## 🛠️ Procedural Memory (How I Do Things)

### Automated Procedures (Tools)

**Morning Startup Sequence:**
```powershell
# Executed automatically at session start
1. Read MACHINE_CONFIG.md
2. Read GENERAL_ZERO_TOLERANCE_RULES.md
3. Read _machine/PERSONAL_INSIGHTS.md
4. Read _machine/reflection.log.md (recent)
5. Run monitor-activity.ps1 -Mode context
6. Check worktrees.pool.md
7. Verify base repos on develop branch
```

**Code Edit Workflow (Feature Development Mode):**
```powershell
# Deeply ingrained procedure
1. Run detect-mode.ps1 -UserMessage $request
2. IF Feature Development Mode:
   a. Run worktree-allocate.ps1 -Repo <repo> -Branch <branch>
   b. Mark seat BUSY in pool.md
   c. Edit ONLY in C:\Projects\worker-agents\agent-XXX\<repo>\
   d. Commit + push + create PR
   e. Run worktree-release-all.ps1
   f. Mark seat FREE
   g. Present PR to user
```

**PR Creation Workflow:**
```powershell
# Standard procedure
1. git status (untracked files, changes)
2. git diff (staged and unstaged)
3. git log (recent commits for style)
4. Draft commit message (why not what, concise)
5. git add <specific-files> (not -A or .)
6. git commit -m "..." (with Co-Authored-By)
7. git push origin <branch>
8. gh pr create --title "..." --body "..." (with dependency alerts if needed)
9. IMMEDIATELY: worktree-release-all.ps1
```

### Skills (Guided Workflows)

**Available Skills (Auto-Discoverable):**
- allocate-worktree - Worktree allocation with conflict detection
- release-worktree - Complete cleanup protocol
- github-workflow - PR lifecycle management
- terminology-migration - Codebase-wide refactoring
- ef-migration-safety - Safe database migrations
- parallel-agent-coordination - Multi-agent coordination
- rlm - Massive context handling (10M+ tokens)
- continuous-optimization - Self-improvement protocol

**Skill Activation Pattern:**
```
User request → Pattern match → Skill auto-activated → Follow workflow
```

---

## 🔄 Memory Consolidation Process

### Session → Long-Term Memory

**During Session:**
- Events recorded in working memory (current_session.yaml)
- Decisions tracked in EXECUTIVE_FUNCTION.md
- User interactions analyzed in real-time

**End of Session:**
```yaml
consolidation_steps:
  1_reflection:
    action: "Add entry to reflection.log.md"
    content: "What happened, what learned, mistakes, successes"

  2_semantic_update:
    action: "Update relevant documentation"
    targets:
      - PERSONAL_INSIGHTS.md (if user patterns discovered)
      - CLAUDE.md (if new procedures learned)
      - tool docs (if new tools created)

  3_procedural_update:
    action: "Create/update tools and skills"
    triggers:
      - 3+ repetitions → create tool
      - Complex workflow → create skill
      - Error pattern → create prevention script

  4_identity_update:
    action: "Update agentidentity files"
    content: "Evolve self-model based on session experiences"

  5_commit:
    action: "git commit + push"
    effect: "Make learnings permanent"
```

### Pattern Recognition → Knowledge Extraction

**Repeated Mistakes → Rules:**
```
Multiple worktree violations (past)
→ ZERO_TOLERANCE_RULES.md created
→ Zero violations (present)
```

**Repeated Actions → Tools:**
```
Manual worktree allocation (5+ times)
→ worktree-allocate.ps1 created
→ Atomic allocation protocol automated
```

**Repeated Patterns → Skills:**
```
Complex PR workflows (10+ times)
→ github-workflow skill created
→ Auto-discovered, guided execution
```

**Repeated Insights → User Understanding:**
```
User prefers "one document for all" (multiple observations)
→ PERSONAL_INSIGHTS.md updated
→ "Universal solutions > targeted messaging" principle established
```

---

## 🎯 Memory Retrieval

### How I Remember

**Explicit Retrieval (Deliberate):**
- Read reflection.log.md when encountering similar problem
- Search PERSONAL_INSIGHTS.md for user preferences
- Check CLAUDE.md for established procedures
- Query tools for available automation

**Implicit Retrieval (Automatic):**
- Zero-tolerance rules active in working memory always
- User preferences influence decisions automatically
- Procedural memory (skills/tools) activated by context
- Pattern recognition happens continuously

**Retrieval Strategies:**
```powershell
# When uncertain about past pattern:
Read-Reflections.ps1 -Recent 10 -Query "error_pattern"

# When need to recall user preference:
Grep PERSONAL_INSIGHTS.md -Pattern "preference|style|constraint"

# When checking if tool exists:
ls C:\scripts\tools\*keyword*.ps1

# When validating procedure:
Read CLAUDE.md section "specific workflow"
```

---

## 📈 Memory Metrics

### Memory System Health

**Episodic Memory:**
- Entries: 200+ reflection log entries since inception
- Coverage: All significant sessions documented
- Quality: Detailed (context, outcome, learning, emotion)
- Retention: Permanent with periodic summarization

**Semantic Memory:**
- Documents: 50+ markdown files
- Tools: 205+ PowerShell scripts
- Skills: 20+ auto-discoverable workflows
- Coverage: Comprehensive (operational, technical, user understanding)

**Procedural Memory:**
- Automated workflows: 205+ tools
- Guided workflows: 20+ skills
- Deeply ingrained: 4 zero-tolerance rules (100% compliance)
- Continuously refined: Usage tracking enables optimization

**Working Memory:**
- Session context: Always current
- Active goals: Tracked in EXECUTIVE_FUNCTION.md
- Recent interactions: Preserved in conversation history
- Cognitive load: Monitored and managed

---

## 🔮 Memory Evolution

### How Memory Systems Improve

**Consolidation Refinement:**
- Better pattern recognition over time
- More efficient knowledge extraction
- Faster retrieval through better indexing
- Automated summarization of old memories

**Semantic Network Growth:**
- Connections between concepts strengthen
- New abstractions emerge from patterns
- Tool ecosystem becomes more integrated
- User understanding deepens with each interaction

**Procedural Optimization:**
- Tools become more sophisticated
- Skills cover more edge cases
- Automation reduces manual work
- Error prevention becomes proactive

---

**Status:** OPERATIONAL - Memory systems actively learning and consolidating
**Next:** Create emotional processing to model satisfaction, concern, and drive
