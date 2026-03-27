<#
.SYNOPSIS
    Create ClickUp tasks for AI Prompting Best Practices implementation
.DESCRIPTION
    Creates comprehensive task structure in ClickUp for implementing
    NetworkChuck video insights into Brand2Boost platform.
    Based on: C:\Projects\client-manager\docs\AI_PROMPTING_ANALYSIS.md
#>

$ErrorActionPreference = "Stop"

# Load ClickUp config
$configPath = "C:\scripts\_machine\clickup-config.json"
$config = Get-Content $configPath | ConvertFrom-Json
$apiKey = $config.api_key
$apiBase = $config.api_base
$listId = "901214097647"  # Brand Designer list

$headers = @{
    Authorization = $apiKey
    "Content-Type" = "application/json"
}

Write-Host "`n🚀 Creating AI Prompting Best Practices Tasks in ClickUp..." -ForegroundColor Cyan
Write-Host "Target List: Brand Designer ($listId)" -ForegroundColor Yellow
Write-Host ""

# Helper function to create task
function New-ClickUpTask {
    param(
        [string]$Name,
        [string]$Description,
        [string]$Priority = "normal",  # urgent, high, normal, low
        [int]$TimeEstimateHours = 0,
        [string[]]$Tags = @()

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
,
        [string]$Status = "todo"
    )

    $url = "$apiBase/list/$listId/task"

    $taskBody = @{
        name = $Name
        description = $Description
        status = $Status
        priority = switch ($Priority) {
            "urgent" { 1 }
            "high" { 2 }
            "normal" { 3 }
            "low" { 4 }
            default { 3 }
        }
    }

    if ($TimeEstimateHours -gt 0) {
        $taskBody.time_estimate = $TimeEstimateHours * 3600000  # Convert hours to milliseconds
    }

    if ($Tags.Count -gt 0) {
        $taskBody.tags = $Tags
    }

    $body = $taskBody | ConvertTo-Json -Depth 10

    try {
        $task = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
        Write-Host "✅ Created: $Name" -ForegroundColor Green
        Write-Host "   URL: $($task.url)" -ForegroundColor Gray
        return $task
    }
    catch {
        Write-Host "❌ Failed: $Name" -ForegroundColor Red
        Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# ============================================================================
# EPIC: AI Prompting Best Practices Implementation
# ============================================================================

$epicDescription = @"
# AI Prompting Best Practices - Implementation Epic

**Source:** NetworkChuck YouTube video analysis
**Document:** C:\Projects\client-manager\docs\AI_PROMPTING_ANALYSIS.md
**Goal:** Implement advanced AI prompting techniques to improve content quality

## Overview
Transform Brand2Boost from generic AI content generation to personalized, brand-voice learning platform.

## Phases
1. Quick Wins (1-2 days)
2. Phase 1: Few-Shot Examples System (2 sprints)
3. Phase 2: Guided Prompting Interface (2 sprints)
4. Phase 3: Content Variation Generator (2 sprints)

## Expected ROI
- Development: \$48,000 (6 sprints)
- Annual Benefit: \$95,000
- Payback: 6 months
- 3-Year ROI: 493%

## Key Differentiation
> "Brand2Boost doesn't just generate content - it learns your brand's unique voice and creates content that sounds like you wrote it yourself."

See full analysis: C:\Projects\client-manager\docs\AI_PROMPTING_ANALYSIS.md
"@

$epic = New-ClickUpTask `
    -Name "🎯 EPIC: AI Prompting Best Practices Implementation" `
    -Description $epicDescription `
    -Priority "high" `
    -Tags @("epic", "ai", "product-enhancement") `
    -Status "todo"

Start-Sleep -Milliseconds 500

# ============================================================================
# QUICK WINS (Can implement immediately)
# ============================================================================

Write-Host "`n📦 Creating Quick Win Tasks..." -ForegroundColor Yellow

# Quick Win 1: Add Personas
$qw1Desc = @"
## Quick Win 1: Add Personas to Existing Prompts

**Effort:** 1-2 hours
**Impact:** Immediate quality improvement in all AI-generated content

### Current State
```csharp
"Generate SEO-optimized blog post..."
```

### Target State
```csharp
var persona = GetPersonaForProject(projectId);
"You are {persona}. Generate SEO-optimized blog post..."
```

### Implementation
1. Enhance `PromptOptimizer.cs` with `AddPersona()` method
2. Extract persona from project's brand profile fields
3. Update all prompt generation calls to include persona

### Code Location
- File: `ClientManagerAPI/Services/Optimization/PromptOptimizer.cs`
- Method to add: `AddPersona(string prompt, string industry, string targetAudience, string toneOfVoice)`

### Acceptance Criteria
- [ ] `AddPersona()` method implemented in PromptOptimizer
- [ ] All blog generation prompts include persona
- [ ] All social media generation prompts include persona
- [ ] All chat prompts include persona
- [ ] Manual test: Generate content with vs without persona and verify quality improvement
"@

New-ClickUpTask `
    -Name "⚡ Quick Win 1: Add Personas to All Prompts" `
    -Description $qw1Desc `
    -Priority "urgent" `
    -TimeEstimateHours 2 `
    -Tags @("quick-win", "ai", "backend") `
    -Status "todo"

Start-Sleep -Milliseconds 500

# Quick Win 2: Context Completeness Warning
$qw2Desc = @"
## Quick Win 2: Context Completeness Warning

**Effort:** 2-3 hours
**Impact:** Encourages users to fill brand profiles → better AI results

### Current State
Users can generate content with incomplete brand profile (no warning).

### Target State
Show warning dialog when context completeness < 70% before generation.

### Implementation
**Backend:**
1. Create `ContextCompletenessScorer.cs` service
2. Calculate score based on filled analysis fields
3. Add endpoint: `GET /api/context/{projectId}/completeness`

**Frontend:**
1. Call completeness endpoint before content generation
2. Show modal warning if < 70%
3. Offer "Complete Profile" or "Generate Anyway" options

### Code Locations
- Backend: `ClientManagerAPI/Services/Prompting/ContextCompletenessScorer.cs` (new)
- Controller: `ClientManagerAPI/Controllers/PromptingController.cs` (new)
- Frontend: `client-manager-frontend/src/components/ContentGeneration/`

### Acceptance Criteria
- [ ] ContextCompletenessScorer service created
- [ ] Scoring algorithm implemented (weighted by field importance)
- [ ] API endpoint created and tested
- [ ] Frontend modal component created
- [ ] Warning shows for projects with < 70% completeness
- [ ] "Complete Profile" button navigates to brand profile page
- [ ] Analytics event tracked when users see warning
"@

New-ClickUpTask `
    -Name "⚡ Quick Win 2: Context Completeness Warning" `
    -Description $qw2Desc `
    -Priority "urgent" `
    -TimeEstimateHours 3 `
    -Tags @("quick-win", "ai", "ux", "fullstack") `
    -Status "todo"

Start-Sleep -Milliseconds 500

# Quick Win 3: Output Format Specification
$qw3Desc = @"
## Quick Win 3: Output Format Specification

**Effort:** 1 hour per content type (blog, social, email)
**Impact:** More consistent structure, less post-generation editing

### Current State
Generic instructions like "Write SEO-optimized blog post."

### Target State
Explicit format requirements for each content type.

### Implementation
Update prompt templates in `PromptOptimizer.cs`:

**Blog Posts:**
```
OUTPUT FORMAT:
- H1: [Compelling title with primary keyword]
- Introduction: 150-200 words, include hook and preview
- H2 Section 1-4: [Main points with H3 subsections]
- Conclusion: 150-200 words, summary + CTA
Word count: 1000-1500 words
```

**Social Media Posts:**
```
OUTPUT FORMAT:
- Hook line (attention grabber)
- Value proposition (1-2 sentences)
- Call-to-action
- Hashtags (3-5 relevant)
Character limit: {platform-specific}
```

### Code Location
- File: `ClientManagerAPI/Services/Optimization/PromptOptimizer.cs`
- Methods to update: `GetBlogPromptTemplate()`, `GetSocialPromptTemplate()`

### Acceptance Criteria
- [ ] Blog prompt template enhanced with explicit format
- [ ] Social media prompts enhanced (per platform)
- [ ] Email prompt template enhanced
- [ ] Chat prompts enhanced
- [ ] Manual testing shows more consistent output structure
"@

New-ClickUpTask `
    -Name "⚡ Quick Win 3: Output Format Specification" `
    -Description $qw3Desc `
    -Priority "high" `
    -TimeEstimateHours 3 `
    -Tags @("quick-win", "ai", "backend") `
    -Status "todo"

Start-Sleep -Milliseconds 500

# ============================================================================
# PHASE 1: Few-Shot Examples System (Priority 1)
# ============================================================================

Write-Host "`n📦 Creating Phase 1 Tasks (Few-Shot Examples)..." -ForegroundColor Yellow

# Phase 1.1: Database Schema
$p1_1Desc = @"
## Phase 1.1: Database Schema for Prompt Examples

**Sprint:** Phase 1 (Sprint 1/2)
**Effort:** 4 hours
**Dependencies:** None

### Objective
Create database tables to store user's best content as examples for few-shot prompting.

### Schema
```sql
CREATE TABLE PromptExamples (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    ProjectId UNIQUEIDENTIFIER NOT NULL,
    Category NVARCHAR(100) NOT NULL,        -- 'social-instagram', 'blog-howto'
    SubCategory NVARCHAR(100),
    Input NVARCHAR(MAX),                    -- What was provided to AI
    Output NVARCHAR(MAX) NOT NULL,          -- What AI generated (approved)
    Rating INT DEFAULT 0,                   -- 1-5 stars (user feedback)
    PerformanceScore DECIMAL(5,2),          -- From analytics
    EngagementMetrics NVARCHAR(MAX),        -- JSON
    UsageCount INT DEFAULT 0,
    IsApproved BIT DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2,
    FOREIGN KEY (ProjectId) REFERENCES Projects(Id) ON DELETE CASCADE
);

CREATE INDEX IX_Examples_Lookup
ON PromptExamples(ProjectId, Category, Rating DESC, PerformanceScore DESC);
```

### Implementation Steps
1. Create migration in `ClientManagerAPI/Migrations/`
2. Add `PromptExample` model to `ClientManagerAPI/Models/`
3. Update `DbContext` with `DbSet<PromptExample>`
4. Run migration on dev database
5. Verify schema with SQL Server Management Studio

### Acceptance Criteria
- [ ] Migration created and reviewed
- [ ] PromptExample model created with all properties
- [ ] DbContext updated
- [ ] Migration applied to dev database
- [ ] Index created for performance
- [ ] Foreign key constraint working
- [ ] Cascade delete tested
"@

New-ClickUpTask `
    -Name "📊 Phase 1.1: Database Schema for Prompt Examples" `
    -Description $p1_1Desc `
    -Priority "high" `
    -TimeEstimateHours 4 `
    -Tags @("phase-1", "database", "backend") `
    -Status "todo"

Start-Sleep -Milliseconds 500

# Phase 1.2: Backend Service
$p1_2Desc = @"
## Phase 1.2: FewShotPromptBuilder Service

**Sprint:** Phase 1 (Sprint 1/2)
**Effort:** 12 hours
**Dependencies:** Phase 1.1 (Database Schema)

### Objective
Create service that builds prompts with examples from user's best content.

### Service Interface
```csharp
public interface IFewShotPromptBuilder
{
    Task<string> BuildPromptWithExamplesAsync(
        string projectId,
        string taskType,
        string userInput,
        int maxExamples = 3);

    Task<List<PromptExample>> GetTopRatedExamplesAsync(
        string projectId,
        string category,
        int count = 3);

    Task<PromptExample> SaveExampleAsync(
        string projectId,
        string category,
        string input,
        string output,
        int rating = 0);
}
```

### Implementation Steps
1. Create `FewShotPromptBuilder.cs` in `Services/Prompting/`
2. Implement example retrieval (top-rated by category)
3. Implement prompt formatting with examples
4. Create `PromptExampleRepository.cs` for data access
5. Add dependency injection in `Program.cs`
6. Write unit tests

### Code Structure
```
Services/
├── Prompting/
│   ├── FewShotPromptBuilder.cs
│   ├── IFewShotPromptBuilder.cs
│   └── PromptExampleRepository.cs
```

### Acceptance Criteria
- [ ] FewShotPromptBuilder service created
- [ ] Repository pattern implemented for data access
- [ ] Top-rated examples retrieval working
- [ ] Prompt formatting with examples tested
- [ ] Unit tests written (≥80% coverage)
- [ ] Dependency injection configured
- [ ] Service documented with XML comments
"@

New-ClickUpTask `
    -Name "⚙️ Phase 1.2: FewShotPromptBuilder Service" `
    -Description $p1_2Desc `
    -Priority "high" `
    -TimeEstimateHours 12 `
    -Tags @("phase-1", "backend", "service") `
    -Status "todo"

Start-Sleep -Milliseconds 500

# Phase 1.3: API Endpoints
$p1_3Desc = @"
## Phase 1.3: API Endpoints for Example Management

**Sprint:** Phase 1 (Sprint 1/2)
**Effort:** 8 hours
**Dependencies:** Phase 1.2 (FewShotPromptBuilder Service)

### Objective
Create REST API endpoints for managing prompt examples.

### Endpoints
```csharp
[ApiController]
[Route("api/examples")]
public class ExamplesController : ControllerBase
{
    // GET /api/examples/{projectId}?category=social-instagram
    [HttpGet("{projectId}")]
    Task<ActionResult<List<PromptExample>>> GetExamples(
        string projectId,
        string category = null);

    // POST /api/examples/{projectId}
    [HttpPost("{projectId}")]
    Task<ActionResult<PromptExample>> CreateExample(
        CreateExampleRequest request);

    // PUT /api/examples/{id}/rating
    [HttpPut("{id}/rating")]
    Task<ActionResult> UpdateRating(string id, int rating);

    // GET /api/examples/{projectId}/top-rated?category=blog&count=3
    [HttpGet("{projectId}/top-rated")]
    Task<ActionResult<List<PromptExample>>> GetTopRated(
        string projectId,
        string category,
        int count = 3);

    // DELETE /api/examples/{id}
    [HttpDelete("{id}")]
    Task<ActionResult> DeleteExample(string id);
}
```

### Implementation Steps
1. Create `ExamplesController.cs`
2. Implement all CRUD endpoints
3. Add authorization (project ownership)
4. Add validation (model validation)
5. Add Swagger documentation
6. Write integration tests

### Acceptance Criteria
- [ ] ExamplesController created
- [ ] All endpoints implemented and tested
- [ ] Authorization working (users can only access their examples)
- [ ] Request validation working
- [ ] Swagger docs generated
- [ ] Integration tests written
- [ ] Postman collection created for testing
"@

New-ClickUpTask `
    -Name "🔌 Phase 1.3: API Endpoints for Examples" `
    -Description $p1_3Desc `
    -Priority "high" `
    -TimeEstimateHours 8 `
    -Tags @("phase-1", "backend", "api") `
    -Status "todo"

Start-Sleep -Milliseconds 500

# Phase 1.4: Auto-Capture System
$p1_4Desc = @"
## Phase 1.4: Auto-Capture Approved Content as Examples

**Sprint:** Phase 1 (Sprint 1/2)
**Effort:** 8 hours
**Dependencies:** Phase 1.3 (API Endpoints)

### Objective
Automatically save user-approved generated content as examples for future prompts.

### Implementation Strategy
When user approves generated content:
1. Detect approval event (user clicks "Use This" or "Publish")
2. Extract: category, input prompt, generated output
3. Save to PromptExamples table with initial rating = 3
4. Update rating based on performance metrics (if available)

### Code Changes
**Backend:**
- Update `BlogGenerationService.cs` to capture approved blogs
- Update `SocialMediaGenerationService.cs` to capture approved posts
- Add event handler for content approval
- Implement background job to update ratings based on analytics

**Analytics Integration:**
- Link examples to PublishedPosts table
- Update PerformanceScore when engagement metrics available
- Auto-promote high-performing content to 5-star examples

### Implementation Steps
1. Add approval tracking to content generation services
2. Create `ExampleCaptureService.cs`
3. Integrate with existing generation workflows
4. Add background job for rating updates
5. Test end-to-end workflow

### Acceptance Criteria
- [ ] Blog approval auto-saves to examples
- [ ] Social post approval auto-saves to examples
- [ ] Category correctly detected and assigned
- [ ] Initial rating set to 3 stars
- [ ] Performance-based rating updates working
- [ ] Background job runs correctly
- [ ] Manual test: Generate → Approve → Verify example saved
"@

New-ClickUpTask `
    -Name "🤖 Phase 1.4: Auto-Capture Approved Content" `
    -Description $p1_4Desc `
    -Priority "high" `
    -TimeEstimateHours 8 `
    -Tags @("phase-1", "backend", "automation") `
    -Status "todo"

Start-Sleep -Milliseconds 500

# Phase 1.5: Frontend - "Use Best Examples" Toggle
$p1_5Desc = @"
## Phase 1.5: Frontend - "Use Best Examples" Toggle

**Sprint:** Phase 1 (Sprint 2/2)
**Effort:** 12 hours
**Dependencies:** Phase 1.3 (API Endpoints), Phase 1.4 (Auto-Capture)

### Objective
Add UI toggle that enables few-shot prompting with user's best content.

### UI Design
```
┌─────────────────────────────────────────┐
│ Generate Instagram Post                 │
├─────────────────────────────────────────┤
│ Product: Bamboo Desk Organizer          │
│                                         │
│ ☑️ Use my best Instagram posts as      │
│    examples (3 selected)                │
│                                         │
│ [View Examples] [Customize]             │
│                                         │
│ Tone: Professional ▼                    │
│                                         │
│ [Generate] [Advanced Options ▼]         │
└─────────────────────────────────────────┘
```

### Components to Create
1. `ExampleToggle.tsx` - Toggle switch component
2. `ExampleViewer.tsx` - Modal to view selected examples
3. `ExampleCustomizer.tsx` - UI to manually select/deselect examples

### Implementation Steps
1. Create React components
2. Integrate with content generation forms
3. Call `/api/examples/{projectId}/top-rated` API
4. Show loading state while fetching examples
5. Display selected examples in modal
6. Pass `useExamples` flag to generation API
7. Add analytics tracking

### Acceptance Criteria
- [ ] Toggle component created and styled
- [ ] Toggle state persisted in localStorage
- [ ] "View Examples" button shows modal with examples
- [ ] Example modal displays input/output beautifully
- [ ] "Customize" allows manual selection
- [ ] Generated content quality improves with examples ON
- [ ] Analytics: Track toggle usage percentage
- [ ] Mobile-responsive design
"@

New-ClickUpTask `
    -Name "🎨 Phase 1.5: Frontend - Use Best Examples Toggle" `
    -Description $p1_5Desc `
    -Priority "high" `
    -TimeEstimateHours 12 `
    -Tags @("phase-1", "frontend", "react") `
    -Status "todo"

Start-Sleep -Milliseconds 500

# Phase 1.6: Integration Testing
$p1_6Desc = @"
## Phase 1.6: Integration Testing - Few-Shot System

**Sprint:** Phase 1 (Sprint 2/2)
**Effort:** 8 hours
**Dependencies:** All Phase 1 tasks

### Objective
End-to-end testing of few-shot prompting system.

### Test Scenarios
1. **New User (No Examples)**
   - Generate content without examples
   - Approve content → verify auto-capture
   - Generate again → verify examples used

2. **Existing User (Has Examples)**
   - Toggle ON → verify top-rated examples loaded
   - Generate content → verify quality improvement
   - Rate generated content → verify rating updates

3. **Example Management**
   - View all examples for project
   - Delete unwanted examples
   - Manually add custom examples
   - Update ratings

4. **Performance**
   - Generate with 0 examples (baseline)
   - Generate with 3 examples
   - Generate with 5 examples
   - Compare output quality and generation time

### Test Coverage
- [ ] Unit tests (≥80% coverage)
- [ ] Integration tests (API endpoints)
- [ ] E2E tests (Playwright/Cypress)
- [ ] Performance tests (load time, token usage)
- [ ] User acceptance testing

### Acceptance Criteria
- [ ] All automated tests passing
- [ ] Manual test scenarios completed
- [ ] Performance benchmarks recorded
- [ ] Quality improvement documented (before/after examples)
- [ ] Bug fixes for issues found during testing
- [ ] Test documentation updated
"@

New-ClickUpTask `
    -Name "🧪 Phase 1.6: Integration Testing" `
    -Description $p1_6Desc `
    -Priority "normal" `
    -TimeEstimateHours 8 `
    -Tags @("phase-1", "testing", "qa") `
    -Status "todo"

Start-Sleep -Milliseconds 500

# Phase 1.7: Migration - Seed Initial Examples
$p1_7Desc = @"
## Phase 1.7: Migration - Seed Initial Examples

**Sprint:** Phase 1 (Sprint 2/2)
**Effort:** 6 hours
**Dependencies:** Phase 1.1 (Database), Phase 1.4 (Auto-Capture)

### Objective
Create migration script to populate PromptExamples table with existing high-quality content.

### Data Sources
1. **PublishedPosts table** - Pull top-performing social media posts
2. **BlogPosts table** - Pull highly-rated blog articles
3. **Manual curated examples** - Hand-picked best content per industry

### Migration Strategy
```sql
-- Extract top 100 published posts per project
-- Filter by engagement metrics (likes, shares, comments)
-- Categorize by platform and content type
-- Insert into PromptExamples with initial rating based on performance
```

### Implementation Steps
1. Analyze existing PublishedPosts for quality metrics
2. Create data extraction queries
3. Write migration script (`SeedInitialExamples.cs`)
4. Test on dev database
5. Validate data quality
6. Document rollback procedure

### Acceptance Criteria
- [ ] Migration script created
- [ ] Data extraction queries tested
- [ ] Quality threshold defined (min engagement score)
- [ ] Examples correctly categorized
- [ ] Ratings assigned based on performance
- [ ] Migration tested on dev database
- [ ] Rollback script created
- [ ] Production migration plan documented
"@

New-ClickUpTask `
    -Name "🔄 Phase 1.7: Migration - Seed Initial Examples" `
    -Description $p1_7Desc `
    -Priority "normal" `
    -TimeEstimateHours 6 `
    -Tags @("phase-1", "database", "migration") `
    -Status "todo"

Start-Sleep -Milliseconds 500

# ============================================================================
# PHASE 2: Guided Prompting Interface (Priority 2)
# ============================================================================

Write-Host "`n📦 Creating Phase 2 Tasks (Guided Prompting)..." -ForegroundColor Yellow

# Phase 2.1: Persona Builder Service
$p2_1Desc = @"
## Phase 2.1: Persona Builder Service

**Sprint:** Phase 2 (Sprint 3/4)
**Effort:** 8 hours
**Dependencies:** Phase 1 completion

### Objective
Create service that builds AI personas from project's brand profile.

### Service Interface
```csharp
public interface IPersonaBuilder
{
    Task<string> BuildPersonaAsync(string projectId, string taskType);
    Task<List<PersonaTemplate>> GetPersonaTemplatesAsync(string category);
    Task<PersonaTemplate> CreateCustomPersonaAsync(string projectId, PersonaRequest request);
}
```

### Persona Templates
```csharp
public class PersonaTemplate
{
    public string Id { get; set; }
    public string Name { get; set; }
    public string Category { get; set; }  // "blog", "social", "email"
    public string Template { get; set; }
    public List<string> RequiredFields { get; set; }
}
```

### Implementation Steps
1. Create `PersonaBuilder.cs` service
2. Define persona templates for common industries
3. Implement persona generation from brand fields
4. Create custom persona storage
5. Add caching for frequently-used personas

### Acceptance Criteria
- [ ] PersonaBuilder service created
- [ ] 10+ persona templates defined
- [ ] Dynamic persona generation working
- [ ] Custom personas can be saved
- [ ] Caching implemented
- [ ] Unit tests written
"@

New-ClickUpTask `
    -Name "👤 Phase 2.1: Persona Builder Service" `
    -Description $p2_1Desc `
    -Priority "normal" `
    -TimeEstimateHours 8 `
    -Tags @("phase-2", "backend", "service") `
    -Status "next sprint"

Start-Sleep -Milliseconds 500

# Phase 2.2: Output Template Library
$p2_2Desc = @"
## Phase 2.2: Output Template Library

**Sprint:** Phase 2 (Sprint 3/4)
**Effort:** 12 hours
**Dependencies:** None (can run parallel with Phase 2.1)

### Objective
Create library of reusable output templates for different content types.

### Database Schema
```sql
CREATE TABLE OutputTemplates (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    Name NVARCHAR(200) NOT NULL,
    Category NVARCHAR(100) NOT NULL,    -- 'blog', 'social', 'email'
    Description NVARCHAR(500),
    Structure NVARCHAR(MAX) NOT NULL,   -- JSON schema
    PersonaTemplate NVARCHAR(MAX),
    IsCustom BIT DEFAULT 0,
    ProjectId UNIQUEIDENTIFIER,         -- NULL for global templates
    UsageCount INT DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE()
);
```

### Templates to Create
**Blog Post Templates:**
1. How-to Guide (Problem → Solution → Steps → Conclusion)
2. Listicle (Intro → 7 Points → Summary)
3. Case Study (Challenge → Approach → Results → Lessons)
4. Thought Leadership (Trend → Analysis → Perspective → Outlook)

**Social Media Templates:**
1. AIDA (Attention → Interest → Desire → Action)
2. Storytelling (Hook → Context → Climax → CTA)
3. Question-Based (Question → Answer → Invitation)
4. Feature Showcase (Product → Benefits → Proof → CTA)

### Implementation Steps
1. Create database migration
2. Create OutputTemplate model
3. Seed database with default templates
4. Create TemplateService for management
5. Create API endpoints
6. Create frontend template selector

### Acceptance Criteria
- [ ] Database schema created
- [ ] 8+ templates seeded (4 blog, 4 social)
- [ ] TemplateService implemented
- [ ] API endpoints working
- [ ] Frontend selector component created
- [ ] Templates improve output consistency
"@

New-ClickUpTask `
    -Name "📋 Phase 2.2: Output Template Library" `
    -Description $p2_2Desc `
    -Priority "normal" `
    -TimeEstimateHours 12 `
    -Tags @("phase-2", "fullstack", "templates") `
    -Status "next sprint"

Start-Sleep -Milliseconds 500

# Phase 2.3: Context Completeness UI
$p2_3Desc = @"
## Phase 2.3: Context Completeness Indicator UI

**Sprint:** Phase 2 (Sprint 4/4)
**Effort:** 10 hours
**Dependencies:** Quick Win 2 (Context Warning)

### Objective
Visual indicator showing brand profile completeness and impact on content quality.

### UI Design
```
┌─────────────────────────────────────────┐
│ Context Quality: 68% ████████░░░░       │
├─────────────────────────────────────────┤
│ ✅ Brand Profile: Complete              │
│ ✅ Target Audience: Complete            │
│ ⚠️  Tone of Voice: Incomplete           │
│ ❌ USPs: Missing                        │
│                                         │
│ 💡 Tip: Adding USPs could improve      │
│    content relevance by 25%             │
│                                         │
│ [Complete Missing Fields]               │
└─────────────────────────────────────────┘
```

### Components
1. `ContextCompletenessBar.tsx` - Progress bar component
2. `ContextFieldStatus.tsx` - Individual field status indicators
3. `ContextImpactTip.tsx` - Smart tips based on missing fields
4. `ContextDashboard.tsx` - Full dashboard view

### Implementation Steps
1. Design UI components in Figma
2. Implement React components
3. Integrate with ContextCompletenessScorer API
4. Add field-specific tips and guidance
5. Create "Complete Profile" wizard
6. Add analytics tracking

### Acceptance Criteria
- [ ] UI components created and styled
- [ ] Real-time score calculation
- [ ] Field-specific improvement tips
- [ ] Wizard guides users through completion
- [ ] Mobile-responsive design
- [ ] Analytics: Track completion rate improvement
"@

New-ClickUpTask `
    -Name "📊 Phase 2.3: Context Completeness UI" `
    -Description $p2_3Desc `
    -Priority "normal" `
    -TimeEstimateHours 10 `
    -Tags @("phase-2", "frontend", "ux") `
    -Status "next sprint"

Start-Sleep -Milliseconds 500

# Phase 2.4: Prompt Builder Interface
$p2_4Desc = @"
## Phase 2.4: Prompt Builder Interface

**Sprint:** Phase 2 (Sprint 4/4)
**Effort:** 16 hours
**Dependencies:** Phase 2.1, Phase 2.2, Phase 2.3

### Objective
Unified interface combining persona selection, template selection, and context review.

### UI Flow
1. **Persona Selection**
   - Choose from preset personas or create custom
   - Preview how persona affects tone

2. **Template Selection**
   - Browse template library
   - Preview template structure
   - Customize template if needed

3. **Context Review**
   - See completeness score
   - Fill missing critical fields
   - Preview what context will be sent to AI

4. **Generate**
   - One-click generation with all settings applied
   - Show confidence score for output quality

### Components
1. `PromptBuilderWizard.tsx` - Main wizard component
2. `PersonaSelector.tsx`
3. `TemplateSelector.tsx`
4. `ContextReviewer.tsx`
5. `GenerationPreview.tsx`

### Implementation Steps
1. Design wizard flow in Figma
2. Implement step-by-step wizard
3. Integrate all Phase 2 components
4. Add preview functionality
5. Implement save/load prompt configurations
6. Add A/B testing infrastructure

### Acceptance Criteria
- [ ] Wizard flow implemented
- [ ] All steps integrated
- [ ] Preview shows actual AI input
- [ ] Configurations can be saved for reuse
- [ ] A/B test: Guided vs Traditional interface
- [ ] User testing completed with 10+ users
- [ ] Feedback incorporated
"@

New-ClickUpTask `
    -Name "🎯 Phase 2.4: Prompt Builder Interface" `
    -Description $p2_4Desc `
    -Priority "normal" `
    -TimeEstimateHours 16 `
    -Tags @("phase-2", "frontend", "wizard") `
    -Status "next sprint"

Start-Sleep -Milliseconds 500

# ============================================================================
# PHASE 3: Content Variation Generator (Priority 3)
# ============================================================================

Write-Host "`n📦 Creating Phase 3 Tasks (Content Variations)..." -ForegroundColor Yellow

# Phase 3.1: Trees of Thought Service
$p3_1Desc = @"
## Phase 3.1: Trees of Thought (ToT) Service

**Sprint:** Phase 3 (Sprint 5/6)
**Effort:** 16 hours
**Dependencies:** Phase 1, Phase 2 completion

### Objective
Generate multiple content variations using different approaches, then synthesize best elements.

### Service Interface
```csharp
public interface IContentVariationService
{
    Task<VariationResult> GenerateVariationsAsync(
        string projectId,
        string content,
        string platform,
        string[] approaches = null);

    Task<ContentVariant> SynthesizeVariantsAsync(
        List<ContentVariant> variants);

    Task<decimal> PredictEngagementAsync(
        string content,
        string platform);
}
```

### Approaches
- Emotional Appeal
- Feature Focus
- Problem-Solution
- Social Proof
- Storytelling
- Educational

### Implementation Steps
1. Create ContentVariationService
2. Implement approach-based generation
3. Create synthesis algorithm
4. Implement engagement prediction (ML model)
5. Create database schema for variations
6. Add caching for common variations

### Acceptance Criteria
- [ ] Service generates 4+ variations
- [ ] Each variation uses distinct approach
- [ ] Synthesis combines best elements
- [ ] Engagement prediction working (basic ML)
- [ ] Variations stored in database
- [ ] Performance: < 10s for 4 variations
"@

New-ClickUpTask `
    -Name "🌲 Phase 3.1: Trees of Thought Service" `
    -Description $p3_1Desc `
    -Priority "low" `
    -TimeEstimateHours 16 `
    -Tags @("phase-3", "backend", "ai", "advanced") `
    -Status "next sprint"

Start-Sleep -Milliseconds 500

# Phase 3.2: Variation Comparison UI
$p3_2Desc = @"
## Phase 3.2: Variation Comparison UI

**Sprint:** Phase 3 (Sprint 5/6)
**Effort:** 12 hours
**Dependencies:** Phase 3.1 (ToT Service)

### Objective
Side-by-side comparison interface for generated variations.

### UI Design
```
┌────────────────────────────────────────┐
│ Social Media Post - Variations        │
├────────────────────────────────────────┤
│ [Emotional] [Feature] [Problem] [Proof]│
├────────────────────────────────────────┤
│                                        │
│  Variant 1: Emotional      [Select ✓] │
│  ┌──────────────────────────────────┐ │
│  │ 🌿 Fall in love with your       │ │
│  │ workspace again! ...             │ │
│  │ Est. Engagement: ⭐⭐⭐⭐☆        │ │
│  └──────────────────────────────────┘ │
│                                        │
│  Variant 2: Feature        [Select  ] │
│  ┌──────────────────────────────────┐ │
│  │ 3 tiers. 100% bamboo...          │ │
│  │ Est. Engagement: ⭐⭐⭐⭐⭐        │ │
│  └──────────────────────────────────┘ │
│                                        │
│ [Combine Best Elements] [Regenerate]  │
└────────────────────────────────────────┘
```

### Components
1. `VariationGenerator.tsx` - Main container
2. `VariantCard.tsx` - Individual variation display
3. `VariantComparison.tsx` - Side-by-side view
4. `SynthesisPanel.tsx` - Hybrid creation interface

### Implementation Steps
1. Design comparison UI in Figma
2. Implement variant cards
3. Add selection mechanism
4. Implement synthesis UI
5. Add engagement prediction display
6. Create analytics tracking

### Acceptance Criteria
- [ ] Variations display side-by-side
- [ ] Users can select favorite
- [ ] "Combine" creates hybrid version
- [ ] Engagement scores displayed
- [ ] Regeneration works with new approaches
- [ ] Analytics track which variants users prefer
"@

New-ClickUpTask `
    -Name "🎨 Phase 3.2: Variation Comparison UI" `
    -Description $p3_2Desc `
    -Priority "low" `
    -TimeEstimateHours 12 `
    -Tags @("phase-3", "frontend", "ux") `
    -Status "next sprint"

Start-Sleep -Milliseconds 500

# Phase 3.3: Engagement Prediction Model
$p3_3Desc = @"
## Phase 3.3: Engagement Prediction Model

**Sprint:** Phase 3 (Sprint 6/6)
**Effort:** 20 hours
**Dependencies:** Phase 3.1 (ToT Service)

### Objective
Train ML model to predict engagement score for generated content.

### Features
- Content length
- Sentiment analysis
- Hashtag count and relevance
- Platform-specific factors
- Brand alignment score
- Historical performance data

### Implementation
**Data Collection:**
1. Extract features from PublishedPosts
2. Collect engagement metrics (likes, shares, comments)
3. Normalize scores by platform
4. Create training dataset (min 1000 samples)

**Model Training:**
1. Use ML.NET or scikit-learn
2. Train regression model (Random Forest or XGBoost)
3. Validate with cross-validation
4. Optimize hyperparameters
5. Export model for production

**Integration:**
1. Create PredictionService
2. Load model at startup
3. Create API endpoint for predictions
4. Add caching for performance

### Acceptance Criteria
- [ ] Dataset created (≥1000 samples)
- [ ] Model trained with R² > 0.6
- [ ] PredictionService implemented
- [ ] API endpoint working
- [ ] Predictions accurate within 20% margin
- [ ] Performance: < 100ms per prediction
- [ ] Model retraining pipeline documented
"@

New-ClickUpTask `
    -Name "🤖 Phase 3.3: Engagement Prediction Model" `
    -Description $p3_3Desc `
    -Priority "low" `
    -TimeEstimateHours 20 `
    -Tags @("phase-3", "ml", "backend", "advanced") `
    -Status "next sprint"

Start-Sleep -Milliseconds 500

# ============================================================================
# SUPPORTING TASKS
# ============================================================================

Write-Host "`n📦 Creating Supporting Tasks..." -ForegroundColor Yellow

# Documentation Task
$docDesc = @"
## Documentation: AI Prompting Best Practices

### Objective
Create comprehensive user-facing documentation for new AI prompting features.

### Documents to Create
1. **User Guide: Getting Better AI Results**
   - How to write effective prompts
   - Importance of context completeness
   - Using examples to teach AI your voice
   - Advanced techniques (variations, templates)

2. **Help Center Articles**
   - "How to Write Effective Prompts for AI Content"
   - "The Power of Examples: Teaching AI Your Brand Voice"
   - "Context is King: Why Complete Brand Profiles Matter"
   - "Advanced Techniques: Getting the Most from AI Generation"

3. **Video Tutorials**
   - "Quick Start: Few-Shot Prompting" (2 min)
   - "Complete Guide: Prompt Builder" (5 min)
   - "Advanced: Content Variations" (3 min)

4. **In-App Tooltips**
   - Contextual help for each feature
   - Progressive disclosure for advanced features

### Acceptance Criteria
- [ ] User guide written and reviewed
- [ ] 4 help center articles published
- [ ] 3 video tutorials recorded and edited
- [ ] Tooltips implemented in UI
- [ ] Documentation tested with beta users
"@

New-ClickUpTask `
    -Name "📚 Documentation: AI Prompting Best Practices" `
    -Description $docDesc `
    -Priority "normal" `
    -TimeEstimateHours 16 `
    -Tags @("documentation", "user-education") `
    -Status "next sprint"

Start-Sleep -Milliseconds 500

# Analytics Task
$analyticsDesc = @"
## Analytics: AI Prompting Feature Tracking

### Objective
Implement comprehensive analytics to measure success of AI prompting features.

### Metrics to Track

**User Behavior:**
- Context completeness score (avg per user)
- % users using "Use Best Examples" toggle
- Average edit time per generated content
- Number of regeneration requests
- Feature adoption rates (persona, templates, variations)

**Content Quality:**
- User satisfaction ratings (1-5 stars)
- Acceptance rate (used vs discarded)
- Edit depth (character changes %)
- Time to publish (generation → publish)

**Business Impact:**
- User retention (with vs without features)
- Premium tier conversion
- Support ticket volume (AI-related)
- LLM API cost per user

### Implementation
1. Add analytics events to all new features
2. Create analytics dashboard in admin panel
3. Set up automated reports (weekly/monthly)
4. Implement A/B testing infrastructure
5. Create data export for deeper analysis

### Acceptance Criteria
- [ ] All key metrics tracked
- [ ] Admin dashboard created
- [ ] Automated reports configured
- [ ] A/B testing ready
- [ ] Data pipeline documented
"@

New-ClickUpTask `
    -Name "📊 Analytics: Feature Tracking" `
    -Description $analyticsDesc `
    -Priority "normal" `
    -TimeEstimateHours 12 `
    -Tags @("analytics", "tracking") `
    -Status "next sprint"

Start-Sleep -Milliseconds 500

# Testing Task
$testingDesc = @"
## QA: Comprehensive Testing Plan

### Objective
Ensure all AI prompting features work correctly and meet quality standards.

### Test Coverage

**Unit Tests (≥80% coverage):**
- All services (FewShotPromptBuilder, PersonaBuilder, etc.)
- All repositories
- Utility functions

**Integration Tests:**
- API endpoints (all CRUD operations)
- Database operations (ACID compliance)
- Service interactions

**E2E Tests (Playwright):**
- User flows (generate with examples, use templates, compare variations)
- Cross-browser testing
- Mobile responsiveness

**Performance Tests:**
- Load testing (concurrent users)
- Token usage optimization
- Database query performance
- API response times

**Security Tests:**
- Authorization (project ownership)
- Input validation (XSS, SQL injection)
- API rate limiting
- Data privacy (examples isolated by project)

### Acceptance Criteria
- [ ] ≥80% unit test coverage
- [ ] All integration tests passing
- [ ] 10+ E2E test scenarios
- [ ] Performance benchmarks met
- [ ] Security scan passed
- [ ] No critical bugs
"@

New-ClickUpTask `
    -Name "🧪 QA: Comprehensive Testing Plan" `
    -Description $testingDesc `
    -Priority "high" `
    -TimeEstimateHours 24 `
    -Tags @("qa", "testing") `
    -Status "next sprint"

Start-Sleep -Milliseconds 500

# Deployment Task
$deployDesc = @"
## DevOps: Deployment & Rollout Plan

### Objective
Plan and execute safe rollout of AI prompting features to production.

### Deployment Strategy

**Phase 1: Beta (10% users)**
- Select 10 beta users
- Enable features via feature flags
- Collect feedback and metrics
- Fix critical issues

**Phase 2: Gradual Rollout (50% users)**
- Enable for 50% of users
- Monitor performance and costs
- A/B test guided vs traditional UI
- Adjust based on data

**Phase 3: Full Release (100% users)**
- Enable for all users
- Announce in changelog and email
- Publish blog post
- Monitor for issues

### Pre-Deployment Checklist
- [ ] All tests passing
- [ ] Database migrations tested
- [ ] Feature flags configured
- [ ] Monitoring dashboards ready
- [ ] Rollback plan documented
- [ ] Performance benchmarks verified
- [ ] Security review completed

### Post-Deployment
- [ ] Monitor error logs (first 24h)
- [ ] Track adoption metrics
- [ ] Collect user feedback
- [ ] Address hot-fix issues
- [ ] Update documentation if needed

### Acceptance Criteria
- [ ] Deployed without incidents
- [ ] No critical bugs reported
- [ ] Metrics show positive impact
- [ ] User feedback positive (≥4.0/5.0)
"@

New-ClickUpTask `
    -Name "🚀 DevOps: Deployment & Rollout Plan" `
    -Description $deployDesc `
    -Priority "high" `
    -TimeEstimateHours 8 `
    -Tags @("devops", "deployment") `
    -Status "next sprint"

Start-Sleep -Milliseconds 500

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host "`n✅ Task Creation Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Summary:" -ForegroundColor Cyan
Write-Host "   - 1 Epic created" -ForegroundColor White
Write-Host "   - 3 Quick Win tasks" -ForegroundColor Yellow
Write-Host "   - 7 Phase 1 tasks (Few-Shot Examples)" -ForegroundColor Yellow
Write-Host "   - 4 Phase 2 tasks (Guided Prompting)" -ForegroundColor Yellow
Write-Host "   - 3 Phase 3 tasks (Content Variations)" -ForegroundColor Yellow
Write-Host "   - 4 Supporting tasks (Docs, Analytics, QA, DevOps)" -ForegroundColor Yellow
Write-Host ""
Write-Host "   Total: 22 tasks" -ForegroundColor Green
Write-Host ""
Write-Host "🔗 View in ClickUp: https://app.clickup.com/9012956001/v/li/901214097647" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Review tasks in ClickUp" -ForegroundColor White
Write-Host "   2. Prioritize Quick Wins for immediate implementation" -ForegroundColor White
Write-Host "   3. Assign tasks to team members" -ForegroundColor White
Write-Host "   4. Start with Quick Win 1 (Add Personas)" -ForegroundColor White
Write-Host ""
