$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json
$apiKey = $config.api_key
$workspaceId = "9012956001"
$docId = "8ckdjv1-1052"
$pageId = "8ckdjv1-812"  # Development Environment Setup page

$headers = @{
    Authorization = $apiKey
    'Content-Type' = 'application/json'
}

Write-Host "Updating Development Environment Setup page with GitHub URLs..." -ForegroundColor Cyan

$content = @"
# Development Environment Setup

## Prerequisites

### Required Software
- **.NET 8 SDK** - https://dotnet.microsoft.com/download
- **Node.js 18+** - https://nodejs.org/
- **PostgreSQL 14+** - https://www.postgresql.org/download/
- **Redis 7+** - https://redis.io/download
- **Git** - https://git-scm.com/downloads

### Recommended IDEs
- **Visual Studio 2022** (Windows)
- **VS Code** with C# extension
- **Rider** (JetBrains)

## Step 1: Clone Repositories

Open terminal/PowerShell:

``````bash
cd C:\Projects

# Clone main repository
git clone https://github.com/martiendejong/client-manager.git client-manager

# Clone Hazina framework
git clone https://github.com/martiendejong/hazina.git hazina
``````

**Repository URLs:**
- Client Manager: https://github.com/martiendejong/client-manager
- Hazina Framework: https://github.com/martiendejong/hazina

## Step 2: Backend Setup

``````bash
cd C:\Projects\client-manager\ClientManagerAPI

# Restore dependencies
dotnet restore

# Configure secrets (see Local Configuration Guide)
# Create appsettings.Secrets.json with your API keys

# Run database migrations
dotnet ef database update

# Build the project
dotnet build

# Run the API
dotnet run
``````

**Backend will start on:**
- HTTPS: https://localhost:5001
- HTTP: http://localhost:5000

## Step 3: Frontend Setup

``````bash
cd C:\Projects\client-manager\client-manager-frontend

# Install dependencies
npm install

# Configure API endpoint
# Edit .env file:
# VITE_API_URL=https://localhost:5001

# Start development server
npm run dev
``````

**Frontend will start on:**
- http://localhost:5173

## Step 4: Verify Setup

1. **Open browser** → http://localhost:5173
2. **Login with admin credentials:**
   - Username: wreckingball
   - Password: Th1s1sSp4rt4!
3. **Check console** for any errors
4. **Test API** → https://localhost:5001/swagger

## Common Issues

### Backend won't start
- Check PostgreSQL is running
- Verify connection string in appsettings.json
- Ensure Redis is running

### Frontend can't connect
- Verify API is running (https://localhost:5001)
- Check .env file has correct API URL
- Check CORS settings in Program.cs

### Database migration errors
- Delete existing database and re-run migrations
- Check connection string format

## Cross-Platform Setup (macOS + Windows VM)

See documentation: `C:\Projects\client-manager\CROSS_PLATFORM_SETUP.md`

**Key points:**
- Run backend in Windows VM (UTM)
- Run frontend on macOS host
- Update frontend config.js with VM IP address
- Use bridged networking mode
"@

$bodyObj = @{ content = $content }
$body = $bodyObj | ConvertTo-Json -Depth 10

try {
    $page = Invoke-RestMethod -Method PUT -Uri "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$docId/pages/$pageId" -Headers $headers -Body $body
    Write-Host "SUCCESS! Development Environment Setup page updated" -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
}
