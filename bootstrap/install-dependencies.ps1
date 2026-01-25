#Requires -Version 5.1
<#
.SYNOPSIS
    Install required dependencies for Claude Agent development environment

.DESCRIPTION
    Installs all software required for the Claude Agent to operate:
    - Git (version control)
    - GitHub CLI (repository operations)
    - Node.js & npm (for Claude Code CLI and frontend tools)
    - .NET SDK (for C# development)
    - Visual Studio Build Tools (optional, for C# compilation)

.PARAMETER NonInteractive
    Skip confirmation prompts

.PARAMETER Force
    Force reinstallation even if already present

.NOTES
    Requires Windows 10+ with winget or chocolatey available
#>

[CmdletBinding()]
param(
    [switch]$NonInteractive,
    [switch]$Force
)

$ErrorActionPreference = "Continue"

function Write-Status {
    param([string]$Message, [string]$Type = "Info")
    $color = switch ($Type) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        "Info"    { "Cyan" }
        default   { "White" }
    }
    $prefix = switch ($Type) {
        "Success" { "[OK]" }
        "Warning" { "[WARN]" }
        "Error"   { "[ERROR]" }
        "Info"    { "[INFO]" }
        default   { "[*]" }
    }
    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Test-Command {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

function Install-WithWinget {
    param(
        [string]$PackageId,
        [string]$DisplayName,
        [string]$TestCommand = $null
    )

    if ($TestCommand -and (Test-Command $TestCommand) -and -not $Force) {
        Write-Status "$DisplayName already installed (found: $TestCommand)" "Success"
        return $true
    }

    Write-Status "Installing $DisplayName via winget..." "Info"

    try {
        $result = & winget install --id $PackageId --accept-package-agreements --accept-source-agreements --silent 2>&1
        if ($LASTEXITCODE -eq 0 -or $result -match "already installed") {
            Write-Status "$DisplayName installed successfully" "Success"
            return $true
        } else {
            Write-Status "winget returned: $result" "Warning"
            return $false
        }
    } catch {
        Write-Status "Failed to install $DisplayName : $_" "Error"
        return $false
    }
}

function Install-WithChocolatey {
    param(
        [string]$PackageName,
        [string]$DisplayName,
        [string]$TestCommand = $null
    )

    if ($TestCommand -and (Test-Command $TestCommand) -and -not $Force) {
        Write-Status "$DisplayName already installed (found: $TestCommand)" "Success"
        return $true
    }

    if (-not (Test-Command "choco")) {
        return $false
    }

    Write-Status "Installing $DisplayName via Chocolatey..." "Info"

    try {
        & choco install $PackageName -y 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "$DisplayName installed successfully" "Success"
            return $true
        }
        return $false
    } catch {
        Write-Status "Failed to install $DisplayName via Chocolatey: $_" "Error"
        return $false
    }
}

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    Write-Status "Refreshed PATH environment variable" "Info"
}

# === MAIN ===
Write-Host ""
Write-Host "Installing Dependencies" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host ""

$installedCount = 0
$failedCount = 0
$skippedCount = 0

# Determine package manager
$hasWinget = Test-Command "winget"
$hasChoco = Test-Command "choco"

if (-not $hasWinget -and -not $hasChoco) {
    Write-Status "No package manager found (winget or chocolatey required)" "Error"
    Write-Host ""
    Write-Host "Please install winget (Windows Package Manager) first:" -ForegroundColor Yellow
    Write-Host "  https://aka.ms/getwinget" -ForegroundColor White
    Write-Host ""
    Write-Host "Or install Chocolatey:" -ForegroundColor Yellow
    Write-Host "  https://chocolatey.org/install" -ForegroundColor White
    exit 1
}

if ($hasWinget) {
    Write-Status "Using winget as package manager" "Info"
} else {
    Write-Status "Using Chocolatey as package manager" "Info"
}

# === REQUIRED DEPENDENCIES ===

$dependencies = @(
    @{
        Name = "Git"
        WingetId = "Git.Git"
        ChocoName = "git"
        TestCommand = "git"
        Required = $true
    },
    @{
        Name = "GitHub CLI"
        WingetId = "GitHub.cli"
        ChocoName = "gh"
        TestCommand = "gh"
        Required = $true
    },
    @{
        Name = "Node.js LTS"
        WingetId = "OpenJS.NodeJS.LTS"
        ChocoName = "nodejs-lts"
        TestCommand = "node"
        Required = $true
    },
    @{
        Name = ".NET SDK 8.0"
        WingetId = "Microsoft.DotNet.SDK.8"
        ChocoName = "dotnet-sdk"
        TestCommand = "dotnet"
        Required = $false
    },
    @{
        Name = "Visual Studio Code"
        WingetId = "Microsoft.VisualStudioCode"
        ChocoName = "vscode"
        TestCommand = "code"
        Required = $false
    }
)

foreach ($dep in $dependencies) {
    Write-Host ""
    Write-Status "Checking $($dep.Name)..." "Info"

    # Check if already installed
    if ($dep.TestCommand -and (Test-Command $dep.TestCommand) -and -not $Force) {
        $version = & $dep.TestCommand --version 2>&1 | Select-Object -First 1
        Write-Status "$($dep.Name) already installed: $version" "Success"
        $skippedCount++
        continue
    }

    # Install
    $success = $false
    if ($hasWinget) {
        $success = Install-WithWinget -PackageId $dep.WingetId -DisplayName $dep.Name -TestCommand $dep.TestCommand
    }

    if (-not $success -and $hasChoco) {
        $success = Install-WithChocolatey -PackageName $dep.ChocoName -DisplayName $dep.Name -TestCommand $dep.TestCommand
    }

    if ($success) {
        $installedCount++
    } elseif ($dep.Required) {
        Write-Status "REQUIRED: $($dep.Name) - Please install manually" "Error"
        $failedCount++
    } else {
        Write-Status "OPTIONAL: $($dep.Name) - Skipping" "Warning"
        $skippedCount++
    }
}

# Refresh PATH after installations
Refresh-Path

# === VERIFY GH CLI AUTH ===
Write-Host ""
Write-Status "Checking GitHub CLI authentication..." "Info"

$ghAuth = & gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Status "GitHub CLI not authenticated" "Warning"
    Write-Host ""
    Write-Host "To authenticate GitHub CLI, run:" -ForegroundColor Yellow
    Write-Host "  gh auth login" -ForegroundColor White
    Write-Host ""

    if (-not $NonInteractive) {
        $response = Read-Host "Would you like to authenticate now? (y/N)"
        if ($response -eq "y" -or $response -eq "Y") {
            & gh auth login
        }
    }
} else {
    Write-Status "GitHub CLI authenticated" "Success"
}

