<#
.SYNOPSIS
    Dead Code Hunter
    50-Expert Council V2 Improvement #7 | Priority: 2.0

.DESCRIPTION
    Finds and removes unused code safely.
    Identifies unused imports, variables, functions.

.PARAMETER Scan
    Scan for dead code.

.PARAMETER Path
    Path to scan.

.PARAMETER Type
    Code type (cs, ts, all).

.PARAMETER Fix
    Attempt to remove dead code (use with caution).

.EXAMPLE
    dead-code.ps1 -Scan -Path "src/"
    dead-code.ps1 -Scan -Path "file.cs" -Type cs
#>

param(
    [switch]$Scan,
    [string]$Path = ".",
    [string]$Type = "all",
    [switch]$Fix,
    [switch]$Report
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


function Scan-CSharpFile {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return $null }

    $issues = @()

    # Unused using statements (simplified)
    $usings = [regex]::Matches($content, 'using\s+([\w.]+);')
    foreach ($using in $usings) {
        $ns = $using.Groups[1].Value
        $shortName = $ns -split '\.' | Select-Object -Last 1

        # Check if namespace is used (simplified check)
        $pattern = "(?<!using\s+[\w.]*)" + [regex]::Escape($shortName)
        if (-not ($content -match $pattern)) {
            $issues += @{
                type = "unused-using"
                text = "using $ns"
                line = ($content.Substring(0, $using.Index) -split "`n").Count
            }
        }
    }

    # Unused private fields
    $privateFields = [regex]::Matches($content, 'private\s+\w+\s+_(\w+)\s*[;=]')
    foreach ($field in $privateFields) {
        $name = "_" + $field.Groups[1].Value
        $count = ([regex]::Matches($content, [regex]::Escape($name))).Count
        if ($count -le 1) {
            $issues += @{
                type = "unused-field"
                text = $name
                line = ($content.Substring(0, $field.Index) -split "`n").Count
            }
        }
    }

    # Unused private methods
    $privateMethods = [regex]::Matches($content, 'private\s+\w+\s+(\w+)\s*\(')
    foreach ($method in $privateMethods) {
        $name = $method.Groups[1].Value
        $count = ([regex]::Matches($content, "\b" + [regex]::Escape($name) + "\b")).Count
        if ($count -le 1) {
            $issues += @{
                type = "unused-method"
                text = $name
                line = ($content.Substring(0, $method.Index) -split "`n").Count
            }
        }
    }

    # Empty catch blocks
    if ($content -match 'catch\s*\([^)]*\)\s*\{\s*\}') {
        $issues += @{
            type = "empty-catch"
            text = "Empty catch block"
            line = 0
        }
    }

    # Commented out code (large blocks)
    $commentedLines = [regex]::Matches($content, '//[^\r\n]*\r?\n//[^\r\n]*\r?\n//[^\r\n]*')
    if ($commentedLines.Count -gt 0) {
        $issues += @{
            type = "commented-code"
            text = "$($commentedLines.Count) blocks of commented code"
            line = 0
        }
    }

    return @{
        file = $FilePath
        issues = $issues
    }
}

function Scan-TypeScriptFile {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return $null }

    $issues = @()

    # Unused imports
    $imports = [regex]::Matches($content, "import\s+\{?\s*(\w+)")
    foreach ($import in $imports) {
        $name = $import.Groups[1].Value
        $count = ([regex]::Matches($content, "\b" + [regex]::Escape($name) + "\b")).Count
        if ($count -le 1 -and $name -ne "React") {
            $issues += @{
                type = "unused-import"
                text = $name
                line = ($content.Substring(0, $import.Index) -split "`n").Count
            }
        }
    }

    # Unused variables (const/let/var not used elsewhere)
    $variables = [regex]::Matches($content, '(const|let|var)\s+(\w+)\s*=')
    foreach ($v in $variables) {
        $name = $v.Groups[2].Value
        if ($name.Length -le 2) { continue }  # Skip short names
        $count = ([regex]::Matches($content, "\b" + [regex]::Escape($name) + "\b")).Count
        if ($count -le 1) {
            $issues += @{
                type = "unused-variable"
                text = $name
                line = ($content.Substring(0, $v.Index) -split "`n").Count
            }
        }
    }

    # console.log statements
    $consoleLogs = [regex]::Matches($content, 'console\.(log|debug|info)')
    if ($consoleLogs.Count -gt 0) {
        $issues += @{
            type = "console-log"
            text = "$($consoleLogs.Count) console statements"
            line = 0
        }
    }

    # TODO comments
    $todos = [regex]::Matches($content, '//\s*TODO')
    if ($todos.Count -gt 0) {
        $issues += @{
            type = "todo"
            text = "$($todos.Count) TODO comments"
            line = 0
        }
    }

    return @{
        file = $FilePath
        issues = $issues
    }
}

