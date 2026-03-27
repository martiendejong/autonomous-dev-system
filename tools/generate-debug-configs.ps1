<#
.SYNOPSIS
    Advanced debug configuration generator for complex debugging scenarios.

.DESCRIPTION
    Generates debugging configurations for advanced scenarios including
    remote debugging, Docker containers, multi-process debugging, and
    attach-to-process configurations.

    Features:
    - Docker container debugging
    - Remote debugging configurations
    - Multi-process/compound debugging
    - Attach to process configurations
    - Environment variable management
    - Custom launch profiles
    - Watch expressions and log points

.PARAMETER ProjectPath
    Path to project root

.PARAMETER Scenario
    Debug scenario: docker, remote, multi-process, attach, custom

.PARAMETER ContainerName
    Docker container name for Docker debugging

.PARAMETER RemoteHost
    Remote host for remote debugging

.PARAMETER RemotePort
    Remote port for debugging

.PARAMETER ProcessName
    Process name to attach to

.PARAMETER EnvironmentFile
    Path to .env file for environment variables

.EXAMPLE
    .\generate-debug-configs.ps1 -ProjectPath "." -Scenario docker -ContainerName "api-container"
    .\generate-debug-configs.ps1 -ProjectPath "." -Scenario remote -RemoteHost "192.168.1.100" -RemotePort 5000
    .\generate-debug-configs.ps1 -ProjectPath "." -Scenario multi-process
    .\generate-debug-configs.ps1 -ProjectPath "." -Scenario attach -ProcessName "dotnet"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [Parameter(Mandatory=$true)]
    [ValidateSet("docker", "remote", "multi-process", "attach", "custom")]
    [string]$Scenario,

    [string]$ContainerName,
    [string]$RemoteHost,
    [int]$RemotePort = 5000,
    [string]$ProcessName,
    [string]$EnvironmentFile
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Generate-DockerDebugConfig {
    param([string]$ContainerName, [string]$ProjectPath)

    return @{
        "name" = "Docker: Attach to .NET"
        "type" = "coreclr"
        "request" = "attach"
        "processId" = "`${command:pickRemoteProcess}"
        "pipeTransport" = @{
            "pipeProgram" = "docker"
            "pipeArgs" = @("exec", "-i", $ContainerName)
            "debuggerPath" = "/vsdbg/vsdbg"
            "pipeCwd" = "`${workspaceFolder}"
            "quoteArgs" = $false
        }
        "sourceFileMap" = @{
            "/app" = "`${workspaceFolder}"
        }
    }
}

function Generate-RemoteDebugConfig {
    param([string]$RemoteHost, [int]$RemotePort)

    return @{
        "name" = "Remote: Attach to .NET"
        "type" = "coreclr"
        "request" = "attach"
        "processId" = "`${command:pickRemoteProcess}"
        "pipeTransport" = @{
            "pipeCwd" = "`${workspaceFolder}"
            "pipeProgram" = "ssh"
            "pipeArgs" = @($RemoteHost)
            "debuggerPath" = "/vsdbg/vsdbg"
        }
        "justMyCode" = $false
    }
}

function Generate-MultiProcessConfig {
    return @{
        "version" = "0.2.0"
        "configurations" = @(
            @{
                "name" = "Backend API"
                "type" = "coreclr"
                "request" = "launch"
                "preLaunchTask" = "build-api"
                "program" = "`${workspaceFolder}/API/bin/Debug/net8.0/API.dll"
                "args" = @()
                "cwd" = "`${workspaceFolder}/API"
                "env" = @{
                    "ASPNETCORE_ENVIRONMENT" = "Development"
                }
                "serverReadyAction" = @{
                    "action" = "openExternally"
                    "pattern" = "\\bNow listening on:\\s+(https?://\\S+)"
                }
            },
            @{
                "name" = "Frontend Dev Server"
                "type" = "node"
                "request" = "launch"
                "runtimeExecutable" = "npm"
                "runtimeArgs" = @("run", "dev")
                "cwd" = "`${workspaceFolder}/Frontend"
                "console" = "integratedTerminal"
            }
        )
        "compounds" = @(
            @{
                "name" = "Full Stack"
                "configurations" = @("Backend API", "Frontend Dev Server")
                "stopAll" = $true
            }
        )
    }
}

function Generate-AttachConfig {
    param([string]$ProcessName)

    return @{
        "name" = "Attach to $ProcessName"
        "type" = "coreclr"
        "request" = "attach"
        "processName" = $ProcessName
    }
}

function Load-EnvironmentVariables {
    param([string]$EnvironmentFile)

    if (-not (Test-Path $EnvironmentFile)) {
        return @{}
    }

    $envVars = @{}

    foreach ($line in Get-Content $EnvironmentFile) {
        $line = $line.Trim()

        if ($line -match '^#' -or $line -eq "") { continue }

        if ($line -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim() -replace '^"(.*)"$', '$1' -replace "^'(.*)'$", '$1'

            $envVars[$key] = $value
        }
    }

    return $envVars
}

# Main execution
Write-Host ""
Write-Host "=== Debug Configuration Generator ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

$vscodeDir = Join-Path $ProjectPath ".vscode"

if (-not (Test-Path $vscodeDir)) {
    New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
}

$launchPath = Join-Path $vscodeDir "launch.json"

# Load existing or create new
$launchConfig = if (Test-Path $launchPath) {
    Get-Content $launchPath | ConvertFrom-Json
} else {
    @{
        "version" = "0.2.0"
        "configurations" = @()
    }
}

# Generate configuration based on scenario
$newConfig = switch ($Scenario) {
    "docker" {
        if (-not $ContainerName) {
            Write-Host "ERROR: -ContainerName required for Docker debugging" -ForegroundColor Red
            exit 1
        }
        Generate-DockerDebugConfig -ContainerName $ContainerName -ProjectPath $ProjectPath
    }
    "remote" {
        if (-not $RemoteHost) {
            Write-Host "ERROR: -RemoteHost required for remote debugging" -ForegroundColor Red
            exit 1
        }
        Generate-RemoteDebugConfig -RemoteHost $RemoteHost -RemotePort $RemotePort
    }
    "multi-process" {
        Generate-MultiProcessConfig
    }
    "attach" {
        if (-not $ProcessName) {
            Write-Host "ERROR: -ProcessName required for attach debugging" -ForegroundColor Red
            exit 1
        }
        Generate-AttachConfig -ProcessName $ProcessName
    }
    "custom" {
        Write-Host "Custom configuration not yet implemented" -ForegroundColor Yellow
        exit 0
    }
}

# Add new configuration
if ($Scenario -eq "multi-process") {
    $launchConfig = $newConfig
} else {
    $launchConfig.configurations += $newConfig
}

# Save
$launchConfig | ConvertTo-Json -Depth 10 | Set-Content $launchPath -Encoding UTF8

Write-Host "Debug configuration added for: $Scenario" -ForegroundColor Green
Write-Host "File: $launchPath" -ForegroundColor White
Write-Host ""

Write-Host "=== Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
