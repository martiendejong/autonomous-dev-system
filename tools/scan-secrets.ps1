<#
.SYNOPSIS
    Scans repository for secrets (API keys, passwords, tokens, private keys).

.DESCRIPTION
    Security scanner that detects hardcoded secrets in code files.
    Can scan entire repository or specific files/directories.

    Detects:
    - API keys and tokens
    - Passwords and connection strings
    - Private keys (RSA, SSH)
    - OAuth tokens and JWTs
    - Cloud provider credentials (AWS, Azure, GCP)

.PARAMETER Path
    Path to scan (file or directory). Defaults to current directory.

.PARAMETER Recursive
    Scan subdirectories recursively

.PARAMETER FailOnSecrets
    Exit with code 1 if secrets found (for CI/CD)

.PARAMETER ExcludePatterns
    Additional file patterns to exclude (comma-separated)

.EXAMPLE
    .\scan-secrets.ps1
    .\scan-secrets.ps1 -Path "C:\Projects\client-manager" -Recursive
    .\scan-secrets.ps1 -Path "src" -FailOnSecrets
#>

param(
    [string]$Path = ".",
    [switch]$Recursive,
    [switch]$FailOnSecrets,
    [string[]]$ExcludePatterns = @()

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

)

$secretPatterns = @{
    "Generic Password" = "password\s*[=:]\s*[`"']?[^`"'\s]{8,}"
    "API Key" = "api[_-]?key\s*[=:]\s*[`"']?[A-Za-z0-9]{20,}"
    "GitHub Token" = "(gh|github)[_-]?token\s*[=:]\s*[`"']?[A-Za-z0-9_]+"
    "OAuth Token" = "Bearer\s+[A-Za-z0-9\-._~+/]+=*"
    "Private Key" = "-----BEGIN (RSA|OPENSSH|PRIVATE) KEY-----"
    "AWS Access Key" = "AKIA[0-9A-Z]{16}"
    "AWS Secret Key" = "aws_secret_access_key\s*[=:]\s*[`"']?[A-Za-z0-9/+=]{40}"
    "Azure Connection String" = "DefaultEndpointsProtocol=https;.*AccountKey=[A-Za-z0-9/+=]+"
    "Generic Secret" = "secret\s*[=:]\s*[`"']?[^`"'\s]{12,}"
    "SQL Connection String" = "Server=.*;Password=[^;]+;"
    "JWT Token" = "eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\."
    "Slack Token" = "xox[baprs]-[0-9a-zA-Z]{10,}"
    "OpenAI API Key" = "sk-[A-Za-z0-9]{48}"
    "Anthropic API Key" = "sk-ant-[A-Za-z0-9\-_]+"
}

# Default exclusions
$defaultExclusions = @(
    '*.md',
    '*.txt',
    '*.log',
    'package-lock.json',
    'yarn.lock',
    '*.min.js',
    '*.map',
    'node_modules',
    '.git',
    'dist',
    'build',
    'bin',
    'obj',
    '.vs',
    'Test*.cs',
    '*Test.cs',
    'tests',
    '__tests__'
)

$allExclusions = $defaultExclusions + $ExcludePatterns

function Test-ShouldExclude {
    param([string]$FilePath)

    foreach ($pattern in $allExclusions) {
        if ($FilePath -like "*$pattern*") {
            return $true
        }
    }
    return $false
}

function Scan-FileForSecrets {
    param([string]$FilePath)

    if (Test-ShouldExclude -FilePath $FilePath) {
        return @()
    }

    if (-not (Test-Path $FilePath)) {
        return @()
    }

    try {
        $content = Get-Content $FilePath -Raw -ErrorAction Stop
    } catch {
        # Skip files that can't be read
        return @()
    }

    $foundSecrets = @()

    foreach ($patternName in $secretPatterns.Keys) {
        $pattern = $secretPatterns[$patternName]

        $matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

        if ($matches.Count -gt 0) {
            foreach ($match in $matches) {
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                $lines = $content -split "`n"
                $contextLine = if ($lineNumber -le $lines.Count) { $lines[$lineNumber - 1].Trim() } else { "" }

                # Redact secret
                $redacted = $contextLine -replace "([=:]\s*[`"']?)[^`"'\s]{4,}", '$1***REDACTED***'

                $foundSecrets += @{
                    "File" = $FilePath
                    "Line" = $lineNumber
                    "Type" = $patternName
                    "Context" = $redacted
                    "Match" = $match.Value.Substring(0, [Math]::Min(50, $match.Value.Length))
                }
            }
        }
    }

    return $foundSecrets
}

