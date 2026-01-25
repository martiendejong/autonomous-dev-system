<#
.SYNOPSIS
    Naming Convention Enforcer
    50-Expert Council V2 Improvement #28 | Priority: 2.0

.DESCRIPTION
    Ensures consistent naming across codebase.

.PARAMETER Check
    Check naming conventions.

.PARAMETER Path
    Path to check.

.PARAMETER Fix
    Suggest fixes.

.EXAMPLE
    naming-enforce.ps1 -Check -Path "src/"
#>

param(
    [switch]$Check,
    [string]$Path = ".",
    [switch]$Fix,
    [string]$Type = "all"
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$conventions = @{
    "csharp" = @{
        "class" = @{ pattern = '^[A-Z][a-zA-Z0-9]+$'; example = 'UserService' }
        "interface" = @{ pattern = '^I[A-Z][a-zA-Z0-9]+$'; example = 'IUserService' }
        "method" = @{ pattern = '^[A-Z][a-zA-Z0-9]+$'; example = 'GetUser' }
        "property" = @{ pattern = '^[A-Z][a-zA-Z0-9]+$'; example = 'UserId' }
        "field" = @{ pattern = '^_[a-z][a-zA-Z0-9]*$'; example = '_userId' }
        "const" = @{ pattern = '^[A-Z][A-Z0-9_]+$'; example = 'MAX_RETRIES' }
        "param" = @{ pattern = '^[a-z][a-zA-Z0-9]*$'; example = 'userId' }
    }
    "typescript" = @{
        "class" = @{ pattern = '^[A-Z][a-zA-Z0-9]+$'; example = 'UserService' }
        "interface" = @{ pattern = '^[A-Z][a-zA-Z0-9]+$'; example = 'User' }
        "function" = @{ pattern = '^[a-z][a-zA-Z0-9]+$'; example = 'getUser' }
        "const" = @{ pattern = '^[A-Z_]+$|^[a-z][a-zA-Z0-9]+$'; example = 'MAX_RETRIES or apiUrl' }
        "variable" = @{ pattern = '^[a-z][a-zA-Z0-9]*$'; example = 'userId' }
        "component" = @{ pattern = '^[A-Z][a-zA-Z0-9]+$'; example = 'UserProfile' }
    }
)

if ($Check) {
    Write-Host "=== NAMING CONVENTION CHECKER ===" -ForegroundColor Cyan
    Write-Host ""

    $files = Get-ChildItem -Path $Path -Recurse -Include "*.cs", "*.ts", "*.tsx" -ErrorAction SilentlyContinue |
             Where-Object { $_.FullName -notmatch 'node_modules|bin|obj|dist|\.d\.ts$' }

    $violations = @()

    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $lang = if ($file.Extension -eq ".cs") { "csharp" } else { "typescript" }
        $conv = $conventions[$lang]

        # Check class names
        $classes = [regex]::Matches($content, '(?:class|interface)\s+(\w+)')
        foreach ($m in $classes) {
            $name = $m.Groups[1].Value
            $type = if ($content -match "interface\s+$name") { "interface" } else { "class" }
            $pattern = $conv[$type].pattern

            if ($name -notmatch $pattern) {
                $violations += @{
                    file = $file.Name
                    type = $type
                    name = $name
                    expected = $conv[$type].example
                }
            }
        }

        # Check C# specific
        if ($lang -eq "csharp") {
            # Private fields
            $fields = [regex]::Matches($content, 'private\s+\w+\s+(\w+)\s*[;=]')
            foreach ($m in $fields) {
                $name = $m.Groups[1].Value
                if ($name -notmatch $conv.field.pattern) {
                    $violations += @{
                        file = $file.Name
                        type = "field"
                        name = $name
                        expected = $conv.field.example
                    }
                }
            }
        }

        # Check TypeScript specific
        if ($lang -eq "typescript") {
            # Function names
            $funcs = [regex]::Matches($content, '(?:function|const)\s+(\w+)\s*[=\(]')
            foreach ($m in $funcs) {
                $name = $m.Groups[1].Value
                if ($name.Length -gt 2 -and $name -cmatch '^[A-Z]' -and $content -notmatch "React|Component") {
                    # Might be a component - OK
                }
                elseif ($name -notmatch $conv.function.pattern -and $name.Length -gt 2) {
                    $violations += @{
                        file = $file.Name
                        type = "function"
                        name = $name
                        expected = $conv.function.example
                    }
                }
            }
        }
    }

    Write-Host "ANALYSIS RESULTS" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Files checked: $($files.Count)" -ForegroundColor White
    Write-Host "  Violations found: $($violations.Count)" -ForegroundColor $(if ($violations.Count -gt 20) { "Red" } elseif ($violations.Count -gt 5) { "Yellow" } else { "Green" })
    Write-Host ""

    if ($violations.Count -gt 0) {
        # Group by type
        $byType = $violations | Group-Object type
        Write-Host "BY TYPE:" -ForegroundColor Yellow
        foreach ($g in $byType) {
            Write-Host "  $($g.Name): $($g.Count)" -ForegroundColor White
        }
        Write-Host ""

        Write-Host "VIOLATIONS:" -ForegroundColor Yellow
        foreach ($v in $violations | Select-Object -First 20) {
            Write-Host "  [$($v.type)] $($v.name) in $($v.file)" -ForegroundColor White
            if ($Fix) {
                Write-Host "     → Should be like: $($v.expected)" -ForegroundColor Gray
            }
        }
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Check -Path 'x'     Check naming conventions" -ForegroundColor White
    Write-Host "  -Fix                 Show fix suggestions" -ForegroundColor White
}
