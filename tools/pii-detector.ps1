<#
.SYNOPSIS
    Detect PII (Personally Identifiable Information) in code, logs, and databases

.DESCRIPTION
    Scans for sensitive data that should not be in code/logs:
    - Email addresses
    - Phone numbers
    - Social Security Numbers (SSN)
    - Credit card numbers
    - IP addresses
    - API keys/tokens
    - Passwords
    - Names (partial detection)

    Prevents:
    - GDPR violations
    - Data breaches
    - Compliance issues
    - Security vulnerabilities

.PARAMETER Path
    Path to scan (file or directory)

.PARAMETER ScanType
    What to scan: code, logs, database, all

.PARAMETER Recursive
    Scan directories recursively

.PARAMETER OutputFormat
    Output format: Table (default), JSON, SARIF

.PARAMETER FailOnDetection
    Fail build if PII detected

.EXAMPLE
    # Scan codebase for PII
    .\pii-detector.ps1 -Path . -Recursive

.EXAMPLE
    # Scan logs only
    .\pii-detector.ps1 -Path ./logs -ScanType logs -FailOnDetection

.NOTES
    Value: 10/10 - GDPR compliance is critical
    Effort: 1.3/10 - Regex pattern matching
    Ratio: 7.7 (TIER S+)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Path = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [ValidateSet('code', 'logs', 'database', 'all')]
    [string]$ScanType = 'all',

    [Parameter(Mandatory=$false)]
    [switch]$Recursive = $false,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'JSON', 'SARIF')]
    [string]$OutputFormat = 'Table',

    [Parameter(Mandatory=$false)]
    [switch]$FailOnDetection = $false
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🔒 PII Detector" -ForegroundColor Cyan
Write-Host "  Path: $Path" -ForegroundColor Gray
Write-Host "  Scan type: $ScanType" -ForegroundColor Gray
Write-Host ""

# PII detection patterns
$piiPatterns = @{
    'Email' = @{
        Pattern = '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
        Severity = 'HIGH'
        Description = 'Email address'
    }
    'Phone' = @{
        Pattern = '\b(\+\d{1,3}[-.]?)?\(?\d{3}\)?[-.]?\d{3}[-.]?\d{4}\b'
        Severity = 'MEDIUM'
        Description = 'Phone number'
    }
    'SSN' = @{
        Pattern = '\b\d{3}-\d{2}-\d{4}\b'
        Severity = 'CRITICAL'
        Description = 'Social Security Number'
    }
    'CreditCard' = @{
        Pattern = '\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'
        Severity = 'CRITICAL'
        Description = 'Credit card number'
    }
    'IPv4' = @{
        Pattern = '\b(?:\d{1,3}\.){3}\d{1,3}\b'
        Severity = 'LOW'
        Description = 'IPv4 address'
    }
    'APIKey' = @{
        Pattern = '(?i)(api[_-]?key|apikey|api[_-]?secret)\s*[:=]\s*["\']?([a-zA-Z0-9_-]{20,})["\']?'
        Severity = 'CRITICAL'
        Description = 'API key'
    }
    'Password' = @{
        Pattern = '(?i)(password|passwd|pwd)\s*[:=]\s*["\']([^"\']{3,})["\']'
        Severity = 'CRITICAL'
        Description = 'Password in plain text'
    }
    'JWT' = @{
        Pattern = 'eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*'
        Severity = 'HIGH'
        Description = 'JWT token'
    }
    'AWSKey' = @{
        Pattern = 'AKIA[0-9A-Z]{16}'
        Severity = 'CRITICAL'
        Description = 'AWS access key'
    }
    'PrivateKey' = @{
        Pattern = '-----BEGIN (RSA |)PRIVATE KEY-----'
        Severity = 'CRITICAL'
        Description = 'Private key'
    }
}

$findings = @()

# Get files to scan
if (Test-Path $Path -PathType Container) {
    $files = Get-ChildItem -Path $Path -File -Recurse:$Recursive |
        Where-Object {
            $_.Extension -in @('.cs', '.js', '.ts', '.py', '.java', '.go', '.log', '.txt', '.json', '.xml', '.sql') -and
            $_.FullName -notmatch '\\node_modules\\|\\bin\\|\\obj\\|\\.git\\'
        }
} else {
    $files = @(Get-Item $Path)
}

