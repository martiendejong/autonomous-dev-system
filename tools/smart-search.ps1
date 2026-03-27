<#
.SYNOPSIS
    Context-aware documentation search across all Claude Agent docs.

.DESCRIPTION
    Natural language search that understands context and returns relevant
    documentation from CLAUDE.md, reflection logs, ADRs, skills, and more.

    Ranks results by relevance and recency, providing context snippets.

.PARAMETER Query
    Natural language search query

.PARAMETER Type
    Limit search to specific document types:
    - all (default)
    - docs (CLAUDE.md, MACHINE_CONFIG.md, etc.)
    - reflection (reflection.log.md)
    - skills (Claude Skills)
    - adr (Architecture Decision Records)
    - patterns (best-practices)

.PARAMETER Limit
    Maximum number of results (default: 10)

.PARAMETER Detailed
    Show full context, not just snippets

.EXAMPLE
    .\smart-search.ps1 -Query "How do I fix CI failures?"
    .\smart-search.ps1 -Query "base branch violations" -Type reflection
    .\smart-search.ps1 -Query "worktree allocation" -Type skills -Detailed
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Query,

    [ValidateSet("all", "docs", "reflection", "skills", "adr", "patterns")]
    [string]$Type = "all",

    [int]$Limit = 10,
    [switch]$Detailed
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$SearchPaths = @{
    "docs" = @(
        "C:\scripts\CLAUDE.md",
        "C:\scripts\MACHINE_CONFIG.md",
        "C:\scripts\GENERAL_*.md",
        "C:\scripts\*.md"
    )
    "reflection" = @(
        "C:\scripts\_machine\reflection.log.md"
    )
    "skills" = @(
        "C:\scripts\.claude\skills\**\SKILL.md"
    )
    "adr" = @(
        "C:\scripts\_machine\ADR\*.md"
    )
    "patterns" = @(
        "C:\scripts\_machine\best-practices\*.md",
        "C:\scripts\_machine\pattern-templates\*.md"
    )
}

function Get-SearchFiles {
    param([string]$SearchType)

    $files = @()

    if ($SearchType -eq "all") {
        foreach ($type in $SearchPaths.Keys) {
            foreach ($pattern in $SearchPaths[$type]) {
                $files += Get-ChildItem $pattern -File -ErrorAction SilentlyContinue
            }
        }
    } else {
        foreach ($pattern in $SearchPaths[$SearchType]) {
            $files += Get-ChildItem $pattern -File -ErrorAction SilentlyContinue
        }
    }

    return $files | Sort-Object -Unique
}

function Get-KeywordScore {
    param(
        [string]$Content,
        [string]$SearchQuery
    )

    $score = 0
    $contentLower = $Content.ToLower()
    $queryLower = $SearchQuery.ToLower()

    # Split query into keywords
    $keywords = $queryLower -split '\s+' | Where-Object { $_.Length -gt 2 }

    foreach ($keyword in $keywords) {
        # Exact phrase match (high score)
        if ($contentLower -like "*$queryLower*") {
            $score += 100
        }

        # Individual keyword matches
        $matches = ([regex]::Matches($contentLower, [regex]::Escape($keyword))).Count
        $score += $matches * 10

        # Header matches (higher weight)
        if ($contentLower -match "^#+.*$keyword" -or $contentLower -match "\n#+.*$keyword") {
            $score += 50
        }

        # Bold/emphasis matches
        if ($contentLower -match "\*\*.*$keyword.*\*\*") {
            $score += 25
        }
    }

    # Recency bonus (for reflection logs)
    if ($Content -match '## (\d{4})-(\d{2})-(\d{2})') {
        try {
            $date = [DateTime]::ParseExact($matches[0].Substring(3), "yyyy-MM-dd", $null)
            $daysSinceEntry = ((Get-Date) - $date).Days

            if ($daysSinceEntry -lt 7) {
                $score += 30
            } elseif ($daysSinceEntry -lt 30) {
                $score += 15
            } elseif ($daysSinceEntry -lt 90) {
                $score += 5
            }
        } catch {
            # Ignore parse errors
        }
    }

    return $score
}

