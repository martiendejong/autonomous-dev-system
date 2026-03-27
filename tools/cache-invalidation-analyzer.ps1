<#
.SYNOPSIS
    Find cache invalidation bugs and suggest strategies

.DESCRIPTION
    Analyzes caching code for common issues:
    - Missing invalidation on updates/deletes
    - Cache key collisions
    - Stale cache problems
    - Cache stampede vulnerabilities
    - Memory leak patterns

    "There are only two hard things in Computer Science: cache invalidation and naming things" - Phil Karlton

.PARAMETER ProjectPath
    Path to project root

.PARAMETER CacheType
    Cache type: memory, redis, distributed, all

.PARAMETER OutputFormat
    Output format: Table (default), JSON

.EXAMPLE
    # Analyze all caching code
    .\cache-invalidation-analyzer.ps1

.EXAMPLE
    # Focus on Redis cache issues
    .\cache-invalidation-analyzer.ps1 -CacheType redis

.NOTES
    Value: 8/10 - Cache bugs are subtle and hard to debug
    Effort: 1.5/10 - Pattern matching
    Ratio: 5.3 (TIER S)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ProjectPath = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [ValidateSet('memory', 'redis', 'distributed', 'all')]
    [string]$CacheType = 'all',

    [Parameter(Mandatory=$false)]
    [ValidateSet('Table', 'JSON')]
    [string]$OutputFormat = 'Table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "Cache Invalidation Analyzer" -ForegroundColor Cyan
Write-Host "  Project: $ProjectPath" -ForegroundColor Gray
Write-Host ""

$files = Get-ChildItem -Path $ProjectPath -Filter "*.cs" -Recurse |
    Where-Object { $_.FullName -notmatch '\\obj\\|\\bin\\' }

$issues = @()

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $lines = Get-Content $file.FullName

    # Pattern 1: Cache Get without corresponding invalidation on update
    $cacheGets = [regex]::Matches($content, '\.Get<([^>]+)>\("([^"]+)"\)|\.GetAsync<([^>]+)>\("([^"]+)"\)')

    foreach ($match in $cacheGets) {
        $cacheKey = if ($match.Groups[2].Value) { $match.Groups[2].Value } else { $match.Groups[4].Value }

        # Check if there's a Remove/Delete for this key
        $hasInvalidation = $content -match "\.Remove\(`"$cacheKey`"\)|\.RemoveAsync\(`"$cacheKey`"\)|\.Delete\(`"$cacheKey`"\)"

        if (-not $hasInvalidation) {
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count

            $issues += [PSCustomObject]@{
                File = $file.Name
                Line = $lineNumber
                Type = "Missing invalidation"
                Issue = "Cache key '$cacheKey' has no Remove/Delete"
                Severity = "MEDIUM"
                Suggestion = "Add cache invalidation when data changes"
            }
        }
    }

    # Pattern 2: Cache stampede - no lock around expensive operation
    $expensiveOps = [regex]::Matches($content, '(var\s+\w+\s*=\s*.*\.Get.*\(.*\);?\s*if\s*\(.*==\s*null\)\s*\{([^}]+)\})')

    foreach ($match in $expensiveOps) {
        $cacheCheckBlock = $match.Groups[2].Value

        # Check if expensive operation (db query, API call) without lock
        if ($cacheCheckBlock -match 'await.*Query|\.ToList|HttpClient|WebRequest' -and $cacheCheckBlock -notmatch 'lock|SemaphoreSlim') {
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count

            $issues += [PSCustomObject]@{
                File = $file.Name
                Line = $lineNumber
                Type = "Cache stampede vulnerability"
                Issue = "Expensive operation without lock"
                Severity = "HIGH"
                Suggestion = "Use SemaphoreSlim to prevent concurrent cache misses"
            }
        }
    }

    # Pattern 3: Hardcoded cache keys (collision risk)
    $hardcodedKeys = [regex]::Matches($content, '\.Get.*\("([a-z]+)"\)|\.Set.*\("([a-z]+)"\)')

    foreach ($match in $hardcodedKeys) {
        $key = if ($match.Groups[1].Value) { $match.Groups[1].Value } else { $match.Groups[2].Value }

        if ($key.Length -lt 10 -and $key -notmatch '\{|\$') {  # Short key without variables
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count

            $issues += [PSCustomObject]@{
                File = $file.Name
                Line = $lineNumber
                Type = "Collision risk"
                Issue = "Short hardcoded cache key: '$key'"
                Severity = "LOW"
                Suggestion = "Use namespaced keys with variables (e.g., 'user_{userId}_profile')"
            }
        }
    }

    # Pattern 4: Missing TTL/expiration
    $cacheSets = [regex]::Matches($content, '\.Set<[^>]+>\([^,)]+\)|\.SetAsync<[^>]+>\([^,)]+\)')

    foreach ($match in $cacheSets) {
        $setCall = $match.Value

        # Check if TTL is specified
        $hasTTL = $setCall -match 'TimeSpan|expiration|ttl|slidingExpiration'

        if (-not $hasTTL) {
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count

            $issues += [PSCustomObject]@{
                File = $file.Name
                Line = $lineNumber
                Type = "Missing TTL"
                Issue = "Cache.Set without expiration time"
                Severity = "MEDIUM"
                Suggestion = "Always set TTL to prevent stale data and memory leaks"
            }
        }
    }
}

Write-Host ""
Write-Host "CACHE INVALIDATION ANALYSIS" -ForegroundColor Cyan
Write-Host ""

if ($issues.Count -eq 0) {
    Write-Host "✅ No cache invalidation issues detected!" -ForegroundColor Green
    exit 0
}

switch ($OutputFormat) {
    'Table' {
        $issues | Format-Table -AutoSize -Wrap -Property @(
            @{Label='File'; Expression={$_.File}; Width=30}
            @{Label='Line'; Expression={$_.Line}; Align='Right'; Width=6}
            @{Label='Type'; Expression={$_.Type}; Width=30}
            @{Label='Severity'; Expression={$_.Severity}; Width=10}
            @{Label='Suggestion'; Expression={$_.Suggestion}; Width=50}
        )

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Total issues: $($issues.Count)" -ForegroundColor Gray
        Write-Host "  HIGH: $(($issues | Where-Object {$_.Severity -eq 'HIGH'}).Count)" -ForegroundColor Red
        Write-Host "  MEDIUM: $(($issues | Where-Object {$_.Severity -eq 'MEDIUM'}).Count)" -ForegroundColor Yellow
        Write-Host "  LOW: $(($issues | Where-Object {$_.Severity -eq 'LOW'}).Count)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "BEST PRACTICES:" -ForegroundColor Yellow
        Write-Host "  1. Always set TTL/expiration on cached items" -ForegroundColor Gray
        Write-Host "  2. Invalidate cache when underlying data changes" -ForegroundColor Gray
        Write-Host "  3. Use locks to prevent cache stampede" -ForegroundColor Gray
        Write-Host "  4. Use namespaced, descriptive cache keys" -ForegroundColor Gray
        Write-Host "  5. Monitor cache hit/miss rates" -ForegroundColor Gray
    }
    'JSON' {
        $issues | ConvertTo-Json -Depth 10
    }
}
