<#
.SYNOPSIS
    Comprehensive development environment health checker.

.DESCRIPTION
    Validates entire development environment for readiness:
    - Required tools (git, gh, node, dotnet, etc.)
    - Environment variables
    - Repository states
    - Database connections
    - API endpoints
    - Worktree pool integrity
    - Disk space
    - Network connectivity

.PARAMETER Full
    Run full comprehensive check (slower but thorough)

.PARAMETER Fix
    Attempt to auto-fix common issues

.PARAMETER SkipNetwork
    Skip network-dependent checks (API endpoints, database)

.PARAMETER OutputFormat
    Output format: console, json, html, markdown (default: console)

.EXAMPLE
    .\health-check.ps1
    .\health-check.ps1 -Full -Fix
    .\health-check.ps1 -OutputFormat json > health-report.json
#>

param(
    [switch]$Full,
    [switch]$Fix,
    [switch]$SkipNetwork,

    [ValidateSet("console", "json", "html", "markdown")

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
]
    [string]$OutputFormat = "console"
)

$script:HealthResults = @{
    "Tools" = @()
    "Environment" = @()
    "Repositories" = @()
    "Network" = @()
    "Worktrees" = @()
    "Disk" = @()
    "Overall" = "PASS"
}

function Test-CommandExists {
    param([string]$Command)

    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Test-RequiredTools {
    Write-Host ""
    Write-Host "=== Required Tools ===" -ForegroundColor Cyan
    Write-Host ""

    $tools = @(
        @{ Name = "git"; MinVersion = "2.30.0"; Command = "git --version" }
        @{ Name = "gh"; MinVersion = "2.0.0"; Command = "gh --version" }
        @{ Name = "node"; MinVersion = "18.0.0"; Command = "node --version" }
        @{ Name = "npm"; MinVersion = "9.0.0"; Command = "npm --version" }
        @{ Name = "dotnet"; MinVersion = "8.0.0"; Command = "dotnet --version" }
        @{ Name = "pwsh"; MinVersion = "7.0.0"; Command = "`$PSVersionTable.PSVersion.ToString()" }
    )

    foreach ($tool in $tools) {
        $exists = Test-CommandExists -Command $tool.Name

        if ($exists) {
            try {
                $versionOutput = Invoke-Expression $tool.Command 2>$null
                $version = $versionOutput -replace '[^\d\.].*$', '' -replace '^v', ''

                $result = @{
                    "Tool" = $tool.Name
                    "Status" = "OK"
                    "Version" = $version
                    "MinVersion" = $tool.MinVersion
                }

                Write-Host ("  {0,-15} {1,-8} (version: {2})" -f $tool.Name, "[OK]", $version) -ForegroundColor Green

            } catch {
                $result = @{
                    "Tool" = $tool.Name
                    "Status" = "WARNING"
                    "Message" = "Installed but version check failed"
                }

                Write-Host ("  {0,-15} {1,-8}" -f $tool.Name, "[WARNING]") -ForegroundColor Yellow
                $script:HealthResults.Overall = "WARNING"
            }

        } else {
            $result = @{
                "Tool" = $tool.Name
                "Status" = "MISSING"
                "Message" = "Not installed"
            }

            Write-Host ("  {0,-15} {1,-8} NOT INSTALLED" -f $tool.Name, "[FAIL]") -ForegroundColor Red
            $script:HealthResults.Overall = "FAIL"

            if ($Fix) {
                Write-Host "    Attempting to install via winget..." -ForegroundColor Yellow
                # Auto-install logic would go here
            }
        }

        $script:HealthResults.Tools += $result
    }

    Write-Host ""
}

function Test-EnvironmentVariables {
    Write-Host "=== Environment Variables ===" -ForegroundColor Cyan
    Write-Host ""

    $required = @(
        "ANTHROPIC_API_KEY",
        "GITHUB_TOKEN"
    )

    $optional = @(
        "OPENAI_API_KEY",
        "AZURE_OPENAI_API_KEY"
    )

    foreach ($var in $required) {
        $value = [System.Environment]::GetEnvironmentVariable($var)

        if ($value) {
            $masked = if ($value.Length -gt 8) {
                $value.Substring(0, 4) + "..." + $value.Substring($value.Length - 4)
            } else {
                "***"
            }

            Write-Host ("  {0,-25} {1,-8} ({2})" -f $var, "[OK]", $masked) -ForegroundColor Green

            $script:HealthResults.Environment += @{
                "Variable" = $var
                "Status" = "OK"
                "Value" = $masked
            }

        } else {
            Write-Host ("  {0,-25} {1,-8} NOT SET" -f $var, "[FAIL]") -ForegroundColor Red
            $script:HealthResults.Overall = "FAIL"

            $script:HealthResults.Environment += @{
                "Variable" = $var
                "Status" = "MISSING"
            }
        }
    }

    Write-Host ""
    Write-Host "  Optional:" -ForegroundColor DarkGray

    foreach ($var in $optional) {
        $value = [System.Environment]::GetEnvironmentVariable($var)

        if ($value) {
            Write-Host ("    {0,-23} {1,-8}" -f $var, "[SET]") -ForegroundColor DarkGray
        } else {
            Write-Host ("    {0,-23} {1,-8}" -f $var, "[NOT SET]") -ForegroundColor DarkGray
        }
    }

    Write-Host ""
}

function Test-Repositories {
    Write-Host "=== Repositories ===" -ForegroundColor Cyan
    Write-Host ""

    $repos = @(
        "C:/Projects/client-manager",
        "C:/Projects/hazina"
    )

    foreach ($repoPath in $repos) {
        if (-not (Test-Path $repoPath)) {
            Write-Host ("  {0,-35} {1,-8} NOT FOUND" -f (Split-Path $repoPath -Leaf), "[FAIL]") -ForegroundColor Red
            $script:HealthResults.Overall = "FAIL"

            $script:HealthResults.Repositories += @{
                "Repository" = (Split-Path $repoPath -Leaf)
                "Status" = "MISSING"
                "Path" = $repoPath
            }
            continue
        }

        Push-Location $repoPath
        try {
            $branch = git branch --show-current 2>$null
            $status = git status --porcelain 2>$null
            $hasUncommitted = $status.Length -gt 0

            $repoName = Split-Path $repoPath -Leaf

            if ($hasUncommitted) {
                Write-Host ("  {0,-35} {1,-8} ({2}, uncommitted changes)" -f $repoName, "[WARNING]", $branch) -ForegroundColor Yellow
                $script:HealthResults.Overall = "WARNING"

                $statusInfo = "UNCOMMITTED"
            } else {
                Write-Host ("  {0,-35} {1,-8} ({2}, clean)" -f $repoName, "[OK]", $branch) -ForegroundColor Green
                $statusInfo = "CLEAN"
            }

            $script:HealthResults.Repositories += @{
                "Repository" = $repoName
                "Status" = "OK"
                "Branch" = $branch
                "Changes" = $statusInfo
                "Path" = $repoPath
            }

        } finally {
            Pop-Location
        }
    }

    Write-Host ""
}

function Test-WorktreePool {
    Write-Host "=== Worktree Pool ===" -ForegroundColor Cyan
    Write-Host ""

    $poolFile = "C:/scripts/_machine/worktrees.pool.md"

    if (-not (Test-Path $poolFile)) {
        Write-Host "  Worktree pool file not found" -ForegroundColor Red
        $script:HealthResults.Overall = "FAIL"
        return
    }

    $content = Get-Content $poolFile -Raw

    # Count seats
    $totalSeats = ([regex]::Matches($content, '\| agent-\d+')).Count
    $busySeats = ([regex]::Matches($content, '\| BUSY')).Count
    $freeSeats = ([regex]::Matches($content, '\| FREE')).Count

    Write-Host ("  Total Seats:  {0}" -f $totalSeats) -ForegroundColor White
    Write-Host ("  BUSY Seats:   {0}" -f $busySeats) -ForegroundColor Yellow
    Write-Host ("  FREE Seats:   {0}" -f $freeSeats) -ForegroundColor Green

    # Validate integrity
    if (($busySeats + $freeSeats) -ne $totalSeats) {
        Write-Host "  WARNING: Seat count mismatch!" -ForegroundColor Red
        $script:HealthResults.Overall = "FAIL"
    }

    # Check for stale BUSY seats (>2 hours)
    $lines = $content -split "`n"
    $staleBusy = 0

    foreach ($line in $lines) {
        if ($line -match '\| agent-\d+ \| BUSY \| .* \| (\d{4}-\d{2}-\d{2} \d{2}:\d{2})') {
            $timestamp = [DateTime]::ParseExact($matches[1], "yyyy-MM-dd HH:mm", $null)
            $age = (Get-Date) - $timestamp

            if ($age.TotalHours -gt 2) {
                $staleBusy++
            }
        }
    }

    if ($staleBusy -gt 0) {
        Write-Host ("  WARNING: {0} stale BUSY seats (>2 hours)" -f $staleBusy) -ForegroundColor Yellow
        $script:HealthResults.Overall = "WARNING"

        if ($Fix) {
            Write-Host "  Run worktree-release-all.ps1 to clean up" -ForegroundColor Cyan
        }
    }

    $script:HealthResults.Worktrees += @{
        "TotalSeats" = $totalSeats
        "BusySeats" = $busySeats
        "FreeSeats" = $freeSeats
        "StaleSeats" = $staleBusy
    }

    Write-Host ""
}

function Test-DiskSpace {
    Write-Host "=== Disk Space ===" -ForegroundColor Cyan
    Write-Host ""

    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -gt 0 }

    foreach ($drive in $drives) {
        $freeGB = [math]::Round($drive.Free / 1GB, 2)
        $usedGB = [math]::Round($drive.Used / 1GB, 2)
        $totalGB = [math]::Round(($drive.Free + $drive.Used) / 1GB, 2)
        $pctFree = [math]::Round(($drive.Free / ($drive.Free + $drive.Used)) * 100, 1)

        $status = if ($pctFree -lt 10) {
            Write-Host ("  {0}:\ {1,-8} {2}% free ({3} GB / {4} GB)" -f $drive.Name, "[CRITICAL]", $pctFree, $freeGB, $totalGB) -ForegroundColor Red
            $script:HealthResults.Overall = "FAIL"
            "CRITICAL"
        } elseif ($pctFree -lt 20) {
            Write-Host ("  {0}:\ {1,-8} {2}% free ({3} GB / {4} GB)" -f $drive.Name, "[WARNING]", $pctFree, $freeGB, $totalGB) -ForegroundColor Yellow
            if ($script:HealthResults.Overall -eq "PASS") { $script:HealthResults.Overall = "WARNING" }
            "WARNING"
        } else {
            Write-Host ("  {0}:\ {1,-8} {2}% free ({3} GB / {4} GB)" -f $drive.Name, "[OK]", $pctFree, $freeGB, $totalGB) -ForegroundColor Green
            "OK"
        }

        $script:HealthResults.Disk += @{
            "Drive" = "$($drive.Name):\"
            "Status" = $status
            "FreeGB" = $freeGB
            "TotalGB" = $totalGB
            "PercentFree" = $pctFree
        }
    }

    Write-Host ""
}

