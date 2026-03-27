<#
.SYNOPSIS
    Automated developer onboarding and environment setup.

.DESCRIPTION
    Comprehensive onboarding script for new developers.
    Checks prerequisites, installs tools, configures environment,
    and generates personalized documentation.

    Features:
    - Prerequisites checking (Git, Node, .NET, VS Code)
    - Tool installation automation
    - Git configuration
    - IDE and editor setup
    - Project cloning and initialization
    - Database setup
    - Documentation generation
    - Team introductions and resources

.PARAMETER DeveloperName
    Developer's full name

.PARAMETER DeveloperEmail
    Developer's email address

.PARAMETER ProjectName
    Project name to set up

.PARAMETER SkipInstallation
    Skip tool installation (check only)

.PARAMETER GenerateDocsOnly
    Only generate documentation

.EXAMPLE
    .\onboard-developer.ps1 -DeveloperName "John Doe" -DeveloperEmail "john@example.com"
    .\onboard-developer.ps1 -DeveloperName "Jane Smith" -DeveloperEmail "jane@example.com" -ProjectName "client-manager"
    .\onboard-developer.ps1 -SkipInstallation
    .\onboard-developer.ps1 -GenerateDocsOnly
#>

param(
    [string]$DeveloperName,
    [string]$DeveloperEmail,
    [string]$ProjectName,
    [switch]$SkipInstallation,
    [switch]$GenerateDocsOnly
)

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


$script:Prerequisites = @{
    "Git" = @{
        "Command" = "git --version"
        "InstallUrl" = "https://git-scm.com/downloads"
        "Required" = $true
    }
    "Node.js" = @{
        "Command" = "node --version"
        "InstallUrl" = "https://nodejs.org/"
        "Required" = $true
    }
    ".NET SDK" = @{
        "Command" = "dotnet --version"
        "InstallUrl" = "https://dotnet.microsoft.com/download"
        "Required" = $true
    }
    "VS Code" = @{
        "Command" = "code --version"
        "InstallUrl" = "https://code.visualstudio.com/"
        "Required" = $false
    }
    "GitHub CLI" = @{
        "Command" = "gh --version"
        "InstallUrl" = "https://cli.github.com/"
        "Required" = $false
    }
}

function Show-Welcome {
    param([string]$DeveloperName)

    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "   Developer Onboarding - Welcome!" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""

    if ($DeveloperName) {
        Write-Host "Welcome, $DeveloperName!" -ForegroundColor Green
    } else {
        Write-Host "Welcome to the team!" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "This script will help you set up your development environment." -ForegroundColor White
    Write-Host ""
}

function Check-Prerequisites {
    Write-Host ""
    Write-Host "=== Checking Prerequisites ===" -ForegroundColor Cyan
    Write-Host ""

    $results = @{}

    foreach ($tool in $script:Prerequisites.Keys) {
        $prereq = $script:Prerequisites[$tool]

        Write-Host "Checking: $tool" -NoNewline -ForegroundColor Yellow

        try {
            $output = Invoke-Expression $prereq.Command 2>&1

            if ($LASTEXITCODE -eq 0 -or $output) {
                Write-Host " [OK]" -ForegroundColor Green
                $results[$tool] = $true
            } else {
                Write-Host " [NOT FOUND]" -ForegroundColor Red
                $results[$tool] = $false
            }

        } catch {
            Write-Host " [NOT FOUND]" -ForegroundColor Red
            $results[$tool] = $false
        }
    }

    Write-Host ""

    # Show missing required tools
    $missing = $results.Keys | Where-Object {
        -not $results[$_] -and $script:Prerequisites[$_].Required
    }

    if ($missing.Count -gt 0) {
        Write-Host "Missing required tools:" -ForegroundColor Red
        Write-Host ""

        foreach ($tool in $missing) {
            $url = $script:Prerequisites[$tool].InstallUrl
            Write-Host "  - $tool" -ForegroundColor Yellow
            Write-Host "    Install from: $url" -ForegroundColor DarkGray
        }

        Write-Host ""

        return $false
    }

    Write-Host "All required prerequisites installed!" -ForegroundColor Green
    Write-Host ""

    return $true
}

function Configure-Git {
    param([string]$Name, [string]$Email)

    Write-Host ""
    Write-Host "=== Configuring Git ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $Name) {
        $Name = Read-Host "Enter your full name"
    }

    if (-not $Email) {
        $Email = Read-Host "Enter your email address"
    }

    git config --global user.name $Name
    git config --global user.email $Email

    Write-Host "Git configured with:" -ForegroundColor Green
    Write-Host "  Name: $Name" -ForegroundColor White
    Write-Host "  Email: $Email" -ForegroundColor White
    Write-Host ""

    # Additional recommended settings
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.autocrlf true

    Write-Host "Applied recommended Git settings" -ForegroundColor Green
    Write-Host ""
}

