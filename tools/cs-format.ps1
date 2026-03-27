<#
.SYNOPSIS
    Run dotnet format on C# projects after edits.

.DESCRIPTION
    Post-edit helper that runs dotnet format on C# solutions or projects.
    Automatically finds .sln or .csproj files if given a directory.

.PARAMETER ProjectPath
    Path to the project/solution file or directory to format

.PARAMETER VerifyOnly
    Only verify formatting without making changes

.PARAMETER Verbose
    Show detailed output

.EXAMPLE
    .\cs-format.ps1 -ProjectPath "C:\Projects\client-manager"
    .\cs-format.ps1 -ProjectPath "C:\Projects\hazina" -VerifyOnly
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath,

    [Parameter(Mandatory=$false)]
    [switch]$VerifyOnly,

    [Parameter(Mandatory=$false)]
    [switch]$Verbose
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ErrorActionPreference = "Stop"

function Write-Status {
    param($Message, $Color = "Cyan")
    Write-Host "[$([DateTime]::Now.ToString('HH:mm:ss'))] $Message" -ForegroundColor $Color
}

function Format-CsProject {
    param($Path, $Verify)

    Write-Status "Formatting C# project at: $Path"

    # Find solution or project file
    $target = $null
    if (Test-Path $Path) {
        if ($Path -match '\.(sln|csproj)$') {
            $target = $Path
        } else {
            # Search for solution file first
            $sln = Get-ChildItem -Path $Path -Filter "*.sln" -File | Select-Object -First 1
            if ($sln) {
                $target = $sln.FullName
            } else {
                # Search for csproj
                $csproj = Get-ChildItem -Path $Path -Filter "*.csproj" -File -Recurse | Select-Object -First 1
                if ($csproj) {
                    $target = $csproj.FullName
                }
            }
        }
    }

    if (-not $target) {
        Write-Status "No solution or project file found in: $Path" "Yellow"
        return $false
    }

    Write-Status "Target: $target"

    # Run dotnet format
    $formatArgs = @($target)
    if ($Verify) {
        $formatArgs += "--verify-no-changes"
    }
    if ($Verbose) {
        $formatArgs += "--verbosity", "diagnostic"
    }

    Write-Status "Running: dotnet format $($formatArgs -join ' ')"

    $output = & dotnet format @formatArgs 2>&1
    $exitCode = $LASTEXITCODE

    if ($Verbose) {
        Write-Host $output
    }

    if ($exitCode -eq 0) {
        Write-Status "Formatting completed successfully" "Green"
        return $true
    } elseif ($Verify -and $exitCode -ne 0) {
        Write-Status "Formatting changes detected - running format..." "Yellow"
        # Run without verify to fix
        $output = & dotnet format $target 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "Files formatted successfully" "Green"
            return $true
        } else {
            Write-Status "Formatting failed" "Red"
            Write-Host $output
            return $false
        }
    } else {
        Write-Status "Formatting failed with exit code: $exitCode" "Red"
        Write-Host $output
        return $false
    }
}

# Main execution
try {
    if (-not $ProjectPath) {
        # Default to current directory
        $ProjectPath = Get-Location
    }

    Write-Status "C# Format Tool Starting" "Cyan"
    Write-Status "Project Path: $ProjectPath"

    $success = Format-CsProject -Path $ProjectPath -Verify $VerifyOnly

    if ($success) {
        Write-Status "✓ Format completed" "Green"
        exit 0
    } else {
        Write-Status "✗ Format failed" "Red"
        exit 1
    }
} catch {
    Write-Status "Error: $_" "Red"
    Write-Host $_.Exception.StackTrace
    exit 1
}