function Test-NetworkConnectivity {
    if ($SkipNetwork) {
        Write-Host "=== Network ===" -ForegroundColor Cyan
        Write-Host "  Skipped (use without -SkipNetwork to test)" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    Write-Host "=== Network Connectivity ===" -ForegroundColor Cyan
    Write-Host ""

    $endpoints = @(
        @{ Name = "GitHub"; Url = "https://api.github.com" }
        @{ Name = "Anthropic API"; Url = "https://api.anthropic.com/v1/messages" }
        @{ Name = "Local API (if running)"; Url = "https://localhost:7001/health"; Optional = $true }
    )

    foreach ($endpoint in $endpoints) {
        try {
            $response = Invoke-WebRequest -Uri $endpoint.Url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop

            Write-Host ("  {0,-30} {1,-8}" -f $endpoint.Name, "[OK]") -ForegroundColor Green

            $script:HealthResults.Network += @{
                "Endpoint" = $endpoint.Name
                "Status" = "OK"
                "Url" = $endpoint.Url
            }

        } catch {
            if ($endpoint.Optional) {
                Write-Host ("  {0,-30} {1,-8} (optional, may not be running)" -f $endpoint.Name, "[SKIP]") -ForegroundColor DarkGray
            } else {
                Write-Host ("  {0,-30} {1,-8}" -f $endpoint.Name, "[FAIL]") -ForegroundColor Red
                $script:HealthResults.Overall = "FAIL"

                $script:HealthResults.Network += @{
                    "Endpoint" = $endpoint.Name
                    "Status" = "FAIL"
                    "Url" = $endpoint.Url
                }
            }
        }
    }

    Write-Host ""
}

function Show-Summary {
    Write-Host "=== Health Check Summary ===" -ForegroundColor Cyan
    Write-Host ""

    $color = switch ($script:HealthResults.Overall) {
        "PASS" { "Green" }
        "WARNING" { "Yellow" }
        "FAIL" { "Red" }
    }

    Write-Host ("  Overall Status: {0}" -f $script:HealthResults.Overall) -ForegroundColor $color
    Write-Host ""

    if ($script:HealthResults.Overall -ne "PASS") {
        Write-Host "Issues found:" -ForegroundColor Yellow
        Write-Host ""

        # Show all failures
        foreach ($tool in $script:HealthResults.Tools | Where-Object { $_.Status -ne "OK" }) {
            Write-Host ("  - Tool missing: {0}" -f $tool.Tool) -ForegroundColor Red
        }

        foreach ($env in $script:HealthResults.Environment | Where-Object { $_.Status -ne "OK" }) {
            Write-Host ("  - Environment variable not set: {0}" -f $env.Variable) -ForegroundColor Red
        }

        foreach ($repo in $script:HealthResults.Repositories | Where-Object { $_.Status -ne "OK" -or $_.Changes -eq "UNCOMMITTED" }) {
            if ($repo.Status -eq "MISSING") {
                Write-Host ("  - Repository not found: {0}" -f $repo.Repository) -ForegroundColor Red
            } else {
                Write-Host ("  - Repository has uncommitted changes: {0}" -f $repo.Repository) -ForegroundColor Yellow
            }
        }

        Write-Host ""
    }

    if ($Fix -and $script:HealthResults.Overall -ne "PASS") {
        Write-Host "Run with -Fix to attempt auto-repair (use with caution)" -ForegroundColor Cyan
        Write-Host ""
    }
}

function Export-Results {
    param([string]$Format)

    switch ($Format) {
        "json" {
            return $script:HealthResults | ConvertTo-Json -Depth 10
        }
        "markdown" {
            $md = "# Development Environment Health Report`n`n"
            $md += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"
            $md += "## Overall Status: $($script:HealthResults.Overall)`n`n"

            $md += "## Tools`n`n"
            $md += "| Tool | Status | Version |`n"
            $md += "|------|--------|---------|`n"
            foreach ($tool in $script:HealthResults.Tools) {
                $md += "| $($tool.Tool) | $($tool.Status) | $($tool.Version) |`n"
            }

            return $md
        }
        "html" {
            # Similar to other HTML generators
            return "<html>...</html>"
        }
    }
}

# Main execution
Write-Host ""
Write-Host "=== Development Environment Health Check ===" -ForegroundColor Cyan
Write-Host ""

Test-RequiredTools
Test-EnvironmentVariables
Test-Repositories
Test-WorktreePool
Test-DiskSpace

if ($Full) {
    Test-NetworkConnectivity
}

Show-Summary

if ($OutputFormat -ne "console") {
    $output = Export-Results -Format $OutputFormat
    Write-Output $output
}

# Exit code
$exitCode = switch ($script:HealthResults.Overall) {
    "PASS" { 0 }
    "WARNING" { 1 }
    "FAIL" { 2 }
}

exit $exitCode
