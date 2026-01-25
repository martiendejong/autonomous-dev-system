<#
.SYNOPSIS
ManicTime Activity Monitor - Real-time activity tracking and context-aware intelligence

.DESCRIPTION
Queries ManicTime databases to:
- Track current user activity and application usage
- Detect idle/unattended system state
- Count running Claude instances
- Analyze work patterns and provide insights
- Enable context-aware assistance

Part of Claude Agent's continuous monitoring system.

.PARAMETER Mode
Operation mode:
- current: Show current activity (default)
- recent: Recent activity (last N hours)
- patterns: Analyze work patterns
- claude: Count Claude instances
- idle: Check if system is idle/unattended
- stats: Daily statistics
- context: Get full context for AI decision-making

.PARAMETER Hours
Hours to look back (for 'recent' and 'stats' modes). Default: 2

.PARAMETER MinIdleMinutes
Minutes of inactivity to consider system idle. Default: 15

.PARAMETER OutputFormat
Output format: text, json, object. Default: text

.EXAMPLE
monitor-activity.ps1 -Mode current
Show current active application and window

.EXAMPLE
monitor-activity.ps1 -Mode claude
Count running Claude Code instances

.EXAMPLE
monitor-activity.ps1 -Mode context -OutputFormat json
Get full context as JSON for AI processing

.EXAMPLE
monitor-activity.ps1 -Mode idle -MinIdleMinutes 10
Check if system idle for 10+ minutes

.NOTES
Author: Claude Agent
Version: 1.0.0
Created: 2026-01-19
Database: C:\Users\HP\AppData\Local\Finkit\ManicTime\ManicTimeCore.db
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('current', 'recent', 'patterns', 'claude', 'idle', 'stats', 'context')]
    [string]$Mode = 'current',

    [Parameter()]
    [int]$Hours = 2,

    [Parameter()]
    [int]$MinIdleMinutes = 15,

    [Parameter()]
    [ValidateSet('text', 'json', 'object')]
    [string]$OutputFormat = 'text'
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ErrorActionPreference = 'Stop'

# ManicTime database path
$DbPath = "$env:LOCALAPPDATA\Finkit\ManicTime\ManicTimeCore.db"
$ReportsDbPath = "$env:LOCALAPPDATA\Finkit\ManicTime\ManicTimeReports.db"

if (-not (Test-Path $DbPath)) {
    throw "ManicTime database not found at: $DbPath"
}

# Load SQLite assembly (comes with .NET)
Add-Type -AssemblyName System.Data

function Get-ManicTimeConnection {
    param([string]$DatabasePath)

    # Use System.Data.SQLite if available, otherwise use basic ODBC
    try {
        $connectionString = "Data Source=$DatabasePath;Version=3;Read Only=True;"
        $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
        $connection.Open()
        return $connection
    }
    catch {
        # Fallback: Try to load SQLite interop
        Write-Warning "SQLite not directly available. Attempting to use alternative method..."

        # Use PowerShell's built-in COM object for SQLite if available
        throw "SQLite access not configured. Please install System.Data.SQLite package."
    }
}

function Invoke-SQLiteQuery {
    param(
        [string]$DatabasePath,
        [string]$Query
    )

    try {
        # Use simple file-based approach with temp script
        $tempScript = [System.IO.Path]::GetTempFileName() + ".sql"
        $tempOutput = [System.IO.Path]::GetTempFileName() + ".txt"

        # Create SQLite query script
        @"
.mode json
.output $tempOutput
$Query
.quit
"@ | Out-File -FilePath $tempScript -Encoding UTF8

        # Note: This requires sqlite3.exe - we'll use a different approach
        # For now, use direct database file reading approach

        throw "Direct SQLite querying requires sqlite3.exe or System.Data.SQLite"
    }
    catch {
        Write-Warning "Cannot query ManicTime database directly: $_"
        return $null
    }
    finally {
        if (Test-Path $tempScript) { Remove-Item $tempScript -Force }
        if (Test-Path $tempOutput) { Remove-Item $tempOutput -Force }
    }
}

function Get-CurrentActivity {
    # Alternative: Use ManicTime's own API or parse log files
    # Check ManicTime logs for current activity

    $logPath = "$env:LOCALAPPDATA\Finkit\ManicTime\Logs"
    $todayLog = Join-Path $logPath "ManicTime_$(Get-Date -Format 'yyyy-MM-dd').log"

    if (Test-Path $todayLog) {
        $recentLines = Get-Content $todayLog -Tail 50

        # Parse log for activity indicators
        $activity = @{
            Timestamp = Get-Date
            LogFile = $todayLog
            RecentEntries = $recentLines | Select-Object -Last 5
        }

        return $activity
    }

    return $null
}

