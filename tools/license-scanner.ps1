<#
.SYNOPSIS
    Scan dependencies for license conflicts and compliance issues

.DESCRIPTION
    Analyzes project dependencies for:
    - License types (MIT, GPL, Apache, proprietary, etc.)
    - License conflicts (GPL vs commercial)
    - Missing licenses
    - Risky licenses (AGPL, SSPL)
    - License compatibility

    Supports:
    - NuGet packages (.NET)
    - npm packages (JavaScript)
    - pip packages (Python)

.PARAMETER ProjectPath
    Path to project root

.PARAMETER PackageManager
    Package manager: nuget, npm, pip, auto

.PARAMETER AllowedLicenses
    Comma-separated list of allowed licenses (default: MIT,Apache-2.0,BSD-3-Clause)

.PARAMETER FailOnConflict
    Fail build if license conflicts found

.PARAMETER OutputFormat
    Output format: Table (default), JSON, CSV, SPDX

.EXAMPLE
    # Scan all dependencies
    .\license-scanner.ps1

.EXAMPLE
    # Only allow specific licenses
    .\license-scanner.ps1 -AllowedLicenses "MIT,Apache-2.0" -FailOnConflict

.NOTES
    Value: 9/10 - Legal compliance is critical
    Effort: 1.1/10 - Package metadata parsing
    Ratio: 8.2 (TIER S+)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [ValidateSet('nuget', 'npm', 'pip', 'auto')]
    [string]$PackageManager = 'auto',

    [Parameter(Mandatory=$false)]
    [string]$AllowedLicenses = "MIT,Apache-2.0,BSD-3-Clause,BSD-2-Clause,ISC",

    [Parameter(Mandatory=$false)]
    [switch]$FailOnConflict = $false,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'JSON', 'CSV', 'SPDX')]
    [string]$OutputFormat = 'Table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "📜 License Scanner" -ForegroundColor Cyan
Write-Host "  Project: $ProjectPath" -ForegroundColor Gray
Write-Host ""

$allowedList = $AllowedLicenses -split ','

# License risk levels
$licenseRisk = @{
    'MIT' = 'LOW'
    'Apache-2.0' = 'LOW'
    'BSD-3-Clause' = 'LOW'
    'BSD-2-Clause' = 'LOW'
    'ISC' = 'LOW'
    'Unlicense' = 'LOW'
    'GPL-2.0' = 'HIGH'
    'GPL-3.0' = 'HIGH'
    'AGPL-3.0' = 'CRITICAL'
    'SSPL-1.0' = 'CRITICAL'
    'Proprietary' = 'CRITICAL'
    'Commercial' = 'CRITICAL'
    'UNKNOWN' = 'MEDIUM'
}

$packages = @()

# Detect package manager
if ($PackageManager -eq 'auto') {
    if (Test-Path "$ProjectPath/*.csproj" -PathType Leaf) {
        $PackageManager = 'nuget'
    } elseif (Test-Path "$ProjectPath/package.json") {
        $PackageManager = 'npm'
    } elseif (Test-Path "$ProjectPath/requirements.txt") {
        $PackageManager = 'pip'
    } else {
        Write-Host "❌ Could not auto-detect package manager" -ForegroundColor Red
        exit 1
    }
}

Write-Host "📦 Package manager: $PackageManager" -ForegroundColor Yellow
Write-Host ""

