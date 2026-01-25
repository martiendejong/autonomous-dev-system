<#
.SYNOPSIS
    Detect N+1 query patterns in Entity Framework code via static analysis

.DESCRIPTION
    Scans C# codebase for common N+1 query anti-patterns:
    - Iterating over collection and querying database inside loop
    - Missing Include/ThenInclude for navigation properties
    - Select N+1 pattern (Select().ToList() in loop)
    - Lazy loading triggers in loops

    N+1 queries cause severe performance issues:
    - 1 query to get parent entities
    - N queries to get related data for each parent
    - Solution: Use .Include() or batch loading

.PARAMETER ProjectPath
    Path to project root (default: current directory)

.PARAMETER FilePattern
    File pattern to scan (default: *.cs)

.PARAMETER OutputFormat
    Output format: Table (default), JSON, CSV

.PARAMETER Confidence
    Minimum confidence level to report (1-10, default: 6)

.EXAMPLE
    # Scan current project for N+1 queries
    .\n-plus-one-query-detector.ps1

.EXAMPLE
    # High confidence only
    .\n-plus-one-query-detector.ps1 -Confidence 8

.EXAMPLE
    # Export to JSON
    .\n-plus-one-query-detector.ps1 -OutputFormat JSON > n-plus-one-issues.json

.NOTES
    Value: 10/10 - N+1 queries are critical performance killers
    Effort: 1.5/10 - Pattern matching with heuristics
    Ratio: 6.7 (TIER S)

    Common patterns detected:
    1. foreach (var item in items) { db.RelatedEntities.Where(...).ToList() }
    2. items.Select(x => x.RelatedEntity) without Include
    3. Lazy loading in loops (item.RelatedEntity access)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [string]$FilePattern = "*.cs",

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'JSON', 'CSV')]
    [string]$OutputFormat = 'Table',

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 10)]
    [int]$Confidence = 6
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🔍 Scanning for N+1 query patterns in: $ProjectPath" -ForegroundColor Cyan
Write-Host "   Pattern: $FilePattern" -ForegroundColor Gray
Write-Host "   Min confidence: $Confidence/10" -ForegroundColor Gray
Write-Host ""

# Get all C# files
$files = Get-ChildItem -Path $ProjectPath -Filter $FilePattern -Recurse -File |
    Where-Object { $_.FullName -notmatch '\.g\.cs$|\.designer\.cs$' }

if ($files.Count -eq 0) {
    Write-Host "⚠️  No files found" -ForegroundColor Yellow
    exit 0
}

Write-Host "📁 Analyzing $($files.Count) files..." -ForegroundColor Yellow
Write-Host ""

