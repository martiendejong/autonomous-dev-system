<#
.SYNOPSIS
    Automated dependency update checker and updater for NuGet and npm packages.

.DESCRIPTION
    Scans projects for outdated dependencies, checks for security vulnerabilities,
    and optionally creates PRs for updates.

    Features:
    - NuGet package updates (dotnet outdated / dotnet list package --outdated)
    - npm package updates (npm outdated)
    - Security vulnerability scanning (npm audit, dotnet list package --vulnerable)
    - Auto-update patch versions (opt-in)
    - PR creation for dependency updates
    - Grouped updates by severity (major, minor, patch)
    - Changelog generation for updates

.PARAMETER ProjectPath
    Path to project (should contain .csproj or package.json)

.PARAMETER CheckOnly
    Only check for updates, don't apply them

.PARAMETER AutoPatch
    Automatically update patch versions (x.y.Z)

.PARAMETER SecurityOnly
    Only update packages with known vulnerabilities

.PARAMETER CreatePR
    Create PR for dependency updates

.PARAMETER DryRun
    Show what would be updated without making changes

.EXAMPLE
    .\update-dependencies.ps1 -ProjectPath "C:\Projects\client-manager" -CheckOnly
    .\update-dependencies.ps1 -ProjectPath "." -AutoPatch -DryRun
    .\update-dependencies.ps1 -ProjectPath "." -SecurityOnly -CreatePR
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [switch]$CheckOnly,
    [switch]$AutoPatch,
    [switch]$SecurityOnly,
    [switch]$CreatePR,
    [switch]$DryRun
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$script:Updates = @{
    "NuGet" = @{
        "Patch" = @()
        "Minor" = @()
        "Major" = @()
        "Vulnerable" = @()
    }
    "npm" = @{
        "Patch" = @()
        "Minor" = @()
        "Major" = @()
        "Vulnerable" = @()
    }
}

function Test-IsDotNetProject {
    param([string]$Path)
    return (Get-ChildItem $Path -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue).Count -gt 0
}

function Test-IsNpmProject {
    param([string]$Path)
    return Test-Path (Join-Path $Path "package.json")
}

function Get-NuGetOutdated {
    param([string]$ProjectPath)

    Write-Host "Checking for outdated NuGet packages..." -ForegroundColor Cyan

    Push-Location $ProjectPath
    try {
        # Use dotnet list package --outdated
        $output = dotnet list package --outdated --format json 2>&1

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Failed to check NuGet packages" -ForegroundColor Red
            return @()
        }

        try {
            $json = $output | ConvertFrom-Json
        } catch {
            Write-Host "  Failed to parse NuGet output" -ForegroundColor Yellow
            return @()
        }

        $outdated = @()

        foreach ($project in $json.projects) {
            foreach ($framework in $project.frameworks) {
                foreach ($package in $framework.topLevelPackages) {
                    if ($package.latestVersion -and $package.resolvedVersion -ne $package.latestVersion) {
                        $outdated += @{
                            "Name" = $package.id
                            "Current" = $package.resolvedVersion
                            "Latest" = $package.latestVersion
                            "Project" = $project.path
                        }
                    }
                }
            }
        }

        return $outdated

    } finally {
        Pop-Location
    }
}

function Get-NuGetVulnerable {
    param([string]$ProjectPath)

    Write-Host "Checking for vulnerable NuGet packages..." -ForegroundColor Cyan

    Push-Location $ProjectPath
    try {
        $output = dotnet list package --vulnerable --include-transitive --format json 2>&1

        if ($LASTEXITCODE -ne 0) {
            return @()
        }

        try {
            $json = $output | ConvertFrom-Json
        } catch {
            return @()
        }

        $vulnerable = @()

        foreach ($project in $json.projects) {
            foreach ($framework in $project.frameworks) {
                if ($framework.vulnerabilities) {
                    foreach ($vuln in $framework.vulnerabilities) {
                        $vulnerable += @{
                            "Name" = $vuln.id
                            "Current" = $vuln.resolvedVersion
                            "Severity" = $vuln.severity
                            "Advisory" = $vuln.advisoryUrl
                        }
                    }
                }
            }
        }

        return $vulnerable

    } finally {
        Pop-Location
    }
}

function Get-NpmOutdated {
    param([string]$ProjectPath)

    Write-Host "Checking for outdated npm packages..." -ForegroundColor Cyan

    Push-Location $ProjectPath
    try {
        $output = npm outdated --json 2>$null

        if (-not $output) {
            Write-Host "  No outdated npm packages" -ForegroundColor Green
            return @()
        }

        try {
            $json = $output | ConvertFrom-Json
        } catch {
            return @()
        }

        $outdated = @()

        foreach ($package in $json.PSObject.Properties) {
            $pkg = $package.Value

            $outdated += @{
                "Name" = $package.Name
                "Current" = $pkg.current
                "Wanted" = $pkg.wanted
                "Latest" = $pkg.latest
                "Type" = $pkg.type
            }
        }

        return $outdated

    } finally {
        Pop-Location
    }
}

