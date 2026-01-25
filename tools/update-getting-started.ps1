$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json
$apiKey = $config.api_key
$workspaceId = "9012956001"
$docId = "8ckdjv1-1052"
$pageId = "8ckdjv1-792"  # Getting Started page

$headers = @{
    Authorization = $apiKey
    'Content-Type' = 'application/json'
}

Write-Host "Updating Getting Started page with GitHub URLs..." -ForegroundColor Cyan

$content = @"
# Getting Started with Brand2Boost

## What is Brand2Boost?

Brand2Boost is a comprehensive promotion and brand development SaaS platform built on .NET 8 and powered by the Hazina AI framework.

**Key Features:**
- AI-powered content generation
- Multi-platform social media management (9 platforms)
- Brand management with voice consistency
- Content quality scoring
- Automated post scheduling
- Interview-based brand onboarding

## Quick Links

**Production:**
- Website: https://brand2boost.com
- API: https://api.brand2boost.com
- Server IP: 85.215.217.154

**Development:**
- Frontend: http://localhost:5173
- Backend API: https://localhost:5001
- Backend HTTP: http://localhost:5000

**Code Repositories:**
- Client Manager (Main): https://github.com/martiendejong/client-manager
  - Local path: C:\Projects\client-manager
- Hazina Framework: https://github.com/martiendejong/hazina
  - Local path: C:\Projects\hazina
- Brand Data Store: C:\stores\brand2boost (local only)

## Tech Stack

**Backend:**
- .NET 8 + ASP.NET Core
- Entity Framework Core
- PostgreSQL (production) / SQLite (development)
- Hazina AI Framework

**Frontend:**
- React + TypeScript
- Tailwind CSS
- Vite

**AI/ML:**
- OpenAI GPT-4 (primary)
- Anthropic Claude
- Ollama (local)

## Next Steps

1. **Set up development environment** → See "Development Environment Setup"
2. **Configure local settings** → See "Local Configuration Guide"
3. **Learn about deployment** → See "Production Server Info"
4. **Explore tools** → See "Tools & Scripts Reference"

## Admin Credentials (Development)

Username: `wreckingball`
Password: `Th1s1sSp4rt4!`

**⚠️ Change these in production!**

## Support

- GitHub Issues: https://github.com/martiendejong/client-manager/issues
- Team Slack: #dev-team channel
- ClickUp Tasks: Brand Designer list (901214097647)
"@

$bodyObj = @{ content = $content }
$body = $bodyObj | ConvertTo-Json -Depth 10

Write-Host "API URL: https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$docId/pages/$pageId" -ForegroundColor Gray

try {
    $page = Invoke-RestMethod -Method PUT -Uri "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$docId/pages/$pageId" -Headers $headers -Body $body
    Write-Host "SUCCESS! Getting Started page updated" -ForegroundColor Green
    Write-Host "Page ID: $($page.id)" -ForegroundColor Cyan
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}
