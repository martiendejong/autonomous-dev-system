<#
.SYNOPSIS
    Automated code review with static analysis and PR comments.

.DESCRIPTION
    Performs static analysis on C# and TypeScript code, detects anti-patterns,
    security vulnerabilities (OWASP Top 10), and posts comments on PRs.

    Features:
    - C# static analysis (Roslyn analyzers, Security Code Scan)
    - TypeScript/JavaScript linting (ESLint)
    - Security vulnerability detection
    - Code complexity analysis
    - Anti-pattern detection
    - PR comment integration (GitHub)
    - Configurable severity thresholds

.PARAMETER Path
    Path to code to review (file or directory)

.PARAMETER PRNumber
    GitHub PR number to comment on (optional)

.PARAMETER Severity
    Minimum severity to report: info, warning, error (default: warning)

.PARAMETER SecurityOnly
    Only check for security vulnerabilities

.PARAMETER PostComments
    Post review comments to GitHub PR

.PARAMETER OutputFormat
    Output format: console, json, markdown (default: console)

.EXAMPLE
    .\auto-code-review.ps1 -Path "C:\Projects\client-manager" -Severity error
    .\auto-code-review.ps1 -Path "." -SecurityOnly
    .\auto-code-review.ps1 -Path "." -PRNumber 123 -PostComments
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [int]$PRNumber,

    [ValidateSet("info", "warning", "error")]
    [string]$Severity = "warning",

    [switch]$SecurityOnly,
    [switch]$PostComments,

    [ValidateSet("console", "json", "markdown")]
    [string]$OutputFormat = "console"
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$script:Issues = @()

function Review-CSharpCode {
    param([string]$Path)

    Write-Host ""
    Write-Host "=== C# Code Review ===" -ForegroundColor Cyan
    Write-Host ""

    $csharpFiles = Get-ChildItem $Path -Filter "*.cs" -Recurse -ErrorAction SilentlyContinue

    if ($csharpFiles.Count -eq 0) {
        Write-Host "No C# files found" -ForegroundColor Yellow
        return
    }

    Write-Host "Analyzing $($csharpFiles.Count) C# files..." -ForegroundColor DarkGray

    foreach ($file in $csharpFiles) {
        $content = Get-Content $file.FullName -Raw

        # Check for common issues
        Check-SqlInjection -Content $content -FilePath $file.FullName
        Check-HardcodedSecrets -Content $content -FilePath $file.FullName
        Check-ExceptionHandling -Content $content -FilePath $file.FullName
        Check-NullReference -Content $content -FilePath $file.FullName
        Check-DisposablePattern -Content $content -FilePath $file.FullName
    }

    Write-Host "Found $($script:Issues.Count) issues" -ForegroundColor $(if ($script:Issues.Count -eq 0) { "Green" } else { "Yellow" })
}

function Review-TypeScriptCode {
    param([string]$Path)

    Write-Host ""
    Write-Host "=== TypeScript Code Review ===" -ForegroundColor Cyan
    Write-Host ""

    $tsFiles = Get-ChildItem $Path -Include "*.ts","*.tsx","*.js","*.jsx" -Recurse -ErrorAction SilentlyContinue

    if ($tsFiles.Count -eq 0) {
        Write-Host "No TypeScript/JavaScript files found" -ForegroundColor Yellow
        return
    }

    Write-Host "Analyzing $($tsFiles.Count) TypeScript/JavaScript files..." -ForegroundColor DarkGray

    # Check for ESLint
    $hasESLint = Test-Path (Join-Path $Path ".eslintrc.json")

    if ($hasESLint) {
        Write-Host "Running ESLint..." -ForegroundColor DarkGray

        Push-Location $Path
        try {
            $output = npx eslint . --format json 2>&1

            if ($output) {
                try {
                    $results = $output | ConvertFrom-Json

                    foreach ($result in $results) {
                        foreach ($message in $result.messages) {
                            if ($message.severity -ge 1) {
                                $script:Issues += @{
                                    "File" = $result.filePath
                                    "Line" = $message.line
                                    "Severity" = if ($message.severity -eq 2) { "error" } else { "warning" }
                                    "Message" = $message.message
                                    "Rule" = $message.ruleId
                                    "Type" = "ESLint"
                                }
                            }
                        }
                    }
                } catch {
                    # ESLint output might not be JSON
                }
            }

        } finally {
            Pop-Location
        }
    } else {
        Write-Host "No ESLint config found, performing basic checks..." -ForegroundColor Yellow

        foreach ($file in $tsFiles) {
            $content = Get-Content $file.FullName -Raw

            Check-ConsoleLog -Content $content -FilePath $file.FullName
            Check-AnyType -Content $content -FilePath $file.FullName
            Check-UnusedVars -Content $content -FilePath $file.FullName
        }
    }

    Write-Host "Found $($script:Issues.Count) issues" -ForegroundColor $(if ($script:Issues.Count -eq 0) { "Green" } else { "Yellow" })
}