if ($Scan) {
    Write-Host "=== DEAD CODE HUNTER ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Path: $Path" -ForegroundColor Yellow
    Write-Host ""

    $files = @()

    if (Test-Path $Path -PathType Leaf) {
        $files = @(Get-Item $Path)
    }
    else {
        $extensions = switch ($Type) {
            "cs" { "*.cs" }
            "ts" { "*.ts", "*.tsx" }
            default { "*.cs", "*.ts", "*.tsx" }
        }

        $files = Get-ChildItem -Path $Path -Recurse -Include $extensions -ErrorAction SilentlyContinue |
                 Where-Object { $_.FullName -notmatch 'node_modules|bin|obj|dist|\.d\.ts$' }
    }

    $allResults = @()
    $totalIssues = 0

    foreach ($file in $files) {
        $result = if ($file.Extension -eq ".cs") {
            Scan-CSharpFile $file.FullName
        }
        else {
            Scan-TypeScriptFile $file.FullName
        }

        if ($result -and $result.issues.Count -gt 0) {
            $allResults += $result
            $totalIssues += $result.issues.Count
        }
    }

    Write-Host "SUMMARY:" -ForegroundColor Magenta
    Write-Host "  Files scanned: $($files.Count)" -ForegroundColor White
    Write-Host "  Files with issues: $($allResults.Count)" -ForegroundColor White
    Write-Host "  Total issues: $totalIssues" -ForegroundColor $(if ($totalIssues -gt 0) { "Yellow" } else { "Green" })
    Write-Host ""

    if ($Report -or $totalIssues -gt 0) {
        # Group by issue type
        $byType = @{}
        foreach ($r in $allResults) {
            foreach ($i in $r.issues) {
                if (-not $byType[$i.type]) { $byType[$i.type] = 0 }
                $byType[$i.type]++
            }
        }

        Write-Host "BY TYPE:" -ForegroundColor Yellow
        foreach ($t in $byType.Keys | Sort-Object) {
            Write-Host "  $t`: $($byType[$t])" -ForegroundColor White
        }
        Write-Host ""

        Write-Host "FILES WITH ISSUES:" -ForegroundColor Yellow
        foreach ($r in $allResults | Select-Object -First 20) {
            Write-Host "  $($r.file | Split-Path -Leaf)" -ForegroundColor White

            foreach ($i in $r.issues | Select-Object -First 5) {
                $icon = switch ($i.type) {
                    "unused-import" { "📦" }
                    "unused-using" { "📦" }
                    "unused-field" { "🔒" }
                    "unused-method" { "🔧" }
                    "unused-variable" { "📝" }
                    "console-log" { "🖥️" }
                    "todo" { "📋" }
                    default { "⚠️" }
                }
                Write-Host "    $icon $($i.type): $($i.text)" -ForegroundColor Gray
            }
            Write-Host ""
        }
    }

    if ($Fix) {
        Write-Host "⚠️  Auto-fix not implemented yet. Manual review recommended." -ForegroundColor Yellow
    }
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Scan -Path 'x'      Scan for dead code" -ForegroundColor White
    Write-Host "  -Type cs|ts|all      Filter by type" -ForegroundColor White
    Write-Host "  -Report              Show detailed report" -ForegroundColor White
}
