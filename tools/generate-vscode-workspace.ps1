<#
.SYNOPSIS
    Generates comprehensive VS Code workspace configuration for projects.

.DESCRIPTION
    Creates VS Code workspace files (.vscode folder) with settings, extensions,
    tasks, and debugging configurations tailored to project type.

    Features:
    - Auto-detect project type (C#, TypeScript, fullstack)
    - Extension recommendations based on tech stack
    - Custom settings for formatters, linters
    - Build/run/test tasks
    - Debug configurations (API, frontend, full-stack)
    - Multi-root workspace support
    - Team-wide consistency enforcement

.PARAMETER ProjectPath
    Path to project root directory

.PARAMETER ProjectType
    Project type: csharp, typescript, fullstack, auto (default: auto)

.PARAMETER WorkspaceName
    Name for multi-root workspace file

.PARAMETER IncludeExtensions
    Include extension recommendations

.PARAMETER IncludeTasks
    Include build/run/test tasks

.PARAMETER IncludeDebug
    Include debug launch configurations

.PARAMETER MultiRoot
    Create multi-root workspace file

.EXAMPLE
    .\generate-vscode-workspace.ps1 -ProjectPath "C:\Projects\client-manager"
    .\generate-vscode-workspace.ps1 -ProjectPath "." -ProjectType fullstack -MultiRoot -WorkspaceName "ClientManager"
    .\generate-vscode-workspace.ps1 -ProjectPath "." -IncludeExtensions -IncludeTasks -IncludeDebug
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    [ValidateSet("csharp", "typescript", "fullstack", "auto")]
    [string]$ProjectType = "auto",

    [string]$WorkspaceName,
    [switch]$IncludeExtensions = $true,
    [switch]$IncludeTasks = $true,
    [switch]$IncludeDebug = $true,
    [switch]$MultiRoot
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Detect-ProjectType {
    param([string]$Path)

    $hasCsProj = (Get-ChildItem $Path -Filter "*.csproj" -Recurse -ErrorAction SilentlyContinue).Count -gt 0
    $hasPackageJson = Test-Path (Join-Path $Path "package.json")
    $hasTsConfig = Test-Path (Join-Path $Path "tsconfig.json")

    if ($hasCsProj -and ($hasPackageJson -or $hasTsConfig)) {
        return "fullstack"
    } elseif ($hasCsProj) {
        return "csharp"
    } elseif ($hasPackageJson -or $hasTsConfig) {
        return "typescript"
    } else {
        return "unknown"
    }
}

function Get-ExtensionRecommendations {
    param([string]$ProjectType)

    $extensions = @{
        "csharp" = @(
            "ms-dotnettools.csharp",
            "ms-dotnettools.csdevkit",
            "jchannon.csharpextensions",
            "jorgeserrano.vscode-csharp-snippets",
            "kreativ-software.csharpextensions",
            "formulahendry.dotnet-test-explorer"
        )
        "typescript" = @(
            "dbaeumer.vscode-eslint",
            "esbenp.prettier-vscode",
            "bradlc.vscode-tailwindcss",
            "dsznajder.es7-react-js-snippets",
            "steoates.autoimport",
            "christian-kohler.path-intellisense"
        )
        "common" = @(
            "editorconfig.editorconfig",
            "eamodio.gitlens",
            "github.copilot",
            "github.copilot-chat",
            "ms-vscode.powershell",
            "bierner.markdown-mermaid",
            "yzhang.markdown-all-in-one",
            "gruntfuggly.todo-tree"
        )
    }

    $recommendations = @()

    if ($ProjectType -eq "fullstack") {
        $recommendations += $extensions.csharp
        $recommendations += $extensions.typescript
    } elseif ($ProjectType -eq "csharp") {
        $recommendations += $extensions.csharp
    } elseif ($ProjectType -eq "typescript") {
        $recommendations += $extensions.typescript
    }

    $recommendations += $extensions.common

    return $recommendations | Select-Object -Unique
}

function Generate-Settings {
    param([string]$ProjectType)

    $commonSettings = @{
        "files.autoSave" = "afterDelay"
        "files.autoSaveDelay" = 1000
        "editor.formatOnSave" = $true
        "editor.codeActionsOnSave" = @{
            "source.organizeImports" = "explicit"
            "source.fixAll.eslint" = "explicit"
        }
        "editor.tabSize" = 2
        "editor.insertSpaces" = $true
        "files.trimTrailingWhitespace" = $true
        "files.insertFinalNewline" = $true
        "files.exclude" = @{
            "**/bin" = $true
            "**/obj" = $true
            "**/node_modules" = $true
            "**/.git" = $true
        }
        "search.exclude" = @{
            "**/node_modules" = $true
            "**/bin" = $true
            "**/obj" = $true
            "**/dist" = $true
        }
    }

    $csharpSettings = @{
        "omnisharp.enableEditorConfigSupport" = $true
        "omnisharp.enableRoslynAnalyzers" = $true
        "csharp.suppressDotnetRestoreNotification" = $true
        "[csharp]" = @{
            "editor.defaultFormatter" = "ms-dotnettools.csharp"
            "editor.tabSize" = 4
        }
    }

    $typescriptSettings = @{
        "typescript.updateImportsOnFileMove.enabled" = "always"
        "javascript.updateImportsOnFileMove.enabled" = "always"
        "eslint.validate" = @("javascript", "typescript", "typescriptreact")
        "[typescript]" = @{
            "editor.defaultFormatter" = "esbenp.prettier-vscode"
        }
        "[typescriptreact]" = @{
            "editor.defaultFormatter" = "esbenp.prettier-vscode"
        }
        "[json]" = @{
            "editor.defaultFormatter" = "esbenp.prettier-vscode"
        }
    }

    $settings = $commonSettings

    if ($ProjectType -eq "fullstack" -or $ProjectType -eq "csharp") {
        foreach ($key in $csharpSettings.Keys) {
            $settings[$key] = $csharpSettings[$key]
        }
    }

    if ($ProjectType -eq "fullstack" -or $ProjectType -eq "typescript") {
        foreach ($key in $typescriptSettings.Keys) {
            $settings[$key] = $typescriptSettings[$key]
        }
    }

    return $settings
}

function Generate-Tasks {
    param([string]$ProjectType, [string]$ProjectPath)

    $tasks = @{
        "version" = "2.0.0"
        "tasks" = @()
    }

    if ($ProjectType -eq "fullstack" -or $ProjectType -eq "csharp") {
        # Find .csproj file
        $csprojFiles = Get-ChildItem $ProjectPath -Filter "*.csproj" -Recurse | Where-Object { $_.Name -notmatch 'Test' }

        if ($csprojFiles.Count -gt 0) {
            $csproj = $csprojFiles[0]
            $csprojRelative = $csproj.FullName.Replace($ProjectPath, ".").Replace('\', '/')

            $tasks.tasks += @{
                "label" = "build"
                "command" = "dotnet"
                "type" = "process"
                "args" = @("build", $csprojRelative, "/property:GenerateFullPaths=true", "/consoleloggerparameters:NoSummary")
                "problemMatcher" = "`$msCompile"
                "group" = @{
                    "kind" = "build"
                    "isDefault" = $true
                }
            }

            $tasks.tasks += @{
                "label" = "test"
                "command" = "dotnet"
                "type" = "process"
                "args" = @("test", "/property:GenerateFullPaths=true", "/consoleloggerparameters:NoSummary")
                "problemMatcher" = "`$msCompile"
                "group" = "test"
            }

            $tasks.tasks += @{
                "label" = "watch"
                "command" = "dotnet"
                "type" = "process"
                "args" = @("watch", "run", "--project", $csprojRelative)
                "problemMatcher" = "`$msCompile"
            }
        }
    }

    if ($ProjectType -eq "fullstack" -or $ProjectType -eq "typescript") {
        if (Test-Path (Join-Path $ProjectPath "package.json")) {
            $tasks.tasks += @{
                "label" = "npm: install"
                "type" = "npm"
                "script" = "install"
                "problemMatcher" = @()
            }

            $tasks.tasks += @{
                "label" = "npm: dev"
                "type" = "npm"
                "script" = "dev"
                "problemMatcher" = @()
                "isBackground" = $true
            }

            $tasks.tasks += @{
                "label" = "npm: build"
                "type" = "npm"
                "script" = "build"
                "group" = "build"
                "problemMatcher" = @()
            }

            $tasks.tasks += @{
                "label" = "npm: test"
                "type" = "npm"
                "script" = "test"
                "group" = "test"
                "problemMatcher" = @()
            }
        }
    }

    return $tasks
}

function Generate-LaunchConfig {
    param([string]$ProjectType, [string]$ProjectPath)

    $config = @{
        "version" = "0.2.0"
        "configurations" = @()
    }

    if ($ProjectType -eq "fullstack" -or $ProjectType -eq "csharp") {
        # Find .csproj file
        $csprojFiles = Get-ChildItem $ProjectPath -Filter "*.csproj" -Recurse | Where-Object { $_.Name -notmatch 'Test' }

        if ($csprojFiles.Count -gt 0) {
            $csproj = $csprojFiles[0]
            $projectName = [System.IO.Path]::GetFileNameWithoutExtension($csproj.Name)
            $csprojRelative = $csproj.FullName.Replace($ProjectPath, "`${workspaceFolder}").Replace('\', '/')
            $dllPath = "`${workspaceFolder}/bin/Debug/net8.0/$projectName.dll"

            $config.configurations += @{
                "name" = ".NET Core Launch (web)"
                "type" = "coreclr"
                "request" = "launch"
                "preLaunchTask" = "build"
                "program" = $dllPath
                "args" = @()
                "cwd" = "`${workspaceFolder}"
                "stopAtEntry" = $false
                "serverReadyAction" = @{
                    "action" = "openExternally"
                    "pattern" = "\\bNow listening on:\\s+(https?://\\S+)"
                }
                "env" = @{
                    "ASPNETCORE_ENVIRONMENT" = "Development"
                }
                "sourceFileMap" = @{
                    "/Views" = "`${workspaceFolder}/Views"
                }
            }

            $config.configurations += @{
                "name" = ".NET Core Attach"
                "type" = "coreclr"
                "request" = "attach"
            }
        }
    }

    if ($ProjectType -eq "fullstack" -or $ProjectType -eq "typescript") {
        $config.configurations += @{
            "name" = "Launch Chrome"
            "type" = "chrome"
            "request" = "launch"
            "url" = "http://localhost:5173"
            "webRoot" = "`${workspaceFolder}"
            "sourceMaps" = $true
        }

        $config.configurations += @{
            "name" = "Attach to Chrome"
            "type" = "chrome"
            "request" = "attach"
            "port" = 9222
            "webRoot" = "`${workspaceFolder}"
        }
    }

    # Full-stack compound configuration
    if ($ProjectType -eq "fullstack") {
        $config.compounds = @(
            @{
                "name" = "Full Stack"
                "configurations" = @(".NET Core Launch (web)", "Launch Chrome")
                "stopAll" = $true
            }
        )
    }

    return $config
}

function Generate-MultiRootWorkspace {
    param([string]$WorkspaceName, [string]$ProjectPath)

    # Find potential folders
    $folders = @()

    # Add main project
    $folders += @{
        "path" = "."
    }

    # Look for API and Frontend folders
    $apiPath = Join-Path $ProjectPath "API"
    $frontendPath = Join-Path $ProjectPath "Frontend"

    if (Test-Path $apiPath) {
        $folders += @{
            "path" = "API"
        }
    }

    if (Test-Path $frontendPath) {
        $folders += @{
            "path" = "Frontend"
        }
    }

    $workspace = @{
        "folders" = $folders
        "settings" = Generate-Settings -ProjectType "fullstack"
    }

    return $workspace
}

# Main execution
Write-Host ""
Write-Host "=== VS Code Workspace Generator ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $ProjectPath)) {
    Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Detect project type
$detectedType = if ($ProjectType -eq "auto") {
    Detect-ProjectType -Path $ProjectPath
} else {
    $ProjectType
}

if ($detectedType -eq "unknown") {
    Write-Host "ERROR: Could not detect project type" -ForegroundColor Red
    Write-Host "Specify -ProjectType parameter" -ForegroundColor Yellow
    exit 1
}

Write-Host "Project Type: $detectedType" -ForegroundColor Green
Write-Host "Project Path: $ProjectPath" -ForegroundColor White
Write-Host ""

# Create .vscode directory
$vscodeDir = Join-Path $ProjectPath ".vscode"

if (-not (Test-Path $vscodeDir)) {
    New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
    Write-Host "Created .vscode directory" -ForegroundColor Green
} else {
    Write-Host ".vscode directory already exists" -ForegroundColor Yellow
}

Write-Host ""

# Generate files
$generated = @()

# Settings
$settings = Generate-Settings -ProjectType $detectedType
$settingsPath = Join-Path $vscodeDir "settings.json"
$settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
$generated += "settings.json"
Write-Host "Generated: settings.json" -ForegroundColor Green

# Extensions
if ($IncludeExtensions) {
    $extensions = Get-ExtensionRecommendations -ProjectType $detectedType
    $extensionsJson = @{
        "recommendations" = $extensions
    }
    $extensionsPath = Join-Path $vscodeDir "extensions.json"
    $extensionsJson | ConvertTo-Json -Depth 10 | Set-Content $extensionsPath -Encoding UTF8
    $generated += "extensions.json"
    Write-Host "Generated: extensions.json" -ForegroundColor Green
}

# Tasks
if ($IncludeTasks) {
    $tasks = Generate-Tasks -ProjectType $detectedType -ProjectPath $ProjectPath
    $tasksPath = Join-Path $vscodeDir "tasks.json"
    $tasks | ConvertTo-Json -Depth 10 | Set-Content $tasksPath -Encoding UTF8
    $generated += "tasks.json"
    Write-Host "Generated: tasks.json" -ForegroundColor Green
}

# Launch configurations
if ($IncludeDebug) {
    $launch = Generate-LaunchConfig -ProjectType $detectedType -ProjectPath $ProjectPath
    $launchPath = Join-Path $vscodeDir "launch.json"
    $launch | ConvertTo-Json -Depth 10 | Set-Content $launchPath -Encoding UTF8
    $generated += "launch.json"
    Write-Host "Generated: launch.json" -ForegroundColor Green
}

# Multi-root workspace
if ($MultiRoot) {
    if (-not $WorkspaceName) {
        $WorkspaceName = Split-Path $ProjectPath -Leaf
    }

    $workspace = Generate-MultiRootWorkspace -WorkspaceName $WorkspaceName -ProjectPath $ProjectPath
    $workspacePath = Join-Path $ProjectPath "$WorkspaceName.code-workspace"
    $workspace | ConvertTo-Json -Depth 10 | Set-Content $workspacePath -Encoding UTF8
    $generated += "$WorkspaceName.code-workspace"
    Write-Host "Generated: $WorkspaceName.code-workspace" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Workspace Configuration Complete ===" -ForegroundColor Green
Write-Host ""

Write-Host "Generated files:" -ForegroundColor Cyan
foreach ($file in $generated) {
    Write-Host "  - $file" -ForegroundColor White
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Open project in VS Code" -ForegroundColor White
Write-Host "  2. Install recommended extensions (Ctrl+Shift+P -> Extensions: Show Recommended Extensions)" -ForegroundColor White
Write-Host "  3. Reload window to apply settings" -ForegroundColor White
Write-Host "  4. Start debugging with F5" -ForegroundColor White
Write-Host ""

exit 0