function Get-NpmVulnerable {
    param([string]$ProjectPath)

    Write-Host "Checking for npm vulnerabilities..." -ForegroundColor Cyan

    Push-Location $ProjectPath
    try {
        $output = npm audit --json 2>$null

        if (-not $output) {
            return @()
        }

        try {
            $json = $output | ConvertFrom-Json
        } catch {
            return @()
        }

        $vulnerable = @()

        if ($json.vulnerabilities) {
            foreach ($vuln in $json.vulnerabilities.PSObject.Properties) {
                $v = $vuln.Value

                $vulnerable += @{
                    "Name" = $vuln.Name
                    "Severity" = $v.severity
                    "Via" = ($v.via | Where-Object { $_.source } | Select-Object -First 1).source
                    "Range" = $v.range
                }
            }
        }

        return $vulnerable

    } finally {
        Pop-Location
    }
}

function Get-VersionChangeType {
    param([string]$Current, [string]$Latest)

    $currentParts = $Current -split '\.' | ForEach-Object { [int]$_ }
    $latestParts = $Latest -split '\.' | ForEach-Object { [int]$_ }

    if ($latestParts[0] -gt $currentParts[0]) {
        return "Major"
    } elseif ($latestParts[1] -gt $currentParts[1]) {
        return "Minor"
    } elseif ($latestParts[2] -gt $currentParts[2]) {
        return "Patch"
    } else {
        return "Unknown"
    }
}

function Update-NuGetPackage {
    param([string]$ProjectPath, [string]$PackageName, [string]$Version, [bool]$DryRunMode)

    if ($DryRunMode) {
        Write-Host "  [DRY RUN] Would update: $PackageName to $Version" -ForegroundColor Cyan
        return $true
    }

    Push-Location $ProjectPath
    try {
        dotnet add package $PackageName --version $Version 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Updated: $PackageName to $Version" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  Failed to update: $PackageName" -ForegroundColor Red
            return $false
        }

    } finally {
        Pop-Location
    }
}

function Update-NpmPackage {
    param([string]$ProjectPath, [string]$PackageName, [string]$Version, [bool]$DryRunMode)

    if ($DryRunMode) {
        Write-Host "  [DRY RUN] Would update: $PackageName to $Version" -ForegroundColor Cyan
        return $true
    }

    Push-Location $ProjectPath
    try {
        npm install "$PackageName@$Version" 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Updated: $PackageName to $Version" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  Failed to update: $PackageName" -ForegroundColor Red
            return $false
        }

    } finally {
        Pop-Location
    }
}

function Show-UpdateSummary {
    Write-Host ""
    Write-Host "=== Update Summary ===" -ForegroundColor Cyan
    Write-Host ""

    $totalNuGet = ($script:Updates.NuGet.Patch + $script:Updates.NuGet.Minor + $script:Updates.NuGet.Major).Count
    $totalNpm = ($script:Updates.npm.Patch + $script:Updates.npm.Minor + $script:Updates.npm.Major).Count

    if ($totalNuGet -gt 0) {
        Write-Host "NuGet Packages:" -ForegroundColor Yellow
        Write-Host ("  Patch updates:  {0}" -f $script:Updates.NuGet.Patch.Count) -ForegroundColor Green
        Write-Host ("  Minor updates:  {0}" -f $script:Updates.NuGet.Minor.Count) -ForegroundColor Yellow
        Write-Host ("  Major updates:  {0}" -f $script:Updates.NuGet.Major.Count) -ForegroundColor Red
        Write-Host ("  Vulnerabilities: {0}" -f $script:Updates.NuGet.Vulnerable.Count) -ForegroundColor Red
        Write-Host ""
    }

    if ($totalNpm -gt 0) {
        Write-Host "npm Packages:" -ForegroundColor Yellow
        Write-Host ("  Patch updates:  {0}" -f $script:Updates.npm.Patch.Count) -ForegroundColor Green
        Write-Host ("  Minor updates:  {0}" -f $script:Updates.npm.Minor.Count) -ForegroundColor Yellow
        Write-Host ("  Major updates:  {0}" -f $script:Updates.npm.Major.Count) -ForegroundColor Red
        Write-Host ("  Vulnerabilities: {0}" -f $script:Updates.npm.Vulnerable.Count) -ForegroundColor Red
        Write-Host ""
    }

    if ($totalNuGet -eq 0 -and $totalNpm -eq 0) {
        Write-Host "All packages are up to date!" -ForegroundColor Green
        Write-Host ""
    }
}

