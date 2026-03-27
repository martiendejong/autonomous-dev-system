<#
.SYNOPSIS
    Smart Caching & Lazy Evaluation
    50-Expert Council Improvements #35, #36, #37 | Priority: 1.75, 1.4, 1.33

.DESCRIPTION
    Caches expensive operations intelligently.
    Implements lazy evaluation and predictive pre-loading.

.PARAMETER Cache
    Cache a value.

.PARAMETER Key
    Cache key.

.PARAMETER Value
    Value to cache.

.PARAMETER Get
    Get cached value.

.PARAMETER Clear
    Clear cache.

.PARAMETER Stats
    Show cache statistics.

.PARAMETER Preload
    Preload likely-needed context.

.EXAMPLE
    smart-cache.ps1 -Cache -Key "build_result" -Value "success"
    smart-cache.ps1 -Get -Key "build_result"
    smart-cache.ps1 -Preload
#>

param(
    [switch]$Cache,
    [string]$Key = "",
    [string]$Value = "",
    [switch]$Get,
    [switch]$Clear,
    [switch]$Stats,
    [switch]$Preload
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$CacheFile = "C:\scripts\_machine\smart_cache.json"
$CacheTTL = 3600  # 1 hour in seconds

if (-not (Test-Path $CacheFile)) {
    @{
        entries = @{}
        hits = 0
        misses = 0
        preloaded = @()
    } | ConvertTo-Json -Depth 10 | Set-Content $CacheFile -Encoding UTF8
}

$cache = Get-Content $CacheFile -Raw | ConvertFrom-Json

function Is-Expired {
    param($Entry)
    $created = [datetime]::Parse($Entry.created)
    $age = (Get-Date) - $created
    return $age.TotalSeconds -gt $CacheTTL
}

if ($Cache -and $Key -and $Value) {
    $entry = @{
        value = $Value
        created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        accessCount = 0
    }

    if (-not $cache.entries) { $cache.entries = @{} }
    if ($cache.entries -is [PSCustomObject]) {
        $cache.entries | Add-Member -NotePropertyName $Key -NotePropertyValue $entry -Force
    } else {
        $cache.entries[$Key] = $entry
    }

    $cache | ConvertTo-Json -Depth 10 | Set-Content $CacheFile -Encoding UTF8

    Write-Host "✓ Cached: $Key" -ForegroundColor Green
}
elseif ($Get -and $Key) {
    $entry = $cache.entries.$Key

    if (-not $entry) {
        $cache.misses++
        $cache | ConvertTo-Json -Depth 10 | Set-Content $CacheFile -Encoding UTF8
        Write-Host "Cache miss: $Key" -ForegroundColor Yellow
    } elseif (Is-Expired $entry) {
        $cache.misses++
        $cache | ConvertTo-Json -Depth 10 | Set-Content $CacheFile -Encoding UTF8
        Write-Host "Cache expired: $Key" -ForegroundColor Yellow
    } else {
        $cache.hits++
        $entry.accessCount++
        $cache | ConvertTo-Json -Depth 10 | Set-Content $CacheFile -Encoding UTF8
        Write-Host "Cache hit: $Key = $($entry.value)" -ForegroundColor Green
        return $entry.value
    }
}
elseif ($Clear) {
    $cache.entries = @{}
    $cache | ConvertTo-Json -Depth 10 | Set-Content $CacheFile -Encoding UTF8
    Write-Host "✓ Cache cleared" -ForegroundColor Green
}
elseif ($Stats) {
    Write-Host "=== CACHE STATISTICS ===" -ForegroundColor Cyan
    Write-Host ""

    $entryCount = if ($cache.entries -is [PSCustomObject]) {
        ($cache.entries.PSObject.Properties).Count
    } else { 0 }

    Write-Host "Entries: $entryCount" -ForegroundColor Yellow
    Write-Host "Hits: $($cache.hits)" -ForegroundColor Green
    Write-Host "Misses: $($cache.misses)" -ForegroundColor Yellow

    $hitRate = if (($cache.hits + $cache.misses) -gt 0) {
        [math]::Round(($cache.hits / ($cache.hits + $cache.misses)) * 100)
    } else { 0 }
    Write-Host "Hit rate: $hitRate%" -ForegroundColor $(if ($hitRate -gt 70) { "Green" } else { "Yellow" })

    if ($cache.preloaded.Count -gt 0) {
        Write-Host ""
        Write-Host "Preloaded: $($cache.preloaded -join ', ')" -ForegroundColor Gray
    }
}
elseif ($Preload) {
    Write-Host "=== PREDICTIVE PRELOADING ===" -ForegroundColor Cyan
    Write-Host ""

    # Preload commonly needed context
    $preloads = @(
        @{ key = "worktree_status"; cmd = "worktree-status.ps1 -Compact" },
        @{ key = "git_status_cm"; cmd = "git -C C:\Projects\client-manager status -sb" },
        @{ key = "git_status_hz"; cmd = "git -C C:\Projects\hazina status -sb" }
    )

    foreach ($p in $preloads) {
        Write-Host "  Preloading: $($p.key)..." -ForegroundColor Gray
        try {
            $result = Invoke-Expression $p.cmd 2>&1 | Out-String
            $entry = @{
                value = $result.Substring(0, [Math]::Min(500, $result.Length))
                created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                accessCount = 0
            }
            $cache.entries | Add-Member -NotePropertyName $p.key -NotePropertyValue $entry -Force
            $cache.preloaded += $p.key
        } catch {
            Write-Host "  Failed: $($p.key)" -ForegroundColor Yellow
        }
    }

    $cache | ConvertTo-Json -Depth 10 | Set-Content $CacheFile -Encoding UTF8
    Write-Host ""
    Write-Host "✓ Preloaded $($preloads.Count) items" -ForegroundColor Green
}
else {
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  -Cache -Key x -Value y   Cache a value" -ForegroundColor White
    Write-Host "  -Get -Key x              Get cached value" -ForegroundColor White
    Write-Host "  -Clear                   Clear cache" -ForegroundColor White
    Write-Host "  -Stats                   Show statistics" -ForegroundColor White
    Write-Host "  -Preload                 Preload common context" -ForegroundColor White
}