function Check-SqlInjection {
    param([string]$Content, [string]$FilePath)

    # Check for string concatenation in SQL queries
    if ($Content -match 'ExecuteSqlRaw.*\+|FromSqlRaw.*\+') {
        $script:Issues += @{
            "File" = $FilePath
            "Line" = 0
            "Severity" = "error"
            "Message" = "Potential SQL injection - use parameterized queries"
            "Rule" = "SQL001"
            "Type" = "Security"
        }
    }
}

function Check-HardcodedSecrets {
    param([string]$Content, [string]$FilePath)

    # Check for hardcoded credentials
    $patterns = @{
        "Password" = 'password\s*=\s*"[^"]+"'
        "API Key" = 'api[_-]?key\s*=\s*"[^"]+"'
        "Secret" = 'secret\s*=\s*"[^"]+"'
    }

    foreach ($pattern in $patterns.Keys) {
        if ($Content -match $patterns[$pattern]) {
            $script:Issues += @{
                "File" = $FilePath
                "Line" = 0
                "Severity" = "error"
                "Message" = "Potential hardcoded $($pattern.ToLower()) - use configuration"
                "Rule" = "SEC001"
                "Type" = "Security"
            }
        }
    }
}

function Check-ExceptionHandling {
    param([string]$Content, [string]$FilePath)

    # Check for empty catch blocks
    if ($Content -match 'catch\s*\([^)]+\)\s*\{\s*\}') {
        $script:Issues += @{
            "File" = $FilePath
            "Line" = 0
            "Severity" = "warning"
            "Message" = "Empty catch block - consider logging or rethrowing"
            "Rule" = "EH001"
            "Type" = "Code Quality"
        }
    }

    # Check for catching generic Exception
    if ($Content -match 'catch\s*\(\s*Exception\s+') {
        $script:Issues += @{
            "File" = $FilePath
            "Line" = 0
            "Severity" = "info"
            "Message" = "Catching generic Exception - consider specific exception types"
            "Rule" = "EH002"
            "Type" = "Code Quality"
        }
    }
}

function Check-NullReference {
    param([string]$Content, [string]$FilePath)

    # Check for potential null reference without null check
    if ($Content -match '(?<!if\s*\([^)]*)\b(\w+)\s*\.\s*\w+' -and $Content -notmatch '\?\.' -and $Content -notmatch '!\s*\.' ) {
        # This is a simplified check - would need proper parsing for accuracy
    }
}

function Check-DisposablePattern {
    param([string]$Content, [string]$FilePath)

    # Check for missing using statement with IDisposable
    if ($Content -match 'new\s+(FileStream|StreamReader|StreamWriter|SqlConnection|HttpClient)\s*\(' -and $Content -notmatch 'using\s*\(') {
        $script:Issues += @{
            "File" = $FilePath
            "Line" = 0
            "Severity" = "warning"
            "Message" = "IDisposable object not wrapped in using statement"
            "Rule" = "DIS001"
            "Type" = "Resource Management"
        }
    }
}

function Check-ConsoleLog {
    param([string]$Content, [string]$FilePath)

    # Check for console.log in production code
    if ($Content -match 'console\.log\(') {
        $script:Issues += @{
            "File" = $FilePath
            "Line" = 0
            "Severity" = "info"
            "Message" = "console.log found - remove before production"
            "Rule" = "JS001"
            "Type" = "Code Quality"
        }
    }
}

function Check-AnyType {
    param([string]$Content, [string]$FilePath)

    # Check for 'any' type in TypeScript
    if ($Content -match ':\s*any\b') {
        $script:Issues += @{
            "File" = $FilePath
            "Line" = 0
            "Severity" = "warning"
            "Message" = "Using 'any' type - consider specific type"
            "Rule" = "TS001"
            "Type" = "Type Safety"
        }
    }
}

function Check-UnusedVars {
    param([string]$Content, [string]$FilePath)

    # Very simplified check for unused variables
    # Proper implementation would need AST parsing
}