function Setup-VSCode {
    Write-Host ""
    Write-Host "=== Setting Up VS Code ===" -ForegroundColor Cyan
    Write-Host ""

    $extensions = @(
        "ms-dotnettools.csharp",
        "ms-dotnettools.csdevkit",
        "dbaeumer.vscode-eslint",
        "esbenp.prettier-vscode",
        "eamodio.gitlens",
        "github.copilot"
    )

    Write-Host "Installing recommended extensions..." -ForegroundColor Yellow
    Write-Host ""

    foreach ($ext in $extensions) {
        Write-Host "Installing: $ext" -NoNewline -ForegroundColor DarkGray
        code --install-extension $ext --force 2>&1 | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host " [OK]" -ForegroundColor Green
        } else {
            Write-Host " [FAILED]" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "VS Code extensions installed" -ForegroundColor Green
    Write-Host ""
}

function Clone-Project {
    param([string]$ProjectName)

    Write-Host ""
    Write-Host "=== Cloning Project ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $ProjectName) {
        $ProjectName = Read-Host "Enter project name to clone"
    }

    $repoUrl = Read-Host "Enter repository URL"

    $targetDir = Join-Path $env:USERPROFILE "Projects\$ProjectName"

    if (Test-Path $targetDir) {
        Write-Host "Project already cloned at: $targetDir" -ForegroundColor Yellow
        return $targetDir
    }

    Write-Host "Cloning $ProjectName..." -ForegroundColor Yellow

    git clone $repoUrl $targetDir

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Project cloned to: $targetDir" -ForegroundColor Green
        Write-Host ""
        return $targetDir
    } else {
        Write-Host "Failed to clone project" -ForegroundColor Red
        return $null
    }
}

