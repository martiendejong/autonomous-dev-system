# Feature Idea Generator - Quick Start Guide

**Status:** ✅ Production Ready
**Created:** 2026-03-11
**Complexity:** Very High (30-60 minute full analysis)

## What This Does

Generates **transformative product features** through systematic multi-expert analysis:

1. **100+ Expert Panel** - Analyzes product from every angle (technical, business, user, scientific)
2. **Core Value Distillation** - Identifies the single most important value proposition
3. **100 Brilliant Ideas** - Generates ideas that amplify and extend core value
4. **100 Billion-Dollar Features** - Designs features so valuable they become must-haves
5. **Expert Refinement** - Makes each feature 1M times better through systematic improvement
6. **Top 5 Selection** - Prioritizes by value-to-effort ratio
7. **ClickUp Integration** - (Optional) Adds features to backlog automatically

## When to Use

**Automatic Activation:**
The skill auto-activates when you:
- Ask to "come up with ideas"
- Say "create new improvements"
- Request "what features should we add"
- Want to "make this product better"
- Need to "brainstorm features"

**Manual Activation:**
```bash
/feature-idea-generator
```

## Quick Examples

### Example 1: Improve Existing Project

**You say:**
```
Come up with improvements for client-manager
```

**What happens:**
1. Analyzes client-manager codebase
2. Assembles expert panel (CRM experts, UX designers, sales leaders, etc.)
3. Identifies core value: "Helps agencies manage client relationships without admin overhead"
4. Generates 100 ideas (AI client insights, automated invoicing, smart scheduling, etc.)
5. Designs 100 billion-dollar features
6. Refines with expert panel
7. Selects Top 5 by ROI
8. Creates ClickUp tasks in client-manager backlog

**You get:**
- Detailed analysis in `C:/scripts/_ideation/client-manager/`
- 5 validated, high-impact features
- ClickUp tasks ready to implement

### Example 2: New Product Idea

**You say:**
```
I have an idea for a meditation app - generate features
```

**What happens:**
1. Researches meditation app market (competitors, gaps)
2. Assembles expert panel (neuroscientists, meditation teachers, UX designers)
3. Identifies core value: "Helps people build consistent meditation practice"
4. Generates 100 ideas from expert perspectives
5. Designs billion-dollar features (AI meditation guide, biometric feedback, etc.)
6. Selects Top 5 practical + Top 5 moonshot
7. Saves full analysis

**You get:**
- Product direction validated
- Clear differentiation strategy
- Roadmap prioritized by impact

### Example 3: Specific Feature Area

**You say:**
```
Generate onboarding improvements for DataDrivenAI
```

**What happens:**
1. Focuses expert panel on onboarding (UX, educators, behavioral psychologists)
2. Analyzes current onboarding flow
3. Identifies core value of onboarding: "Get users to first insight in <5 min"
4. Generates ideas specific to onboarding (interactive tutorial, AI guide, etc.)
5. Designs features that eliminate friction
6. Prioritizes quick wins

**You get:**
- Focused improvements for specific problem
- Quick wins identified
- Full context documented

## Output Structure

All analysis saved to:
```
C:/scripts/_ideation/<project-name>/
├── expert-analysis.md              # 100+ expert perspectives
├── core-value.md                   # Value proposition distillation
├── 100-ideas.md                    # All generated ideas
├── idea-essence.md                 # Synthesis of idea themes
├── 100-billion-dollar-features.md  # Transformative features
├── refined-features.md             # Expert-refined features
└── top-5-features.md               # Prioritized recommendations
```

## What You Get

**Final Deliverable:**

```markdown
# 🚀 Feature Ideation Complete: <Project>

## 📊 Analysis Summary
- Expert Perspectives: 100+
- Ideas Generated: 100
- Features Designed: 100
- Features Refined: 100
- Top Features Selected: 5

## 💎 Core Value Proposition
<The single most important value>

## 🏆 Top 5 High-Impact Features

### #1: <Name> (ROI: 3.8)
<One-paragraph pitch>
**Why This Matters:** <Impact>
**Quick Win:** <Phase 1>
**Full Vision:** <Ultimate capability>

[... #2, #3, #4, #5 ...]

## 📁 Documentation
See: C:/scripts/_ideation/<project>/

## ✅ Next Steps
[ClickUp tasks or implementation roadmap]
```

## Customization

### Focus on Specific Domain

**You say:**
```
Generate AI/ML features for DataDrivenAI - focus on prediction accuracy
```

**Result:** Expert panel weighted toward data scientists, ML engineers, statisticians

### Quick vs. Comprehensive

**Quick mode (15 min):**
```
Quick feature ideas for <project>
```
- Abbreviated expert panel (20 experts)
- 20 ideas instead of 100
- Top 3 features

**Comprehensive mode (60 min):**
```
Full feature analysis for <project>
```
- Complete 100+ expert panel
- 100 ideas, 100 features, full refinement
- Top 5 + honorable mentions

