---
name: self-improvement
description: Update CLAUDE.md and specialized documentation files with new procedures discovered during sessions. Use when discovering new workflows, creating new patterns, or receiving user feedback. Core continuous improvement directive.
allowed-tools: Read, Write, Edit, Grep, Bash
user-invocable: true
---

# Self-Improvement Protocol

**Purpose:** Continuously improve system documentation and mechanisms based on learnings from each session.

## Core Directive

**User Mandate:**
> "zorg dat je dus constant leert van jezelf en je eigen instructies bijwerkt"

**Translation:**
> "make sure you constantly learn from yourself and update your own instructions"

**This means:**
- Every session should improve the system
- Documentation should always reflect current best practices
- Mistakes should trigger documentation updates
- New patterns should be immediately captured
- Future sessions should benefit from today's learnings

## When to Update Documentation

### Immediate Updates (Real-Time)

**Update documentation IMMEDIATELY when:**
- ✅ User provides feedback about workflow
- ✅ Discover violation of zero-tolerance rule
- ✅ Find gap in existing documentation
- ✅ Learn new pattern or approach
- ✅ Receive clarification on ambiguous instruction

**Example (from reflection.log.md 2026-01-11):**
```
User feedback: "when user posts build errors, they are debugging in C:\Projects\<repo>"
Action taken: IMMEDIATELY updated CLAUDE.md with exception clause
Time: ~5 minutes from feedback to commit
```

### End-of-Session Updates (Mandatory)

**Before ending ANY session:**
- ✅ Update reflection.log.md with learnings
- ✅ Update CLAUDE.md if new workflows discovered
- ✅ Update specialized .md files if patterns changed
- ✅ Create new Skills if workflows should be discoverable
- ✅ Commit and push all documentation changes

## Documentation Structure

### File Hierarchy

```
C:/scripts/
├── CLAUDE.md                           # Main operational manual (index)
├── ZERO_TOLERANCE_RULES.md            # Critical hard-stop rules
├── worktree-workflow.md               # Worktree allocation/release
├── continuous-improvement.md          # Self-learning protocols
├── git-workflow.md                    # Git/PR workflows
├── session-management.md              # Window colors, notifications
├── tools-and-productivity.md          # Productivity tools
├── ci-cd-troubleshooting.md           # CI/CD issue resolution
├── development-patterns.md            # Feature implementation patterns
├── _machine/
│   ├── reflection.log.md              # Lessons learned (growing log)
│   ├── worktrees.pool.md              # Seat allocations (live state)
│   ├── worktrees.activity.md          # Activity log (audit trail)
│   ├── pr-dependencies.md             # Cross-repo PR tracking
│   ├── instances.map.md               # Active agent sessions
│   └── best-practices/                # Pattern library
└── .claude/skills/                    # Auto-discoverable Skills
    ├── allocate-worktree/
    ├── release-worktree/
    ├── github-workflow/
    └── ...
```

### Update Decision Tree

```
New learning discovered
    │
    ├─> Operational workflow change?
    │   └─> Update CLAUDE.md + specialized .md file
    │
    ├─> New hard-stop rule?
    │   └─> Update ZERO_TOLERANCE_RULES.md
    │
    ├─> New pattern discovered?
    │   ├─> Update reflection.log.md
    │   └─> Consider creating Skill
    │
    ├─> Bug fix or workaround?
    │   ├─> Update reflection.log.md
    │   └─> Update relevant specialized .md
    │
    └─> User feedback?
        ├─> Update CLAUDE.md immediately
        ├─> Update reflection.log.md
        └─> Update any affected .md files
```

## Updating CLAUDE.md

### When to Update

**Add to CLAUDE.md when:**
- New workflow discovered (e.g., debugging in base repo)
- New tool added (e.g., conflict detection script)
- Process clarification (e.g., branch strategy change)
- Exception to existing rule (e.g., build error handling)
- New integration point (e.g., Skills system)

### How to Update

**Step 1: Read current CLAUDE.md**
```bash
cat C:/scripts/CLAUDE.md
```

**Step 2: Identify correct section**

CLAUDE.md is now modular:
- Points to specialized .md files
- Acts as index/navigation
- Contains quick reference only

**Update specialized file, not CLAUDE.md itself** (unless adding new section)

**Step 3: Add to specialized file**

Example: Adding new worktree pattern → update `worktree-workflow.md`

**Step 4: Update CLAUDE.md index** (if new file created)

```markdown
### 🔧 **Development & Troubleshooting**
7. **[ci-cd-troubleshooting.md](./ci-cd-troubleshooting.md)** - CI issues, batch fixes
8. **[development-patterns.md](./development-patterns.md)** - Feature implementation
9. **[new-file.md](./new-file.md)** - New topic area  ← ADD HERE
```

### Example Update (Real from 2026-01-11)

**User feedback received:**
```
"when the user posts build errors, that means they must be debugging in
the c:\projects\..path_to_project folder meaning its allowed to work there"
```

