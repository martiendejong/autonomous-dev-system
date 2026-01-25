<#
.SYNOPSIS
    Central configuration module for Claude Agent tools.

.DESCRIPTION
    Provides standardized paths and settings used across all tools.
    Dot-source this file in other tools to access config.

.EXAMPLE
    . "$PSScriptRoot\config.ps1"
    Write-Host $Config.Paths.Pool
#>

# Global configuration object
$global:Config = @{

    # File paths
    Paths = @{
        ControlPlane = "C:\scripts"
        MachineContext = "C:\scripts\_machine"
        Tools = "C:\scripts\tools"
        Skills = "C:\scripts\.claude\skills"

        Pool = "C:\scripts\_machine\worktrees.pool.md"
        Activity = "C:\scripts\_machine\worktrees.activity.md"
        Reflection = "C:\scripts\_machine\reflection.log.md"
        Snapshot = "C:\scripts\_machine\bootstrap-snapshot.json"
        ToolLog = "C:\scripts\_machine\tool-executions.log"

        WorkerAgents = "C:\Projects\worker-agents"
    }

    # Repository configuration
    Repos = @{
        ClientManager = @{
            Name = "client-manager"
            Path = "C:\Projects\client-manager"
            MainBranch = "develop"
        }
        Hazina = @{
            Name = "hazina"
            Path = "C:\Projects\hazina"
            MainBranch = "develop"
        }
    }

    # Tool settings
    Settings = @{
        DefaultRecentCount = 5
        MaxBranchAge = 14          # Days before considering branch stale
        ReflectionArchiveDays = 30 # Days before archiving reflections
    }

    # Seat configuration
    Seats = @{
        Pattern = "agent-\d+"      # Regex for valid seat names
        RestingBranchPrefix = "agent" # e.g., agent001, agent002
    }

    # Output colors
    Colors = @{
        Success = "Green"
        Warning = "Yellow"
        Error = "Red"
        Info = "Cyan"
        Muted = "DarkGray"
    }
}

# Helper functions
function Get-BaseRepoPaths {
    return @(
        $Config.Repos.ClientManager.Path,
        $Config.Repos.Hazina.Path
    )
}

function Test-ValidSeatName {
    param([string]$Name)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

    return $Name -match "^$($Config.Seats.Pattern)$"
}

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Success", "Warning", "Error", "Info", "Muted")]
        [string]$Type = "Info"
    )
    Write-Host $Message -ForegroundColor $Config.Colors[$Type]
}

# Export for module use
Export-ModuleMember -Variable Config -Function Get-BaseRepoPaths, Test-ValidSeatName, Write-Status
