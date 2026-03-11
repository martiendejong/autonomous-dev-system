---
name: feature-idea-generator
description: Generate breakthrough product features using multi-perspective expert analysis. Use when brainstorming features, improving products, generating ideas, or when user asks to come up with improvements, create new features, or make products more valuable.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Task, WebSearch
user-invocable: true
---

# Feature Idea Generator

**Purpose:** Generate transformative product features through systematic multi-expert analysis, value distillation, and high-impact ideation. This skill simulates a team of 100+ domain experts to identify core value propositions and create features that make products 10-1000x more valuable.

## When to Use This Skill

**Use when:**
- User asks to "come up with ideas" or "create new improvements"
- Brainstorming features for existing product or codebase
- Need to identify most valuable improvements
- Want breakthrough innovations, not incremental changes
- Analyzing what makes a product truly valuable
- Prioritizing features by value-to-effort ratio
- User says "make this product better" or "what features should we add"

**Don't use when:**
- Fixing specific bugs (use debug-mode)
- Implementing already-defined features (use feature-mode)
- User has specific feature already in mind (just implement it)

## Prerequisites

- Target project/product/idea must be identified
- Access to codebase (if applicable) to understand current state
- Understanding of product domain and user base
- ClickUp access (optional - for backlog integration)

## Workflow Steps

### Phase 1: Deep Expert Analysis (100-Expert Panel Assembly)

**Objective:** Understand the product from every possible angle

#### Step 1.1: Analyze Current State

```markdown
For codebase/product:
1. Read architecture, README, key files
2. Identify tech stack, patterns, integrations
3. Map current feature set
4. Understand data models and business logic

For new idea:
1. Research domain and competitors
2. Identify market gaps
3. Map potential user personas
4. Understand regulatory/technical constraints
```

#### Step 1.2: Assemble Expert Panel

**Simulate perspectives from 100+ experts across:**

**Technical Experts (20):**
- Software Architects (scalability, patterns)
- UX/UI Designers (usability, delight)
- Data Scientists (ML/AI opportunities)
- Security Experts (threat modeling)
- Performance Engineers (optimization)
- DevOps Engineers (deployment, reliability)
- Mobile Developers (cross-platform)
- Accessibility Specialists (WCAG, inclusive design)
- API Designers (integration, extensibility)
- Database Architects (data modeling)

**Business Stakeholders (20):**
- Product Managers (roadmap, market fit)
- Marketing Directors (positioning, messaging)
- Sales Leaders (conversion, objection handling)
- Customer Success (retention, satisfaction)
- Finance/CFO (monetization, unit economics)
- Legal/Compliance (regulatory, risk)
- Operations (scalability, efficiency)
- Business Development (partnerships, ecosystems)
- Pricing Strategists (value capture)
- Growth Hackers (viral loops, activation)

**Domain Scientists (20):**
- Industry-specific experts (e.g., healthcare, fintech)
- Research scientists (cutting-edge tech)
- Behavioral psychologists (user motivation)
- Economists (market dynamics)
- Anthropologists (cultural factors)
- Neuroscientists (cognitive load, attention)
- Statisticians (analytics, measurement)
- Game Designers (engagement, rewards)
- Educators (learning, onboarding)
- Ethicists (fairness, bias, impact)

**End Users (20):**
- Power users (advanced needs)
- Casual users (simplicity, clarity)
- First-time users (onboarding)
- Mobile-first users
- Desktop power users
- Accessibility-dependent users
- Enterprise admins
- Individual contributors
- Budget-conscious users
- Premium/power users

**Adjacent Innovators (20):**
- Adjacent industry experts (cross-pollination)
- Startup founders (disruptive thinking)
- Open source maintainers (community)
- Platform architects (ecosystems)
- Design thinkers (human-centered)
- Futurists (emerging trends)
- Complexity scientists (systems thinking)
- Biomimicry experts (nature-inspired solutions)
- Artists (creative perspectives)
- Philosophers (first principles)

#### Step 1.3: Multi-Perspective Analysis

**For each expert group, ask:**
1. What is this product's core value?
2. What are the biggest missed opportunities?
3. What would make this 10x better in your domain?
4. What unique insights does your expertise bring?
5. What are the hidden constraints/opportunities?

**Document findings in:**
```
C:/scripts/_ideation/<project-name>/expert-analysis.md
```

### Phase 2: Core Value Distillation

**Objective:** Identify the single most important value this product delivers

#### Step 2.1: Value Brainstorm Session

**Simulate roundtable discussion:**
- Each expert group presents their value hypothesis
- Identify common themes across perspectives
- Challenge assumptions and surface contradictions
- Vote on core value propositions