**Action taken:**
1. Read CLAUDE.md § Worktree-only rule
2. Added "Exception - When user posts build errors" section
3. Committed with clear message
4. Pushed immediately

**Time:** 5 minutes from feedback to live documentation

## Creating New Documentation Files

### When to Create New File

**Create new .md file when:**
- Topic is large enough (> 500 lines)
- Topic is self-contained (e.g., CI/CD troubleshooting)
- Multiple patterns for same domain (e.g., development patterns)
- Referenced frequently (better as separate file)

### File Creation Checklist

```
[ ] Create file in C:/scripts/<topic>.md
[ ] Add YAML frontmatter (if using)
[ ] Write clear introduction
[ ] Organize with headers (##, ###)
[ ] Include code examples
[ ] Add cross-references to other files
[ ] Update CLAUDE.md index with link
[ ] Commit with descriptive message
```

### Template for New Documentation File

```markdown
# <Topic Name>

**Purpose:** <What this file covers>
**Last Updated:** <YYYY-MM-DD>

---

## Overview

<Introduction to topic>

## <Section 1>

<Content>

### <Subsection>

<Details with examples>

## <Section 2>

<Content>

## Reference

- Related file: `<path>`
- See also: `<path>`

---

**Maintained by:** Claude Agent (Self-improving documentation)
```

## Updating Specialized Files

### worktree-workflow.md

**Update when:**
- New allocation/release steps discovered
- Conflict detection improvements
- Cleanup procedures refined

### git-workflow.md

**Update when:**
- PR creation patterns change
- Cross-repo dependency rules clarified
- Branch strategy modified

### continuous-improvement.md

**Update when:**
- Self-learning protocols enhanced
- Reflection format improved
- Documentation update process refined

### ci-cd-troubleshooting.md

**Update when:**
- New CI failure pattern discovered
- Batch fix procedures improved
- GitHub Actions issues resolved

### tools-and-productivity.md

**Update when:**
- New tool added to C:/scripts/tools/
- Existing tool usage clarified
- Integration patterns improved

## Creating New Skills

### When to Create Skill

**Create Skill when:**
- Workflow is complex enough to benefit from auto-discovery
- Pattern is used frequently across sessions
- Process has mandatory steps that shouldn't be forgotten
- New agents would benefit from guided workflow

**Examples:**
- ✅ Worktree allocation (complex, mandatory, frequent)
- ✅ PR dependencies (specific rules, frequent)
- ✅ API patterns (common pitfalls, reusable)
- ❌ Simple git commands (too basic)
- ❌ One-time migrations (not reusable)

### Skill Creation Process

```bash
# 1. Create skill directory
mkdir C:/scripts/.claude/skills/<skill-name>
mkdir C:/scripts/.claude/skills/<skill-name>/scripts

# 2. Write SKILL.md with proper YAML frontmatter
cat > C:/scripts/.claude/skills/<skill-name>/SKILL.md << 'EOF'
---
name: skill-name
description: Auto-discovery trigger with specific keywords
allowed-tools: Bash, Read, Write
user-invocable: true
---

# Skill Name

[Content]
EOF

# 3. Add supporting files if needed
# - scripts/ for helper scripts
# - reference.md for detailed docs
# - examples.md for examples

# 4. Test Skill loads
# Ask: "What Skills are available?"

# 5. Update CLAUDE.md to reference new Skill
```

### Skill Documentation in CLAUDE.md

Add to appropriate section:

```markdown
## Available Skills

Auto-discoverable Claude Skills in `.claude/skills/`:

### Worktree Management
- `allocate-worktree` - Allocate worker agent worktree
- `release-worktree` - Release worktree after PR
- `worktree-status` - Check pool status

### GitHub Workflows
- `github-workflow` - PR creation, reviews, merging
- `pr-dependencies` - Cross-repo dependency tracking

### Development Patterns
- `api-patterns` - API development best practices
- `terminology-migration` - Codebase-wide refactoring

### Continuous Improvement
- `session-reflection` - Update reflection.log.md
- `self-improvement` - Update documentation
```

## Commit Message Best Practices

### For Documentation Updates

**Format:**
```
docs: <Brief description of update>

<Optional longer explanation>

<Why this update was needed>
<What changed>
<Impact on future sessions>

Pattern: <Pattern name if applicable>
User feedback: <If based on user input>
Session: <Session ID or date>

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
```

**Examples:**

