---
name: skill-creator
description: Create new Claude Skills with proper format, YAML frontmatter, and best practices. Use when user asks to create a new skill, workflow guide, or auto-discoverable pattern. Meta-skill for skill generation.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
user-invocable: true
---

# Skill Creator - Meta-Skill for Creating New Skills

**Purpose:** Standardized creation of new Claude Skills with proper structure, frontmatter, and documentation integration.

## When to Use This Skill

**Use when:**
- User explicitly asks to create a new skill
- A workflow is complex enough to benefit from auto-discovery
- A pattern is used frequently and should be documented
- New agents need guided workflows for specific tasks

**Don't use when:**
- Workflow is too simple (< 5 steps)
- One-time operation (not reusable)
- Already covered by existing skill

## Skill Creation Process

### Step 1: Gather Requirements

Before creating a skill, determine:

```markdown
[ ] Skill name (kebab-case, e.g., `api-debugging`)
[ ] Description (trigger keywords for auto-discovery)
[ ] Purpose (what problem does this skill solve?)
[ ] Allowed tools (which tools does the skill need?)
[ ] User-invocable (can users call it directly with /skill-name?)
[ ] Steps involved (the actual workflow)
[ ] Examples (when would this skill be activated?)
```

### Step 2: Create Directory Structure

```bash
# Create skill directory
mkdir -p "C:/scripts/.claude/skills/<skill-name>"

# Optional: Create scripts subdirectory for helpers
mkdir -p "C:/scripts/.claude/skills/<skill-name>/scripts"
```

### Step 3: Write SKILL.md

**Required YAML Frontmatter:**

```yaml
---
name: <skill-name>
description: <Auto-discovery trigger description with specific keywords>
allowed-tools: <Comma-separated list: Bash, Read, Write, Edit, Glob, Grep>
user-invocable: <true|false>
---
```

**Required Sections:**

```markdown
# <Skill Name>

**Purpose:** <What this skill accomplishes>

## When to Use This Skill

<Activation criteria - when should Claude use this?>

## Prerequisites

<What must be true before using this skill?>

## Workflow Steps

### Step 1: <Name>
<Instructions>

### Step 2: <Name>
<Instructions>

[... additional steps ...]

## Examples

<Real-world activation examples>

## Success Criteria

<How to verify the skill was executed correctly>

## Common Issues

<Troubleshooting for common problems>

## Related Skills

<Links to related skills>
```

### Step 4: Add Supporting Files (Optional)

**For complex skills:**
- `scripts/<helper>.ps1` - PowerShell helper scripts
- `scripts/<helper>.sh` - Bash helper scripts
- `reference.md` - Extended documentation
- `examples.md` - Detailed examples

### Step 5: Update CLAUDE.md Index

Add the new skill to the appropriate section in `C:/scripts/CLAUDE.md`:

```markdown
### <Category>
- **`skill-name`** - Brief description
```

### Step 6: Verify Skill Loads

After creation, verify the skill is discoverable:
1. Start new Claude session
2. Ask: "What skills are available?"
3. Confirm new skill appears in list

## YAML Frontmatter Reference

### Required Fields

| Field | Description | Example |
|-------|-------------|---------|
| `name` | Skill identifier (kebab-case) | `api-patterns` |
| `description` | Auto-discovery trigger text | "Common API development patterns..." |
| `allowed-tools` | Tools the skill can use | `Read, Write, Bash` |
| `user-invocable` | Can be called with `/skill-name` | `true` |

### Best Practices for Description

**Good descriptions include:**
- Specific keywords that trigger discovery
- Action verbs (create, fix, debug, migrate)
- Domain terminology (API, worktree, PR, database)

**Examples:**
```yaml
# Good - specific trigger keywords
description: Create new Claude Skills with proper format, YAML frontmatter, and best practices. Use when user asks to create a new skill.

# Good - multiple trigger paths
description: Handle GitHub pull request workflows including creating PRs, reviewing code, checking PR comments, and managing PR lifecycle.

# Bad - too vague
description: Helps with coding tasks
```

## Template for New Skill