function Initialize-Project {
    param([string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Initializing Project ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not $ProjectPath -or -not (Test-Path $ProjectPath)) {
        Write-Host "ERROR: Invalid project path" -ForegroundColor Red
        return
    }

    Push-Location $ProjectPath
    try {
        # Install npm packages if package.json exists
        if (Test-Path "package.json") {
            Write-Host "Installing npm dependencies..." -ForegroundColor Yellow
            npm install
            Write-Host "npm dependencies installed" -ForegroundColor Green
            Write-Host ""
        }

        # Restore NuGet packages if .csproj exists
        $csprojFiles = Get-ChildItem -Filter "*.csproj" -Recurse

        if ($csprojFiles.Count -gt 0) {
            Write-Host "Restoring NuGet packages..." -ForegroundColor Yellow
            dotnet restore
            Write-Host "NuGet packages restored" -ForegroundColor Green
            Write-Host ""
        }

        # Create .env from template if it exists
        if ((Test-Path ".env.template") -and -not (Test-Path ".env")) {
            Write-Host "Creating .env from template..." -ForegroundColor Yellow
            Copy-Item ".env.template" ".env"
            Write-Host "Created .env file - please update with your local settings" -ForegroundColor Yellow
            Write-Host ""
        }

    } finally {
        Pop-Location
    }
}

function Generate-OnboardingDoc {
    param([string]$DeveloperName, [string]$ProjectPath)

    Write-Host ""
    Write-Host "=== Generating Onboarding Documentation ===" -ForegroundColor Cyan
    Write-Host ""

    $doc = @"
# Onboarding Guide for $DeveloperName

Welcome to the team! This document was generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss').

## Getting Started

### Your Development Environment

**Tools Installed:**
- Git
- Node.js
- .NET SDK
- VS Code with recommended extensions

**Git Configuration:**
- Name: $DeveloperName
- Email: $DeveloperEmail

### Project Setup

**Project Location:**
``````
$ProjectPath
``````

### Next Steps

1. **Read the Project README**
   - Start with the main README.md in the project root
   - Review architecture documentation in /docs folder

2. **Run the Application**
   - Backend: ``dotnet run`` in API folder
   - Frontend: ``npm run dev`` in Frontend folder

3. **Run Tests**
   - Backend: ``dotnet test``
   - Frontend: ``npm test``

4. **Create Your First Branch**
   ``````bash
   git checkout -b feature/your-name/first-task
   ``````

5. **Make Your First Commit**
   - Follow conventional commits format
   - Run pre-commit hooks

### Team Resources

**Documentation:**
- Main docs: /docs folder
- API docs: /docs/api
- Architecture: /docs/architecture

**Communication:**
- Daily standup: 9:00 AM
- Team chat: [Your team chat platform]
- Code reviews: GitHub Pull Requests

**Important Contacts:**
- Tech Lead: [Name]
- Product Manager: [Name]
- DevOps: [Name]

### Common Tasks

**Starting Development:**
``````bash
# Backend API
cd API
dotnet watch run

# Frontend
cd Frontend
npm run dev
``````

**Running Tests:**
``````bash
# All tests
dotnet test
npm test

# With coverage
dotnet test --collect:"XPlat Code Coverage"
npm run test:coverage
``````

**Database Migrations:**
``````bash
# Create migration
dotnet ef migrations add MigrationName

# Apply migration
dotnet ef database update
``````

**Code Style:**
- C#: Follow .editorconfig
- TypeScript: ESLint + Prettier
- Format on save enabled

### Useful Scripts

Located in ``C:\scripts\tools``:
- ``generate-vscode-workspace.ps1`` - Generate workspace configs
- ``manage-snippets.ps1`` - Code snippet management
- ``git-interactive.ps1`` - Interactive Git helper

### Troubleshooting

**Common Issues:**

1. **Build Errors**
   - Clean: ``dotnet clean && dotnet build``
   - Clear node_modules: ``rm -rf node_modules && npm install``

2. **Database Issues**
   - Check connection string in appsettings.json
   - Ensure SQL Server is running
   - Recreate database: ``dotnet ef database drop && dotnet ef database update``

3. **Port Conflicts**
   - Backend default: 5001
   - Frontend default: 5173
   - Change in configuration if needed

### Learning Resources

**Technology Stack:**
- ASP.NET Core 8.0
- Entity Framework Core
- React 18
- TypeScript
- SQL Server

**Recommended Learning:**
- [ASP.NET Core docs](https://docs.microsoft.com/aspnet/core)
- [React docs](https://react.dev)
- [TypeScript handbook](https://www.typescriptlang.org/docs/)

---

**Questions?**
Don't hesitate to ask your teammates! We're here to help.

Generated by Developer Onboarding Script
"@

    $docPath = if ($ProjectPath) {
        Join-Path $ProjectPath "ONBOARDING-$($DeveloperName -replace '\s', '-').md"
    } else {
        "ONBOARDING-$($DeveloperName -replace '\s', '-').md"
    }

    $doc | Set-Content $docPath -Encoding UTF8

    Write-Host "Onboarding documentation generated: $docPath" -ForegroundColor Green
    Write-Host ""

    return $docPath
}

# Main execution
Show-Welcome -DeveloperName $DeveloperName

if ($GenerateDocsOnly) {
    $docPath = Generate-OnboardingDoc -DeveloperName $DeveloperName -ProjectPath $ProjectPath
    Write-Host "Documentation generated at: $docPath" -ForegroundColor Cyan
    exit 0
}

# Check prerequisites
$prereqsOk = Check-Prerequisites

if (-not $prereqsOk -and -not $SkipInstallation) {
    Write-Host "Please install missing prerequisites and run this script again" -ForegroundColor Yellow
    exit 1
}

if ($SkipInstallation) {
    Write-Host "Skipping installation (check only)" -ForegroundColor Yellow
    exit 0
}

# Configure Git
if ($DeveloperName -and $DeveloperEmail) {
    Configure-Git -Name $DeveloperName -Email $DeveloperEmail
}

# Setup VS Code
if (Test-Path (Get-Command code -ErrorAction SilentlyContinue).Source) {
    $setupVSCode = Read-Host "Set up VS Code with recommended extensions? (yes/no)"

    if ($setupVSCode -eq "yes") {
        Setup-VSCode
    }
}

# Clone project
if ($ProjectName) {
    $cloneProject = Read-Host "Clone project repository? (yes/no)"

    if ($cloneProject -eq "yes") {
        $projectPath = Clone-Project -ProjectName $ProjectName

        if ($projectPath) {
            Initialize-Project -ProjectPath $projectPath
        }
    }
}

# Generate documentation
$generateDocs = Read-Host "Generate personalized onboarding documentation? (yes/no)"

if ($generateDocs -eq "yes") {
    Generate-OnboardingDoc -DeveloperName $DeveloperName -ProjectPath $projectPath
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "   Onboarding Complete!" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "You're all set! Happy coding!" -ForegroundColor Green
Write-Host ""

exit 0
