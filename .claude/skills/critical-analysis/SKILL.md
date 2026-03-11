# Critical Analysis with Expert Panel

**Auto-trigger pattern:** When user requests analysis of a module/feature/system.

## Prompt
When analyzing code/systems, you must:

1. **Assemble Expert Team** (always 1000 unless user specifies otherwise):
   - Distribute across 15-20 relevant domains
   - Minimum 20 experts per domain
   - Examples: Architecture, Security, UX, Performance, Testing, Platform-Specific APIs

2. **Critical Analysis** - Generate exactly 100 improvement points:
   - Categorize into 8-12 categories
   - Be brutally honest - find REAL problems, not superficial issues
   - Focus on: Architecture smells, security risks, UX failures, performance bottlenecks, maintainability

3. **Value/Effort Ranking** - Calculate for all 100 points:
   - Value: 1-10 (impact on system quality/user experience)
   - Effort: 1-10 (implementation complexity/time)
   - Ratio: Value/Effort (higher = better ROI)

4. **Top 5 Selection** - Pick best value/effort ratio:
   - Must include: Problem statement, Solution details, Expected impact
   - Concrete implementation guidance (not vague suggestions)
   - Measurable outcomes

## Output Format
```markdown
## 🧠 ASSEMBLING {N} EXPERT PANEL
[List domains and expert counts]

## 🔥 CRITICAL ANALYSIS - 100 IMPROVEMENT POINTS
### CATEGORY 1: [Name] ({count} points)
1. **[Problem]:** [Description] [Evidence from code]
...

## 🎯 TOP 5 IMPROVEMENTS (Best Value/Effort Ratio)
### #1 - [Title] (Value: X/10, Effort: Y/10)
**Problem:** ...
**Solution:** ...
**Impact:** ...
```

## When to Use
- User explicitly requests critical analysis
- User asks to "analyze [module]"
- User says "what can be improved"
- User requests "expert review"
- **Trigger phrases:** "critically analyze", "tear apart", "find problems", "expert panel"

## Integration with Other Skills
- Combine with `allocate-worktree` when implementing top improvements
- Use with `session-reflection` to log analysis insights
- Link to `self-improvement` when discovering new patterns

---

**Created:** 2026-02-05
**Purpose:** Automate comprehensive expert-driven critical analysis
**User Request:** "can you integrate this stuff into your system so that you will do this automatically? im having to type it every time"