Copy this template when creating new skills:

```markdown
---
name: <skill-name>
description: <Trigger description with keywords>. Use when <specific scenario>.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
user-invocable: true
---

# <Skill Name>

**Purpose:** <One-line description of what this skill accomplishes>

## When to Use This Skill

**Use when:**
- <Scenario 1>
- <Scenario 2>

**Don't use when:**
- <Anti-pattern 1>
- <Anti-pattern 2>

## Prerequisites

- <Prerequisite 1>
- <Prerequisite 2>

## Workflow Steps

### Step 1: <Step Name>

<Detailed instructions>

```bash
# Example command
<command>
```

### Step 2: <Step Name>

<Detailed instructions>

[Continue for all steps...]

## Examples

### Example 1: <Scenario Name>

**User says:** "<User request>"

**Claude activates:** This skill

**Actions:**
1. <Action 1>
2. <Action 2>

**Result:** <Outcome>

## Success Criteria

✅ <Criterion 1>
✅ <Criterion 2>
✅ <Criterion 3>

## Common Issues

### Issue: <Problem Description>

**Symptom:** <What you observe>

**Cause:** <Why it happens>

**Solution:** <How to fix>

## Related Skills

- `related-skill-1` - How it relates
- `related-skill-2` - How it relates

---

**Created:** <YYYY-MM-DD>
**Author:** Claude Agent
```

## Skill Categories

When adding to CLAUDE.md, place in appropriate category:

| Category | Description | Examples |
|----------|-------------|----------|
| **Worktree Management** | Worktree allocation/release | allocate-worktree, release-worktree |
| **GitHub Workflows** | PR, reviews, GitHub ops | github-workflow, pr-dependencies |
| **Development Patterns** | Code patterns, best practices | api-patterns, terminology-migration |
| **Continuous Improvement** | Documentation, learning | session-reflection, self-improvement |
| **Integrations** | External tool setup | mcp-setup |
| **Meta** | Skills about skills | skill-creator |

## Examples

### Example 1: Creating a Database Migration Skill

**User says:** "Create a skill for handling database migrations"

**Claude uses skill-creator and:**

1. Creates directory: `C:/scripts/.claude/skills/database-migration/`
2. Writes SKILL.md with:
   - Proper YAML frontmatter
   - Migration workflow steps
   - Rollback procedures
   - Testing requirements
3. Updates CLAUDE.md index under "Development Patterns"
4. Verifies skill loads correctly

### Example 2: Creating a Testing Skill

**User says:** "I need a skill for running test suites"

**Claude uses skill-creator and:**

1. Creates directory: `C:/scripts/.claude/skills/test-runner/`
2. Writes SKILL.md with:
   - Test discovery steps
   - Coverage requirements
   - Failure handling
   - Report generation
3. Adds helper script for common test commands
4. Updates CLAUDE.md index

## Success Criteria

✅ Skill directory created at correct path
✅ SKILL.md has valid YAML frontmatter
✅ All required sections present
✅ Description contains trigger keywords
✅ Examples are realistic and helpful
✅ CLAUDE.md updated with new skill reference
✅ Skill discoverable in new session

## Common Issues

### Issue: Skill Not Discovered

**Symptom:** Skill doesn't appear in available skills list

**Cause:** Invalid YAML frontmatter or wrong file location

**Solution:**
1. Verify file is at `.claude/skills/<name>/SKILL.md`
2. Validate YAML syntax (use online validator)
3. Check frontmatter has all required fields

### Issue: Description Too Vague

**Symptom:** Skill not activated when expected

**Cause:** Description lacks trigger keywords

**Solution:** Add specific action verbs and domain terms to description

### Issue: Skill Too Complex

**Symptom:** Skill is hundreds of lines, hard to follow

**Cause:** Trying to cover too much in one skill

**Solution:** Split into multiple focused skills or use supporting files

## Related Skills

- `self-improvement` - Documents when/why to create skills
- `session-reflection` - Documents learnings that might become skills

---

**Created:** 2026-01-14
**Author:** Claude Agent (Meta-skill for skill generation)
