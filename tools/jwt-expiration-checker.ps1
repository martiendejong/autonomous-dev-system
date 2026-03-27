<#
.SYNOPSIS
    Check JWT token expiration times and validity

.DESCRIPTION
    Validates JWT tokens:
    - Decodes JWT without verification
    - Checks expiration time
    - Validates claims
    - Detects expired tokens
    - Reports time until expiration

.PARAMETER Token
    JWT token string

.PARAMETER TokenFile
    File containing JWT tokens (one per line)

.PARAMETER WarnThreshold
    Warn if token expires within this time (seconds, default: 300)

.PARAMETER OutputFormat
    Output format: table (default), json

.EXAMPLE
    .\jwt-expiration-checker.ps1 -Token "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

.NOTES
    Value: 7/10 - Token expiration causes outages
    Effort: 1.5/10 - Base64 decode + JSON parse
    Ratio: 4.7 (TIER A)
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Token = "",

    [Parameter(Mandatory=$false)]
    [string]$TokenFile = "",

    [Parameter(Mandatory=$false)]
    [int]$WarnThreshold = 300,

    [Parameter(Mandatory=$false)]
    [ValidateSet('table', 'json')]
    [string]$OutputFormat = 'table'
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

Write-Host "🔐 JWT Expiration Checker" -ForegroundColor Cyan
Write-Host ""

function Decode-JWT {
    param([string]$JWTToken)

    try {
        $parts = $JWTToken -split '\.'
        if ($parts.Count -ne 3) {
            return $null
        }

        # Decode payload (part 1)
        $payload = $parts[1]
        # Add padding if needed
        while ($payload.Length % 4 -ne 0) {
            $payload += '='
        }

        $bytes = [Convert]::FromBase64String($payload)
        $json = [System.Text.Encoding]::UTF8.GetString($bytes)
        $claims = $json | ConvertFrom-Json

        return $claims
    } catch {
        return $null
    }
}

$tokens = @()
if ($Token) {
    $tokens += $Token
}
if ($TokenFile -and (Test-Path $TokenFile)) {
    $tokens += Get-Content $TokenFile
}

if ($tokens.Count -eq 0) {
    Write-Host "❌ No tokens provided" -ForegroundColor Red
    exit 1
}

$results = @()

foreach ($jwt in $tokens) {
    $claims = Decode-JWT -JWTToken $jwt

    if (-not $claims) {
        $results += [PSCustomObject]@{
            Token = $jwt.Substring(0, [Math]::Min(20, $jwt.Length)) + "..."
            Status = "INVALID"
            ExpiresIn = "N/A"
            IssuedAt = "N/A"
        }
        continue
    }

    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $exp = if ($claims.exp) { [long]$claims.exp } else { 0 }
    $iat = if ($claims.iat) { [DateTimeOffset]::FromUnixTimeSeconds([long]$claims.iat).ToString('yyyy-MM-dd HH:mm:ss') } else { "N/A" }

    $status = if ($exp -eq 0) {
        "NO_EXPIRY"
    } elseif ($exp -lt $now) {
        "EXPIRED"
    } elseif (($exp - $now) -lt $WarnThreshold) {
        "EXPIRING_SOON"
    } else {
        "VALID"
    }

    $expiresIn = if ($exp -gt 0) {
        $seconds = $exp - $now
        if ($seconds -lt 0) {
            "Expired $([Math]::Abs($seconds))s ago"
        } else {
            "${seconds}s remaining"
        }
    } else {
        "No expiry"
    }

    $results += [PSCustomObject]@{
        Token = $jwt.Substring(0, [Math]::Min(20, $jwt.Length)) + "..."
        Status = $status
        ExpiresIn = $expiresIn
        IssuedAt = $iat
    }
}

Write-Host "JWT TOKEN VALIDATION" -ForegroundColor Cyan
Write-Host ""

switch ($OutputFormat) {
    'table' {
        $results | Format-Table -AutoSize -Property @(
            @{Label='Token'; Expression={$_.Token}; Width=22}
            @{Label='Status'; Expression={$_.Status}; Width=15}
            @{Label='Expires In'; Expression={$_.ExpiresIn}; Width=30}
            @{Label='Issued At'; Expression={$_.IssuedAt}; Width=20}
        )

        Write-Host ""
        Write-Host "SUMMARY:" -ForegroundColor Cyan
        Write-Host "  Total tokens: $($results.Count)" -ForegroundColor Gray
        Write-Host "  Valid: $(($results | Where-Object {$_.Status -eq 'VALID'}).Count)" -ForegroundColor Green
        Write-Host "  Expiring soon: $(($results | Where-Object {$_.Status -eq 'EXPIRING_SOON'}).Count)" -ForegroundColor Yellow
        Write-Host "  Expired: $(($results | Where-Object {$_.Status -eq 'EXPIRED'}).Count)" -ForegroundColor Red
        Write-Host "  Invalid: $(($results | Where-Object {$_.Status -eq 'INVALID'}).Count)" -ForegroundColor Red
    }
    'json' {
        @{
            Tokens = $results
            Summary = @{
                Total = $results.Count
                Valid = ($results | Where-Object {$_.Status -eq 'VALID'}).Count
                ExpiringSoon = ($results | Where-Object {$_.Status -eq 'EXPIRING_SOON'}).Count
                Expired = ($results | Where-Object {$_.Status -eq 'EXPIRED'}).Count
                Invalid = ($results | Where-Object {$_.Status -eq 'INVALID'}).Count
            }
        } | ConvertTo-Json -Depth 10
    }
}

Write-Host ""
if (($results | Where-Object {$_.Status -in @('EXPIRED','EXPIRING_SOON')}).Count -gt 0) {
    Write-Host "⚠️  Expired or expiring tokens detected" -ForegroundColor Yellow
} else {
    Write-Host "✅ All tokens valid" -ForegroundColor Green
}
