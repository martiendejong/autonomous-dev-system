$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json
$apiKey = $config.api_key
$workspaceId = "9012956001"
$docId = "8ckdjv1-1052"

$headers = @{
    Authorization = $apiKey
    'Content-Type' = 'application/json'
}

Write-Host "Adding Production Server page..." -ForegroundColor Cyan

$content = @"
# Production Server Information

## Server Details

**IP Address:** 85.215.217.154
**Services:** https://brand2boost.com | https://api.brand2boost.com

## Configuration Files Location

**Google Drive Folder:**
https://drive.google.com/drive/u/1/folders/1VNUbEgZxFUQzkCySwwYtryIvfEAsZ-kG

Download env folder and copy to: C:\Projects\client-manager\env\

## Deployment

**Automated (Recommended):**
- Backend: Run publish-brand2boost-backend.ps1
- Frontend: Run publish-brand2boost-frontend.ps1

**Manual:**
See docs/PRODUCTION-DEPLOYMENT-GUIDE.md

## Monitoring

- Health Check: https://api.brand2boost.com/health
- Swagger: https://api.brand2boost.com/swagger
- Logs: C:\inetpub\logs\

## Troubleshooting

**API not starting:**
- Check PostgreSQL connection
- Verify API keys in environment
- Check IIS pool status

**Frontend issues:**
- Verify config.js API URL
- Check CORS settings
- Clear browser cache
"@

$bodyObj = @{ name = "Production Server Info"; content = $content }
$body = $bodyObj | ConvertTo-Json -Depth 10

try {
    $page = Invoke-RestMethod -Method POST -Uri "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$docId/pages" -Headers $headers -Body $body
    Write-Host "SUCCESS! Page ID: $($page.id)" -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
}
