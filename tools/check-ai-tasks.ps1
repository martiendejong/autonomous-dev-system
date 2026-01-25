$config = Get-Content 'C:\scripts\_machine\clickup-config.json' | ConvertFrom-Json


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$config = Get-Content 'C:\scripts\_machine\clickup-config.json' | ConvertFrom-Json
$headers = @{ Authorization = $config.api_key }
$response = Invoke-RestMethod -Uri 'https://api.clickup.com/api/v2/list/901214097647/task?archived=false' -Headers $headers

Write-Host "`nAI Prompting Tasks Created:" -ForegroundColor Green
$aiTasks = $response.tasks | Where-Object {
    $_.name -like '*Quick Win*' -or
    $_.name -like '*EPIC: AI*' -or
    $_.name -like '*Phase 1.*' -or
    $_.name -like '*Phase 2.*' -or
    $_.name -like '*Phase 3.*' -or
    $_.name -like '*Documentation: AI*' -or
    $_.name -like '*Analytics: AI*'
} | Sort-Object date_created -Descending

$aiTasks | Select-Object -First 25 id, name, @{N='Status';E={$_.status.status}}, @{N='Created';E={[DateTimeOffset]::FromUnixTimeMilliseconds([long]$_.date_created).ToString("yyyy-MM-dd HH:mm")}} | Format-Table -AutoSize

Write-Host "`nTotal AI Prompting tasks: $($aiTasks.Count)" -ForegroundColor Cyan
