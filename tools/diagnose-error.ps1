<#
.SYNOPSIS
    AI-powered error diagnosis using reflection log patterns.

.DESCRIPTION
    Analyzes errors and searches reflection.log.md for similar past issues.
    Extracts historical solutions and adapts them to current context.

    Self-improving: Updates reflection log with new patterns if solution works.

.PARAMETER ErrorMessage
    Error message or stack trace to diagnose

.PARAMETER ErrorFile
    File containing error output (alternative to -ErrorMessage)

.PARAMETER Context
    Additional context (what you were doing when error occurred)

.PARAMETER AutoFix
    Suggest automated fix commands (experimental)

.EXAMPLE
    .\diagnose-error.ps1 -ErrorMessage "Cannot find module '@rollup/rollup-linux-x64-gnu'"
    .\diagnose-error.ps1 -ErrorFile "build-error.txt" -Context "Running npm build"
    .\diagnose-error.ps1 -ErrorMessage "NullReferenceException" -AutoFix
#>

param(
    [string]$ErrorMessage,
    [string]$ErrorFile,
    [string]$Context,
    [switch]$AutoFix
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$ReflectionLog = "C:\scripts\_machine\reflection.log.md"
$CICDTroubleshooting = "C:\scripts\ci-cd-troubleshooting.md"

function Get-ErrorSignature {
    param([string]$ErrorText)

    # Extract key patterns from error
    $signatures = @()

    # Common error patterns
    $patterns = @{
        "ModuleNotFound" = "Cannot find module|Module not found|ENOENT.*node_modules"
        "PackageSync" = "package-lock\.json.*out of sync|package\.json.*package-lock"
        "NullReference" = "NullReferenceException|null reference|Cannot read property.*undefined"
        "BuildFailure" = "Build failed|Compilation error|error CS\d+"
        "TestFailure" = "Test failed|Tests.*failed|\d+ failing"
        "CIFailure" = "CI.*failed|GitHub Actions.*failed|workflow.*failed"
        "RollupIssue" = "@rollup.*not found|rollup.*platform"
        "ESLintConfig" = "eslint\.config|ESLint.*couldn't find"
        "ViteError" = "vite.*error|Could not resolve entry"
        "TypeScriptError" = "error TS\d+|TypeScript.*error"
        "DependencyConflict" = "peer dependency|ERESOLVE|npm.*conflict"
    }

    foreach ($pattern in $patterns.Keys) {
        if ($ErrorText -match $patterns[$pattern]) {
            $signatures += $pattern
        }
    }

    # Extract specific identifiers
    if ($ErrorText -match "error (CS|TS)(\d+)") {
        $signatures += "ERROR_$($matches[1])$($matches[2])"
    }

    if ($ErrorText -match "Exception: ([A-Za-z]+Exception)") {
        $signatures += $matches[1]
    }

    return $signatures
}

function Search-ReflectionLog {
    param(
        [string[]]$Signatures,
        [string]$OriginalError
    )

    if (-not (Test-Path $ReflectionLog)) {
        Write-Host "WARNING: Reflection log not found: $ReflectionLog" -ForegroundColor Yellow
        return @()
    }

    $content = Get-Content $ReflectionLog -Raw
    $matches = @()

    # Search for each signature
    foreach ($signature in $Signatures) {
        # Find sections containing this signature
        $sectionMatches = [regex]::Matches($content, "(?s)^## \d{4}-\d{2}-\d{2}[^\n]*.*?(?=^## \d{4}|\z)")

        foreach ($match in $sectionMatches) {
            $section = $match.Value

            if ($section -match $signature -or $section -like "*$signature*") {
                # Extract date
                if ($section -match '^## (\d{4}-\d{2}-\d{2})') {
                    $date = $matches[1]
                } else {
                    $date = "Unknown"
                }

                # Extract title
                if ($section -match '^## \d{4}-\d{2}-\d{2}[^\n]*\[([^\]]+)\]') {
                    $title = $matches[1]
                } else {
                    $title = "Pattern"
                }

                # Extract solution section
                $solution = ""
                if ($section -match '(?s)### (Solution|Fix|Resolution|Outcome)[^\n]*\n(.*?)(?=^###|\z)') {
                    $solution = $matches[2].Trim()
                }

                # Calculate relevance score
                $score = 0
                foreach ($sig in $Signatures) {
                    $score += ([regex]::Matches($section, [regex]::Escape($sig), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count * 10
                }

                # Boost recent entries
                if ($date -match '^\d{4}-\d{2}-\d{2}$') {
                    try {
                        $entryDate = [DateTime]::ParseExact($date, "yyyy-MM-dd", $null)
                        $daysAgo = ((Get-Date) - $entryDate).Days
                        if ($daysAgo -lt 30) { $score += 20 }
                        elseif ($daysAgo -lt 90) { $score += 10 }
                    } catch { }
                }

                $matches += @{
                    "Date" = $date
                    "Title" = $title
                    "Section" = $section
                    "Solution" = $solution
                    "Score" = $score
                }
            }
        }
    }

    return $matches | Sort-Object -Property Score -Descending
}

function Search-CICDTroubleshooting {
    param([string[]]$Signatures)

    if (-not (Test-Path $CICDTroubleshooting)) {
        return @()
    }

    $content = Get-Content $CICDTroubleshooting -Raw
    $solutions = @()

    foreach ($signature in $Signatures) {
        # Find sections with this error type
        if ($content -match "(?s)### \d+\. $signature[^\n]*.*?(?=^###|\z)") {
            $solutionText = $matches[0]

            $solutions += @{
                "Source" = "CI/CD Troubleshooting Guide"
                "Pattern" = $signature
                "Solution" = $solutionText
            }
        }
    }

    return $solutions
}

function Show-Diagnosis {
    param(
        [string]$ErrorText,
        [string[]]$Signatures,
        [array]$ReflectionMatches,
        [array]$CICDMatches
    )

    Write-Host ""
    Write-Host "=== Error Diagnosis ===" -ForegroundColor Cyan
    Write-Host ""

    # Show error snippet
    $errorPreview = $ErrorText
    if ($errorPreview.Length -gt 300) {
        $errorPreview = $errorPreview.Substring(0, 297) + "..."
    }
    Write-Host "Error:" -ForegroundColor White
    Write-Host "  $errorPreview" -ForegroundColor Red
    Write-Host ""

    # Show signatures
    Write-Host "Detected Patterns: $($Signatures -join ', ')" -ForegroundColor Yellow
    Write-Host ""

    # Show CI/CD guide solutions first (more specific)
    if ($CICDMatches.Count -gt 0) {
        Write-Host "=== CI/CD Troubleshooting Guide ===" -ForegroundColor Green
        Write-Host ""

        foreach ($match in $CICDMatches) {
            Write-Host "Pattern: $($match.Pattern)" -ForegroundColor White
            Write-Host "$($match.Solution)" -ForegroundColor DarkGray
            Write-Host ""
        }
    }

    # Show reflection log matches
    if ($ReflectionMatches.Count -gt 0) {
        Write-Host "=== Similar Issues from Reflection Log ===" -ForegroundColor Green
        Write-Host ""

        $topMatches = $ReflectionMatches | Select-Object -First 5

        for ($i = 0; $i -lt $topMatches.Count; $i++) {
            $match = $topMatches[$i]

            Write-Host "$($i + 1). [$($match.Date)] $($match.Title)" -ForegroundColor White
            Write-Host "   Relevance Score: $($match.Score)" -ForegroundColor DarkGray
            Write-Host ""

            if ($match.Solution) {
                Write-Host "   Solution:" -ForegroundColor Cyan
                $solutionPreview = $match.Solution
                if ($solutionPreview.Length -gt 500) {
                    $solutionPreview = $solutionPreview.Substring(0, 497) + "..."
                }
                Write-Host "   $solutionPreview" -ForegroundColor White
                Write-Host ""
            }
        }

    } else {
        Write-Host "No similar issues found in reflection log." -ForegroundColor Yellow
        Write-Host "This may be a new pattern. After fixing, update reflection.log.md" -ForegroundColor Yellow
        Write-Host ""
    }

    # Auto-fix suggestions
    if ($AutoFix) {
        Write-Host "=== Suggested Fix Commands ===" -ForegroundColor Magenta
        Write-Host ""

        $suggestedCommands = Get-AutoFixCommands -Signatures $Signatures

        if ($suggestedCommands.Count -gt 0) {
            foreach ($cmd in $suggestedCommands) {
                Write-Host "  $cmd" -ForegroundColor Yellow
            }
            Write-Host ""
            Write-Host "Review these commands before executing!" -ForegroundColor Red
        } else {
            Write-Host "  No automated fix available for this error type." -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}

function Get-AutoFixCommands {
    param([string[]]$Signatures)

    $commands = @()

    foreach ($sig in $Signatures) {
        switch ($sig) {
            "PackageSync" {
                $commands += "npm install  # Regenerate package-lock.json"
                $commands += "git add package-lock.json"
            }
            "RollupIssue" {
                $commands += "rm -rf node_modules package-lock.json"
                $commands += "npm install"
            }
            "ESLintConfig" {
                $commands += "# Create eslint.config.js (ESLint v9 flat config)"
                $commands += "See: C:\scripts\ci-cd-troubleshooting.md § 3"
            }
            "ModuleNotFound" {
                $commands += "npm install  # Install missing dependencies"
            }
            "DependencyConflict" {
                $commands += "npm install --legacy-peer-deps"
            }
        }
    }

    return $commands | Select-Object -Unique
}

# Main execution
if (-not $ErrorMessage -and -not $ErrorFile) {
    Write-Host "ERROR: Either -ErrorMessage or -ErrorFile required" -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor White
    Write-Host "  .\diagnose-error.ps1 -ErrorMessage 'error message'" -ForegroundColor DarkGray
    Write-Host "  .\diagnose-error.ps1 -ErrorFile 'error.txt'" -ForegroundColor DarkGray
    Write-Host "  .\diagnose-error.ps1 -ErrorMessage 'error' -Context 'what you were doing' -AutoFix" -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}

# Load error text
$errorText = ""
if ($ErrorFile) {
    if (-not (Test-Path $ErrorFile)) {
        Write-Host "ERROR: File not found: $ErrorFile" -ForegroundColor Red
        exit 1
    }
    $errorText = Get-Content $ErrorFile -Raw
} else {
    $errorText = $ErrorMessage
}

if ($Context) {
    $errorText = "Context: $Context`n`n$errorText"
}

# Analyze error
$signatures = Get-ErrorSignature -ErrorText $errorText

if ($signatures.Count -eq 0) {
    Write-Host "WARNING: Could not identify error pattern" -ForegroundColor Yellow
    Write-Host "Using generic search..." -ForegroundColor DarkGray
    $signatures = @("error", "failed")
}

# Search for solutions
$reflectionMatches = Search-ReflectionLog -Signatures $signatures -OriginalError $errorText
$cicdMatches = Search-CICDTroubleshooting -Signatures $signatures

# Show diagnosis
Show-Diagnosis -ErrorText $errorText -Signatures $signatures -ReflectionMatches $reflectionMatches -CICDMatches $cicdMatches

# Suggest documentation update if no matches
if ($reflectionMatches.Count -eq 0 -and $cicdMatches.Count -eq 0) {
    Write-Host "=== Next Steps ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Fix the error manually" -ForegroundColor White
    Write-Host "2. Document the solution in reflection.log.md:" -ForegroundColor White
    Write-Host "   - Add entry with date and [PATTERN] tag" -ForegroundColor DarkGray
    Write-Host "   - Describe problem and solution" -ForegroundColor DarkGray
    Write-Host "   - Include error signature: $($signatures -join ', ')" -ForegroundColor DarkGray
    Write-Host "3. Future sessions will find this solution automatically" -ForegroundColor White
    Write-Host ""
}

Write-Host "=== Diagnosis Complete ===" -ForegroundColor Cyan
Write-Host ""