function Get-ContextSnippet {
    param(
        [string]$Content,
        [string]$SearchQuery,
        [int]$ContextLines = 3
    )

    $lines = $Content -split "`n"
    $queryLower = $SearchQuery.ToLower()
    $snippets = @()

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].ToLower() -like "*$queryLower*") {
            $startLine = [Math]::Max(0, $i - $ContextLines)
            $endLine = [Math]::Min($lines.Count - 1, $i + $ContextLines)

            $snippetLines = $lines[$startLine..$endLine]
            $snippet = ($snippetLines -join "`n").Trim()

            if ($snippet.Length -gt 500) {
                $snippet = $snippet.Substring(0, 497) + "..."
            }

            $snippets += @{
                "Line" = $i + 1
                "Text" = $snippet
            }

            # Limit snippets per file
            if ($snippets.Count -ge 3) { break }
        }
    }

    return $snippets
}

function Search-Documentation {
    param(
        [string]$SearchQuery,
        [string]$SearchType,
        [int]$MaxResults
    )

    Write-Host ""
    Write-Host "=== Smart Documentation Search ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Query: $SearchQuery" -ForegroundColor White
    Write-Host "  Type: $SearchType" -ForegroundColor DarkGray
    Write-Host ""

    # Get files to search
    $files = Get-SearchFiles -SearchType $SearchType
    Write-Host "Searching $($files.Count) documents..." -ForegroundColor DarkGray
    Write-Host ""

    $results = @()

    foreach ($file in $files) {
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction Stop

            # Calculate relevance score
            $score = Get-KeywordScore -Content $content -SearchQuery $SearchQuery

            if ($score -gt 0) {
                # Get context snippets
                $snippets = Get-ContextSnippet -Content $content -SearchQuery $SearchQuery

                $results += @{
                    "File" = $file.FullName
                    "FileName" = $file.Name
                    "Score" = $score
                    "Snippets" = $snippets
                    "Modified" = $file.LastWriteTime
                }
            }

        } catch {
            # Skip files that can't be read
            continue
        }
    }

    # Sort by score (descending)
    $results = $results | Sort-Object -Property Score -Descending | Select-Object -First $MaxResults

    if ($results.Count -eq 0) {
        Write-Host "No results found for query: $SearchQuery" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Try:" -ForegroundColor DarkGray
        Write-Host "  - Broader search terms" -ForegroundColor DarkGray
        Write-Host "  - Different document type (-Type docs|reflection|skills|adr|patterns)" -ForegroundColor DarkGray
        Write-Host "  - Check spelling" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    Write-Host "=== Results ($($results.Count)) ===" -ForegroundColor Cyan
    Write-Host ""

    for ($i = 0; $i -lt $results.Count; $i++) {
        $result = $results[$i]

        Write-Host "$($i + 1). $($result.FileName)" -ForegroundColor Green
        Write-Host "   Score: $($result.Score) | Modified: $($result.Modified.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor DarkGray
        Write-Host "   Path: $($result.File)" -ForegroundColor DarkGray
        Write-Host ""

        if ($Detailed) {
            # Show all snippets in detailed mode
            foreach ($snippet in $result.Snippets) {
                Write-Host "   --- Line $($snippet.Line) ---" -ForegroundColor DarkCyan
                Write-Host "   $($snippet.Text)" -ForegroundColor White
                Write-Host ""
            }
        } else {
            # Show first snippet only
            if ($result.Snippets.Count -gt 0) {
                $firstSnippet = $result.Snippets[0]
                $preview = $firstSnippet.Text
                if ($preview.Length -gt 200) {
                    $preview = $preview.Substring(0, 197) + "..."
                }
                Write-Host "   $preview" -ForegroundColor White
                Write-Host ""
            }
        }
    }

    Write-Host "=== Search Complete ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Tip: Use -Detailed for full context" -ForegroundColor DarkGray
    Write-Host ""
}

# Main execution
Search-Documentation -SearchQuery $Query -SearchType $Type -MaxResults $Limit
