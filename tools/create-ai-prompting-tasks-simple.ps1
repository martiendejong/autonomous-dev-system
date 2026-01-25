# Create AI Prompting Tasks in ClickUp - Simplified
$ErrorActionPreference = "Stop"

$configPath = "C:\scripts\_machine\clickup-config.json"
$config = Get-Content $configPath | ConvertFrom-Json
$apiKey = $config.api_key
$apiBase = $config.api_base
$listId = "901214097647"

$headers = @{
    Authorization = $apiKey
    "Content-Type" = "application/json"
}

function New-Task {
    param(
        [string]$Name,
        [string]$Desc,
        [string]$Priority = "normal",
        [int]$Hours = 0
    )

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


    $url = "$apiBase/list/$listId/task"
    $priorityNum = switch ($Priority) {
        "urgent" { 1 }
        "high" { 2 }
        "normal" { 3 }
        "low" { 4 }
        default { 3 }
    }

    $taskBody = @{
        name = $Name
        description = $Desc
        priority = $priorityNum
    }

    if ($Hours -gt 0) {
        $taskBody.time_estimate = $Hours * 3600000
    }

    $body = $taskBody | ConvertTo-Json -Depth 10

    try {
        $task = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
        Write-Host "CREATED: $Name" -ForegroundColor Green
        Write-Host "URL: $($task.url)" -ForegroundColor Gray
        return $task.id
    }
    catch {
        Write-Host "FAILED: $Name - $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

Write-Host "`n=== Creating AI Prompting Tasks ===" -ForegroundColor Cyan

# EPIC
$epicId = New-Task `
    -Name "EPIC: AI Prompting Best Practices Implementation" `
    -Desc "Transform Brand2Boost with advanced AI prompting techniques. Source: NetworkChuck video analysis. Document: C:\Projects\client-manager\docs\AI_PROMPTING_ANALYSIS.md. Expected ROI: 493% over 3 years. Payback: 6 months." `
    -Priority "high" `
    -Hours 0

Start-Sleep -Seconds 1

# QUICK WINS
Write-Host "`n--- Quick Wins ---" -ForegroundColor Yellow

New-Task `
    -Name "Quick Win 1: Add Personas to All Prompts" `
    -Desc "Enhance PromptOptimizer.cs with AddPersona() method. Extract persona from brand profile (industry, target audience, tone). Update all generation services to use personas. Immediate quality improvement. Effort: 1-2 hours." `
    -Priority "urgent" `
    -Hours 2

Start-Sleep -Seconds 1

New-Task `
    -Name "Quick Win 2: Context Completeness Warning" `
    -Desc "Create ContextCompletenessScorer service. Show warning modal when brand profile <70% complete. Add API endpoint for completeness score. Frontend modal with 'Complete Profile' or 'Generate Anyway' options. Effort: 2-3 hours." `
    -Priority "urgent" `
    -Hours 3

Start-Sleep -Seconds 1

New-Task `
    -Name "Quick Win 3: Output Format Specification" `
    -Desc "Add explicit format requirements to prompts. Update GetBlogPromptTemplate() and GetSocialPromptTemplate() with structured output formats. Include H1/H2 structure for blogs, character limits for social. Effort: 1 hour per content type." `
    -Priority "high" `
    -Hours 3

Start-Sleep -Seconds 1

# PHASE 1
Write-Host "`n--- Phase 1: Few-Shot Examples System ---" -ForegroundColor Yellow

New-Task `
    -Name "Phase 1.1: Database Schema for Prompt Examples" `
    -Desc "Create PromptExamples table with fields: Id, ProjectId, Category, Input, Output, Rating, PerformanceScore. Add indexes for performance. Create migration and update DbContext. Effort: 4 hours." `
    -Priority "high" `
    -Hours 4

Start-Sleep -Seconds 1

New-Task `
    -Name "Phase 1.2: FewShotPromptBuilder Service" `
    -Desc "Create service that builds prompts with examples from user's best content. Implement top-rated example retrieval, prompt formatting. Create PromptExampleRepository. Add DI configuration. Write unit tests. Effort: 12 hours." `
    -Priority "high" `
    -Hours 12

Start-Sleep -Seconds 1

New-Task `
    -Name "Phase 1.3: API Endpoints for Example Management" `
    -Desc "Create ExamplesController with CRUD endpoints: GET examples, POST create, PUT rating, DELETE. Add authorization (project ownership). Write integration tests. Create Postman collection. Effort: 8 hours." `
    -Priority "high" `
    -Hours 8

Start-Sleep -Seconds 1

New-Task `
    -Name "Phase 1.4: Auto-Capture Approved Content as Examples" `
    -Desc "Automatically save user-approved content as examples. Update BlogGenerationService and SocialMediaGenerationService. Create ExampleCaptureService. Add background job for rating updates based on analytics. Effort: 8 hours." `
    -Priority "high" `
    -Hours 8

Start-Sleep -Seconds 1

New-Task `
    -Name "Phase 1.5: Frontend - Use Best Examples Toggle" `
    -Desc "Create ExampleToggle component for content generation forms. Add ExampleViewer modal to preview selected examples. Add ExampleCustomizer for manual selection. Integrate with generation API. Track analytics. Effort: 12 hours." `
    -Priority "high" `
    -Hours 12

Start-Sleep -Seconds 1

New-Task `
    -Name "Phase 1.6: Integration Testing - Few-Shot System" `
    -Desc "End-to-end testing of few-shot system. Test scenarios: new user, existing user, example management, performance. Write unit, integration, E2E tests. Document quality improvement metrics. Effort: 8 hours." `
    -Priority "normal" `
    -Hours 8

Start-Sleep -Seconds 1

New-Task `
    -Name "Phase 1.7: Migration - Seed Initial Examples" `
    -Desc "Populate PromptExamples with existing high-quality content from PublishedPosts and BlogPosts. Extract top 100 per project based on engagement. Create migration script. Test on dev. Document rollback. Effort: 6 hours." `
    -Priority "normal" `
    -Hours 6

Start-Sleep -Seconds 1

# PHASE 2
Write-Host "`n--- Phase 2: Guided Prompting Interface ---" -ForegroundColor Yellow

New-Task `
    -Name "Phase 2.1: Persona Builder Service" `
    -Desc "Create PersonaBuilder service that generates AI personas from brand profile. Define 10+ persona templates for common industries. Implement custom persona storage and caching. Write unit tests. Effort: 8 hours." `
    -Priority "normal" `
    -Hours 8

Start-Sleep -Seconds 1

New-Task `
    -Name "Phase 2.2: Output Template Library" `
    -Desc "Create OutputTemplates table and seed with 8+ templates (4 blog, 4 social). Templates include: How-to Guide, Listicle, Case Study, AIDA, Storytelling. Create TemplateService and API endpoints. Frontend selector. Effort: 12 hours." `
    -Priority "normal" `
    -Hours 12

Start-Sleep -Seconds 1

New-Task `
    -Name "Phase 2.3: Context Completeness Indicator UI" `
    -Desc "Visual indicator showing brand profile completeness. Components: ContextCompletenessBar, FieldStatus, ImpactTip, Dashboard. Real-time score calculation. Field-specific improvement tips. Completion wizard. Mobile-responsive. Effort: 10 hours." `
    -Priority "normal" `
    -Hours 10

Start-Sleep -Seconds 1

New-Task `
    -Name "Phase 2.4: Prompt Builder Interface" `
    -Desc "Unified wizard combining persona selection, template selection, context review. Step-by-step flow with preview. Save/load configurations. A/B test guided vs traditional UI. User testing with 10+ users. Effort: 16 hours." `
    -Priority "normal" `
    -Hours 16

Start-Sleep -Seconds 1

# PHASE 3
Write-Host "`n--- Phase 3: Content Variation Generator ---" -ForegroundColor Yellow

New-Task `
    -Name "Phase 3.1: Trees of Thought (ToT) Service" `
    -Desc "Generate multiple content variations using different approaches (emotional, feature, problem-solution, social proof). Implement synthesis algorithm. Add engagement prediction ML model. Database schema for variations. Effort: 16 hours." `
    -Priority "low" `
    -Hours 16

Start-Sleep -Seconds 1

New-Task `
    -Name "Phase 3.2: Variation Comparison UI" `
    -Desc "Side-by-side comparison interface for variations. VariantCard, VariantComparison, SynthesisPanel components. Selection mechanism and hybrid creation. Display engagement predictions. Analytics on user preferences. Effort: 12 hours." `
    -Priority "low" `
    -Hours 12

Start-Sleep -Seconds 1

New-Task `
    -Name "Phase 3.3: Engagement Prediction Model" `
    -Desc "Train ML model to predict engagement. Features: length, sentiment, hashtags, platform factors. Collect dataset (1000+ samples). Train with ML.NET or scikit-learn. Create PredictionService. Performance: <100ms. R-squared >0.6. Effort: 20 hours." `
    -Priority "low" `
    -Hours 20

Start-Sleep -Seconds 1

# SUPPORTING
Write-Host "`n--- Supporting Tasks ---" -ForegroundColor Yellow

New-Task `
    -Name "Documentation: AI Prompting Best Practices" `
    -Desc "Create user guide, 4 help center articles, 3 video tutorials, in-app tooltips. Topics: effective prompts, examples, context completeness, advanced techniques. Test with beta users. Effort: 16 hours." `
    -Priority "normal" `
    -Hours 16

Start-Sleep -Seconds 1

New-Task `
    -Name "Analytics: AI Prompting Feature Tracking" `
    -Desc "Track metrics: context completeness, example usage, edit time, regenerations, satisfaction ratings, business impact. Create admin dashboard, automated reports, A/B testing infrastructure. Effort: 12 hours." `
    -Priority "normal" `
    -Hours 12

Start-Sleep -Seconds 1

New-Task `
    -Name "QA: Comprehensive Testing Plan" `
    -Desc "Ensure 80%+ unit test coverage. Integration tests for all APIs. E2E tests with Playwright. Performance, security, load testing. Cross-browser and mobile testing. Fix all critical bugs. Effort: 24 hours." `
    -Priority "high" `
    -Hours 24

Start-Sleep -Seconds 1

New-Task `
    -Name "DevOps: Deployment and Rollout Plan" `
    -Desc "Gradual rollout: Beta 10%, then 50%, then 100%. Feature flags configuration. Monitoring dashboards. Rollback plan. Post-deployment monitoring and feedback collection. Target: 4.0+ user rating. Effort: 8 hours." `
    -Priority "high" `
    -Hours 8

Write-Host "`n=== Task Creation Complete ===" -ForegroundColor Green
Write-Host "Total: 22 tasks created" -ForegroundColor Cyan
Write-Host "View in ClickUp: https://app.clickup.com/9012956001/v/li/901214097647" -ForegroundColor Yellow