$issues = @()

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $lines = Get-Content $file.FullName

    # Pattern 1: Database query inside foreach loop
    # foreach (var x in collection) { ... .Where(...) ... }
    $foreachMatches = [regex]::Matches($content, 'foreach\s*\([^)]+\)\s*\{([^}]+)\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)

    foreach ($match in $foreachMatches) {
        $loopBody = $match.Groups[1].Value

        # Check for EF query methods in loop body
        if ($loopBody -match '\.Where\(|\.FirstOrDefault\(|\.ToList\(|\.Single\(|\.Any\(') {
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count

            $issues += [PSCustomObject]@{
                File = $file.Name
                FilePath = $file.FullName
                Line = $lineNumber
                Pattern = 'Query in foreach loop'
                Code = $match.Value.Substring(0, [Math]::Min(100, $match.Value.Length)) + "..."
                Confidence = 9
                Impact = 'HIGH'
                Suggestion = 'Move query outside loop or use .Include() to eager load'
            }
        }
    }

    # Pattern 2: Navigation property access in loop without Include
    # foreach (var x in items) { ... x.NavigationProperty ... }
    # Check if parent query uses .Include()
    $foreachWithNavigation = [regex]::Matches($content, 'foreach\s*\(\s*var\s+(\w+)\s+in\s+(\w+)\s*\)\s*\{([^}]+)\}', [System.Text.RegularExpressions.RegexOptions]::Singleline)

    foreach ($match in $foreachWithNavigation) {
        $itemVar = $match.Groups[1].Value
        $collectionVar = $match.Groups[2].Value
        $loopBody = $match.Groups[3].Value

        # Check if item variable has property access (likely navigation property)
        if ($loopBody -match "$itemVar\.[\w]+") {
            # Check if collection was loaded with Include
            $hasInclude = $content -match "$collectionVar.*\.Include\("

            if (-not $hasInclude) {
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count

                $issues += [PSCustomObject]@{
                    File = $file.Name
                    FilePath = $file.FullName
                    Line = $lineNumber
                    Pattern = 'Potential lazy loading in loop'
                    Code = $match.Value.Substring(0, [Math]::Min(100, $match.Value.Length)) + "..."
                    Confidence = 6
                    Impact = 'MEDIUM'
                    Suggestion = "Use .Include() when loading $collectionVar to eager load navigation properties"
                }
            }
        }
    }

    # Pattern 3: Select with ToList inside another Select
    # items.Select(x => x.RelatedEntities.Where(...).ToList())
    $selectMatches = [regex]::Matches($content, '\.Select\([^)]*\.Where\([^)]*\)\.ToList\(\)')

    foreach ($match in $selectMatches) {
        $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count

        $issues += [PSCustomObject]@{
            File = $file.Name
            FilePath = $file.FullName
            Line = $lineNumber
            Pattern = 'Select with nested query'
            Code = $match.Value
            Confidence = 8
            Impact = 'HIGH'
            Suggestion = 'Use .Include() or batch loading instead of nested Select'
        }
    }

    # Pattern 4: Multiple FirstOrDefault/SingleOrDefault calls in sequence
    # Indicates possible N queries pattern
    $multipleFirstOrDefault = [regex]::Matches($content, '(\.FirstOrDefault\(|\.SingleOrDefault\()[^;]+;', [System.Text.RegularExpressions.RegexOptions]::Multiline)

    if ($multipleFirstOrDefault.Count -ge 3) {
        # Check if they're close together (within 10 lines)
        $firstLine = ($content.Substring(0, $multipleFirstOrDefault[0].Index) -split "`n").Count
        $lastLine = ($content.Substring(0, $multipleFirstOrDefault[-1].Index) -split "`n").Count

        if ($lastLine - $firstLine -le 10) {
            $issues += [PSCustomObject]@{
                File = $file.Name
                FilePath = $file.FullName
                Line = $firstLine
                Pattern = 'Multiple sequential queries'
                Code = "$($multipleFirstOrDefault.Count) FirstOrDefault/SingleOrDefault calls within 10 lines"
                Confidence = 7
                Impact = 'MEDIUM'
                Suggestion = 'Consider batching queries or using a join/include'
            }
        }
    }
}

# Filter by confidence
$issues = $issues | Where-Object { $_.Confidence -ge $Confidence } | Sort-Object Impact, Confidence -Descending

# Output results
Write-Host ""
Write-Host "🚨 N+1 QUERY PATTERN ANALYSIS" -ForegroundColor Red
Write-Host ""

if ($issues.Count -eq 0) {
    Write-Host "✅ No N+1 query patterns detected (with confidence >= $Confidence)" -ForegroundColor Green
    exit 0
}

switch ($OutputFormat) {
    'Table' {
        $issues | Format-Table -AutoSize -Wrap -Property @(
            @{Label='File'; Expression={$_.File}; Width=25}
            @{Label='Line'; Expression={$_.Line}; Align='Right'; Width=5}
            @{Label='Pattern'; Expression={$_.Pattern}; Width=25}
            @{Label='Impact'; Expression={$_.Impact}; Width=8}
            @{Label='Conf'; Expression={"$($_.Confidence)/10"}; Align='Right'; Width=5}
            @{Label='Suggestion'; Expression={$_.Suggestion}; Width=50}
        )

        # Summary
        Write-Host ""
        Write-Host "📈 Summary:" -ForegroundColor Cyan
        Write-Host "   Total issues: $($issues.Count)" -ForegroundColor Gray
        Write-Host "   HIGH impact: $(($issues | Where-Object {$_.Impact -eq 'HIGH'}).Count)" -ForegroundColor Red
        Write-Host "   MEDIUM impact: $(($issues | Where-Object {$_.Impact -eq 'MEDIUM'}).Count)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "💡 Recommended Actions:" -ForegroundColor Yellow
        Write-Host "   1. Review HIGH impact issues first" -ForegroundColor Gray
        Write-Host "   2. Add .Include() for navigation properties" -ForegroundColor Gray
        Write-Host "   3. Use batch loading instead of loops" -ForegroundColor Gray
        Write-Host "   4. Consider caching for frequently accessed data" -ForegroundColor Gray
        Write-Host ""
        Write-Host "📚 Learn more: https://learn.microsoft.com/en-us/ef/core/querying/related-data/" -ForegroundColor Cyan
    }
    'JSON' {
        $issues | ConvertTo-Json -Depth 10
    }
    'CSV' {
        $issues | ConvertTo-Csv -NoTypeInformation
    }
}