function Scan-Directory {
    param([string]$DirPath, [bool]$IsRecursive)

    $allSecrets = @()

    $files = if ($IsRecursive) {
        Get-ChildItem -Path $DirPath -File -Recurse -ErrorAction SilentlyContinue
    } else {
        Get-ChildItem -Path $DirPath -File -ErrorAction SilentlyContinue
    }

    $totalFiles = $files.Count
    $scannedFiles = 0

    Write-Host ""
    Write-Host "=== Secret Scanner ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Scanning: $DirPath" -ForegroundColor White
    Write-Host "Files to scan: $totalFiles" -ForegroundColor DarkGray
    Write-Host ""

    foreach ($file in $files) {
        $scannedFiles++

        if ($scannedFiles % 50 -eq 0) {
            Write-Host "  Scanned $scannedFiles / $totalFiles files..." -ForegroundColor DarkGray
        }

        $secrets = Scan-FileForSecrets -FilePath $file.FullName

        if ($secrets.Count -gt 0) {
            $allSecrets += $secrets
        }
    }

    return $allSecrets
}

# Main execution
if (-not (Test-Path $Path)) {
    Write-Host "ERROR: Path not found: $Path" -ForegroundColor Red
    exit 1
}

$isDirectory = (Get-Item $Path) -is [System.IO.DirectoryInfo]

$secrets = if ($isDirectory) {
    Scan-Directory -DirPath $Path -IsRecursive:$Recursive
} else {
    Scan-FileForSecrets -FilePath $Path
}

# Display results
Write-Host ""
Write-Host "=== Scan Results ===" -ForegroundColor Cyan
Write-Host ""

if ($secrets.Count -eq 0) {
    Write-Host "No secrets detected!" -ForegroundColor Green
    Write-Host ""
    exit 0
}

Write-Host "Found $($secrets.Count) potential secret(s):" -ForegroundColor Red
Write-Host ""

# Group by file
$secretsByFile = $secrets | Group-Object -Property File

foreach ($group in $secretsByFile) {
    $relativePath = $group.Name -replace [regex]::Escape((Get-Location).Path), "."

    Write-Host "File: $relativePath" -ForegroundColor Yellow
    Write-Host "  Secrets found: $($group.Count)" -ForegroundColor Red
    Write-Host ""

    foreach ($secret in $group.Group) {
        Write-Host "  Line $($secret.Line): $($secret.Type)" -ForegroundColor White
        Write-Host "    $($secret.Context)" -ForegroundColor DarkGray
        Write-Host ""
    }
}

Write-Host "=== Remediation ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Remove hardcoded secrets from code" -ForegroundColor White
Write-Host "2. Use environment variables or secret management:" -ForegroundColor White
Write-Host "   - Azure KeyVault for production" -ForegroundColor DarkGray
Write-Host "   - .env files (add to .gitignore)" -ForegroundColor DarkGray
Write-Host "   - appsettings.Development.json (add to .gitignore)" -ForegroundColor DarkGray
Write-Host "3. If false positive, add pattern to ExcludePatterns" -ForegroundColor White
Write-Host "4. Install pre-commit hook to prevent future commits:" -ForegroundColor White
Write-Host "   C:/scripts/tools/pre-commit-hook.ps1 -Install -RepoPath <path>" -ForegroundColor DarkGray
Write-Host ""

if ($FailOnSecrets) {
    Write-Host "Exiting with failure code (FailOnSecrets enabled)" -ForegroundColor Red
    exit 1
}

exit 0
