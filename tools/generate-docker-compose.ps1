<#
.SYNOPSIS
    Generates docker-compose.yml for full-stack development environment.

.DESCRIPTION
    Creates docker-compose configuration for ASP.NET Core API, React frontend,
    SQL Server, Redis, and other services. Includes health checks, volumes,
    and dependency ordering.

    Features:
    - Auto-detects project structure
    - Generates Dockerfiles if missing
    - Configures SQL Server with persistent volumes
    - Redis for caching
    - Nginx reverse proxy for frontend
    - Health checks for all services
    - Development and production profiles

.PARAMETER ProjectPath
    Root path containing API and frontend projects

.PARAMETER Services
    Services to include: api, frontend, sqlserver, redis, nginx (default: all)

.PARAMETER OutputPath
    Output path for docker-compose.yml (default: project root)

.PARAMETER Profile
    Configuration profile: development, production (default: development)

.PARAMETER GenerateDockerfiles
    Generate Dockerfiles for API and frontend if missing

.EXAMPLE
    .\generate-docker-compose.ps1 -ProjectPath "C:\Projects\client-manager"
    .\generate-docker-compose.ps1 -ProjectPath "." -Services api,sqlserver,redis
    .\generate-docker-compose.ps1 -ProjectPath "." -Profile production -GenerateDockerfiles
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [string[]]$Services = @("api", "frontend", "sqlserver", "redis", "nginx"),
    [string]$OutputPath,
    [ValidateSet("development", "production")]
    [string]$Profile = "development",
    [switch]$GenerateDockerfiles
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Find-ApiProject {
    param([string]$ProjectPath)

    $apiProjects = Get-ChildItem $ProjectPath -Filter "*Api*.csproj" -Recurse | Select-Object -First 1

    if ($apiProjects) {
        return $apiProjects.Directory.FullName
    }

    return $null
}

function Find-FrontendProject {
    param([string]$ProjectPath)

    $frontendDirs = Get-ChildItem $ProjectPath -Directory | Where-Object {
        $_.Name -match 'Frontend|Client|UI' -and (Test-Path (Join-Path $_.FullName "package.json"))
    } | Select-Object -First 1

    if ($frontendDirs) {
        return $frontendDirs.FullName
    }

    return $null
}

function Generate-ApiDockerfile {
    param([string]$ApiProjectPath, [string]$Profile)

    $csproj = Get-ChildItem $ApiProjectPath -Filter "*.csproj" | Select-Object -First 1
    $projectName = $csproj.BaseName

    $dockerfile = @"
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY *.csproj .
RUN dotnet restore

# Copy source code and build
COPY . .
RUN dotnet build -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=publish /app/publish .

EXPOSE 80
EXPOSE 443

ENTRYPOINT ["dotnet", "$projectName.dll"]
"@

    $dockerfilePath = Join-Path $ApiProjectPath "Dockerfile"
    $dockerfile | Set-Content $dockerfilePath -Encoding UTF8

    Write-Host "Generated: $dockerfilePath" -ForegroundColor Green
}