**Ask:**
- Why would someone choose this over alternatives?
- What job is the user really trying to do?
- What transformation does this product enable?
- What would users lose if this didn't exist?

#### Step 2.2: Compile Core Value Document

**Create comprehensive value analysis:**

```markdown
# Core Value Analysis: <Project Name>

## Primary Value Proposition
<The single most important value this product delivers>

## Supporting Values (Top 5)
1. <Value 2>
2. <Value 3>
3. <Value 4>
4. <Value 5>
5. <Value 6>

## Value Evidence
- User testimonials
- Usage patterns
- Market positioning
- Competitive advantages

## Value Constraints
- What limits value delivery today?
- What could destroy this value?
- What dependencies exist?

## Value Expansion Vectors
- How can this value be amplified?
- What adjacent values could be unlocked?
- What would 10x this value mean?
```

**Save to:**
```
C:/scripts/_ideation/<project-name>/core-value.md
```

### Phase 3: 100 Brilliant Ideas Generation

**Objective:** Generate 100 ideas that realize and extend core value

#### Step 3.1: Ideation Rules

**Each idea must:**
- Directly amplify the core value identified
- Be technically feasible (even if ambitious)
- Solve a real user problem
- Be specific and actionable (not vague)
- Have clear success metrics

**Ideation techniques:**
1. **Value Amplification:** How can core value be 10x stronger?
2. **Adjacent Expansion:** What related problems share the same value?
3. **Constraint Removal:** What if [limitation] didn't exist?
4. **Cross-Domain:** What solutions from other industries apply?
5. **User Journey:** What friction points can be eliminated?
6. **Network Effects:** How can users create value for each other?
7. **AI/Automation:** What manual work can be automated?
8. **Personalization:** How can this adapt to individual users?
9. **Integration:** What ecosystems can this connect to?
10. **Gamification:** How can engagement be increased?

#### Step 3.2: Generate 100 Ideas

**Use all 100+ expert perspectives to generate ideas:**

**Format each idea:**
```markdown
## Idea #N: <Name>

**Value Amplification:** <How this extends core value>
**User Benefit:** <Specific benefit to user>
**Expert Source:** <Which expert perspective generated this>
**Feasibility:** <Low/Medium/High>
**Impact Potential:** <1-10>
```

**Save to:**
```
C:/scripts/_ideation/<project-name>/100-ideas.md
```

#### Step 3.3: Distill Essence

**Create synthesis document:**
- Identify themes across 100 ideas
- Group related concepts
- Extract meta-patterns
- Document breakthrough insights

**Save to:**
```
C:/scripts/_ideation/<project-name>/idea-essence.md
```

### Phase 4: 100 Billion-Dollar Features

**Objective:** Design features so valuable they become must-haves

#### Step 4.1: Billion-Dollar Feature Criteria

**Each feature must pass this test:**
```
✅ Makes product 1000x more valuable
✅ Creates unique, irreplaceable value
✅ Users would switch from competitors for this alone
✅ Clear, immediate user benefit
✅ Difficult/impossible to replicate
✅ Creates network effects or lock-in (ethical)
✅ Solves problem user didn't know they had
```

#### Step 4.2: Design 100 Transformative Features

**For each feature, document:**

```markdown
## Feature #N: <Name>

### The Billion-Dollar Pitch
<One-paragraph pitch: Why this makes product irresistible>

### User Story
**As a** <user type>
**I want** <capability>
**So that** <transformative benefit>

### Unique Value
<What makes this impossible to get elsewhere>

### Value Calculation
- Current pain: <What user suffers today>
- Feature solves: <How feature eliminates pain>
- Time saved: <Quantifiable time savings>
- Money saved: <Quantifiable cost savings>
- New capability unlocked: <What becomes possible>

### Why Now
<Why hasn't this been done before? Why is now the time?>

### Network Effects
<How does this get better with more users?>

### Competitive Moat
<Why can't competitors easily copy this?>

### Success Metrics
- Activation: <What % of users use this?>
- Retention: <Does this increase stickiness?>
- Referral: <Do users tell others about this?>
- Revenue: <Direct or indirect revenue impact?>

### Technical Feasibility
- **Complexity:** <Low/Medium/High/Very High>
- **Dependencies:** <What's needed to build this>
- **Risks:** <What could go wrong>
- **Timeline:** <Rough estimate>

### Expert Validation
<Which experts endorsed this and why>
```

**Save to:**
```
C:/scripts/_ideation/<project-name>/100-billion-dollar-features.md
```

### Phase 5: Million-Times Better (Feature Refinement)

