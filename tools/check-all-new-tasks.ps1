$config = Get-Content 'C:\scripts\_machine\clickup-config.json' | ConvertFrom-Json


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$config = Get-Content 'C:\scripts\_machine\clickup-config.json' | ConvertFrom-Json
$headers = @{ Authorization = $config.api_key }
$response = Invoke-RestMethod -Uri 'https://api.clickup.com/api/v2/list/901214097647/task?archived=false' -Headers $headers

# Get tasks created in last 10 minutes
$now = [DateTimeOffset]::UtcNow
$tenMinutesAgo = $now.AddMinutes(-10).ToUnixTimeMilliseconds()

Write-Host "`nAll Tasks Created in Last 10 Minutes:" -ForegroundColor Green
$newTasks = $response.tasks | Where-Object {
    [long]$_.date_created -gt $tenMinutesAgo
} | Sort-Object date_created -Descending

$newTasks | Select-Object id, name, @{N='Status';E={$_.status.status}}, @{N='Created';E={[DateTimeOffset]::FromUnixTimeMilliseconds([long]$_.date_created).ToString("HH:mm:ss")}} | Format-Table -AutoSize -Wrap

Write-Host "`nTotal new tasks: $($newTasks.Count)" -ForegroundColor Cyan