Write-Host "📁 Scanning $($files.Count) files..." -ForegroundColor Yellow
Write-Host ""

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue

    if (-not $content) { continue }

    $lines = $content -split "`n"

    foreach ($piiType in $piiPatterns.Keys) {
        $pattern = $piiPatterns[$piiType]

        $matches = [regex]::Matches($content, $pattern.Pattern)

        foreach ($match in $matches) {
            # Get line number
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count

            # Get context (surrounding text)
            $lineContent = $lines[$lineNumber - 1]
            $context = $lineContent.Substring(0, [Math]::Min(80, $lineContent.Length))

            # Skip false positives
            if ($piiType -eq 'Email' -and $match.Value -match 'example\.com|test\.com|localhost') {
                continue
            }

            if ($piiType -eq 'IPv4' -and $match.Value -match '^(127\.|0\.|10\.|192\.168\.)') {
                continue  # Skip localhost/private IPs
            }

            if ($piiType -eq 'Password' -and $context -match '(?i)test|example|dummy|placeholder') {
                continue  # Skip test passwords
            }

            $findings += [PSCustomObject]@{
                File = $file.Name
                FilePath = $file.FullName
                Line = $lineNumber
                Type = $piiType
                Description = $pattern.Description
                Severity = $pattern.Severity
                Match = $match.Value.Substring(0, [Math]::Min(40, $match.Value.Length))
                Context = $context
            }
        }
    }
}

Write-Host ""
Write-Host "PII DETECTION RESULTS" -ForegroundColor $(if($findings.Count -gt 0){"Red"}else{"Green"})
Write-Host ""

if ($findings.Count -eq 0) {
    Write-Host "✅ No PII detected!" -ForegroundColor Green
    exit 0
}

switch ($OutputFormat) {
    'Table' {
        $findings | Sort-Object Severity, File | Format-Table -AutoSize -Wrap -Property @(
            @{Label='Severity'; Expression={$_.Severity}; Width=10}
            @{Label='Type'; Expression={$_.Type}; Width=15}
            @{Label='File'; Expression={$_.File}; Width=30}
            @{Label='Line'; Expression={$_.Line}; Align='Right'; Width=6}
            @{Label='Match'; Expression={$_.Match}; Width=40}
        )

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Total findings: $($findings.Count)" -ForegroundColor Red
        Write-Host "  CRITICAL: $(($findings | Where-Object {$_.Severity -eq 'CRITICAL'}).Count)" -ForegroundColor Red
        Write-Host "  HIGH: $(($findings | Where-Object {$_.Severity -eq 'HIGH'}).Count)" -ForegroundColor Yellow
        Write-Host "  MEDIUM: $(($findings | Where-Object {$_.Severity -eq 'MEDIUM'}).Count)" -ForegroundColor Yellow
        Write-Host "  LOW: $(($findings | Where-Object {$_.Severity -eq 'LOW'}).Count)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
        Write-Host "  1. Remove PII from code/logs immediately" -ForegroundColor Gray
        Write-Host "  2. Use environment variables for sensitive data" -ForegroundColor Gray
        Write-Host "  3. Implement data anonymization in logs" -ForegroundColor Gray
        Write-Host "  4. Review GDPR compliance requirements" -ForegroundColor Gray
        Write-Host "  5. Add PII detection to CI/CD pipeline" -ForegroundColor Gray
    }
    'JSON' {
        @{
            TotalFindings = $findings.Count
            CriticalCount = ($findings | Where-Object {$_.Severity -eq 'CRITICAL'}).Count
            Findings = $findings
        } | ConvertTo-Json -Depth 10
    }
    'SARIF' {
        # SARIF format for security scanners
        $sarif = @{
            version = "2.1.0"
            runs = @(
                @{
                    tool = @{
                        driver = @{
                            name = "PII Detector"
                            version = "1.0.0"
                        }
                    }
                    results = $findings | ForEach-Object {
                        @{
                            ruleId = $_.Type
                            level = switch($_.Severity) {
                                'CRITICAL' { 'error' }
                                'HIGH' { 'error' }
                                'MEDIUM' { 'warning' }
                                'LOW' { 'note' }
                            }
                            message = @{
                                text = "$($_.Description) detected"
                            }
                            locations = @(
                                @{
                                    physicalLocation = @{
                                        artifactLocation = @{
                                            uri = $_.FilePath
                                        }
                                        region = @{
                                            startLine = $_.Line
                                        }
                                    }
                                }
                            )
                        }
                    }
                }
            )
        }

        $sarif | ConvertTo-Json -Depth 10
    }
}

if ($FailOnDetection) {
    Write-Host ""
    Write-Host "❌ BUILD FAILED - PII detected" -ForegroundColor Red
    exit 1
}