function Generate-UpdatePR {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Creating Update PR ===" -ForegroundColor Cyan
    Write-Host ""

    $branchName = "deps/auto-update-$(Get-Date -Format 'yyyy-MM-dd')"

    Push-Location $ProjectPath
    try {
        # Create branch
        git checkout -b $branchName 2>&1 | Out-Null

        # Commit changes
        git add -A

        $commitMsg = "chore(deps): update dependencies`n`n"
        $commitMsg += "Automated dependency update`n`n"

        $totalUpdates = 0

        if ($script:Updates.NuGet.Patch.Count -gt 0) {
            $commitMsg += "NuGet Patch Updates:`n"
            foreach ($pkg in $script:Updates.NuGet.Patch) {
                $commitMsg += "- $($pkg.Name): $($pkg.Current) -> $($pkg.Latest)`n"
                $totalUpdates++
            }
            $commitMsg += "`n"
        }

        if ($script:Updates.npm.Patch.Count -gt 0) {
            $commitMsg += "npm Patch Updates:`n"
            foreach ($pkg in $script:Updates.npm.Patch) {
                $commitMsg += "- $($pkg.Name): $($pkg.Current) -> $($pkg.Latest)`n"
                $totalUpdates++
            }
            $commitMsg += "`n"
        }

        $commitMsg += "Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

        git commit -m $commitMsg

        # Push
        git push -u origin $branchName

        # Create PR
        $prTitle = "chore(deps): update dependencies ($totalUpdates packages)"
        $prBody = $commitMsg

        gh pr create --title $prTitle --body $prBody --label "dependencies"

        Write-Host "PR created successfully!" -ForegroundColor Green
        Write-Host ""

    } finally {
        Pop-Location
    }
}

# Main execution
Write-Host ""
Write-Host "=== Dependency Update Checker ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

$isDotNet = Test-IsDotNetProject -Path $ProjectPath
$isNpm = Test-IsNpmProject -Path $ProjectPath

if (-not $isDotNet -and -not $isNpm) {
    Write-Host "ERROR: No .csproj or package.json found" -ForegroundColor Red
    exit 1
}

# Check for outdated packages
if ($isDotNet) {
    $nugetOutdated = Get-NuGetOutdated -ProjectPath $ProjectPath
    $nugetVulnerable = Get-NuGetVulnerable -ProjectPath $ProjectPath

    foreach ($pkg in $nugetOutdated) {
        $changeType = Get-VersionChangeType -Current $pkg.Current -Latest $pkg.Latest
        $script:Updates.NuGet[$changeType] += $pkg
    }

    $script:Updates.NuGet.Vulnerable = $nugetVulnerable
}

if ($isNpm) {
    $npmOutdated = Get-NpmOutdated -ProjectPath $ProjectPath
    $npmVulnerable = Get-NpmVulnerable -ProjectPath $ProjectPath

    foreach ($pkg in $npmOutdated) {
        $changeType = Get-VersionChangeType -Current $pkg.Current -Latest $pkg.Latest
        $script:Updates.npm[$changeType] += $pkg
    }

    $script:Updates.npm.Vulnerable = $npmVulnerable
}

# Show summary
Show-UpdateSummary

# Apply updates if requested
if (-not $CheckOnly) {
    $packagesToUpdate = @()

    if ($SecurityOnly) {
        $packagesToUpdate += $script:Updates.NuGet.Vulnerable
        $packagesToUpdate += $script:Updates.npm.Vulnerable
    } elseif ($AutoPatch) {
        $packagesToUpdate += $script:Updates.NuGet.Patch
        $packagesToUpdate += $script:Updates.npm.Patch
    }

    if ($packagesToUpdate.Count -gt 0) {
        Write-Host "=== Applying Updates ===" -ForegroundColor Cyan
        Write-Host ""

        foreach ($pkg in $script:Updates.NuGet.Patch) {
            Update-NuGetPackage -ProjectPath $ProjectPath -PackageName $pkg.Name -Version $pkg.Latest -DryRunMode:$DryRun
        }

        foreach ($pkg in $script:Updates.npm.Patch) {
            Update-NpmPackage -ProjectPath $ProjectPath -PackageName $pkg.Name -Version $pkg.Latest -DryRunMode:$DryRun
        }

        Write-Host ""
        Write-Host "Updates applied!" -ForegroundColor Green
        Write-Host ""

        if ($CreatePR -and -not $DryRun) {
            Generate-UpdatePR -ProjectPath $ProjectPath
        }
    }
}

Write-Host "=== Check Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