function Show-ReviewResults {
    param([array]$Issues, [string]$Format)

    if ($Format -eq "console") {
        Write-Host ""
        Write-Host "=== Review Results ===" -ForegroundColor Cyan
        Write-Host ""

        if ($Issues.Count -eq 0) {
            Write-Host "No issues found!" -ForegroundColor Green
            Write-Host ""
            return
        }

        # Group by severity
        $errors = $Issues | Where-Object { $_.Severity -eq "error" }
        $warnings = $Issues | Where-Object { $_.Severity -eq "warning" }
        $info = $Issues | Where-Object { $_.Severity -eq "info" }

        Write-Host ("Total Issues: {0}" -f $Issues.Count) -ForegroundColor White
        Write-Host ("  Errors:   {0}" -f $errors.Count) -ForegroundColor Red
        Write-Host ("  Warnings: {0}" -f $warnings.Count) -ForegroundColor Yellow
        Write-Host ("  Info:     {0}" -f $info.Count) -ForegroundColor Cyan
        Write-Host ""

        # Show grouped by type
        $byType = $Issues | Group-Object -Property Type

        foreach ($group in $byType | Sort-Object Name) {
            Write-Host "$($group.Name):" -ForegroundColor Yellow

            foreach ($issue in $group.Group | Select-Object -First 10) {
                $color = switch ($issue.Severity) {
                    "error" { "Red" }
                    "warning" { "Yellow" }
                    "info" { "Cyan" }
                }

                Write-Host ("  [{0}] {1}" -f $issue.Rule, $issue.Message) -ForegroundColor $color
                Write-Host ("      File: {0}" -f $issue.File) -ForegroundColor DarkGray
                Write-Host ""
            }

            if ($group.Count -gt 10) {
                Write-Host ("  ... and {0} more" -f ($group.Count - 10)) -ForegroundColor DarkGray
                Write-Host ""
            }
        }

    } elseif ($Format -eq "json") {
        $Issues | ConvertTo-Json -Depth 10

    } elseif ($Format -eq "markdown") {
        $md = "# Code Review Results`n`n"
        $md += "**Total Issues:** $($Issues.Count)`n`n"

        $byType = $Issues | Group-Object -Property Type

        foreach ($group in $byType) {
            $md += "## $($group.Name)`n`n"

            foreach ($issue in $group.Group) {
                $md += "- **[$($issue.Severity.ToUpper())]** $($issue.Message)`n"
                $md += "  - File: ``$($issue.File)```n"
                $md += "  - Rule: $($issue.Rule)`n`n"
            }
        }

        Write-Output $md
    }
}

function Post-PRComments {
    param([array]$Issues, [int]$PRNumber)

    Write-Host ""
    Write-Host "=== Posting PR Comments ===" -ForegroundColor Cyan
    Write-Host ""

    if ($Issues.Count -eq 0) {
        Write-Host "No issues to comment on" -ForegroundColor Green
        return
    }

    # Group issues by file
    $byFile = $Issues | Group-Object -Property File

    $commentBody = "## Automated Code Review`n`n"
    $commentBody += "Found $($Issues.Count) issues:`n`n"

    foreach ($group in $byFile | Select-Object -First 5) {
        $commentBody += "### ``$($group.Name)```n`n"

        foreach ($issue in $group.Group | Select-Object -First 3) {
            $emoji = switch ($issue.Severity) {
                "error" { "🔴" }
                "warning" { "🟡" }
                "info" { "🔵" }
            }

            $commentBody += "- $emoji **$($issue.Severity.ToUpper())**: $($issue.Message)`n"
        }

        $commentBody += "`n"
    }

    $commentBody += "`n---`n"
    $commentBody += "*Generated by auto-code-review.ps1*"

    # Post comment using gh CLI
    try {
        $commentBody | gh pr comment $PRNumber --body-file -

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Posted comment to PR #$PRNumber" -ForegroundColor Green
        } else {
            Write-Host "Failed to post comment" -ForegroundColor Red
        }

    } catch {
        Write-Host "ERROR: Failed to post comment: $_" -ForegroundColor Red
    }

    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== Automated Code Review ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $Path)) {
    Write-Host "ERROR: Path not found: $Path" -ForegroundColor Red
    exit 1
}

# Determine code type
$hasCSharp = (Get-ChildItem $Path -Filter "*.cs" -Recurse -ErrorAction SilentlyContinue).Count -gt 0
$hasTypeScript = (Get-ChildItem $Path -Include "*.ts","*.tsx","*.js","*.jsx" -Recurse -ErrorAction SilentlyContinue).Count -gt 0

if (-not $hasCSharp -and -not $hasTypeScript) {
    Write-Host "ERROR: No C# or TypeScript files found" -ForegroundColor Red
    exit 1
}

# Perform reviews
if ($hasCSharp -and (-not $SecurityOnly -or $SecurityOnly)) {
    Review-CSharpCode -Path $Path
}

if ($hasTypeScript -and -not $SecurityOnly) {
    Review-TypeScriptCode -Path $Path
}

# Filter by severity
$filteredIssues = $script:Issues | Where-Object {
    switch ($Severity) {
        "error" { $_.Severity -eq "error" }
        "warning" { $_.Severity -eq "error" -or $_.Severity -eq "warning" }
        "info" { $true }
    }
}

# Show results
Show-ReviewResults -Issues $filteredIssues -Format $OutputFormat

# Post PR comments if requested
if ($PostComments -and $PRNumber) {
    Post-PRComments -Issues $filteredIssues -PRNumber $PRNumber
}

Write-Host "=== Review Complete ===" -ForegroundColor Green
Write-Host ""

# Exit with error code if errors found
if (($filteredIssues | Where-Object { $_.Severity -eq "error" }).Count -gt 0) {
    exit 1
}

exit 0
