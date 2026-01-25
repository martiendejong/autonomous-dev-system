<#
.SYNOPSIS
    Generate context-aware PR review checklist based on files changed

.DESCRIPTION
    Automatically generates customized review checklist based on:
    - File types changed (backend, frontend, database, config)
    - Patterns detected (migrations, API changes, security)
    - Complexity metrics
    - High-risk areas

    Ensures reviewers don't miss critical checks.

.PARAMETER PRNumber
    PR number to analyze (uses gh CLI)

.PARAMETER BaseBranch
    Base branch (default: auto-detect from PR)

.PARAMETER OutputFormat
    Output format: Markdown (default), JSON, GitHub

.EXAMPLE
    # Generate checklist for PR #123
    .\pr-review-checklist-generator.ps1 -PRNumber 123

.EXAMPLE
    # Generate and post as PR comment
    .\pr-review-checklist-generator.ps1 -PRNumber 123 -OutputFormat GitHub

.NOTES
    Value: 7/10 - Improves review quality
    Effort: 1/10 - Pattern matching + template
    Ratio: 7.0 (TIER S)
#>

param(
    [Parameter(Mandatory=$false)]
    [int]$PRNumber = 0,

    [Parameter(Mandatory=$false)]
    [string]$BaseBranch = "",

    [Parameter(Mandatory=$false)]
    [ValidateSet('Markdown', 'JSON', 'GitHub')]
    [string]$OutputFormat = 'Markdown'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "PR Review Checklist Generator" -ForegroundColor Cyan
Write-Host ""

# Get PR info
if ($PRNumber -gt 0) {
    # Use GitHub CLI
    $prInfo = gh pr view $PRNumber --json files,baseRefName,headRefName 2>$null | ConvertFrom-Json

    if (-not $prInfo) {
        Write-Host "❌ PR #$PRNumber not found" -ForegroundColor Red
        exit 1
    }

    $changedFiles = $prInfo.files | ForEach-Object { $_.path }
    if (-not $BaseBranch) {
        $BaseBranch = $prInfo.baseRefName
    }
    $headBranch = $prInfo.headRefName
} else {
    # Use git diff
    if (-not $BaseBranch) {
        $BaseBranch = "main"
    }
    $headBranch = "HEAD"
    $changedFiles = git diff $BaseBranch...$headBranch --name-only
}

Write-Host "Analyzing changes..." -ForegroundColor Yellow
Write-Host "  Base: $BaseBranch" -ForegroundColor Gray
Write-Host "  Head: $headBranch" -ForegroundColor Gray
Write-Host "  Files changed: $($changedFiles.Count)" -ForegroundColor Gray
Write-Host ""

# Categorize files
$categories = @{
    Backend = @()
    Frontend = @()
    Database = @()
    Config = @()
    Tests = @()
    Documentation = @()
}

$patterns = @{
    HasMigration = $false
    HasAPIChanges = $false
    HasSecurityChanges = $false
    HasPerformanceConcerns = $false
    HasBreakingChanges = $false
}

foreach ($file in $changedFiles) {
    # Backend
    if ($file -match '\.(cs|java|py|go|rb)$') {
        $categories.Backend += $file
    }

    # Frontend
    if ($file -match '\.(tsx?|jsx?|vue|svelte)$') {
        $categories.Frontend += $file
    }

    # Database
    if ($file -match 'migration|schema\.sql|\.sql$') {
        $categories.Database += $file
        $patterns.HasMigration = $true
    }

    # Config
    if ($file -match 'appsettings|\.config|\.env|docker|\.yml$|\.yaml$') {
        $categories.Config += $file
    }

    # Tests
    if ($file -match 'test|spec|\\.test\\.|\.spec\\.') {
        $categories.Tests += $file
    }

    # Documentation
    if ($file -match '\.md$|\.txt$|docs/') {
        $categories.Documentation += $file
    }

    # Patterns
    if ($file -match 'Controller\.cs|api/|endpoints/') {
        $patterns.HasAPIChanges = $true
    }

    if ($file -match 'auth|security|crypto|password|token') {
        $patterns.HasSecurityChanges = $true
    }

    if ($file -match 'cache|performance|query|index') {
        $patterns.HasPerformanceConcerns = $true
    }
}

# Generate checklist
$checklist = @()

# General checks (always included)
$checklist += "## General"
$checklist += "- [ ] Code follows project conventions and style guide"
$checklist += "- [ ] No commented-out code or debug statements"
$checklist += "- [ ] Error handling is appropriate"
$checklist += "- [ ] No sensitive data (passwords, keys, tokens) in code"
$checklist += ""

# Backend-specific
if ($categories.Backend.Count -gt 0) {
    $checklist += "## Backend ($($categories.Backend.Count) files)"
    $checklist += "- [ ] Business logic is properly separated from controllers"
    $checklist += "- [ ] Input validation is present"
    $checklist += "- [ ] Dependencies are injected, not newed up"
    $checklist += "- [ ] Async/await used correctly (no blocking calls)"
    $checklist += "- [ ] No N+1 query issues"
    $checklist += ""
}

# Frontend-specific
if ($categories.Frontend.Count -gt 0) {
    $checklist += "## Frontend ($($categories.Frontend.Count) files)"
    $checklist += "- [ ] Components are properly typed (TypeScript)"
    $checklist += "- [ ] No unnecessary re-renders"
    $checklist += "- [ ] Accessibility considerations (ARIA, keyboard navigation)"
    $checklist += "- [ ] Responsive design maintained"
    $checklist += "- [ ] Loading and error states handled"
    $checklist += ""
}

# Database-specific
if ($categories.Database.Count -gt 0) {
    $checklist += "## Database ($($categories.Database.Count) files)"
    $checklist += "- [ ] Migration is reversible (Down method implemented)"
    $checklist += "- [ ] No breaking schema changes without migration path"
    $checklist += "- [ ] Indexes added for new queries"
    $checklist += "- [ ] Data migration tested with production-like data volume"
    $checklist += "- [ ] Backup strategy considered for destructive changes"
    $checklist += ""
}

# API changes
if ($patterns.HasAPIChanges) {
    $checklist += "## API Changes"
    $checklist += "- [ ] OpenAPI/Swagger documentation updated"
    $checklist += "- [ ] Breaking changes are documented and versioned"
    $checklist += "- [ ] API clients notified of changes"
    $checklist += "- [ ] Backward compatibility maintained or migration guide provided"
    $checklist += ""
}

# Security changes
if ($patterns.HasSecurityChanges) {
    $checklist += "## Security (CRITICAL)"
    $checklist += "- [ ] Authentication/authorization logic is correct"
    $checklist += "- [ ] No security vulnerabilities (SQL injection, XSS, CSRF)"
    $checklist += "- [ ] Secrets are stored securely (not in code)"
    $checklist += "- [ ] Rate limiting considered for new endpoints"
    $checklist += "- [ ] Security review by security team (if available)"
    $checklist += ""
}

# Tests
if ($categories.Tests.Count -gt 0) {
    $checklist += "## Tests ($($categories.Tests.Count) files)"
    $checklist += "- [ ] Tests cover happy path and edge cases"
    $checklist += "- [ ] Test names clearly describe what they test"
    $checklist += "- [ ] No flaky tests introduced"
    $checklist += "- [ ] Mocks are used appropriately"
    $checklist += ""
} else {
    $checklist += "## Tests"
    $checklist += "- [ ] ⚠️ No test files changed - are tests needed?"
    $checklist += ""
}

# Performance
if ($patterns.HasPerformanceConcerns) {
    $checklist += "## Performance"
    $checklist += "- [ ] Performance impact measured (if significant)"
    $checklist += "- [ ] Caching strategy appropriate"
    $checklist += "- [ ] Database queries optimized"
    $checklist += "- [ ] No memory leaks"
    $checklist += ""
}

# Config changes
if ($categories.Config.Count -gt 0) {
    $checklist += "## Configuration ($($categories.Config.Count) files)"
    $checklist += "- [ ] Configuration changes documented"
    $checklist += "- [ ] Environment-specific values use environment variables"
    $checklist += "- [ ] No hardcoded URLs or credentials"
    $checklist += "- [ ] Changes applied to all environments (dev, staging, prod)"
    $checklist += ""
}

# Final checks
$checklist += "## Pre-Merge"
$checklist += "- [ ] PR description clearly explains changes"
$checklist += "- [ ] Commits are clean and well-messaged"
$checklist += "- [ ] No merge conflicts"
$checklist += "- [ ] CI/CD pipeline passes"
$checklist += "- [ ] Breaking changes communicated to team"

$checklistText = $checklist -join "`n"

switch ($OutputFormat) {
    'Markdown' {
        Write-Host ""
        Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  PR REVIEW CHECKLIST" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host $checklistText
    }
    'GitHub' {
        if ($PRNumber -gt 0) {
            $comment = @"
## 📋 Review Checklist

$checklistText

---
*🤖 Generated by PR Review Checklist Generator*
"@
            $comment | gh pr comment $PRNumber --body-file -
            Write-Host "✅ Checklist posted to PR #$PRNumber" -ForegroundColor Green
        } else {
            Write-Host "❌ -PRNumber required for GitHub output" -ForegroundColor Red
            exit 1
        }
    }
    'JSON' {
        @{
            Categories = $categories
            Patterns = $patterns
            Checklist = $checklist
        } | ConvertTo-Json -Depth 10
    }
}