```bash
# Simple update
git commit -m "docs: Add conflict detection to allocation workflow"

# With context
git commit -m "docs: Add exception for debugging in base repo

User clarified that posting build errors indicates they are
debugging in C:\Projects\<repo> and it's allowed to work there
directly to fix compilation issues.

Added exception clause to worktree-workflow.md and CLAUDE.md.

User feedback: 2026-01-11
Session: agent-002"

# Pattern addition
git commit -m "docs: Add Pattern 54 - API response enrichment

Documented pattern for enriching API responses with related
table data in controller layer.

Pattern solves: Frontend showing 0/null for fields that exist
in database but aren't included in API response.

Added to reflection.log.md and api-patterns Skill.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

## Verification After Updates

### Documentation Quality Checklist

**After updating documentation, verify:**

```
[ ] File is valid markdown (no syntax errors)
[ ] Code examples are correct and complete
[ ] Cross-references point to existing files
[ ] Headers use consistent hierarchy (##, ###)
[ ] Examples use correct paths (C:/scripts/...)
[ ] Success criteria clearly defined
[ ] Committed with descriptive message
[ ] Pushed to remote (machine_agents repo)
```

### Test Documentation Usability

**Ask yourself:**
- Can a new agent session follow these instructions?
- Are examples clear and complete?
- Is the "why" explained, not just "what"?
- Are edge cases covered?
- Is troubleshooting included?

## Pattern Numbering System

### In reflection.log.md

**Format:** Pattern <N>: <Name>

**Numbering:**
- Pattern 1-50: Historical patterns (already documented)
- Pattern 51+: New patterns (add sequentially)

**When adding new pattern:**

```bash
# 1. Find highest pattern number
grep "Pattern [0-9]" C:/scripts/_machine/reflection.log.md | tail -1

# 2. Use next sequential number
# If highest is Pattern 55, new pattern is Pattern 56

# 3. Document with clear name
## Pattern 56: <Descriptive Name>
```

### Pattern Lifecycle

```
Discovery → Reflection log entry → Pattern documented
         → Consider creating Skill
         → Add to specialized .md file
         → Cross-reference in CLAUDE.md
```

## Continuous Improvement Metrics

### Success Indicators

**System is improving ONLY IF:**
- ✅ Reflection.log.md grows every session
- ✅ New patterns documented with examples
- ✅ Documentation commits every session
- ✅ Fewer violations over time
- ✅ Faster problem resolution (known patterns)
- ✅ User feedback integrated immediately

### Anti-Patterns (Signs of Not Improving)

**⚠️ Warning signs:**
- ❌ Same mistakes repeated across sessions
- ❌ Documentation not updated for weeks
- ❌ Violations not triggering doc updates
- ❌ User feedback ignored or delayed
- ❌ Patterns discovered but not documented
- ❌ Knowledge lost between sessions

## End-of-Session Documentation Update

### Mandatory Checklist

**Before ending session:**

```bash
# 1. Update reflection.log.md
cd C:/scripts
# Add entry for this session

# 2. Update specialized .md files if needed
# E.g., new worktree pattern → worktree-workflow.md

# 3. Create new Skills if warranted
# E.g., new complex workflow → new Skill

# 4. Stage all changes
git add _machine/reflection.log.md
git add *.md
git add .claude/skills/

# 5. Commit with context
git commit -m "docs: Session learnings - <brief description>

<What was learned>
<What was updated>
<Impact on future sessions>

Session: <date/id>
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# 6. Push to remote
git push origin main

# 7. Verify pushed
git log -1 --oneline
```

### Post-Update Verification

```bash
# Check documentation is committed
git status  # Should be clean

# Check pushed to remote
git log origin/main -1  # Should match local

# Verify Skills discovered
# (Claude Code will auto-discover on next session)
```

## Reference Files

- Main manual: `C:/scripts/CLAUDE.md`
- Reflection log: `C:/scripts/_machine/reflection.log.md`
- Continuous improvement: `C:/scripts/continuous-improvement.md`
- All specialized .md files in `C:/scripts/`
- Skills: `C:/scripts/.claude/skills/`

## Success Criteria

✅ **Following self-improvement protocol correctly ONLY IF:**
- Documentation updated EVERY session
- User feedback integrated within minutes
- Patterns documented with examples
- New workflows captured in Skills
- Commits clear and descriptive
- All updates pushed to remote
- System knowledge grows over time
- Future sessions benefit from past learnings

**User mandate:** "constantly learn from yourself and update your own instructions"

**This is not optional. This is core directive.**

## Examples of Good Self-Improvement

### Example 1: User Feedback Integration (2026-01-11)

```
Feedback received: "debugging in base repo is allowed when user posts errors"
Time to update: 5 minutes
Files updated: CLAUDE.md, reflection.log.md
Result: Exception clause added, future sessions know the rule
```

### Example 2: Violation Recovery (2026-01-11)

```
Violation: Two agents worked on same branch
Time to update: 30 minutes
Files created: MULTI_AGENT_CONFLICT_DETECTION.md, check-branch-conflicts.sh
Skills created: multi-agent-conflict Skill
Result: Prevention mechanism in place, future sessions protected
```

### Example 3: Pattern Discovery (2026-01-12)

```
Discovery: OpenAIConfig Model parameter trap
Time to update: 10 minutes
Files updated: reflection.log.md, claude_info.txt, api-patterns Skill
Result: Pattern 1 documented, future sessions avoid the trap
```

**This is how continuous improvement works: Immediate action, not delayed.**
