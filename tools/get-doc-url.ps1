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

# Try to get doc details which should include URL
$url = "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$docId"

Write-Host "Fetching doc details for: $docId" -ForegroundColor Cyan

try {
    $doc = Invoke-RestMethod -Method GET -Uri $url -Headers $headers

    Write-Host "`nKnowledge Base Found!" -ForegroundColor Green
    Write-Host "Name: $($doc.name)" -ForegroundColor Yellow
    Write-Host "Doc ID: $($doc.id)" -ForegroundColor Yellow

    # Check if URL is in response
    if ($doc.url) {
        Write-Host "`nDirect Link:" -ForegroundColor Cyan
        Write-Host $doc.url -ForegroundColor White
    } else {
        # Construct URL based on ClickUp patterns
        $constructedUrl = "https://app.clickup.com/$workspaceId/v/dc/$docId"
        Write-Host "`nConstructed Link:" -ForegroundColor Cyan
        Write-Host $constructedUrl -ForegroundColor White
    }

    Write-Host "`nAlternative: Search for 'Brand2Boost Knowledge Base' in ClickUp Docs" -ForegroundColor Yellow
}
catch {
    Write-Host "Error fetching doc: $($_.Exception.Message)" -ForegroundColor Red

    # Provide constructed URL anyway
    $constructedUrl = "https://app.clickup.com/$workspaceId/v/dc/$docId"
    Write-Host "`nTry this link:" -ForegroundColor Cyan
    Write-Host $constructedUrl -ForegroundColor White
}