**Objective:** Take each feature from great to transcendent

#### Step 5.1: Expert Panel Refinement

**For each of the 100 features:**

**Assemble relevant experts (10-20 per feature):**
- Technical feasibility experts
- User experience experts
- Business model experts
- Domain-specific experts

**Refinement questions:**
1. How can this be simpler?
2. How can this be more powerful?
3. What edge cases are missed?
4. What would make this delightful, not just useful?
5. How can onboarding be instant?
6. What would make this viral?
7. How can this create habit formation?
8. What's the minimum viable version?
9. What's the "wow" moment?
10. How can this compound over time?

#### Step 5.2: Apply Systematic Improvements

**For each feature, apply these lenses:**

**1. Simplicity Lens:**
- Remove steps
- Reduce cognitive load
- Make defaults perfect
- Hide complexity

**2. Power Lens:**
- Add keyboard shortcuts
- Enable bulk operations
- Allow customization
- Support advanced workflows

**3. Delight Lens:**
- Add animations
- Celebrate successes
- Surprise and delight
- Personalize experience

**4. Intelligence Lens:**
- Add AI assistance
- Predict user needs
- Learn from behavior
- Automate decisions

**5. Integration Lens:**
- Connect to ecosystem
- Enable workflows
- Import/export easily
- API-first design

**6. Scale Lens:**
- Works with 1 item or 1M items
- Collaborative features
- Performance optimized
- Mobile + desktop

#### Step 5.3: Document Refined Features

**Update each feature with:**
```markdown
## Feature #N (REFINED): <Name>

### Refinement Summary
<What changed and why>

### Simplicity Improvements
- <Improvement 1>
- <Improvement 2>

### Power Improvements
- <Improvement 1>
- <Improvement 2>

### Delight Improvements
- <Improvement 1>
- <Improvement 2>

[... other lenses ...]

### Expert Consensus
<Final validation from expert panel>

### Revised Value Calculation
<Updated ROI after refinements>
```

**Save to:**
```
C:/scripts/_ideation/<project-name>/refined-features.md
```

### Phase 6: Top 5 High-Impact, Low-Effort Features

**Objective:** Identify the most valuable features to build first

#### Step 6.1: Value-Effort Matrix

**Score each feature:**

**Value Score (1-100):**
- User impact: 0-30 points
- Business impact: 0-30 points
- Competitive advantage: 0-20 points
- Network effects: 0-10 points
- Strategic alignment: 0-10 points

**Effort Score (1-100):**
- Development time: 0-30 points
- Technical complexity: 0-25 points
- Dependencies: 0-15 points
- Risk: 0-15 points
- Team capacity: 0-15 points

**Calculate ROI:**
```
ROI = Value Score / Effort Score
```

#### Step 6.2: Rank and Select Top 5

**Sort by ROI and select top 5:**

```markdown
# Top 5 Features: <Project Name>

## #1: <Feature Name>
**Value Score:** <X>/100
**Effort Score:** <Y>/100
**ROI:** <X/Y>

### Why This First
<Strategic rationale for prioritization>

### Quick Wins
<What can be delivered in Phase 1>

### Full Vision
<What the complete feature looks like>

### Success Criteria
- <Metric 1>
- <Metric 2>
- <Metric 3>

---

## #2: <Feature Name>
[... same structure ...]

[... #3, #4, #5 ...]
```

**Save to:**
```
C:/scripts/_ideation/<project-name>/top-5-features.md
```

#### Step 6.3: Create Visual Summary

**Generate summary table:**

```markdown
| Rank | Feature | Value | Effort | ROI | Quick Summary |
|------|---------|-------|--------|-----|---------------|
| 1 | <Name> | 95 | 25 | 3.8 | <One-line pitch> |
| 2 | <Name> | 88 | 30 | 2.9 | <One-line pitch> |
| 3 | <Name> | 85 | 35 | 2.4 | <One-line pitch> |
| 4 | <Name> | 82 | 40 | 2.1 | <One-line pitch> |
| 5 | <Name> | 80 | 42 | 1.9 | <One-line pitch> |
```

### Phase 7: ClickUp Integration (Optional)

**Objective:** Add top features to project backlog

#### Step 7.1: Detect ClickUp Integration

**Check if project has ClickUp:**
```bash
# Look for ClickUp references in project
grep -r "clickup" C:/Projects/<project-name>
grep -r "CLICKUP" C:/scripts/_machine/PROJECT_MASTER_MAP.md
```

#### Step 7.2: Create Backlog Tasks

**For each of the Top 5 features:**