### Industry-Specific

**Healthcare:**
```
Generate HIPAA-compliant features for <medical app>
```
- Adds healthcare compliance experts
- Privacy and security emphasized
- Regulatory constraints considered

**Fintech:**
```
Generate financial features for <banking app>
```
- Adds financial analysts, compliance officers
- Security and fraud prevention emphasized
- Regulatory requirements considered

## Integration with ClickUp

**Automatic detection:**
If project has ClickUp integration in `PROJECT_MASTER_MAP.md`, tasks are created automatically.

**Manual ClickUp integration:**
```bash
python C:/scripts/.claude/skills/feature-idea-generator/clickup-integration.py \
  <project-name> \
  C:/scripts/_ideation/<project>/top-5-features.md
```

**Task format:**
- Name: `[FEATURE] <Feature Name>`
- Priority: High
- Tags: feature, high-impact, innovation, value-creation
- Description: Full feature spec with ROI scores

## Tips for Best Results

**1. Be Specific About Context**
```
Good: "Generate features for client-manager that help agencies scale"
Bad: "Make it better"
```

**2. Specify Constraints**
```
"Generate features for <project> - must work offline, budget-conscious users"
```

**3. Target Specific Pain Points**
```
"Generate features that reduce onboarding time from 30 min to 5 min"
```

**4. Combine with Other Skills**

**Feature generation → UI design:**
```
Generate features for <project>, then design UI for top feature
```

**Feature generation → Implementation:**
```
Generate features, then implement #1 in new branch
```

**Feature generation → Backlog refinement:**
```
Generate features, add to ClickUp, then refine backlog
```

## Common Questions

### Q: How long does this take?
**A:** 30-60 minutes for full analysis. Quick mode: 15 minutes.

### Q: Can I run this multiple times?
**A:** Yes! Run periodically (quarterly) to refresh roadmap. Each run saves timestamped analysis.

### Q: What if I disagree with the Top 5?
**A:** Full analysis saved - review all 100 features in `100-billion-dollar-features.md` and choose different ones. The prioritization is data-driven but not absolute.

### Q: Can I focus on specific feature types?
**A:** Yes! Specify: "Generate AI features" or "Generate UI improvements" or "Generate backend optimizations"

### Q: How do I know features are valuable?
**A:** Each feature has:
- Value score (0-100)
- Effort score (0-100)
- ROI calculation
- Success metrics
- User story with benefit

### Q: What if codebase is very large?
**A:** Skill uses smart sampling - reads architecture, README, key files. For massive codebases (>10k files), focuses on public APIs and documentation.

## Advanced Usage

### Multi-Product Comparison

**Generate features for multiple products, compare:**
```
Generate features for client-manager
[wait for completion]
Generate features for brand2boost
[wait for completion]
Compare the feature sets and find cross-product opportunities
```

### Competitive Analysis Mode

**Include competitor analysis:**
```
Generate features for <project> - analyze what Competitor X does well and find gaps
```

### Innovation Sprints

**Monthly innovation ritual:**
```
# Month 1
Generate features for <project>

# Month 2
Implement Top 5 from Month 1
Generate new features based on user feedback

# Month 3
Measure impact of Month 1 features
Generate refinements
```

## Success Metrics

**You know it worked when:**
- ✅ Clear product direction emerged
- ✅ Features differentiate from competitors
- ✅ Team excited about roadmap
- ✅ Features align with core value
- ✅ Quick wins identified (low-effort, high-value)
- ✅ Users request features after seeing them

## Troubleshooting

### Issue: Features too generic

**Fix:** Add domain context
```
Generate features for <project> - users are busy professionals, need mobile-first, value speed over features
```

### Issue: All high-effort features

**Fix:** Request quick wins explicitly
```
Generate features for <project> - emphasize quick wins that can ship in 1 week
```

### Issue: Features don't solve real problems

**Fix:** Include user research
```
Generate features for <project> - users complain about: [specific pain points]
```

### Issue: Too many features, overwhelmed

**Fix:** Focus on one area
```
Generate onboarding features only for <project>
```

## Related Skills

- **`beautiful-ui`** - Design UI for selected features
- **`clickup-refinement`** - Convert features into structured tasks
- **`deployment-reasoning`** - Plan architecture for features
- **`allocate-worktree`** - Start implementing features

## Next Steps After Feature Generation

**Recommended workflow:**

1. **Review** - Read `top-5-features.md` thoroughly
2. **Validate** - Show to users/stakeholders for feedback
3. **Prototype** - Quick mockup of #1 feature
4. **Implement** - Start with highest ROI feature
5. **Measure** - Track success metrics defined in analysis
6. **Iterate** - Run feature-idea-generator again after launch

---

**Need help?** Ask: "How do I use feature-idea-generator for [your use case]"