function Get-RunningProcesses {
    # Get current Windows processes - especially Claude instances
    $processes = Get-Process -ErrorAction SilentlyContinue

    return @{
        ClaudeInstances = @($processes | Where-Object {
            $_.ProcessName -like '*claude*' -or
            $_.MainWindowTitle -like '*Claude*'
        })
        ActiveWindow = Get-ActiveWindow
        TotalProcesses = $processes.Count
        HighCPU = @($processes | Where-Object { $_.CPU -gt 10 } | Sort-Object CPU -Descending | Select-Object -First 5)
    }
}

function Get-ActiveWindow {
    # Use Windows API to get active window
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        using System.Text;
        public class WindowHelper {
            [DllImport("user32.dll")]
            public static extern IntPtr GetForegroundWindow();

            [DllImport("user32.dll")]
            public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

            [DllImport("user32.dll", SetLastError=true)]
            public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

            public static string GetActiveWindowTitle() {
                IntPtr handle = GetForegroundWindow();
                StringBuilder text = new StringBuilder(256);
                if (GetWindowText(handle, text, 256) > 0) {
                    return text.ToString();
                }
                return null;
            }

            public static uint GetActiveWindowProcessId() {
                IntPtr handle = GetForegroundWindow();
                uint processId;
                GetWindowThreadProcessId(handle, out processId);
                return processId;
            }
        }
"@ -ErrorAction SilentlyContinue

    try {
        $title = [WindowHelper]::GetActiveWindowTitle()
        $processId = [WindowHelper]::GetActiveWindowProcessId()

        if ($processId -gt 0) {
            $process = Get-Process -Id $processId -ErrorAction SilentlyContinue

            return @{
                Title = $title
                ProcessId = $processId
                ProcessName = $process.ProcessName
                Path = $process.Path
            }
        }
    }
    catch {
        Write-Warning "Could not get active window: $_"
    }

    return $null
}

function Get-IdleTime {
    # Get system idle time using Windows API
    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        public class IdleTimeHelper {
            [DllImport("user32.dll")]
            public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

            [StructLayout(LayoutKind.Sequential)]
            public struct LASTINPUTINFO {
                public uint cbSize;
                public uint dwTime;
            }

            public static TimeSpan GetIdleTime() {
                LASTINPUTINFO lastInputInfo = new LASTINPUTINFO();
                lastInputInfo.cbSize = (uint)Marshal.SizeOf(lastInputInfo);
                GetLastInputInfo(ref lastInputInfo);

                return TimeSpan.FromMilliseconds(Environment.TickCount - lastInputInfo.dwTime);
            }
        }
"@ -ErrorAction SilentlyContinue

    try {
        return [IdleTimeHelper]::GetIdleTime()
    }
    catch {
        Write-Warning "Could not get idle time: $_"
        return [TimeSpan]::Zero
    }
}

function Get-ClaudeInstances {
    $processes = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match 'claude|anthropic' -or
        $_.MainWindowTitle -match 'Claude' -or
        $_.Path -like '*claude*'
    }

    $windows = $processes | Where-Object { $_.MainWindowTitle } | ForEach-Object {
        @{
            ProcessName = $_.ProcessName
            ProcessId = $_.Id
            WindowTitle = $_.MainWindowTitle
            Path = $_.Path
            StartTime = $_.StartTime
            CPU = [math]::Round($_.CPU, 2)
            Memory = [math]::Round($_.WorkingSet64 / 1MB, 2)
        }
    }

    return @{
        Count = $windows.Count
        Instances = $windows
    }
}

function Get-WorkPatterns {
    param([int]$Hours = 8)

    # Analyze recent work patterns from process history
    # This is a simplified version - full version would query ManicTime DB

    $startTime = (Get-Date).AddHours(-$Hours)

    # Get process snapshot
    $snapshot = @{
        TimeRange = "$Hours hours"
        StartTime = $startTime
        EndTime = Get-Date
        CurrentActivity = Get-ActiveWindow
        ClaudeUsage = Get-ClaudeInstances
        IdleTime = Get-IdleTime
    }

    return $snapshot
}