**Task Format:**
```
Name: [FEATURE] <Feature Name>

Description:
## Value Proposition
<Why this feature is transformative>

## User Story
As a <user type>
I want <capability>
So that <benefit>

## Acceptance Criteria
- [ ] <Criterion 1>
- [ ] <Criterion 2>
- [ ] <Criterion 3>

## Implementation Notes
<Technical approach>

## Success Metrics
- <Metric 1>: <Target>
- <Metric 2>: <Target>

## References
See: C:/scripts/_ideation/<project>/top-5-features.md

Priority: <Urgent/High/Normal>
Tags: feature, high-impact, innovation, value-creation
```

**Use ClickUp API to create:**
```bash
# Get list ID from PROJECT_MASTER_MAP.md
# Create task with description, priority, tags
```

#### Step 7.3: Link Ideation Documents

**Add comment to each task:**
```markdown
## Ideation Process

This feature was generated through systematic expert analysis:

1. **Expert Panel:** 100+ domain experts analyzed product
2. **Core Value:** Identified transformative value proposition
3. **Ideation:** Generated 100 feature ideas
4. **Refinement:** Expert panel refined to billion-dollar features
5. **Prioritization:** Selected as Top 5 by value-to-effort ratio

**Full Analysis:** C:/scripts/_ideation/<project>/

**ROI Score:** <X.Y>
**Value Score:** <X>/100
**Effort Score:** <Y>/100
```

## Output Format

**Present to user:**

```markdown
# 🚀 Feature Ideation Complete: <Project Name>

## 📊 Analysis Summary

**Expert Perspectives Analyzed:** 100+
**Ideas Generated:** 100
**Billion-Dollar Features Designed:** 100
**Features Refined:** 100
**Top Features Selected:** 5

## 💎 Core Value Proposition

<Single most important value this product delivers>

## 🏆 Top 5 High-Impact Features

### #1: <Feature Name> (ROI: <X.Y>)
<One-paragraph pitch>

**Why This Matters:** <Transformative impact>
**Quick Win:** <Phase 1 deliverable>
**Full Vision:** <Ultimate capability>

---

### #2: <Feature Name> (ROI: <X.Y>)
[... same structure ...]

[... #3, #4, #5 ...]

## 📁 Detailed Documentation

All analysis saved to: `C:/scripts/_ideation/<project>/`

- `expert-analysis.md` - 100+ expert perspectives
- `core-value.md` - Value distillation
- `100-ideas.md` - All generated ideas
- `100-billion-dollar-features.md` - Transformative features
- `refined-features.md` - Expert-refined features
- `top-5-features.md` - Prioritized recommendations

## ✅ Next Steps

[If ClickUp integrated:]
✅ Added 5 tasks to ClickUp backlog: <Board Name>
- Task links: <URLs>

[If no ClickUp:]
Recommended actions:
1. Review top-5-features.md in detail
2. Validate assumptions with real users
3. Prototype #1 feature for user testing
4. Iterate based on feedback

## 🎯 Success Metrics

For each feature, track:
- Activation rate (% of users who use it)
- Retention impact (does it increase stickiness?)
- Referral rate (do users tell others?)
- Revenue impact (direct or indirect)
```

## Examples

### Example 1: Improve Existing SaaS Product

**User says:** "Come up with improvements for our project management tool"

**Claude activates feature-idea-generator:**

1. **Phase 1:** Analyzes current codebase, features, tech stack
   - Assembles expert panel (PM experts, UX designers, productivity scientists)
   - Identifies current features and user workflows

2. **Phase 2:** Distills core value
   - Value: "Helps teams coordinate asynchronously without meetings"
   - Supporting values: transparency, accountability, flexibility

3. **Phase 3:** Generates 100 ideas
   - AI-powered task estimation
   - Async video updates on tasks
   - Automatic meeting summarization
   - Smart dependency detection
   - [... 96 more ...]

4. **Phase 4:** Designs 100 billion-dollar features
   - Feature #1: "AI Project Copilot" - Predicts blockers before they happen
   - Feature #2: "Ambient Collaboration" - Captures context automatically
   - [... 98 more ...]

5. **Phase 5:** Refines with expert panel
   - AI Copilot refined: Add explainability, human override, learning from feedback

6. **Phase 6:** Selects Top 5
   - #1: Smart Daily Digest (ROI: 4.2)
   - #2: One-Click Status Updates (ROI: 3.8)
   - #3: AI Meeting Summarizer (ROI: 3.5)
   - #4: Dependency Auto-Detection (ROI: 3.2)
   - #5: Team Energy Dashboard (ROI: 2.9)

7. **Phase 7:** Creates ClickUp tasks for Top 5

