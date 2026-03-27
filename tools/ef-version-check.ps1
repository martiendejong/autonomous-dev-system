#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verify all EF Core packages are at the same version
.DESCRIPTION
    Scans all .csproj files for EF Core package references and checks version consistency
.PARAMETER SolutionPath
    Path to solution or project directory (default: C:\Projects\client-manager)
.PARAMETER Fix
    Automatically update all EF Core packages to the same version
.EXAMPLE
    .\ef-version-check.ps1
.EXAMPLE
    .\ef-version-check.ps1 -SolutionPath C:\Projects\client-manager -Fix
#>

param(
    [string]$SolutionPath = "C:\Projects\client-manager",
    [switch]$Fix
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


Write-Host "=== EF Core Version Check ===" -ForegroundColor Cyan
Write-Host "Path: $SolutionPath" -ForegroundColor Gray
Write-Host ""

# Find all .csproj files
$projectFiles = Get-ChildItem -Path $SolutionPath -Filter "*.csproj" -Recurse

if ($projectFiles.Count -eq 0) {
    Write-Host "❌ No .csproj files found in $SolutionPath" -ForegroundColor Red
    exit 1
}

Write-Host "📦 Scanning $($projectFiles.Count) project(s)..." -ForegroundColor Cyan
Write-Host ""

# EF Core packages to check
$efPackages = @(
    "Microsoft.EntityFrameworkCore",
    "Microsoft.EntityFrameworkCore.Design",
    "Microsoft.EntityFrameworkCore.Sqlite",
    "Microsoft.EntityFrameworkCore.Tools",
    "Microsoft.EntityFrameworkCore.InMemory",
    "Microsoft.EntityFrameworkCore.SqlServer",
    "Microsoft.EntityFrameworkCore.Relational"
)

$versionMap = @{}
$mismatches = @()

foreach ($projectFile in $projectFiles) {
    $projectName = $projectFile.Name
    [xml]$project = Get-Content $projectFile.FullName

    foreach ($packageRef in $project.Project.ItemGroup.PackageReference) {
        $packageName = $packageRef.Include

        if ($efPackages -contains $packageName) {
            $version = $packageRef.Version

            if (-not $versionMap.ContainsKey($packageName)) {
                $versionMap[$packageName] = @{}
            }

            if (-not $versionMap[$packageName].ContainsKey($version)) {
                $versionMap[$packageName][$version] = @()
            }

            $versionMap[$packageName][$version] += $projectName
        }
    }
}

# Display results
$hasIssues = $false

foreach ($package in $versionMap.Keys | Sort-Object) {
    $versions = $versionMap[$package]

    if ($versions.Count -gt 1) {
        $hasIssues = $true
        Write-Host "❌ $package - VERSION MISMATCH!" -ForegroundColor Red

        foreach ($version in $versions.Keys | Sort-Object) {
            $projects = $versions[$version] -join ", "
            Write-Host "   v$version: $projects" -ForegroundColor Yellow
        }

        $mismatches += @{
            Package = $package
            Versions = $versions
        }
    } else {
        $version = $versions.Keys[0]
        Write-Host "✅ $package v$version" -ForegroundColor Green
    }
}

if (-not $hasIssues) {
    Write-Host ""
    Write-Host "✅ All EF Core packages are at consistent versions!" -ForegroundColor Green
    exit 0
}

# Check .NET version compatibility
Write-Host ""
Write-Host "📋 Version Compatibility:" -ForegroundColor Cyan
Write-Host "  .NET 8.0 → EF Core 8.x" -ForegroundColor Gray
Write-Host "  .NET 9.0 → EF Core 9.x" -ForegroundColor Gray

if ($Fix) {
    Write-Host ""
    Write-Host "🔧 Fixing version mismatches..." -ForegroundColor Yellow

    # Determine target version (use most common)
    $allVersions = @()
    foreach ($package in $mismatches) {
        foreach ($version in $package.Versions.Keys) {
            $allVersions += $version
        }
    }

    $targetVersion = $allVersions | Group-Object | Sort-Object Count -Descending | Select-Object -First 1 -ExpandProperty Name

    Write-Host "Target version: $targetVersion" -ForegroundColor Cyan

    foreach ($projectFile in $projectFiles) {
        $modified = $false
        [xml]$project = Get-Content $projectFile.FullName

        foreach ($packageRef in $project.Project.ItemGroup.PackageReference) {
            if ($efPackages -contains $packageRef.Include) {
                if ($packageRef.Version -ne $targetVersion) {
                    Write-Host "  Updating $($packageRef.Include) in $($projectFile.Name): $($packageRef.Version) → $targetVersion" -ForegroundColor Yellow
                    $packageRef.Version = $targetVersion
                    $modified = $true
                }
            }
        }

        if ($modified) {
            $project.Save($projectFile.FullName)
            Write-Host "  ✅ Updated $($projectFile.Name)" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "✅ Version fixes applied. Run 'dotnet restore' to update packages." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "⚠️  Version mismatches detected. Run with -Fix to automatically update." -ForegroundColor Yellow
    exit 1
}