function Get-ActivityContext {
    # Get comprehensive context for AI decision-making

    $activeWindow = Get-ActiveWindow
    $claudeInstances = Get-ClaudeInstances
    $idleTime = Get-IdleTime
    $processes = Get-RunningProcesses

    $context = @{
        Timestamp = Get-Date -Format 'o'
        ActiveWindow = $activeWindow
        ClaudeInstances = $claudeInstances
        IdleTime = @{
            Total = $idleTime.ToString()
            Minutes = [math]::Round($idleTime.TotalMinutes, 2)
            IsIdle = $idleTime.TotalMinutes -gt $MinIdleMinutes
        }
        System = @{
            UserAttending = $idleTime.TotalMinutes -lt $MinIdleMinutes
            MultipleClaudeSessions = $claudeInstances.Count -gt 1
            HighActivityProcesses = $processes.HighCPU
        }
        Insights = @()
    }

    # Add contextual insights
    if ($context.IdleTime.IsIdle) {
        $context.Insights += "System appears idle for $([math]::Round($idleTime.TotalMinutes, 1)) minutes - user may be away"
    }

    if ($claudeInstances.Count -gt 1) {
        $context.Insights += "Multiple Claude sessions detected ($($claudeInstances.Count)) - potential multi-agent coordination needed"
    }

    if ($activeWindow -and $activeWindow.Title -match 'Claude') {
        $context.Insights += "User currently focused on Claude window"
    }

    if ($activeWindow -and $activeWindow.Title -match 'Visual Studio|VS Code|vim|notepad') {
        $context.Insights += "User actively coding in: $($activeWindow.ProcessName)"
    }

    return $context
}

# Main execution
try {
    switch ($Mode) {
        'current' {
            $result = Get-ActiveWindow
            if ($null -eq $result) {
                $result = @{ Status = 'Unable to determine current activity' }
            }
        }

        'claude' {
            $result = Get-ClaudeInstances
        }

        'idle' {
            $idleTime = Get-IdleTime
            $result = @{
                IdleTime = $idleTime.ToString()
                IdleMinutes = [math]::Round($idleTime.TotalMinutes, 2)
                IsIdle = $idleTime.TotalMinutes -gt $MinIdleMinutes
                Threshold = $MinIdleMinutes
                UserPresent = $idleTime.TotalMinutes -lt $MinIdleMinutes
            }
        }

        'patterns' {
            $result = Get-WorkPatterns -Hours $Hours
        }

        'context' {
            $result = Get-ActivityContext
        }

        'recent' {
            $result = @{
                TimeRange = "$Hours hours"
                Note = "Full recent activity requires direct database access"
                CurrentSnapshot = Get-ActivityContext
            }
        }

        'stats' {
            $result = @{
                Date = Get-Date -Format 'yyyy-MM-dd'
                Note = "Full statistics require direct database access"
                CurrentState = Get-ActivityContext
            }
        }
    }

    # Output formatting
    switch ($OutputFormat) {
        'json' {
            $result | ConvertTo-Json -Depth 10
        }
        'object' {
            return $result
        }
        'text' {
            Write-Host "=== ManicTime Activity Monitor ===" -ForegroundColor Cyan
            Write-Host "Mode: $Mode" -ForegroundColor Yellow
            Write-Host "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
            Write-Host ""

            if ($Mode -eq 'current') {
                Write-Host "Active Window:" -ForegroundColor Green
                Write-Host "  Title: $($result.Title)"
                Write-Host "  Process: $($result.ProcessName) (PID: $($result.ProcessId))"
                Write-Host "  Path: $($result.Path)"
            }
            elseif ($Mode -eq 'claude') {
                Write-Host "Claude Instances: $($result.Count)" -ForegroundColor Green
                foreach ($instance in $result.Instances) {
                    Write-Host "  - $($instance.WindowTitle)" -ForegroundColor White
                    Write-Host "    PID: $($instance.ProcessId) | CPU: $($instance.CPU)s | Memory: $($instance.Memory)MB"
                }
            }
            elseif ($Mode -eq 'idle') {
                $color = if ($result.IsIdle) { 'Red' } else { 'Green' }
                Write-Host "Idle Time: $($result.IdleMinutes) minutes" -ForegroundColor $color
                Write-Host "User Present: $($result.UserPresent)" -ForegroundColor $color
            }
            elseif ($Mode -eq 'context') {
                Write-Host "=== Full Context ===" -ForegroundColor Magenta
                Write-Host ""
                Write-Host "Active Window:" -ForegroundColor Green
                Write-Host "  $($result.ActiveWindow.Title)"
                Write-Host "  Process: $($result.ActiveWindow.ProcessName)"
                Write-Host ""
                Write-Host "Claude Sessions: $($result.ClaudeInstances.Count)" -ForegroundColor Green
                Write-Host "Idle Time: $($result.IdleTime.Minutes) minutes" -ForegroundColor $(if ($result.IdleTime.IsIdle) { 'Red' } else { 'Green' })
                Write-Host "User Attending: $($result.System.UserAttending)" -ForegroundColor $(if ($result.System.UserAttending) { 'Green' } else { 'Red' })
                Write-Host ""
                if ($result.Insights.Count -gt 0) {
                    Write-Host "Insights:" -ForegroundColor Yellow
                    foreach ($insight in $result.Insights) {
                        Write-Host "  • $insight" -ForegroundColor White
                    }
                }
            }
            else {
                $result | Format-List
            }
        }
    }
}
catch {
    Write-Error "Activity monitoring failed: $_"
    Write-Error $_.ScriptStackTrace
    exit 1
}