**Result:** User has 5 validated, high-impact features ready to build

### Example 2: New Product Idea

**User says:** "I have an idea for a personal finance app - generate features for it"

**Claude activates feature-idea-generator:**

1. **Phase 1:** Research domain (no existing codebase)
   - Studies competitor apps (Mint, YNAB, Personal Capital)
   - Assembles fintech experts, behavioral economists, UX designers
   - Identifies market gaps

2. **Phase 2:** Distills core value
   - Value: "Helps people feel in control of their financial future"
   - Focus on psychology, not just tracking

3. **Phase 3:** Generates 100 ideas from expert perspectives
   - Behavioral economist: "Gamify saving with dopamine triggers"
   - UX designer: "Make budgets visual, not spreadsheets"
   - Neuroscientist: "Use color psychology for spending awareness"

4. **Phases 4-6:** Billion-dollar features → refinement → Top 5
   - #1: Financial Therapist AI (understands money anxiety)
   - #2: Invisible Budgeting (auto-categorizes, auto-saves)
   - #3: Future Self Visualization (see your 65-year-old self)
   - #4: Guilt-Free Spending Zones
   - #5: Social Accountability Pods

7. **Phase 7:** No ClickUp integration, generates implementation roadmap

**Result:** User has validated product direction with psychological moat

### Example 3: Brainstorming Session

**User says:** "Let's brainstorm some wild ideas for our codebase"

**Claude activates feature-idea-generator:**

- Runs full ideation process
- Emphasizes creativity in Phase 3 (100 ideas)
- Presents both Top 5 practical AND Top 5 moonshot ideas
- Documents all 100 for future inspiration

## Success Criteria

✅ Expert panel covers 100+ perspectives
✅ Core value clearly identified and documented
✅ 100 ideas generated that extend core value
✅ Each billion-dollar feature has clear ROI
✅ Refinement process improves each feature measurably
✅ Top 5 features prioritized by value-to-effort
✅ All documentation saved to _ideation directory
✅ (If applicable) Tasks created in ClickUp backlog
✅ User receives actionable, validated feature roadmap

## Common Issues

### Issue: Too Generic Ideas

**Symptom:** Ideas sound like "add AI" or "make it faster"

**Cause:** Not enough domain-specific expert input

**Solution:**
- Deepen Phase 1 analysis
- Add more domain-specific experts to panel
- Research competitor features to differentiate
- Focus on user pain points, not technology

### Issue: All Features Seem High-Effort

**Symptom:** No clear quick wins in Top 5

**Cause:** Ideas too ambitious, no MVP thinking

**Solution:**
- Add "Quick Win" section to each feature
- Break features into phases
- Look for low-hanging fruit in 100 ideas
- Consider technical feasibility earlier

### Issue: Features Don't Align with Core Value

**Symptom:** Top features feel disconnected from value prop

**Cause:** Phase 2 value distillation was weak

**Solution:**
- Revisit core value analysis
- Ensure each feature explicitly amplifies core value
- Test feature pitch against value proposition
- Remove features that don't serve core value

### Issue: Can't Decide Between Similar Features

**Symptom:** Multiple features solving same problem

**Cause:** Ideas too granular, need consolidation

**Solution:**
- Group related features in Phase 3
- Create "super-feature" that combines best aspects
- Use expert panel to break tie based on strategic fit

## Related Skills

- `clickup-refinement` - Convert features into well-structured tasks
- `beautiful-ui` - Design UI for selected features
- `deployment-reasoning` - Plan technical architecture for features
- `self-improvement` - Document new ideation patterns learned

---

## Behavioral Integration Notes

**Ring 1 (Resource Management):**
- This is a LONG workflow (7 phases)
- If context getting full, save intermediate results and continue
- Use Task tool with Explore agent for research-heavy phases
- Don't regenerate ideas - save and reference files

**Ring 2 (Confidence/Anti-Hallucination):**
- When simulating "expert opinions," be clear these are generated perspectives
- Don't fabricate competitor features or market data - research or flag uncertainty
- If uncertain about domain, use WebSearch for real examples
- Value scores are estimates - present as "estimated ROI" not absolute truth

**Ring 3 (Emergence/Creativity):**
- This skill IS creative - let emergence happen
- Cross-pollinate ideas between expert perspectives
- Look for non-obvious connections
- Don't self-censor "wild" ideas in Phase 3 - filter in Phase 6

---

**Created:** 2026-03-11
**Author:** Jengo (Claude Agent)
**Complexity:** Very High (Multi-phase, long workflow)
**Estimated Duration:** 30-60 minutes for full analysis
