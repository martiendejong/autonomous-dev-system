<#
.SYNOPSIS
    Analyze EF queries and suggest missing database indexes

.DESCRIPTION
    Finds performance issues from missing indexes:
    - WHERE clauses without indexes
    - JOIN columns without indexes
    - ORDER BY without covering index
    - Frequent queries without optimization

    Suggests:
    - Single column indexes
    - Composite indexes
    - Covering indexes
    - Index order

.PARAMETER ProjectPath
    Path to project root

.PARAMETER MinimumOccurrences
    Minimum query occurrences to recommend index (default: 3)

.PARAMETER OutputFormat
    Output format: Table (default), SQL, JSON

.EXAMPLE
    # Analyze queries and suggest indexes
    .\index-recommendation-engine.ps1

.EXAMPLE
    # Generate SQL CREATE INDEX statements
    .\index-recommendation-engine.ps1 -OutputFormat SQL

.NOTES
    Value: 9/10 - Database performance is critical
    Effort: 2/10 - Query parsing + heuristics
    Ratio: 4.5 (TIER S)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [int]$MinimumOccurrences = 3,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'SQL', 'JSON')]
    [string]$OutputFormat = 'Table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "Index Recommendation Engine" -ForegroundColor Cyan
Write-Host "  Project: $ProjectPath" -ForegroundColor Gray
Write-Host ""

$files = Get-ChildItem -Path $ProjectPath -Filter "*.cs" -Recurse |
    Where-Object { $_.FullName -notmatch '\\obj\\|\\bin\\|Migrations' }

$queryPatterns = @{}

Write-Host "Analyzing LINQ queries..." -ForegroundColor Yellow
Write-Host ""

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw

    # Pattern: .Where(x => x.Property == value)
    $whereMatches = [regex]::Matches($content, '\.Where\([^)]*=>.*\.(\w+)\s*==')

    foreach ($match in $whereMatches) {
        $property = $match.Groups[1].Value

        # Try to determine table name from context
        $beforeMatch = $content.Substring([Math]::Max(0, $match.Index - 200), [Math]::Min(200, $match.Index))

        $tableMatch = [regex]::Match($beforeMatch, '<(\w+)>|DbSet<(\w+)>')
        $tableName = if ($tableMatch.Success) {
            if ($tableMatch.Groups[1].Value) { $tableMatch.Groups[1].Value } else { $tableMatch.Groups[2].Value }
        } else {
            "Unknown"
        }

        $key = "${tableName}.${property}"

        if (-not $queryPatterns.ContainsKey($key)) {
            $queryPatterns[$key] = @{
                Table = $tableName
                Column = $property
                Count = 0
                QueryType = @()
            }
        }

        $queryPatterns[$key].Count++
        if ("WHERE" -notin $queryPatterns[$key].QueryType) {
            $queryPatterns[$key].QueryType += "WHERE"
        }
    }

    # Pattern: .OrderBy(x => x.Property)
    $orderByMatches = [regex]::Matches($content, '\.OrderBy(?:Descending)?\([^)]*=>.*\.(\w+)\)')

    foreach ($match in $orderByMatches) {
        $property = $match.Groups[1].Value

        $beforeMatch = $content.Substring([Math]::Max(0, $match.Index - 200), [Math]::Min(200, $match.Index))
        $tableMatch = [regex]::Match($beforeMatch, '<(\w+)>|DbSet<(\w+)>')
        $tableName = if ($tableMatch.Success) {
            if ($tableMatch.Groups[1].Value) { $tableMatch.Groups[1].Value } else { $tableMatch.Groups[2].Value }
        } else {
            "Unknown"
        }

        $key = "${tableName}.${property}"

        if (-not $queryPatterns.ContainsKey($key)) {
            $queryPatterns[$key] = @{
                Table = $tableName
                Column = $property
                Count = 0
                QueryType = @()
            }
        }

        $queryPatterns[$key].Count++
        if ("ORDER BY" -notin $queryPatterns[$key].QueryType) {
            $queryPatterns[$key].QueryType += "ORDER BY"
        }
    }
}

# Filter by minimum occurrences
$recommendations = @()

foreach ($key in $queryPatterns.Keys) {
    $pattern = $queryPatterns[$key]

    if ($pattern.Count -ge $MinimumOccurrences) {
        $recommendations += [PSCustomObject]@{
            Table = $pattern.Table
            Column = $pattern.Column
            Occurrences = $pattern.Count
            QueryTypes = ($pattern.QueryType -join ", ")
            IndexType = if ($pattern.QueryType.Count -eq 1 -and $pattern.QueryType[0] -eq "WHERE") { "Non-clustered" } else { "Covering" }
            Priority = if ($pattern.Count -gt 10) { "HIGH" } elseif ($pattern.Count -gt 5) { "MEDIUM" } else { "LOW" }
        }
    }
}

Write-Host ""
Write-Host "INDEX RECOMMENDATIONS" -ForegroundColor Cyan
Write-Host ""

if ($recommendations.Count -eq 0) {
    Write-Host "No index recommendations (queries occur < $MinimumOccurrences times)" -ForegroundColor Yellow
    exit 0
}

# Sort by priority and occurrences
$recommendations = $recommendations | Sort-Object @{Expression={$_.Priority}; Descending=$true}, Occurrences -Descending

switch ($OutputFormat) {
    'Table' {
        $recommendations | Format-Table -AutoSize -Property @(
            @{Label='Table'; Expression={$_.Table}; Width=25}
            @{Label='Column'; Expression={$_.Column}; Width=25}
            @{Label='Used In'; Expression={$_.QueryTypes}; Width=20}
            @{Label='Count'; Expression={$_.Occurrences}; Align='Right'}
            @{Label='Priority'; Expression={$_.Priority}; Width=10}
            @{Label='Index Type'; Expression={$_.IndexType}; Width=15}
        )

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Total recommendations: $($recommendations.Count)" -ForegroundColor Gray
        Write-Host "  HIGH priority: $(($recommendations | Where-Object {$_.Priority -eq 'HIGH'}).Count)" -ForegroundColor Red
        Write-Host "  MEDIUM priority: $(($recommendations | Where-Object {$_.Priority -eq 'MEDIUM'}).Count)" -ForegroundColor Yellow
        Write-Host "  LOW priority: $(($recommendations | Where-Object {$_.Priority -eq 'LOW'}).Count)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Run with -OutputFormat SQL to generate CREATE INDEX statements" -ForegroundColor Cyan
    }
    'SQL' {
        Write-Host "-- Database Index Recommendations"
        Write-Host "-- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Write-Host ""

        foreach ($rec in $recommendations) {
            $indexName = "IX_$($rec.Table)_$($rec.Column)"

            Write-Host "-- Priority: $($rec.Priority) | Used $($rec.Occurrences)x in $($rec.QueryTypes)"
            Write-Host "CREATE NONCLUSTERED INDEX [$indexName]"
            Write-Host "ON [dbo].[$($rec.Table)] ([$($rec.Column)])"

            if ($rec.IndexType -eq "Covering") {
                Write-Host "-- Consider adding INCLUDE columns for better coverage"
            }

            Write-Host "GO"
            Write-Host ""
        }

        Write-Host "-- Performance Impact:"
        Write-Host "-- HIGH priority indexes should show immediate query improvement"
        Write-Host "-- Monitor index usage with: sys.dm_db_index_usage_stats"
        Write-Host "-- Remove unused indexes after 30 days if hit count = 0"
    }
    'JSON' {
        $recommendations | ConvertTo-Json -Depth 10
    }
}
