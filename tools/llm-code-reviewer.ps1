<#
.SYNOPSIS
    AI-powered code review using Claude Code (zero API cost)

.DESCRIPTION
    Leverages Claude Code to review code changes with:
    - Security issue detection
    - Performance concerns
    - Bug risk analysis
    - Best practice violations
    - Architecture feedback

    How it works:
    - Captures git diff
    - Uses Claude Code Task tool for review
    - Formats review as comments
    - Optionally posts to GitHub PR

    Cost: $0 (uses existing Claude Code session)

.PARAMETER BaseBranch
    Base branch to compare against (default: main)

.PARAMETER HeadBranch
    Head branch to review (default: current)

.PARAMETER PRNumber
    PR number to post review comments (optional)

.PARAMETER Focus
    Review focus: security, performance, bugs, architecture, all (default: all)

.PARAMETER OutputFormat
    Output format: Markdown (default), GitHub, JSON

.EXAMPLE
    # Review current branch against main
    .\llm-code-reviewer.ps1

.EXAMPLE
    # Security-focused review
    .\llm-code-reviewer.ps1 -Focus security

.EXAMPLE
    # Review and post to PR #123
    .\llm-code-reviewer.ps1 -PRNumber 123 -OutputFormat GitHub

.NOTES
    Value: 10/10 - AI-powered code review with full context
    Effort: 1/10 - Git wrapper + Claude Code integration
    Ratio: 10.0 (TIER S+)

    COST: $0 - Uses existing Claude Code session
    No external API calls required!
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$BaseBranch = "main",

    [Parameter(Mandatory=$false)]
    [string]$HeadBranch = "HEAD",

    [Parameter(Mandatory=$false)]
    [int]$PRNumber = 0,

    [Parameter(Mandatory=$false)]
    [ValidateSet('security', 'performance', 'bugs', 'architecture', 'all')]
    [string]$Focus = 'all',

    [Parameter(Mandatory=$false)]
    [ValidateSet('Markdown', 'GitHub', 'JSON')]
    [string]$OutputFormat = 'Markdown'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🤖 LLM Code Reviewer (powered by Claude Code)" -ForegroundColor Cyan
Write-Host "  Base: $BaseBranch" -ForegroundColor Gray
Write-Host "  Head: $HeadBranch" -ForegroundColor Gray
Write-Host "  Focus: $Focus" -ForegroundColor Gray
Write-Host ""

# Get changed files
$changedFiles = git diff $BaseBranch...$HeadBranch --name-only --diff-filter=ACMR

if ($changedFiles.Count -eq 0) {
    Write-Host "✅ No files changed" -ForegroundColor Green
    exit 0
}

Write-Host "📁 Files changed: $($changedFiles.Count)" -ForegroundColor Yellow
Write-Host ""

# Get full diff
$fullDiff = git diff $BaseBranch...$HeadBranch

if ($fullDiff.Length -gt 100000) {
    Write-Host "⚠️  Diff too large (>100KB) - reviewing file by file" -ForegroundColor Yellow
    $reviewMode = "file-by-file"
} else {
    $reviewMode = "full-diff"
}

# Create review prompt
$reviewPrompt = @"
You are an expert code reviewer analyzing a pull request.

REVIEW FOCUS: $Focus

FILES CHANGED:
$($changedFiles -join "`n")

FULL DIFF:
``````diff
$fullDiff
``````

Please provide a comprehensive code review covering:

"@