function Generate-FrontendDockerfile {
    param([string]$FrontendProjectPath, [string]$Profile)

    if ($Profile -eq "development") {
        $dockerfile = @"
# Development mode - hot reload with Vite
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm install

# Copy source code
COPY . .

EXPOSE 5173

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
"@
    } else {
        $dockerfile = @"
# Build stage
FROM node:18-alpine AS build
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm ci

# Copy source and build
COPY . .
RUN npm run build

# Production stage with nginx
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
"@
    }

    $dockerfilePath = Join-Path $FrontendProjectPath "Dockerfile"
    $dockerfile | Set-Content $dockerfilePath -Encoding UTF8

    Write-Host "Generated: $dockerfilePath" -ForegroundColor Green

    # Generate nginx.conf for production
    if ($Profile -eq "production") {
        $nginxConf = @"
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server {
        listen 80;
        server_name localhost;
        root /usr/share/nginx/html;
        index index.html;

        location / {
            try_files `$uri `$uri/ /index.html;
        }

        location /api {
            proxy_pass http://api:80;
            proxy_http_version 1.1;
            proxy_set_header Upgrade `$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host `$host;
            proxy_cache_bypass `$http_upgrade;
        }
    }
}
"@

        $nginxConfPath = Join-Path $FrontendProjectPath "nginx.conf"
        $nginxConf | Set-Content $nginxConfPath -Encoding UTF8

        Write-Host "Generated: $nginxConfPath" -ForegroundColor Green
    }
}

function Generate-DockerCompose {
    param([string]$ProjectPath, [string[]]$Services, [string]$Profile, [string]$ApiPath, [string]$FrontendPath)

    $services = @()

    # API Service
    if ($Services -contains "api" -and $ApiPath) {
        $apiRelativePath = $ApiPath -replace [regex]::Escape($ProjectPath), '.' -replace '\\', '/'

        $apiService = @"
  api:
    build:
      context: $apiRelativePath
      dockerfile: Dockerfile
    container_name: clientmanager-api
    ports:
      - "7001:80"
      - "7002:443"
    environment:
      - ASPNETCORE_ENVIRONMENT=$Profile
      - ConnectionStrings__DefaultConnection=Server=sqlserver;Database=ClientManager;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True
      - Redis__ConnectionString=redis:6379
    depends_on:
      sqlserver:
        condition: service_healthy
      redis:
        condition: service_started
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
"@
        $services += $apiService
    }

    # Frontend Service
    if ($Services -contains "frontend" -and $FrontendPath) {
        $frontendRelativePath = $FrontendPath -replace [regex]::Escape($ProjectPath), '.' -replace '\\', '/'

        if ($Profile -eq "development") {
            $frontendService = @"
  frontend:
    build:
      context: $frontendRelativePath
      dockerfile: Dockerfile
    container_name: clientmanager-frontend
    ports:
      - "5173:5173"
    environment:
      - VITE_API_BASE_URL=http://localhost:7001
    volumes:
      - $frontendRelativePath:/app
      - /app/node_modules
    networks:
      - app-network
    depends_on:
      - api
"@
        } else {
            $frontendService = @"
  frontend:
    build:
      context: $frontendRelativePath
      dockerfile: Dockerfile
    container_name: clientmanager-frontend
    ports:
      - "80:80"
    environment:
      - API_URL=http://api:80
    networks:
      - app-network
    depends_on:
      - api
"@
        }

        $services += $frontendService
    }

    # SQL Server Service
    if ($Services -contains "sqlserver") {
        $sqlServerService = @"
  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    container_name: clientmanager-sqlserver
    ports:
      - "1433:1433"
    environment:
      - ACCEPT_EULA=Y
      - SA_PASSWORD=YourStrong@Passw0rd
      - MSSQL_PID=Developer
    volumes:
      - sqlserver-data:/var/opt/mssql
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "/opt/mssql-tools/bin/sqlcmd", "-S", "localhost", "-U", "sa", "-P", "YourStrong@Passw0rd", "-Q", "SELECT 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
"@
        $services += $sqlServerService
    }

    # Redis Service
    if ($Services -contains "redis") {
        $redisService = @"
  redis:
    image: redis:7-alpine
    container_name: clientmanager-redis
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    networks:
      - app-network
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3
"@
        $services += $redisService
    }

    # Build docker-compose.yml
    $dockerCompose = @"
version: '3.8'

services:
$($services -join "`n`n")

networks:
  app-network:
    driver: bridge

volumes:
"@

    if ($Services -contains "sqlserver") {
        $dockerCompose += "`n  sqlserver-data:"
    }

    if ($Services -contains "redis") {
        $dockerCompose += "`n  redis-data:"
    }

    return $dockerCompose
}

function Generate-DockerIgnore {
    param([string]$Path)

    $dockerignore = @"
# Build outputs
bin/
obj/
dist/
build/
out/

# Dependencies
node_modules/
packages/

# IDE
.vs/
.vscode/
.idea/

# Git
.git/
.gitignore

# Environment
.env
.env.local

# Logs
*.log
logs/

# OS
.DS_Store
Thumbs.db
"@

    $dockerignorePath = Join-Path $Path ".dockerignore"
    $dockerignore | Set-Content $dockerignorePath -Encoding UTF8

    Write-Host "Generated: $dockerignorePath" -ForegroundColor Green
}

# Main execution
Write-Host ""
Write-Host "=== Docker Compose Generator ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Find projects
Write-Host "Scanning for projects..." -ForegroundColor Cyan

$apiPath = Find-ApiProject -ProjectPath $ProjectPath
$frontendPath = Find-FrontendProject -ProjectPath $ProjectPath

if ($apiPath) {
    Write-Host "  Found API: $apiPath" -ForegroundColor Green
} else {
    Write-Host "  API project not found" -ForegroundColor Yellow
}

if ($frontendPath) {
    Write-Host "  Found Frontend: $frontendPath" -ForegroundColor Green
} else {
    Write-Host "  Frontend project not found" -ForegroundColor Yellow
}

Write-Host ""

# Generate Dockerfiles if requested
if ($GenerateDockerfiles) {
    Write-Host "=== Generating Dockerfiles ===" -ForegroundColor Cyan
    Write-Host ""

    if ($apiPath -and $Services -contains "api") {
        Generate-ApiDockerfile -ApiProjectPath $apiPath -Profile $Profile
    }

    if ($frontendPath -and $Services -contains "frontend") {
        Generate-FrontendDockerfile -FrontendProjectPath $frontendPath -Profile $Profile
    }

    # Generate .dockerignore files
    if ($apiPath) {
        Generate-DockerIgnore -Path $apiPath
    }

    if ($frontendPath) {
        Generate-DockerIgnore -Path $frontendPath
    }

    Write-Host ""
}

# Generate docker-compose.yml
Write-Host "=== Generating docker-compose.yml ===" -ForegroundColor Cyan
Write-Host ""

$dockerCompose = Generate-DockerCompose -ProjectPath $ProjectPath -Services $Services -Profile $Profile -ApiPath $apiPath -FrontendPath $frontendPath

$outputFilePath = if ($OutputPath) {
    $OutputPath
} else {
    Join-Path $ProjectPath "docker-compose.yml"
}

$dockerCompose | Set-Content $outputFilePath -Encoding UTF8

Write-Host "Generated: $outputFilePath" -ForegroundColor Green
Write-Host ""

# Generate helper scripts
$startScript = @"
#!/bin/bash
# Start all services
docker-compose up -d

echo "Services started!"
echo ""
echo "API:      http://localhost:7001"
echo "Frontend: http://localhost:$(if ($Profile -eq 'development') { '5173' } else { '80' })"
echo "SQL Server: localhost:1433 (sa / YourStrong@Passw0rd)"
echo "Redis:    localhost:6379"
echo ""
echo "To view logs: docker-compose logs -f"
echo "To stop:      docker-compose down"
"@

$startScriptPath = Join-Path $ProjectPath "docker-start.sh"
$startScript | Set-Content $startScriptPath -Encoding UTF8

Write-Host "Generated: $startScriptPath" -ForegroundColor Green
Write-Host ""

Write-Host "=== Next Steps ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Review docker-compose.yml and adjust as needed" -ForegroundColor White
Write-Host "2. Update connection strings in appsettings.json" -ForegroundColor White
Write-Host "3. Start services:" -ForegroundColor White
Write-Host "   docker-compose up -d" -ForegroundColor DarkGray
Write-Host "4. View logs:" -ForegroundColor White
Write-Host "   docker-compose logs -f" -ForegroundColor DarkGray
Write-Host "5. Stop services:" -ForegroundColor White
Write-Host "   docker-compose down" -ForegroundColor DarkGray
Write-Host ""

Write-Host "=== Generation Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
