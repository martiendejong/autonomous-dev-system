$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json
$apiKey = $config.api_key
$headers = @{
    Authorization = $apiKey
    'Content-Type' = 'application/json'
}

$url = "https://api.clickup.com/api/v3/workspaces/9012956001/docs/8ckdjv1-1012/pages"
$bodyObj = @{
    name = "Dashboard Setup Test"
    content = "# Test Content`n`nThis is a test page with markdown content."
}
$body = $bodyObj | ConvertTo-Json

Write-Host "Creating page in doc 8ckdjv1-1012..."
try {
    $page = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
    Write-Host "SUCCESS! Page created: $($page.id)"
    Write-Host "Name: $($page.name)"
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    if ($_.ErrorDetails) {
        Write-Host "Details: $($_.ErrorDetails.Message)"
    }
}
