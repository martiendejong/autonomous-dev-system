<#
.SYNOPSIS
    Sets up Git commit message templates with conventional commits format.

.DESCRIPTION
    Installs standardized commit message templates to ensure consistent formatting.
    Supports conventional commits (feat, fix, docs, etc.), issue linking, and co-authors.

    Features:
    - Interactive commit message builder
    - Conventional commit type selection
    - Automatic scope detection from changed files
    - Issue/PR linking
    - Co-author attribution (includes Claude by default)
    - Breaking change markers
    - Template validation

.PARAMETER Install
    Install commit template globally for all repositories

.PARAMETER Repo
    Install commit template for specific repository

.PARAMETER Interactive
    Launch interactive commit message builder

.PARAMETER Type
    Commit type (feat, fix, docs, style, refactor, perf, test, build, ci, chore)

.PARAMETER Scope
    Commit scope (optional, e.g., api, frontend, db)

.PARAMETER Message
    Short commit message (required)

.PARAMETER Body
    Detailed commit body (optional)

.PARAMETER Breaking
    Mark as breaking change

.PARAMETER IssueRef
    Issue or PR reference (e.g., #123)

.EXAMPLE
    .\setup-commit-template.ps1 -Install
    .\setup-commit-template.ps1 -Repo "C:\Projects\client-manager" -Install
    .\setup-commit-template.ps1 -Interactive
    .\setup-commit-template.ps1 -Type feat -Scope api -Message "Add user authentication" -IssueRef "#123"
#>

param(
    [switch]$Install,
    [string]$Repo,
    [switch]$Interactive,

    [ValidateSet("feat", "fix", "docs", "style", "refactor", "perf", "test", "build", "ci", "chore")

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
]
    [string]$Type,

    [string]$Scope,
    [string]$Message,
    [string]$Body,
    [switch]$Breaking,
    [string]$IssueRef
)

$CommitTypes = @{
    "feat" = "A new feature"
    "fix" = "A bug fix"
    "docs" = "Documentation only changes"
    "style" = "Changes that do not affect the meaning of the code (formatting, missing semi-colons, etc.)"
    "refactor" = "A code change that neither fixes a bug nor adds a feature"
    "perf" = "A code change that improves performance"
    "test" = "Adding missing tests or correcting existing tests"
    "build" = "Changes that affect the build system or external dependencies"
    "ci" = "Changes to CI configuration files and scripts"
    "chore" = "Other changes that don't modify src or test files"
}

$TemplateContent = @'
# <type>(<scope>): <subject>
#
# <body>
#
# <footer>
#
# Type should be one of:
#   feat:     A new feature
#   fix:      A bug fix
#   docs:     Documentation only changes
#   style:    Changes that do not affect the meaning of the code
#   refactor: A code change that neither fixes a bug nor adds a feature
#   perf:     A code change that improves performance
#   test:     Adding missing tests or correcting existing tests
#   build:    Changes that affect the build system or external dependencies
#   ci:       Changes to CI configuration files and scripts
#   chore:    Other changes that don't modify src or test files
#
# Scope is optional and represents the module/component affected
#
# Subject should be 50 chars or less, lowercase, no period at end
#
# Body should explain what and why (not how), wrap at 72 chars
#
# Footer should contain:
#   - Issue/PR references (e.g., Closes #123, Fixes #456)
#   - BREAKING CHANGE: description (if applicable)
#   - Co-Authored-By: Name <email>
#
# Example:
#   feat(api): add user authentication
#
#   Implement JWT-based authentication for API endpoints.
#   Users can now register and login with email/password.
#
#   Closes #123
#   Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
'@

function Install-CommitTemplate {
    param([string]$RepoPath)

    $templatePath = if ($RepoPath) {
        Join-Path $RepoPath ".git/commit-template.txt"
    } else {
        Join-Path $env:USERPROFILE ".gitmessage"
    }

    # Create template file
    $TemplateContent | Set-Content $templatePath -Encoding UTF8

    # Configure git
    if ($RepoPath) {
        Push-Location $RepoPath
        try {
            git config commit.template ".git/commit-template.txt"
            Write-Host "Commit template installed for repository: $RepoPath" -ForegroundColor Green
        } finally {
            Pop-Location
        }
    } else {
        git config --global commit.template $templatePath
        Write-Host "Commit template installed globally: $templatePath" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Template installed! Use 'git commit' (without -m) to see the template." -ForegroundColor Cyan
    Write-Host ""
}

function Get-AutoScope {
    param([string]$RepoPath)

    if (-not $RepoPath) {
        $RepoPath = Get-Location
    }

    Push-Location $RepoPath
    try {
        # Get changed files
        $changedFiles = git diff --cached --name-only 2>$null

        if (-not $changedFiles) {
            return $null
        }

        # Detect scope from file paths
        foreach ($file in $changedFiles) {
            # Frontend files
            if ($file -match 'ClientManagerFrontend|frontend|client|ui') {
                return "frontend"
            }
            # API files
            if ($file -match 'Api|Controllers|Services|Backend') {
                return "api"
            }
            # Database files
            if ($file -match 'Migrations|DbContext|Models|Entities') {
                return "db"
            }
            # Documentation
            if ($file -match '\.md$|docs/') {
                return "docs"
            }
            # CI/CD
            if ($file -match '\.github|\.yml$|\.yaml$') {
                return "ci"
            }
            # Tests
            if ($file -match 'Test|Spec') {
                return "test"
            }
        }

        return $null

    } finally {
        Pop-Location
    }
}

function Show-InteractiveBuilder {
    Write-Host ""
    Write-Host "=== Interactive Commit Message Builder ===" -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Select type
    Write-Host "1. Select commit type:" -ForegroundColor Yellow
    Write-Host ""

    $i = 1
    $typeList = @()
    foreach ($type in $CommitTypes.Keys | Sort-Object) {
        $typeList += $type
        Write-Host ("  {0}. {1,-10} - {2}" -f $i, $type, $CommitTypes[$type]) -ForegroundColor White
        $i++
    }

    Write-Host ""
    $typeChoice = Read-Host "Select type (1-$($CommitTypes.Count))"
    $selectedType = $typeList[[int]$typeChoice - 1]

    # Step 2: Scope (with auto-detection)
    Write-Host ""
    Write-Host "2. Enter scope (optional):" -ForegroundColor Yellow

    $autoScope = Get-AutoScope
    if ($autoScope) {
        Write-Host "  Suggested scope: $autoScope" -ForegroundColor DarkGray
    }

    $scopeInput = Read-Host "  Scope"
    $selectedScope = if ($scopeInput) { $scopeInput } elseif ($autoScope) { $autoScope } else { "" }

    # Step 3: Subject
    Write-Host ""
    Write-Host "3. Enter subject (50 chars max, lowercase, no period):" -ForegroundColor Yellow
    $subject = Read-Host "  Subject"

    # Validate subject
    if ($subject.Length -gt 50) {
        Write-Host "  WARNING: Subject is too long ($($subject.Length) chars)" -ForegroundColor Yellow
        $subject = $subject.Substring(0, 50)
    }

    # Step 4: Body (optional)
    Write-Host ""
    Write-Host "4. Enter body (optional, press Enter to skip):" -ForegroundColor Yellow
    Write-Host "  (Explain what and why, not how. Wrap at 72 chars)" -ForegroundColor DarkGray
    $bodyInput = Read-Host "  Body"

    # Step 5: Breaking change
    Write-Host ""
    Write-Host "5. Is this a breaking change? (y/n):" -ForegroundColor Yellow
    $isBreaking = (Read-Host "  Breaking") -eq "y"

    # Step 6: Issue reference
    Write-Host ""
    Write-Host "6. Issue/PR reference (optional, e.g., #123):" -ForegroundColor Yellow
    $issueRef = Read-Host "  Issue"

    # Build commit message
    $commitMsg = Build-CommitMessage -Type $selectedType -Scope $selectedScope -Subject $subject -Body $bodyInput -Breaking:$isBreaking -IssueRef $issueRef

    # Preview
    Write-Host ""
    Write-Host "=== Commit Message Preview ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host $commitMsg -ForegroundColor White
    Write-Host ""

    # Confirm
    $confirm = Read-Host "Create commit with this message? (y/n)"

    if ($confirm -eq "y") {
        # Write to temp file and commit
        $tempFile = [System.IO.Path]::GetTempFileName()
        $commitMsg | Set-Content $tempFile -Encoding UTF8

        git commit -F $tempFile

        Remove-Item $tempFile

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "Commit created successfully!" -ForegroundColor Green
            Write-Host ""
        } else {
            Write-Host ""
            Write-Host "Commit failed!" -ForegroundColor Red
            Write-Host ""
        }
    } else {
        Write-Host "Commit cancelled" -ForegroundColor Yellow
    }
}

function Build-CommitMessage {
    param(
        [string]$Type,
        [string]$Scope,
        [string]$Subject,
        [string]$Body,
        [switch]$Breaking,
        [string]$IssueRef
    )

    # Build subject line
    $subjectLine = if ($Scope) {
        "$Type($Scope): $Subject"
    } else {
        "$Type: $Subject"
    }

    # Build body
    $bodySection = if ($Body) {
        "`n`n$Body"
    } else {
        ""
    }

    # Build footer
    $footerParts = @()

    if ($Breaking) {
        $footerParts += "BREAKING CHANGE: Breaking changes introduced"
    }

    if ($IssueRef) {
        $footerParts += "Closes $IssueRef"
    }

    # Always include Claude co-author
    $footerParts += "Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

    $footer = if ($footerParts.Count -gt 0) {
        "`n`n" + ($footerParts -join "`n")
    } else {
        ""
    }

    return "$subjectLine$bodySection$footer"
}

function Show-Examples {
    Write-Host ""
    Write-Host "=== Commit Message Examples ===" -ForegroundColor Cyan
    Write-Host ""

    $examples = @(
        @{
            Title = "Feature with scope"
            Message = @"
feat(api): add user authentication

Implement JWT-based authentication for API endpoints.
Users can now register and login with email/password.

Closes #123
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
"@
        }
        @{
            Title = "Bug fix"
            Message = @"
fix(frontend): resolve login form validation

Fix issue where email validation was not working correctly.
Now properly validates email format before submission.

Fixes #456
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
"@
        }
        @{
            Title = "Breaking change"
            Message = @"
refactor(api): change authentication endpoint structure

Restructure authentication endpoints for better REST compliance.
All auth routes now under /api/v2/auth instead of /api/auth.

BREAKING CHANGE: Authentication endpoint URLs have changed
Closes #789
Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
"@
        }
    )

    foreach ($example in $examples) {
        Write-Host $example.Title -ForegroundColor Yellow
        Write-Host ""
        Write-Host $example.Message -ForegroundColor DarkGray
        Write-Host ""
        Write-Host ("─" * 60) -ForegroundColor DarkGray
        Write-Host ""
    }
}

# Main execution
if ($Install) {
    Write-Host ""
    Write-Host "=== Git Commit Template Setup ===" -ForegroundColor Cyan
    Write-Host ""

    if ($Repo) {
        if (-not (Test-Path $Repo)) {
            Write-Host "ERROR: Repository not found: $Repo" -ForegroundColor Red
            exit 1
        }

        Install-CommitTemplate -RepoPath $Repo
    } else {
        Install-CommitTemplate
    }

    Show-Examples

} elseif ($Interactive) {
    Show-InteractiveBuilder

} elseif ($Type -and $Message) {
    # Direct commit message generation
    $commitMsg = Build-CommitMessage -Type $Type -Scope $Scope -Subject $Message -Body $Body -Breaking:$Breaking -IssueRef $IssueRef

    Write-Host ""
    Write-Host "=== Generated Commit Message ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host $commitMsg -ForegroundColor White
    Write-Host ""
    Write-Host "Copy this message or use: git commit -m `"<message>`"" -ForegroundColor Cyan
    Write-Host ""

} else {
    Write-Host ""
    Write-Host "=== Git Commit Template ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  Install globally:        .\setup-commit-template.ps1 -Install" -ForegroundColor White
    Write-Host "  Install for repo:        .\setup-commit-template.ps1 -Repo <path> -Install" -ForegroundColor White
    Write-Host "  Interactive builder:     .\setup-commit-template.ps1 -Interactive" -ForegroundColor White
    Write-Host "  Generate message:        .\setup-commit-template.ps1 -Type feat -Message `"...`"" -ForegroundColor White
    Write-Host ""
    Write-Host "Commit types: feat, fix, docs, style, refactor, perf, test, build, ci, chore" -ForegroundColor DarkGray
    Write-Host ""

    Show-Examples
}

exit 0
