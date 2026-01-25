<#
.SYNOPSIS
    Pre-commit hook for zero-tolerance rule enforcement.

.DESCRIPTION
    This script is designed to be run as a git pre-commit hook.
    It checks for violations of zero-tolerance rules before allowing commits.

    Checks performed:
    - Edits in C:\Projects\<repo> during Feature Development Mode
    - Uncommitted worktree changes
    - Pool/worktree inconsistencies
    - Secret scanning (API keys, passwords, tokens, private keys)

.PARAMETER Install
    Install this hook to a repository

.PARAMETER Check
    Run checks without being in a hook context

.EXAMPLE
    .\pre-commit-hook.ps1 -Install -RepoPath "C:\Projects\client-manager"
    .\pre-commit-hook.ps1 -Check
#>

param(
    [switch]$Install,
    [string]$RepoPath,
    [switch]$Check
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$PoolPath = "C:\scripts\_machine\worktrees.pool.md"
$BaseRepos = @(
    "C:\Projects\client-manager",
    "C:\Projects\hazina"
)

function Test-IsBaseRepo {
    param([string]$Path)
    return $BaseRepos -contains $Path
}

function Test-HasBusyWorktrees {
    if (-not (Test-Path $PoolPath)) { return $false }

    $content = Get-Content $PoolPath -Raw
    return $content -match '\| BUSY \|'
}

function Get-CurrentRepoPath {
    $gitDir = git rev-parse --git-dir 2>$null
    if ($gitDir) {
        return (Resolve-Path (Join-Path $gitDir "..")).Path.TrimEnd('\')
    }
    return $null
}

function Write-Violation {
    param([string]$Message)
    Write-Host ""
    Write-Host "=== ZERO-TOLERANCE VIOLATION ===" -ForegroundColor Red
    Write-Host $Message -ForegroundColor Red
    Write-Host ""
    Write-Host "This commit has been blocked." -ForegroundColor Yellow
    Write-Host "See: C:\scripts\ZERO_TOLERANCE_RULES.md" -ForegroundColor Yellow
    Write-Host ""
}

function Test-ForSecrets {
    <#
    .SYNOPSIS
        Scans staged files for secrets (API keys, passwords, tokens)
    #>

    # Secret patterns (regex)
    $secretPatterns = @{
        "Generic Password" = 'password\s*[=:]\s*["\']?[^"\'\s]{8,}'
        "API Key" = 'api[_-]?key\s*[=:]\s*["\']?[A-Za-z0-9]{20,}'
        "GitHub Token" = '(gh|github)[_-]?token\s*[=:]\s*["\']?[A-Za-z0-9_]+'
        "OAuth Token" = 'Bearer\s+[A-Za-z0-9\-._~+/]+=*'
        "Private Key" = '-----BEGIN (RSA|OPENSSH|PRIVATE) KEY-----'
        "AWS Access Key" = 'AKIA[0-9A-Z]{16}'
        "Generic Secret" = 'secret\s*[=:]\s*["\']?[^"\'\s]{12,}'
        "Connection String" = 'Server=.*;Password=[^;]+;'
        "JWT Token" = 'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.'
    }

    # Files to always exclude
    $excludePatterns = @(
        '\.md$',          # Markdown (documentation)
        '\.txt$',         # Text files
        'package-lock\.json$',  # Package lock files
        '\.min\.js$',     # Minified files
        '\.map$',         # Source maps
        'test.*\.cs$',    # Test files
        'Test.*\.cs$'     # Test files
    )

    # Get staged files
    $stagedFiles = git diff --cached --name-only --diff-filter=ACM 2>$null

    if (-not $stagedFiles) {
        return @()  # No staged files
    }

    $foundSecrets = @()

    foreach ($file in $stagedFiles) {
        # Skip excluded files
        $shouldSkip = $false
        foreach ($pattern in $excludePatterns) {
            if ($file -match $pattern) {
                $shouldSkip = $true
                break
            }
        }
        if ($shouldSkip) { continue }

        # Get file content from staging area
        $content = git show ":$file" 2>$null
        if (-not $content) { continue }

        # Check each pattern
        foreach ($patternName in $secretPatterns.Keys) {
            $pattern = $secretPatterns[$patternName]

            $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

            if ($matches.Count -gt 0) {
                foreach ($match in $matches) {
                    # Get line number
                    $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count

                    # Get context (the line containing the secret)
                    $lines = $content -split "`n"
                    $contextLine = if ($lineNumber -le $lines.Count) { $lines[$lineNumber - 1] } else { "" }

                    # Redact the secret value for display
                    $redacted = $contextLine -replace '([=:]\s*["\']?)[^"\'\s]{4,}', '$1***REDACTED***'

                    $foundSecrets += @{
                        "File" = $file
                        "Line" = $lineNumber
                        "Type" = $patternName
                        "Context" = $redacted
                    }
                }
            }
        }
    }

    return $foundSecrets
}

function Invoke-PreCommitChecks {
    $violations = @()
    $warnings = @()

    # Get current repo path
    $currentRepo = Get-CurrentRepoPath

    # Check 1: Are we committing in a base repo while worktrees are BUSY?
    if ($currentRepo -and (Test-IsBaseRepo -Path $currentRepo)) {
        if (Test-HasBusyWorktrees) {
            # This might be Feature Development Mode - check if this is a violation
            $repoName = Split-Path $currentRepo -Leaf
            $poolContent = Get-Content $PoolPath -Raw

            # Check if any worktree is working on this repo
            if ($poolContent -match "\| BUSY \|.*\| $repoName \|") {
                $violations += "Committing in base repo ($repoName) while a worktree is BUSY for this repo."
                $violations += "In Feature Development Mode, commits should be in worktrees, not base repos."
            } else {
                $warnings += "Committing in base repo while worktrees are BUSY. Verify you're in Active Debugging Mode."
            }
        }
    }

    # Check 2: Is this a worktree commit without the seat being marked BUSY?
    if ($currentRepo -and $currentRepo -match "worker-agents\\(agent-\d+)\\") {
        $seat = $matches[1]
        $poolContent = Get-Content $PoolPath -Raw

        if ($poolContent -notmatch "\| $seat .* \| BUSY \|") {
            $warnings += "Committing in $seat worktree but seat is not marked BUSY in pool.md"
        }
    }

    # Check 3: Secret scanning
    $secrets = Test-ForSecrets
    if ($secrets.Count -gt 0) {
        Write-Host ""
        Write-Host "=== SECRET DETECTED ===" -ForegroundColor Red
        Write-Host ""
        Write-Host "Found $($secrets.Count) potential secret(s) in staged files:" -ForegroundColor Red
        Write-Host ""

        foreach ($secret in $secrets) {
            Write-Host "  File: $($secret.File):$($secret.Line)" -ForegroundColor Yellow
            Write-Host "  Type: $($secret.Type)" -ForegroundColor Yellow
            Write-Host "  Context: $($secret.Context)" -ForegroundColor DarkGray
            Write-Host ""
        }

        Write-Host "CRITICAL: Secrets should NEVER be committed to git!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Actions:" -ForegroundColor Cyan
        Write-Host "  1. Remove the secret from the file" -ForegroundColor White
        Write-Host "  2. Store in environment variables or Azure KeyVault" -ForegroundColor White
        Write-Host "  3. Add to .gitignore if file should not be tracked" -ForegroundColor White
        Write-Host "  4. If this is a false positive, add to excludePatterns in pre-commit-hook.ps1" -ForegroundColor White
        Write-Host ""

        $violations += "SECRET SCANNING: Found $($secrets.Count) potential secret(s) in commit"
    }

    # Output results
    if ($violations.Count -gt 0) {
        foreach ($v in $violations) {
            Write-Violation $v
        }
        return $false
    }

    if ($warnings.Count -gt 0) {
        Write-Host ""
        Write-Host "=== PRE-COMMIT WARNINGS ===" -ForegroundColor Yellow
        foreach ($w in $warnings) {
            Write-Host "  - $w" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "Commit allowed, but please verify this is intentional." -ForegroundColor Yellow
        Write-Host ""
    }

    return $true
}

function Install-Hook {
    param([string]$TargetRepo)

    if (-not (Test-Path $TargetRepo)) {
        Write-Host "ERROR: Repository not found at $TargetRepo" -ForegroundColor Red
        return
    }

    $hooksDir = Join-Path $TargetRepo ".git\hooks"
    if (-not (Test-Path $hooksDir)) {
        Write-Host "ERROR: Not a git repository or hooks dir missing" -ForegroundColor Red
        return
    }

    $hookPath = Join-Path $hooksDir "pre-commit"
    $hookContent = @"
#!/bin/sh
# Pre-commit hook installed by Claude Agent
# Runs zero-tolerance checks before commits

powershell.exe -ExecutionPolicy Bypass -File "C:\scripts\tools\pre-commit-hook.ps1" -Check
exit `$?
"@

    $hookContent | Set-Content $hookPath -Encoding ASCII
    Write-Host "Hook installed to: $hookPath" -ForegroundColor Green
    Write-Host "Make sure the hook is executable (chmod +x on Unix)" -ForegroundColor DarkGray
}

# Main execution
if ($Install) {
    if (-not $RepoPath) {
        Write-Host "ERROR: -RepoPath required for install" -ForegroundColor Red
        Write-Host "Usage: .\pre-commit-hook.ps1 -Install -RepoPath 'C:\Projects\client-manager'"
        exit 1
    }
    Install-Hook -TargetRepo $RepoPath
} elseif ($Check) {
    $result = Invoke-PreCommitChecks
    if (-not $result) {
        exit 1
    }
    exit 0
} else {
    # Running as actual hook
    $result = Invoke-PreCommitChecks
    if (-not $result) {
        exit 1
    }
    exit 0
}
