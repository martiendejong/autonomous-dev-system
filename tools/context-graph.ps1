<#
.SYNOPSIS
    Context Graph & Knowledge Management
    50-Expert Council Improvements #3, #26, #29, #30 | Priority: 1.4, 1.125, 1.6, 2.0

.DESCRIPTION
    Builds semantic connections between documents.
    Manages knowledge compression and deduplication.

.PARAMETER Build
    Build/rebuild context graph.

.PARAMETER Search
    Search across all knowledge.

.PARAMETER Compress
    Compress session learnings.

.PARAMETER Dedupe
    Deduplicate insights.

.EXAMPLE
    context-graph.ps1 -Build
    context-graph.ps1 -Search "worktree"
#>

param(
    [switch]$Build,
    [string]$Search = "",
    [switch]$Compress,
    [switch]$Dedupe
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$GraphFile = "C:\scripts\_machine\context_graph.json"
$DocsPath = "C:\scripts\_machine"

if (-not (Test-Path $GraphFile)) {
    @{
        nodes = @()
        edges = @()
        lastBuild = $null
    } | ConvertTo-Json -Depth 10 | Set-Content $GraphFile -Encoding UTF8
}

$graph = Get-Content $GraphFile -Raw | ConvertFrom-Json

function Build-ContextGraph {
    Write-Host "=== BUILDING CONTEXT GRAPH ===" -ForegroundColor Cyan
    Write-Host ""

    $docs = Get-ChildItem $DocsPath -Filter "*.md" -ErrorAction SilentlyContinue
    $docs += Get-ChildItem $DocsPath -Filter "*.json" -ErrorAction SilentlyContinue

    $nodes = @()
    $keywords = @{}

    foreach ($doc in $docs) {
        $content = Get-Content $doc.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        # Extract keywords
        $words = ($content -replace '[^\w\s]', ' ') -split '\s+' | Where-Object { $_.Length -gt 4 } | Select-Object -Unique

        $node = @{
            id = $doc.Name
            path = $doc.FullName
            keywords = ($words | Select-Object -First 20)
            size = $content.Length
        }
        $nodes += $node

        foreach ($word in $words | Select-Object -First 20) {
            if (-not $keywords[$word]) { $keywords[$word] = @() }
            $keywords[$word] += $doc.Name
        }

        Write-Host "  + $($doc.Name) ($($words.Count) keywords)" -ForegroundColor Gray
    }

    # Build edges from shared keywords
    $edges = @()
    foreach ($kw in $keywords.GetEnumerator()) {
        if ($kw.Value.Count -gt 1) {
            for ($i = 0; $i -lt $kw.Value.Count - 1; $i++) {
                for ($j = $i + 1; $j -lt $kw.Value.Count; $j++) {
                    $edges += @{
                        source = $kw.Value[$i]
                        target = $kw.Value[$j]
                        keyword = $kw.Key
                    }
                }
            }
        }
    }

    $graph.nodes = $nodes
    $graph.edges = $edges | Select-Object -First 100
    $graph.lastBuild = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $graph | ConvertTo-Json -Depth 10 | Set-Content $GraphFile -Encoding UTF8

    Write-Host ""
    Write-Host "✓ Graph built" -ForegroundColor Green
    Write-Host "  Nodes: $($nodes.Count)" -ForegroundColor Yellow
    Write-Host "  Edges: $($edges.Count)" -ForegroundColor Yellow
}

function Search-Knowledge {
    param([string]$Query)

    Write-Host "=== KNOWLEDGE SEARCH: $Query ===" -ForegroundColor Cyan
    Write-Host ""

    $results = @()

    foreach ($node in $graph.nodes) {
        $score = 0
        foreach ($kw in $node.keywords) {
            if ($kw -match $Query) { $score += 10 }
        }
        if ($node.id -match $Query) { $score += 20 }

        if ($score -gt 0) {
            $results += @{
                file = $node.id
                score = $score
                path = $node.path
            }
        }
    }

    $results = $results | Sort-Object score -Descending | Select-Object -First 10

    if ($results.Count -eq 0) {
        Write-Host "No results found for '$Query'" -ForegroundColor Yellow
    } else {
        foreach ($r in $results) {
            Write-Host "[$($r.score)] $($r.file)" -ForegroundColor Green
            Write-Host "  $($r.path)" -ForegroundColor Gray
        }
    }

    # Show related nodes
    $related = $graph.edges | Where-Object { $_.keyword -match $Query } | Select-Object -First 5
    if ($related.Count -gt 0) {
        Write-Host ""
        Write-Host "RELATED CONNECTIONS:" -ForegroundColor Magenta
        foreach ($e in $related) {
            Write-Host "  $($e.source) ↔ $($e.target) (via: $($e.keyword))" -ForegroundColor Gray
        }
    }
}

function Compress-Learnings {
    Write-Host "=== COMPRESSING LEARNINGS ===" -ForegroundColor Cyan
    Write-Host ""

    # Read recent reflections and compress
    $reflectionLog = "C:\scripts\_machine\reflection.log.md"
    if (Test-Path $reflectionLog) {
        $content = Get-Content $reflectionLog -Raw

        # Extract key insights (lines with specific markers)
        $insights = [regex]::Matches($content, '(?m)^\*\*.*?\*\*.*$') | ForEach-Object { $_.Value }

        Write-Host "Extracted $($insights.Count) key insights" -ForegroundColor Yellow

        # Save compressed version
        $compressed = @{
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            insightCount = $insights.Count
            topInsights = $insights | Select-Object -First 20
        }

        $compressedFile = "C:\scripts\_machine\compressed_learnings.json"
        $compressed | ConvertTo-Json -Depth 10 | Set-Content $compressedFile -Encoding UTF8

        Write-Host "✓ Compressed to: $compressedFile" -ForegroundColor Green
    }
}

function Deduplicate-Insights {
    Write-Host "=== DEDUPLICATING INSIGHTS ===" -ForegroundColor Cyan
    Write-Host ""

    $patternLib = "C:\scripts\_machine\pattern_library.json"
    if (Test-Path $patternLib) {
        $lib = Get-Content $patternLib -Raw | ConvertFrom-Json

        $unique = @()
        $seen = @{}

        foreach ($p in $lib.patterns) {
            $key = ($p.pattern -replace '\s+', ' ').ToLower().Substring(0, [Math]::Min(50, $p.pattern.Length))
            if (-not $seen[$key]) {
                $seen[$key] = $true
                $unique += $p
            }
        }

        $removed = $lib.patterns.Count - $unique.Count
        $lib.patterns = $unique
        $lib | ConvertTo-Json -Depth 10 | Set-Content $patternLib -Encoding UTF8

        Write-Host "Removed $removed duplicate patterns" -ForegroundColor Yellow
        Write-Host "Remaining: $($unique.Count) unique patterns" -ForegroundColor Green
    }
}

# Main
if ($Build) { Build-ContextGraph }
elseif ($Search) { Search-Knowledge -Query $Search }
elseif ($Compress) { Compress-Learnings }
elseif ($Dedupe) { Deduplicate-Insights }
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Build            Build context graph" -ForegroundColor White
    Write-Host "  -Search <query>   Search knowledge" -ForegroundColor White
    Write-Host "  -Compress         Compress learnings" -ForegroundColor White
    Write-Host "  -Dedupe           Deduplicate insights" -ForegroundColor White
}
