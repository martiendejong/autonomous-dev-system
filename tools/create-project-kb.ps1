$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$config = Get-Content C:\scripts\_machine\clickup-config.json | ConvertFrom-Json
$apiKey = $config.api_key
$workspaceId = "9012956001"

$headers = @{
    Authorization = $apiKey
    'Content-Type' = 'application/json'
}

Write-Host "=== Creating Brand2Boost Project Knowledge Base ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create main Knowledge Base doc
Write-Host "[1/6] Creating Project Knowledge Base doc..." -ForegroundColor Cyan
$url = "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs"
$bodyObj = @{ name = "Brand2Boost - Project Documentation" }
$body = $bodyObj | ConvertTo-Json

try {
    $kbDoc = Invoke-RestMethod -Method POST -Uri $url -Headers $headers -Body $body
    $kbDocId = $kbDoc.id
    Write-Host "SUCCESS! Knowledge Base created: $kbDocId" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Page 1: Getting Started
Write-Host "[2/6] Adding Getting Started page..." -ForegroundColor Cyan
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
- Client Manager (Main): C:\Projects\client-manager
- Hazina Framework: C:\Projects\hazina
- Brand Data Store: C:\stores\brand2boost

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

- GitHub Issues: Post in martiendejong/client-manager
- Team Slack: #dev-team channel
- ClickUp Tasks: Brand Designer list (901214097647)
"@

$bodyObj = @{ name = "Getting Started"; content = $content }
$body = $bodyObj | ConvertTo-Json -Depth 10

try {
    $page = Invoke-RestMethod -Method POST -Uri "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$kbDocId/pages" -Headers $headers -Body $body
    Write-Host "SUCCESS! Page ID: $($page.id)" -ForegroundColor Green
}
catch { Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red }
Write-Host ""

# Page 2: Development Environment Setup
Write-Host "[3/6] Adding Development Environment Setup..." -ForegroundColor Cyan
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

$bodyObj = @{ name = "Development Environment Setup"; content = $content }
$body = $bodyObj | ConvertTo-Json -Depth 10

try {
    $page = Invoke-RestMethod -Method POST -Uri "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$kbDocId/pages" -Headers $headers -Body $body
    Write-Host "SUCCESS! Page ID: $($page.id)" -ForegroundColor Green
}
catch { Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red }
Write-Host ""

# Page 3: Production Server Information
Write-Host "[4/6] Adding Production Server Info..." -ForegroundColor Cyan
$content = @"
# Production Server Information

## Server Details

**IP Address:** 85.215.217.154

**Hosted Services:**
- Website: https://brand2boost.com
- API: https://api.brand2boost.com
- Database: PostgreSQL (hosted)

**IIS Application Pools:**
- ClientManagerAPI
- Brand2BoostFrontend

## Production Configuration

### Google Drive Location

Production configuration files are stored in Google Drive (they contain secrets):

**📁 Google Drive Folder:**
https://drive.google.com/drive/u/1/folders/1VNUbEgZxFUQzkCySwwYtryIvfEAsZ-kG

### Download env Folder

1. Download `env` folder from Google Drive
2. Copy to: `C:\Projects\client-manager\env\`

**Folder structure:**
``````
env\
├── prod\
│   ├── backend\
│   │   ├── appsettings.json        # Production secrets
│   │   ├── web.config              # IIS config
│   │   └── Configuration\
│   │       ├── model-routing.config.json
│   │       └── feature-flags.json
│   ├── frontend\
│   │   └── config.js               # Production API URL
│   └── backend.publish.password    # MSDeploy password
``````

**⚠️ IMPORTANT:** Never commit the `env` folder - it's in .gitignore

## Deployment Process

### Automated Deployment (Recommended)

**Backend:**
``````powershell
.\publish-brand2boost-backend.ps1
``````

**Frontend:**
``````powershell
.\publish-brand2boost-frontend.ps1
``````

**What the scripts do:**
1. Build application (Release mode)
2. Copy output to dist\ folder
3. Overlay production config from env\prod\
4. Deploy via MSDeploy to server 85.215.217.154

**Prerequisites:**
- env folder downloaded from Google Drive
- Microsoft Web Deploy V3 installed
- Network access to port 8172

### Manual Deployment

See full guide: `C:\Projects\client-manager\docs\PRODUCTION-DEPLOYMENT-GUIDE.md`

**Quick steps:**
1. Build: `dotnet publish -c Release`
2. Copy to: `C:\inetpub\client-manager-api`
3. Create IIS Application Pool
4. Configure bindings (HTTPS port 443)
5. Set environment variables
6. Restart IIS

## Monitoring & Logs

**Application Logs:**
- Location: `C:\inetpub\logs\`
- Check for startup errors
- Monitor LLM provider initialization

**Health Checks:**
- API: https://api.brand2boost.com/health
- Swagger: https://api.brand2boost.com/swagger

## Troubleshooting

### API not starting
- Check PostgreSQL connection
- Verify API keys in environment variables
- Check IIS application pool status

### Frontend not loading
- Verify API URL in config.js
- Check CORS settings
- Clear browser cache

### Database issues
- Verify connection string
- Check PostgreSQL service status
- Run migrations: `dotnet ef database update`
"@

$bodyObj = @{ name = "Production Server Info"; content = $content }
$body = $bodyObj | ConvertTo-Json -Depth 10

try {
    $page = Invoke-RestMethod -Method POST -Uri "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$kbDocId/pages" -Headers $headers -Body $body
    Write-Host "SUCCESS! Page ID: $($page.id)" -ForegroundColor Green
}
catch { Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red }
Write-Host ""

# Page 4: Local Configuration Guide
Write-Host "[5/6] Adding Local Configuration Guide..." -ForegroundColor Cyan
$content = @"
# Local Configuration Guide

## Configuration Files Overview

Brand2Boost uses a layered configuration system:

1. **appsettings.json** - Default values (checked into git)
2. **appsettings.Secrets.json** - Local secrets (gitignored)
3. **Environment Variables** - Production overrides (highest priority)

## Setting Up Local Secrets

### Step 1: Create appsettings.Secrets.json

Create this file in `ClientManagerAPI` folder:

**Location:** `C:\Projects\client-manager\ClientManagerAPI\appsettings.Secrets.json`

``````json
{
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=c:/stores/brand2boost/identity.db"
  },
  "ApiSettings": {
    "OpenApiKey": "sk-your-openai-api-key"
  },
  "AuthOptions": {
    "JwtKey": "your-secure-jwt-key-at-least-32-characters",
    "SeedAdminUserPassword": "YourSecureAdminPassword!",
    "SeedUSERUserPassword": "YourSecureUserPassword!"
  },
  "Smtp": {
    "Username": "your-email@example.com",
    "Password": "your-app-password",
    "From": "your-email@example.com"
  },
  "GoogleOAuth": {
    "ClientId": "your-google-client-id",
    "ClientSecret": "your-google-client-secret"
  },
  "LinkedInOAuth": {
    "ClientId": "your-linkedin-client-id",
    "ClientSecret": "your-linkedin-client-secret"
  }
}
``````

**This file is automatically gitignored and will never be committed.**

### Step 2: Get API Keys

#### OpenAI API Key
1. Go to: https://platform.openai.com/api-keys
2. Create new secret key
3. Copy to `ApiSettings:OpenApiKey`

#### Google OAuth (for social media imports)
1. Go to: https://console.cloud.google.com/
2. Create OAuth 2.0 credentials
3. Copy Client ID and Secret

#### LinkedIn OAuth
1. Go to: https://www.linkedin.com/developers/
2. Create app and get credentials

### Step 3: Frontend Configuration

Create `.env` file in `client-manager-frontend`:

``````
VITE_API_URL=https://localhost:5001
VITE_APP_NAME=Brand2Boost
``````

## Configuration Templates

### Minimal Development Setup

**Minimum required for local development:**
``````json
{
  "ConnectionStrings": {
    "DefaultConnection": "Data Source=c:/stores/brand2boost/identity.db"
  },
  "ApiSettings": {
    "OpenApiKey": "sk-your-openai-key"
  },
  "AuthOptions": {
    "JwtKey": "at-least-32-characters-long-secret-key",
    "SeedAdminUserPassword": "Admin123!",
    "SeedUSERUserPassword": "User123!"
  }
}
``````

### Example Configuration File

See template: `C:\Projects\client-manager\ClientManagerAPI\appsettings.example.json`

## Database Setup

**SQLite (Development):**
``````json
"ConnectionStrings": {
  "DefaultConnection": "Data Source=c:/stores/brand2boost/identity.db"
}
``````

**PostgreSQL (Production):**
``````json
"ConnectionStrings": {
  "DefaultConnection": "Host=localhost;Database=brand2boost;Username=postgres;Password=yourpassword"
}
``````

## Verifying Configuration

### Check Configuration Loads
``````bash
cd ClientManagerAPI
dotnet run
``````

Look for startup logs:
``````
[ModelRouter] Initialized OpenAI provider
[ModelRouter] ModelRouter ready with 1 provider(s)
``````

### Common Errors

**Missing API Key:**
``````
CRITICAL: No LLM providers initialized. Check API keys.
``````
→ Add OpenAI API key to appsettings.Secrets.json

**Invalid Connection String:**
``````
Unable to connect to database
``````
→ Check ConnectionStrings:DefaultConnection format

**JWT Key Too Short:**
``````
JWT key must be at least 32 characters
``````
→ Update AuthOptions:JwtKey with longer key

## Security Best Practices

1. **Never commit secrets** - appsettings.Secrets.json is gitignored
2. **Use strong passwords** - Minimum 12 characters, mixed case, symbols
3. **Rotate API keys** regularly
4. **Use environment variables** in production
5. **Keep .env out of git** - Already in .gitignore

## See Also

- Full secrets guide: `ClientManagerAPI/SECRETS_SETUP.md`
- Production deployment: `docs/PRODUCTION-DEPLOYMENT-GUIDE.md`
- Cross-platform setup: `CROSS_PLATFORM_SETUP.md`
"@

$bodyObj = @{ name = "Local Configuration Guide"; content = $content }
$body = $bodyObj | ConvertTo-Json -Depth 10

try {
    $page = Invoke-RestMethod -Method POST -Uri "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$kbDocId/pages" -Headers $headers -Body $body
    Write-Host "SUCCESS! Page ID: $($page.id)" -ForegroundColor Green
}
catch { Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red }
Write-Host ""

# Page 5: Tools & Scripts Reference
Write-Host "[6/6] Adding Tools & Scripts Reference..." -ForegroundColor Cyan
$content = @"
# Tools & Scripts Reference

## Deployment Scripts

### publish-brand2boost-backend.ps1
**Purpose:** Deploy backend to production server

**Usage:**
``````powershell
.\publish-brand2boost-backend.ps1
``````

**What it does:**
1. Builds Release configuration
2. Copies to dist\ folder
3. Overlays production config from env\prod\
4. Deploys via MSDeploy to 85.215.217.154:8172

**Prerequisites:**
- env\ folder from Google Drive
- Microsoft Web Deploy V3 installed

### publish-brand2boost-frontend.ps1
**Purpose:** Deploy frontend to production

**Usage:**
``````powershell
.\publish-brand2boost-frontend.ps1
``````

## Database Tools

### Entity Framework Migrations

**Create migration:**
``````bash
cd ClientManagerAPI
dotnet ef migrations add YourMigrationName
``````

**Apply migrations:**
``````bash
dotnet ef database update
``````

**Remove last migration:**
``````bash
dotnet ef migrations remove
``````

**Generate SQL script:**
``````bash
dotnet ef migrations script > migration.sql
``````

## Testing Tools

### Backend Tests
``````bash
cd ClientManagerAPI.Tests
dotnet test
``````

### Frontend Tests
``````bash
cd client-manager-frontend
npm run test
``````

### Run specific test
``````bash
dotnet test --filter "FullyQualifiedName~YourTestName"
``````

## Development Tools

### dotnet CLI

**Watch mode (auto-reload):**
``````bash
dotnet watch run
``````

**Clean build:**
``````bash
dotnet clean
dotnet build
``````

**Format code:**
``````bash
dotnet format
``````

### npm Scripts

**Development:**
``````bash
npm run dev          # Start dev server
npm run build        # Build for production
npm run preview      # Preview production build
``````

**Code quality:**
``````bash
npm run lint         # Run ESLint
npm run type-check   # TypeScript checking
``````

## Git Workflow Tools

### gh CLI (GitHub)

**Create PR:**
``````bash
gh pr create --title "feat: Your feature" --body "Description"
``````

**View PRs:**
``````bash
gh pr list
gh pr view 123
``````

**Merge PR:**
``````bash
gh pr merge 123 --squash
``````

## Documentation Tools

### API Documentation (DocFX)

**Generate docs:**
``````bash
cd docs
dotnet tool restore
dotnet docfx metadata docfx.json
dotnet docfx build docfx.json
``````

**View docs:**
- Open `docs/apidoc/index.html` in browser

## Monitoring & Debugging

### Application Logs

**Development:**
- Console output when running `dotnet run`
- Structured logging to console

**Production:**
- IIS logs: `C:\inetpub\logs\`
- Application logs: Check IIS application pool settings

### Health Checks

**API Health:**
``````bash
curl https://localhost:5001/health
curl https://api.brand2boost.com/health
``````

**Swagger UI:**
- Local: https://localhost:5001/swagger
- Production: https://api.brand2boost.com/swagger

## ClickUp Integration

### clickup-sync.ps1
**Purpose:** Sync tasks between ClickUp and local workflow

**Usage:**
``````powershell
# List tasks
.\clickup-sync.ps1 -Action list

# Update task status
.\clickup-sync.ps1 -Action update -TaskId 869xxx -Status busy

# Add comment
.\clickup-sync.ps1 -Action comment -TaskId 869xxx -Comment "PR created"
``````

## Useful Commands Cheat Sheet

**Start everything:**
``````bash
# Terminal 1: Backend
cd C:\Projects\client-manager\ClientManagerAPI
dotnet run

# Terminal 2: Frontend
cd C:\Projects\client-manager\client-manager-frontend
npm run dev

# Terminal 3: Redis (if not running as service)
redis-server

# Terminal 4: PostgreSQL
# Usually runs as service, check: services.msc
``````

**Reset database:**
``````bash
cd ClientManagerAPI
dotnet ef database drop
dotnet ef database update
``````

**Clean everything:**
``````bash
# Backend
dotnet clean
rm -rf bin obj

# Frontend
rm -rf node_modules dist
npm install
``````

## IDE Extensions (VS Code)

**Recommended:**
- C# (Microsoft)
- ESLint
- Prettier
- GitLens
- Docker
- REST Client

## Further Reading

- Project README: `C:\Projects\client-manager\README.md`
- Production deployment: `docs/PRODUCTION-DEPLOYMENT-GUIDE.md`
- Secrets setup: `ClientManagerAPI/SECRETS_SETUP.md`
- Social media setup: `docs/social-media-setup-guide.md`
"@

$bodyObj = @{ name = "Tools & Scripts Reference"; content = $content }
$body = $bodyObj | ConvertTo-Json -Depth 10

try {
    $page = Invoke-RestMethod -Method POST -Uri "https://api.clickup.com/api/v3/workspaces/$workspaceId/docs/$kbDocId/pages" -Headers $headers -Body $body
    Write-Host "SUCCESS! Page ID: $($page.id)" -ForegroundColor Green
}
catch { Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red }
Write-Host ""

Write-Host "=== PROJECT KNOWLEDGE BASE COMPLETE ===" -ForegroundColor Green
Write-Host ""
Write-Host "Knowledge Base Doc ID: $kbDocId" -ForegroundColor Cyan
Write-Host "URL: https://app.clickup.com/$workspaceId/v/dc/$kbDocId" -ForegroundColor White
Write-Host ""
Write-Host "Pages created:" -ForegroundColor Yellow
Write-Host "  1. Getting Started" -ForegroundColor White
Write-Host "  2. Development Environment Setup" -ForegroundColor White
Write-Host "  3. Production Server Information" -ForegroundColor White
Write-Host "  4. Local Configuration Guide" -ForegroundColor White
Write-Host "  5. Tools & Scripts Reference" -ForegroundColor White
Write-Host ""
Write-Host "NEXT: Convert to Wiki in ClickUp for better navigation" -ForegroundColor Yellow
