<#
.SYNOPSIS
    Detects and optionally fixes .csproj files that are missing from a solution file.

.DESCRIPTION
    Scans a repository for all .csproj files and compares them against the projects
    listed in the solution file. Reports missing projects and can automatically add them.

.PARAMETER SolutionPath
    Path to the .sln file to check

.PARAMETER RepositoryPath
    Root directory of the repository to scan for .csproj files (defaults to solution directory)

.PARAMETER AutoFix
    Automatically add missing projects to the solution

.PARAMETER ShowDetails
    Show detailed information about the scan

.EXAMPLE
    .\detect-missing-projects.ps1 -SolutionPath "C:\Projects\hazina\Hazina.sln"

.EXAMPLE
    .\detect-missing-projects.ps1 -SolutionPath "C:\Projects\hazina\Hazina.sln" -AutoFix

.EXAMPLE
    # Check all solutions in a directory
    Get-ChildItem C:\Projects\hazina -Filter *.sln | ForEach-Object {
        .\detect-missing-projects.ps1 -SolutionPath $_.FullName
    }
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$SolutionPath,

    [Parameter(Mandatory = $false)]
    [string]$RepositoryPath,

    [Parameter(Mandatory = $false)]
    [switch]$AutoFix,

    [Parameter(Mandatory = $false)]
    [switch]$ShowDetails
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

# Resolve paths
$SolutionPath = Resolve-Path $SolutionPath -ErrorAction Stop
$SolutionDir = Split-Path $SolutionPath -Parent

if ([string]::IsNullOrEmpty($RepositoryPath)) {
    $RepositoryPath = $SolutionDir
} else {
    $RepositoryPath = Resolve-Path $RepositoryPath -ErrorAction Stop
}

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Missing Project Detection Tool" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Solution: $SolutionPath" -ForegroundColor White
Write-Host "Repository: $RepositoryPath" -ForegroundColor White
Write-Host ""

# Find all .csproj files (excluding bin/obj directories)
Write-Host "Scanning for .csproj files..." -ForegroundColor Yellow
$allProjects = Get-ChildItem -Path $RepositoryPath -Filter "*.csproj" -Recurse |
    Where-Object {
        $_.FullName -notmatch '\\bin\\' -and
        $_.FullName -notmatch '\\obj\\'
    } |
    ForEach-Object { $_.FullName }

Write-Host "Found $($allProjects.Count) project files" -ForegroundColor Green

# Get projects listed in solution
Write-Host "Reading solution file..." -ForegroundColor Yellow
$slnContent = Get-Content $SolutionPath -Raw

# Parse solution file for project references
$projectPattern = 'Project\("{[^}]+}"\)\s*=\s*"[^"]+",\s*"([^"]+\.csproj)"'
$solutionProjects = [regex]::Matches($slnContent, $projectPattern) |
    ForEach-Object {
        $relativePath = $_.Groups[1].Value
        # Convert relative path to absolute
        $absolutePath = Join-Path $SolutionDir $relativePath
        $absolutePath = [System.IO.Path]::GetFullPath($absolutePath)
        $absolutePath
    }

Write-Host "Solution contains $($solutionProjects.Count) projects" -ForegroundColor Green

# Find missing projects
$missingProjects = $allProjects | Where-Object {
    $projectPath = $_
    $isInSolution = $false

    foreach ($slnProject in $solutionProjects) {
        if ($slnProject -eq $projectPath) {
            $isInSolution = $true
            break
        }
    }

    -not $isInSolution
}

# Report results
Write-Host ""
if ($missingProjects.Count -eq 0) {
    Write-Host "[+] All projects are included in the solution!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[!] Found $($missingProjects.Count) missing project(s):" -ForegroundColor Red
    Write-Host ""

    foreach ($missing in $missingProjects) {
        $relativePath = $missing.Replace($RepositoryPath, '.').Replace('\', '/')
        Write-Host "  - $relativePath" -ForegroundColor Yellow

        if ($ShowDetails) {
            Write-Host "    Full path: $missing" -ForegroundColor DarkGray
        }
    }

    Write-Host ""

    # Auto-fix if requested
    if ($AutoFix) {
        Write-Host "Adding missing projects to solution..." -ForegroundColor Cyan

        foreach ($missing in $missingProjects) {
            $relativePath = $missing.Replace($RepositoryPath + '\', '')

            Push-Location $RepositoryPath
            try {
                dotnet sln "$SolutionPath" add "$relativePath" 2>&1 | Out-Null

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  [+] Added: $relativePath" -ForegroundColor Green
                } else {
                    Write-Host "  [!] Failed: $relativePath" -ForegroundColor Red
                }
            } catch {
                Write-Host "  [!] Error adding $relativePath : $_" -ForegroundColor Red
            } finally {
                Pop-Location
            }
        }

        Write-Host ""
        Write-Host "[+] Auto-fix complete!" -ForegroundColor Green
    } else {
        Write-Host "Run with -AutoFix to automatically add these projects to the solution." -ForegroundColor Cyan
    }

    exit 1
}