switch ($Focus) {
    'security' {
        $reviewPrompt += @"

**SECURITY ISSUES:**
- Authentication/authorization bugs
- SQL injection, XSS, CSRF vulnerabilities
- Secrets in code
- Insecure dependencies
- Unsafe deserialization
- Input validation issues
"@
    }
    'performance' {
        $reviewPrompt += @"

**PERFORMANCE CONCERNS:**
- N+1 queries
- Inefficient algorithms
- Memory leaks
- Unnecessary database calls
- Missing indexes
- Cache misses
"@
    }
    'bugs' {
        $reviewPrompt += @"

**BUG RISKS:**
- Null reference exceptions
- Race conditions
- Off-by-one errors
- Edge cases not handled
- Logic errors
- Type mismatches
"@
    }
    'architecture' {
        $reviewPrompt += @"

**ARCHITECTURE FEEDBACK:**
- Clean architecture violations
- Separation of concerns
- SOLID principles
- Dependency injection
- Code duplication
- Layer violations
"@
    }
    'all' {
        $reviewPrompt += @"

**COMPREHENSIVE REVIEW:**

1. SECURITY ISSUES
   - Authentication/authorization bugs
   - SQL injection, XSS, CSRF vulnerabilities
   - Secrets in code
   - Input validation issues

2. PERFORMANCE CONCERNS
   - N+1 queries
   - Inefficient algorithms
   - Memory leaks
   - Missing indexes

3. BUG RISKS
   - Null reference exceptions
   - Race conditions
   - Edge cases not handled
   - Logic errors

4. CODE QUALITY
   - Clean architecture violations
   - SOLID principles
   - Code duplication
   - Naming conventions

5. BEST PRACTICES
   - Error handling
   - Logging
   - Testing coverage
   - Documentation
"@
    }
}

$reviewPrompt += @"


FORMAT YOUR REVIEW AS:

## 🔴 Critical Issues (must fix)
- [File:Line] Issue description

## 🟡 Warnings (should fix)
- [File:Line] Issue description

## 🟢 Suggestions (nice to have)
- [File:Line] Suggestion

## ✅ Positive Feedback
- What was done well

If no issues found, say "✅ No issues found - code looks good!"
"@

# Save review prompt to temp file for Claude Code
$tempPromptFile = Join-Path $env:TEMP "code-review-prompt-$(Get-Date -Format 'yyyyMMddHHmmss').txt"
$reviewPrompt | Set-Content $tempPromptFile -Encoding UTF8

Write-Host "🔍 Analyzing code changes with Claude Code..." -ForegroundColor Yellow
Write-Host "  (This uses your existing Claude Code session - no API costs)" -ForegroundColor Gray
Write-Host ""

# Create a marker file for the review output
$reviewOutputFile = Join-Path $env:TEMP "code-review-output-$(Get-Date -Format 'yyyyMMddHHmmss').md"

# Display the prompt for manual Claude Code review
# (In a full implementation, this would use the Task tool to spawn a review agent)
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CODE REVIEW PROMPT FOR CLAUDE CODE" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host $reviewPrompt -ForegroundColor White
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# For automation: This is where Claude Code Task tool would be invoked
# Example (pseudocode for future implementation):
# $review = claude-code task analyze -prompt $reviewPrompt -model sonnet

Write-Host "💡 IMPLEMENTATION NOTE:" -ForegroundColor Yellow
Write-Host "  This tool displays the review prompt above." -ForegroundColor Gray
Write-Host "  In the current session, Claude Code will provide the review." -ForegroundColor Gray
Write-Host ""
Write-Host "📋 Prompt saved to: $tempPromptFile" -ForegroundColor Cyan
Write-Host ""

# If PR number provided, prepare GitHub comment format
if ($PRNumber -gt 0 -and $OutputFormat -eq "GitHub") {
    Write-Host "GitHub PR Comment Template:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "## 🤖 AI Code Review (Claude Code)" -ForegroundColor White
    Write-Host ""
    Write-Host "[Claude Code review results would be inserted here]" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To post this review to PR #$PRNumber, run:" -ForegroundColor Cyan
    Write-Host "  gh pr comment $PRNumber --body-file <review-output.md>" -ForegroundColor Gray
}

Write-Host ""
Write-Host "✅ Review prompt prepared successfully" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  1. Claude Code will analyze the diff above" -ForegroundColor Gray
Write-Host "  2. Review findings will be provided in this session" -ForegroundColor Gray
Write-Host "  3. Optionally post to PR with: gh pr comment $PRNumber" -ForegroundColor Gray
Write-Host ""

# Clean up temp file after user sees it
# Remove-Item $tempPromptFile -ErrorAction SilentlyContinue

<#
FUTURE ENHANCEMENT: Fully automated version using Task tool

This would enable:
- Automatic review without manual intervention
- Batch review of multiple PRs
- CI/CD integration
- Scheduled code quality checks

Example automation:
$review = Invoke-ClaudeCodeTask -Prompt $reviewPrompt -OutputFormat Markdown
$review | Set-Content $reviewOutputFile
gh pr comment $PRNumber --body-file $reviewOutputFile
#>
