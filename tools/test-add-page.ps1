$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json
$apiKey = $config.api_key
$workspaceId = "9012956001"
$docId = "8ckdjv1-1032"

$headers = @{
    Authorization = $apiKey
    'Content-Type' = 'application/json'
}

# Test with small content first
Write-Host "Testing page creation with small content..."
$url = "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$docId/pages"

# Try with minimal content
$bodyObj = @{
    name = "Test Page"
    content = "This is a simple test page."
}

$body = $bodyObj | ConvertTo-Json -Depth 10

Write-Host "Request URL: $url"
Write-Host "Request Body: $body"

try {
    $page = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body -Verbose
    Write-Host "SUCCESS! Page created: $($page.id)"
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    Write-Host "Response: $($_.Exception.Response)"
    if ($_.ErrorDetails) {
        Write-Host "Error Details: $($_.ErrorDetails.Message)"
    }

    # Try to get more detail from the error
    $result = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($result)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd()
    Write-Host "Response Body: $responseBody"
}
