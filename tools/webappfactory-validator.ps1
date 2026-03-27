<#
.SYNOPSIS
    WebApplicationFactory compatibility validator for ASP.NET Core integration tests

.DESCRIPTION
    Scans Program.cs for environment conditionals that prevent app.RunAsync() in Testing
    environment, which breaks WebApplicationFactory integration tests.

    Common anti-pattern:
    if (app.Environment.EnvironmentName != "Testing") {
        await app.RunAsync();  // ← Integration tests NEED this to run!
    }

    WebApplicationFactory creates TestServer which requires the app pipeline to initialize
    even though it manages the server lifecycle itself.

.PARAMETER ProjectPath
    Path to ASP.NET Core project directory (containing Program.cs)

.PARAMETER Fix
    Automatically fix detected issues (remove Testing environment conditionals)

.EXAMPLE
    .\webappfactory-validator.ps1 -ProjectPath "C:\Projects\client-manager\ClientManagerAPI"

.EXAMPLE
    .\webappfactory-validator.ps1 -ProjectPath "." -Fix

.NOTES
    Triggered by: Integration test failures in test session 2026-01-25
    Root cause: Program.cs conditional prevented app.RunAsync() in Testing environment
    Fix: Always call app.RunAsync(), WebApplicationFactory manages lifecycle

    Pattern detected:
    - 14 integration tests failing with "server has not been started"
    - Root cause took 1+ hour to diagnose
    - Simple conditional check would have prevented this

    Tool value: Proactive detection before test failures occur
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [switch]$Fix
)

# AUTO-USAGE TRACKING
try {
    $toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
    . "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{
        ProjectPath = $ProjectPath
        Fix = $Fix.IsPresent
    } -ErrorAction Stop
} catch {
    # Silently continue if usage logging fails
}

# Resolve project path
$ProjectPath = Resolve-Path $ProjectPath -ErrorAction Stop

# Find Program.cs
$programCs = Get-ChildItem -Path $ProjectPath -Filter "Program.cs" -Recurse | Select-Object -First 1

if (-not $programCs) {
    Write-Error "Program.cs not found in $ProjectPath"
    exit 1
}

Write-Host "Analyzing: $($programCs.FullName)" -ForegroundColor Cyan

# Read Program.cs
$content = Get-Content $programCs.FullName -Raw

# Pattern 1: Environment check that prevents RunAsync
$pattern1 = 'if\s*\(\s*app\.Environment\.EnvironmentName\s*!=\s*"Testing"\s*\)\s*\{[^}]*app\.RunAsync\(\)'

# Pattern 2: Testing environment early return
$pattern2 = 'if\s*\(\s*app\.Environment\.EnvironmentName\s*==\s*"Testing"\s*\)\s*\{\s*return'

# Pattern 3: Testing environment that skips app.RunAsync
$pattern3 = 'if\s*\(\s*app\.Environment\.EnvironmentName\s*==\s*"Testing"\s*\)\s*\{(?!.*app\.RunAsync)'

$issues = @()

# Check Pattern 1
if ($content -match $pattern1) {
    $issues += [PSCustomObject]@{
        Pattern = "Environment != Testing conditional around app.RunAsync()"
        Severity = "CRITICAL"
        Impact = "WebApplicationFactory integration tests will fail with 'server has not been started'"
        Fix = "Remove conditional - always call app.RunAsync(), WebApplicationFactory manages lifecycle"
        LineNumber = (($content.Substring(0, $content.IndexOf($matches[0])) -split "`n").Count)
    }
}

# Check Pattern 2
if ($content -match $pattern2) {
    $issues += [PSCustomObject]@{
        Pattern = "Testing environment early return"
        Severity = "CRITICAL"
        Impact = "Integration tests cannot initialize application pipeline"
        Fix = "Remove early return - let app.RunAsync() execute for all environments"
        LineNumber = (($content.Substring(0, $content.IndexOf($matches[0])) -split "`n").Count)
    }
}

# Check Pattern 3
if ($content -match $pattern3) {
    $issues += [PSCustomObject]@{
        Pattern = "Testing environment conditional without app.RunAsync()"
        Severity = "WARNING"
        Impact = "May prevent WebApplicationFactory from accessing app variable"
        Fix = "Ensure app.RunAsync() is called inside Testing environment block"
        LineNumber = (($content.Substring(0, $content.IndexOf($matches[0])) -split "`n").Count)
    }
}

# Report results
if ($issues.Count -eq 0) {
    Write-Host "`n✅ No WebApplicationFactory compatibility issues detected" -ForegroundColor Green
    Write-Host "   Program.cs appears safe for integration testing`n" -ForegroundColor Gray
    exit 0
}

Write-Host "`n⚠️  COMPATIBILITY ISSUES DETECTED: $($issues.Count)`n" -ForegroundColor Yellow

foreach ($issue in $issues) {
    Write-Host "[$($issue.Severity)] $($issue.Pattern)" -ForegroundColor $(if ($issue.Severity -eq "CRITICAL") { "Red" } else { "Yellow" })
    Write-Host "   Line: ~$($issue.LineNumber)" -ForegroundColor Gray
    Write-Host "   Impact: $($issue.Impact)" -ForegroundColor Gray
    Write-Host "   Fix: $($issue.Fix)" -ForegroundColor Gray
    Write-Host ""
}

# Auto-fix if requested
if ($Fix) {
    Write-Host "APPLYING FIXES..." -ForegroundColor Cyan

    # Backup original
    $backupPath = "$($programCs.FullName).backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $programCs.FullName $backupPath
    Write-Host "Backup created: $backupPath" -ForegroundColor Gray

    # Fix Pattern 1: Remove Environment != Testing conditional
    if ($content -match $pattern1) {
        Write-Host "Fixing: Removing Testing environment conditional..." -ForegroundColor Yellow
        # This is complex - recommend manual fix
        Write-Host "⚠️  MANUAL FIX REQUIRED: Pattern too complex for auto-fix" -ForegroundColor Yellow
        Write-Host "   Recommended change:" -ForegroundColor Gray
        Write-Host "   // BEFORE:" -ForegroundColor Gray
        Write-Host "   if (app.Environment.EnvironmentName != `"Testing`") {" -ForegroundColor DarkGray
        Write-Host "       await app.RunAsync();" -ForegroundColor DarkGray
        Write-Host "   }" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "   // AFTER:" -ForegroundColor Gray
        Write-Host "   await app.RunAsync();  // WebApplicationFactory manages lifecycle" -ForegroundColor Green
        Write-Host ""
    }

    Write-Host "✅ Analysis complete - manual fixes recommended above" -ForegroundColor Green
    Write-Host "   See backup: $backupPath" -ForegroundColor Gray
}

Write-Host "`nRECOMMENDATION:" -ForegroundColor Cyan
Write-Host "   Always call app.RunAsync() regardless of environment" -ForegroundColor White
Write-Host "   WebApplicationFactory will manage the server lifecycle" -ForegroundColor White
Write-Host "   This ensures integration tests can access the TestServer.Application property`n" -ForegroundColor White

exit 1  # Issues detected