switch ($PackageManager) {
    'nuget' {
        # Get NuGet packages
        $csprojFiles = Get-ChildItem -Path $ProjectPath -Filter "*.csproj" -Recurse

        foreach ($csproj in $csprojFiles) {
            [xml]$proj = Get-Content $csproj.FullName
            $packageRefs = $proj.Project.ItemGroup.PackageReference

            foreach ($pkg in $packageRefs) {
                $pkgName = $pkg.Include
                $pkgVersion = $pkg.Version

                # Fetch license info from NuGet API
                $apiUrl = "https://api.nuget.org/v3/registration5-semver1/$($pkgName.ToLower())/index.json"

                try {
                    $response = Invoke-RestMethod -Uri $apiUrl -ErrorAction Stop
                    $latestVersion = $response.items[-1].items[-1]
                    $licenseUrl = $latestVersion.catalogEntry.licenseUrl
                    $licenseExpression = $latestVersion.catalogEntry.licenseExpression

                    $license = if ($licenseExpression) { $licenseExpression } elseif ($licenseUrl -match '(MIT|Apache|BSD|GPL)') { $Matches[1] } else { 'UNKNOWN' }

                    $packages += [PSCustomObject]@{
                        Name = $pkgName
                        Version = $pkgVersion
                        License = $license
                        LicenseUrl = $licenseUrl
                        Risk = $licenseRisk[$license]
                        Allowed = $license -in $allowedList
                    }
                } catch {
                    Write-Host "  ⚠️  Failed to fetch license for $pkgName" -ForegroundColor Yellow
                }
            }
        }
    }
    'npm' {
        # Use npm ls --json to get package info
        $npmOutput = npm ls --json --depth=0 2>$null | ConvertFrom-Json

        foreach ($dep in $npmOutput.dependencies.PSObject.Properties) {
            $pkgName = $dep.Name
            $pkgData = $dep.Value

            $license = if ($pkgData.license) { $pkgData.license } else { 'UNKNOWN' }

            $packages += [PSCustomObject]@{
                Name = $pkgName
                Version = $pkgData.version
                License = $license
                LicenseUrl = ""
                Risk = if ($licenseRisk.ContainsKey($license)) { $licenseRisk[$license] } else { 'MEDIUM' }
                Allowed = $license -in $allowedList
            }
        }
    }
    'pip' {
        # Use pip-licenses tool if available, otherwise parse requirements.txt
        $pipLicenses = pip-licenses --format json 2>$null

        if ($pipLicenses) {
            $licenses = $pipLicenses | ConvertFrom-Json

            foreach ($pkg in $licenses) {
                $packages += [PSCustomObject]@{
                    Name = $pkg.Name
                    Version = $pkg.Version
                    License = $pkg.License
                    LicenseUrl = ""
                    Risk = if ($licenseRisk.ContainsKey($pkg.License)) { $licenseRisk[$pkg.License] } else { 'MEDIUM' }
                    Allowed = $pkg.License -in $allowedList
                }
            }
        } else {
            Write-Host "⚠️  Install pip-licenses for accurate results: pip install pip-licenses" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "LICENSE ANALYSIS" -ForegroundColor Cyan
Write-Host ""

if ($packages.Count -eq 0) {
    Write-Host "No packages found" -ForegroundColor Yellow
    exit 0
}

# Find conflicts
$conflicts = $packages | Where-Object { -not $_.Allowed }
$critical = $packages | Where-Object { $_.Risk -eq 'CRITICAL' }

switch ($OutputFormat) {
    'Table' {
        $packages | Sort-Object Risk -Descending | Format-Table -AutoSize -Property @(
            @{Label='Package'; Expression={$_.Name}; Width=35}
            @{Label='Version'; Expression={$_.Version}; Width=12}
            @{Label='License'; Expression={$_.License}; Width=20}
            @{Label='Risk'; Expression={$_.Risk}; Width=10}
            @{Label='Allowed'; Expression={if($_.Allowed){"✅"}else{"❌"}}; Width=8}
        )

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Total packages: $($packages.Count)" -ForegroundColor Gray
        Write-Host "  Allowed licenses: $(($packages | Where-Object {$_.Allowed}).Count)" -ForegroundColor Green
        Write-Host "  Conflicts: $($conflicts.Count)" -ForegroundColor $(if($conflicts.Count -gt 0){"Red"}else{"Gray"})
        Write-Host "  CRITICAL risk: $($critical.Count)" -ForegroundColor $(if($critical.Count -gt 0){"Red"}else{"Gray"})
        Write-Host ""

        if ($conflicts.Count -gt 0) {
            Write-Host "❌ LICENSE CONFLICTS DETECTED:" -ForegroundColor Red
            Write-Host ""
            $conflicts | ForEach-Object {
                Write-Host "  $($_.Name) - $($_.License) [$($_.Risk) risk]" -ForegroundColor Yellow
            }
            Write-Host ""

            if ($FailOnConflict) {
                exit 1
            }
        } else {
            Write-Host "✅ All licenses comply with policy" -ForegroundColor Green
        }
    }
    'JSON' {
        @{
            TotalPackages = $packages.Count
            Conflicts = $conflicts.Count
            CriticalRisk = $critical.Count
            Packages = $packages
        } | ConvertTo-Json -Depth 10
    }
    'CSV' {
        $packages | ConvertTo-Csv -NoTypeInformation
    }
    'SPDX' {
        # SPDX format for software bill of materials
        Write-Host "SPDXVersion: SPDX-2.2"
        Write-Host "DataLicense: CC0-1.0"
        Write-Host "SPDXID: SPDXRef-DOCUMENT"
        Write-Host "DocumentName: $(Split-Path $ProjectPath -Leaf)"
        Write-Host "DocumentNamespace: https://example.com/$(Split-Path $ProjectPath -Leaf)"
        Write-Host "Creator: Tool: license-scanner"
        Write-Host ""

        foreach ($pkg in $packages) {
            Write-Host "PackageName: $($pkg.Name)"
            Write-Host "SPDXID: SPDXRef-Package-$($pkg.Name)"
            Write-Host "PackageVersion: $($pkg.Version)"
            Write-Host "PackageLicenseConcluded: $($pkg.License)"
            Write-Host ""
        }
    }
}
