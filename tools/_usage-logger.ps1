# INTERNAL: Automatic Usage Logger - Called by all tools
# Do not call directly - this is infrastructure

param(
    [Parameter(Mandatory=$true)]
    [string]$ToolName,

    [Parameter(Mandatory=$false)]
    [string]$Action = "execute",

    [Parameter(Mandatory=$false)]
    [hashtable]$Metadata = @{}
)

$LogFile = "C:\scripts\_machine\tool-usage-log.jsonl"

# Ensure log file exists
if (-not (Test-Path $LogFile)) {
    "" | Set-Content $LogFile -Encoding UTF8
}

# Create log entry
$entry = @{
    Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Tool = $ToolName
    Action = $Action
    Metadata = $Metadata
    User = $env:USERNAME
    Session = $PID
}

# Append to log (JSONL format - one JSON object per line)
$entry | ConvertTo-Json -Compress | Add-Content $LogFile -Encoding UTF8

# Also update aggregated stats (fast lookup)
$StatsFile = "C:\scripts\_machine\tool-usage-stats.json"

if (Test-Path $StatsFile) {
    $stats = Get-Content $StatsFile -Raw | ConvertFrom-Json
} else {
    $stats = @{ Tools = @{} }
}

if (-not $stats.Tools.$ToolName) {
    $stats.Tools | Add-Member -MemberType NoteProperty -Name $ToolName -Value @{
        TotalCalls = 0
        FirstUsed = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        LastUsed = $null
        RecentCalls = 0
    }
}

$stats.Tools.$ToolName.TotalCalls++
$stats.Tools.$ToolName.LastUsed = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Save stats
$stats | ConvertTo-Json -Depth 10 | Set-Content $StatsFile -Encoding UTF8