# === NPM GLOBAL PACKAGES ===
Write-Host ""
Write-Status "Checking npm global packages..." "Info"

$npmPackages = @(
    @{
        Name = "@anthropic-ai/claude-code"
        DisplayName = "Claude Code CLI"
        TestCommand = "claude"
    }
)

foreach ($pkg in $npmPackages) {
    if ($pkg.TestCommand -and (Test-Command $pkg.TestCommand) -and -not $Force) {
        $version = & $pkg.TestCommand --version 2>&1 | Select-Object -First 1
        Write-Status "$($pkg.DisplayName) already installed: $version" "Success"
        continue
    }

    if (Test-Command "npm") {
        Write-Status "Installing $($pkg.DisplayName) via npm..." "Info"
        & npm install -g $pkg.Name 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "$($pkg.DisplayName) installed successfully" "Success"
            $installedCount++
        } else {
            Write-Status "Failed to install $($pkg.DisplayName)" "Warning"
        }
    } else {
        Write-Status "npm not available - skipping $($pkg.DisplayName)" "Warning"
    }
}

# === SUMMARY ===
Write-Host ""
Write-Host "==============================" -ForegroundColor Cyan
Write-Host "  Dependency Installation Summary" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Installed: $installedCount" -ForegroundColor Green
Write-Host "  Skipped:   $skippedCount" -ForegroundColor Yellow
Write-Host "  Failed:    $failedCount" -ForegroundColor Red
Write-Host ""

if ($failedCount -gt 0) {
    Write-Status "Some required dependencies failed to install. Please install manually." "Warning"
    exit 1
}

Write-Status "Dependency installation complete" "Success"
exit 0
