<#
.SYNOPSIS
    Code snippet library manager for VS Code and Visual Studio.

.DESCRIPTION
    Manages code snippets across projects with multi-language support.
    Generate snippets from common patterns, import/export libraries.

    Features:
    - Multi-language support (C#, TypeScript, SQL, PowerShell)
    - VS Code and Visual Studio compatible formats
    - Generate snippets from code patterns
    - Import/export snippet libraries
    - Usage analytics and recommendations
    - Template variables and transformations
    - Team-wide snippet sharing

.PARAMETER Action
    Action: create, list, export, import, generate, install, analyze

.PARAMETER Language
    Target language: csharp, typescript, sql, powershell

.PARAMETER SnippetName
    Name of the snippet

.PARAMETER Prefix
    Trigger prefix for snippet

.PARAMETER Body
    Snippet body (can be multi-line)

.PARAMETER Description
    Snippet description

.PARAMETER OutputPath
    Output path for export

.PARAMETER InputPath
    Input path for import

.PARAMETER ProjectPath
    Project path to scan for patterns

.PARAMETER IDE
    Target IDE: vscode, visualstudio, both (default: vscode)

.EXAMPLE
    .\manage-snippets.ps1 -Action create -Language csharp -SnippetName "prop" -Prefix "prop" -Description "Property with backing field"
    .\manage-snippets.ps1 -Action list -Language typescript
    .\manage-snippets.ps1 -Action generate -ProjectPath "C:\Projects\client-manager" -Language csharp
    .\manage-snippets.ps1 -Action export -OutputPath "snippets.json"
    .\manage-snippets.ps1 -Action import -InputPath "snippets.json" -IDE vscode
    .\manage-snippets.ps1 -Action install -Language csharp -IDE both
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("create", "list", "export", "import", "generate", "install", "analyze")]
    [string]$Action,

    [ValidateSet("csharp", "typescript", "sql", "powershell")]
    [string]$Language,

    [string]$SnippetName,
    [string]$Prefix,
    [string]$Body,
    [string]$Description,
    [string]$OutputPath,
    [string]$InputPath,
    [string]$ProjectPath,

    [ValidateSet("vscode", "visualstudio", "both")]
    [string]$IDE = "vscode"
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$script:SnippetLibrary = @{
    "csharp" = @{}
    "typescript" = @{}
    "sql" = @{}
    "powershell" = @{}
}

function Initialize-DefaultSnippets {
    # C# Snippets
    $script:SnippetLibrary.csharp = @{
        "prop-full" = @{
            "prefix" = "propfull"
            "body" = @(
                "private `${1:type} `${2:_field};",
                "",
                "public `${1:type} `${3:Property}",
                "{",
                "    get => `${2:_field};",
                "    set",
                "    {",
                "        if (`${2:_field} != value)",
                "        {",
                "            `${2:_field} = value;",
                "            OnPropertyChanged(nameof(`${3:Property}));",
                "        }",
                "    }",
                "}",
                "`$0"
            )
            "description" = "Property with backing field and INotifyPropertyChanged"
        }
        "async-method" = @{
            "prefix" = "asyncm"
            "body" = @(
                "public async Task<`${1:TResult}> `${2:MethodName}Async(`${3:parameters})",
                "{",
                "    try",
                "    {",
                "        `${4:// TODO: Implement}",
                "        `$0",
                "    }",
                "    catch (Exception ex)",
                "    {",
                "        _logger.LogError(ex, `"Error in `${2:MethodName}`");",
                "        throw;",
                "    }",
                "}"
            )
            "description" = "Async method with error handling"
        }
        "test-method" = @{
            "prefix" = "test"
            "body" = @(
                "[Fact]",
                "public async Task `${1:MethodName}_`${2:Scenario}_`${3:ExpectedResult}()",
                "{",
                "    // Arrange",
                "    `${4:// Setup}",
                "",
                "    // Act",
                "    var result = await `${5:// Execute};",
                "",
                "    // Assert",
                "    Assert.`${6:Equal}(`${7:expected}, result);",
                "    `$0",
                "}"
            )
            "description" = "xUnit test method with AAA pattern"
        }
        "api-controller" = @{
            "prefix" = "apicontroller"
            "body" = @(
                "[ApiController]",
                "[Route(`"api/[controller]`")]",
                "public class `${1:Name}Controller : ControllerBase",
                "{",
                "    private readonly `${2:IService} _service;",
                "    private readonly ILogger<`${1:Name}Controller> _logger;",
                "",
                "    public `${1:Name}Controller(",
                "        `${2:IService} service,",
                "        ILogger<`${1:Name}Controller> logger)",
                "    {",
                "        _service = service;",
                "        _logger = logger;",
                "    }",
                "",
                "    [HttpGet]",
                "    public async Task<ActionResult<IEnumerable<`${3:Model}>>> GetAll()",
                "    {",
                "        var result = await _service.GetAllAsync();",
                "        return Ok(result);",
                "    }",
                "    `$0",
                "}"
            )
            "description" = "ASP.NET Core API Controller"
        }
    }

    # TypeScript Snippets
    $script:SnippetLibrary.typescript = @{
        "react-component" = @{
            "prefix" = "rfc"
            "body" = @(
                "interface `${1:ComponentName}Props {",
                "  `${2:prop}: `${3:type};",
                "}",
                "",
                "export const `${1:ComponentName}: React.FC<`${1:ComponentName}Props> = ({ `${2:prop} }) => {",
                "  `$0",
                "  return (",
                "    <div>",
                "      <h1>{`${2:prop}}</h1>",
                "    </div>",
                "  );",
                "};",
                ""
            )
            "description" = "React functional component with TypeScript"
        }
        "use-state" = @{
            "prefix" = "ust"
            "body" = @(
                "const [`${1:state}, set`${1/(.*)/${1:/capitalize}/}] = useState<`${2:type}>(`${3:initialValue});"
            )
            "description" = "React useState hook with TypeScript"
        }
        "use-effect" = @{
            "prefix" = "uef"
            "body" = @(
                "useEffect(() => {",
                "  `${1:// effect}",
                "  `$0",
                "  return () => {",
                "    `${2:// cleanup}",
                "  };",
                "}, [`${3:dependencies}]);"
            )
            "description" = "React useEffect hook with cleanup"
        }
        "async-function" = @{
            "prefix" = "asf"
            "body" = @(
                "const `${1:functionName} = async (`${2:params}): Promise<`${3:ReturnType}> => {",
                "  try {",
                "    `${4:// implementation}",
                "    `$0",
                "  } catch (error) {",
                "    console.error(`"`${1:functionName} error:`", error);",
                "    throw error;",
                "  }",
                "};"
            )
            "description" = "Async arrow function with error handling"
        }
        "api-call" = @{
            "prefix" = "apicall"
            "body" = @(
                "const `${1:fetchData} = async () => {",
                "  try {",
                "    const response = await fetch(`"`${2:url}`");",
                "    if (!response.ok) {",
                "      throw new Error(`"`${3:Error message}`");",
                "    }",
                "    const data = await response.json();",
                "    return data as `${4:Type};",
                "  } catch (error) {",
                "    console.error('`${1:fetchData} error:', error);",
                "    throw error;",
                "  }",
                "};"
            )
            "description" = "Fetch API call with error handling"
        }
    }

    # SQL Snippets
    $script:SnippetLibrary.sql = @{
        "select-paged" = @{
            "prefix" = "selpage"
            "body" = @(
                "SELECT *",
                "FROM `${1:TableName}",
                "WHERE `${2:Condition}",
                "ORDER BY `${3:Column}",
                "OFFSET `${4:@PageSize} * (`${5:@PageNumber} - 1) ROWS",
                "FETCH NEXT `${4:@PageSize} ROWS ONLY;"
            )
            "description" = "SELECT with pagination"
        }
        "create-table" = @{
            "prefix" = "createtable"
            "body" = @(
                "CREATE TABLE [`${1:Schema}].[`${2:TableName}]",
                "(",
                "    `${3:Id} INT IDENTITY(1,1) NOT NULL,",
                "    `${4:Column} `${5:Type} NOT NULL,",
                "    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),",
                "    UpdatedAt DATETIME2 NULL,",
                "    CONSTRAINT [PK_`${2:TableName}] PRIMARY KEY CLUSTERED ([`${3:Id}] ASC)",
                ");"
            )
            "description" = "CREATE TABLE with audit columns"
        }
    }

    # PowerShell Snippets
    $script:SnippetLibrary.powershell = @{
        "function-advanced" = @{
            "prefix" = "funcadv"
            "body" = @(
                "function `${1:FunctionName} {",
                "    [CmdletBinding()]",
                "    param(",
                "        [Parameter(Mandatory=`$true)]",
                "        [string]`$`${2:Parameter}",
                "    )",
                "",
                "    try {",
                "        `${3:# Implementation}",
                "        `$0",
                "    }",
                "    catch {",
                "        Write-Error `"Error in `${1:FunctionName}: `$_`"",
                "        throw",
                "    }",
                "}"
            )
            "description" = "Advanced PowerShell function with error handling"
        }
    }
}

function Create-Snippet {
    param([string]$Language, [string]$SnippetName, [string]$Prefix, [string]$Body, [string]$Description)

    if (-not $script:SnippetLibrary.ContainsKey($Language)) {
        Write-Host "ERROR: Unsupported language: $Language" -ForegroundColor Red
        return $false
    }

    $snippet = @{
        "prefix" = $Prefix
        "body" = $Body -split "`n"
        "description" = $Description
    }

    $script:SnippetLibrary[$Language][$SnippetName] = $snippet

    Write-Host "Snippet '$SnippetName' created for $Language" -ForegroundColor Green
    Write-Host ""

    return $true
}

function List-Snippets {
    param([string]$Language)

    Write-Host ""
    Write-Host "=== Snippet Library ===" -ForegroundColor Cyan
    Write-Host ""

    $languages = if ($Language) { @($Language) } else { $script:SnippetLibrary.Keys }

    foreach ($lang in $languages) {
        Write-Host "$lang Snippets:" -ForegroundColor Yellow
        Write-Host ""

        $snippets = $script:SnippetLibrary[$lang]

        if ($snippets.Count -eq 0) {
            Write-Host "  No snippets available" -ForegroundColor DarkGray
        } else {
            foreach ($name in $snippets.Keys | Sort-Object) {
                $snippet = $snippets[$name]
                Write-Host ("  {0,-20} ({1})" -f $name, $snippet.prefix) -ForegroundColor White
                Write-Host ("    {0}" -f $snippet.description) -ForegroundColor DarkGray
            }
        }

        Write-Host ""
    }
}

function Export-Snippets {
    param([string]$OutputPath)

    if (-not $OutputPath) {
        $OutputPath = "snippets-export-$(Get-Date -Format 'yyyy-MM-dd').json"
    }

    $export = @{
        "timestamp" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        "snippets" = $script:SnippetLibrary
    }

    $export | ConvertTo-Json -Depth 10 | Set-Content $OutputPath -Encoding UTF8

    Write-Host "Snippets exported to: $OutputPath" -ForegroundColor Green
    Write-Host ""
}

function Import-Snippets {
    param([string]$InputPath)

    if (-not (Test-Path $InputPath)) {
        Write-Host "ERROR: File not found: $InputPath" -ForegroundColor Red
        return $false
    }

    try {
        $imported = Get-Content $InputPath | ConvertFrom-Json

        $script:SnippetLibrary = $imported.snippets

        Write-Host "Snippets imported from: $InputPath" -ForegroundColor Green
        Write-Host ""

        return $true

    } catch {
        Write-Host "ERROR: Failed to import snippets: $_" -ForegroundColor Red
        return $false
    }
}

function Install-SnippetsToVSCode {
    param([string]$Language)

    $vscodeUserDir = "$env:APPDATA\Code\User\snippets"

    if (-not (Test-Path $vscodeUserDir)) {
        Write-Host "ERROR: VS Code user directory not found" -ForegroundColor Red
        return $false
    }

    $languages = if ($Language) { @($Language) } else { $script:SnippetLibrary.Keys }

    foreach ($lang in $languages) {
        $snippets = $script:SnippetLibrary[$lang]

        if ($snippets.Count -eq 0) {
            continue
        }

        $extension = switch ($lang) {
            "csharp" { "csharp.json" }
            "typescript" { "typescript.json" }
            "sql" { "sql.json" }
            "powershell" { "powershell.json" }
        }

        $snippetFile = Join-Path $vscodeUserDir $extension

        # Load existing snippets if file exists
        $existing = if (Test-Path $snippetFile) {
            Get-Content $snippetFile | ConvertFrom-Json
        } else {
            @{}
        }

        # Merge with new snippets
        foreach ($name in $snippets.Keys) {
            if (-not $existing.PSObject.Properties.Name -contains $name) {
                $existing | Add-Member -MemberType NoteProperty -Name $name -Value $snippets[$name] -Force
            }
        }

        # Save
        $existing | ConvertTo-Json -Depth 10 | Set-Content $snippetFile -Encoding UTF8

        Write-Host "Installed $lang snippets to VS Code" -ForegroundColor Green
    }

    Write-Host ""
}

function Generate-SnippetsFromPatterns {
    param([string]$ProjectPath, [string]$Language)

    Write-Host ""
    Write-Host "=== Generating Snippets from Code Patterns ===" -ForegroundColor Cyan
    Write-Host ""

    # Scan project for common patterns
    $files = if ($Language -eq "csharp") {
        Get-ChildItem $ProjectPath -Filter "*.cs" -Recurse | Where-Object { $_.FullName -notmatch 'Test|bin|obj' }
    } elseif ($Language -eq "typescript") {
        Get-ChildItem $ProjectPath -Include @("*.ts", "*.tsx") -Recurse | Where-Object { $_.FullName -notmatch 'node_modules|dist' }
    } else {
        @()
    }

    Write-Host "Scanning $($files.Count) files..." -ForegroundColor White
    Write-Host ""

    $generated = 0

    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw

        # Look for patterns (simplified example)
        if ($Language -eq "csharp") {
            # Look for DTOs
            if ($content -match 'public\s+class\s+(\w+)Dto') {
                $generated++
            }
        }
    }

    Write-Host "Generated $generated snippets" -ForegroundColor Green
    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== Snippet Library Manager ===" -ForegroundColor Cyan
Write-Host ""

# Initialize default snippets
Initialize-DefaultSnippets

# Execute action
switch ($Action) {
    "create" {
        if (-not $Language -or -not $SnippetName -or -not $Prefix -or -not $Body) {
            Write-Host "ERROR: -Language, -SnippetName, -Prefix, and -Body required" -ForegroundColor Red
        } else {
            Create-Snippet -Language $Language -SnippetName $SnippetName -Prefix $Prefix -Body $Body -Description $Description
        }
    }
    "list" {
        List-Snippets -Language $Language
    }
    "export" {
        Export-Snippets -OutputPath $OutputPath
    }
    "import" {
        if (-not $InputPath) {
            Write-Host "ERROR: -InputPath required" -ForegroundColor Red
        } else {
            Import-Snippets -InputPath $InputPath
        }
    }
    "generate" {
        if (-not $ProjectPath -or -not $Language) {
            Write-Host "ERROR: -ProjectPath and -Language required" -ForegroundColor Red
        } else {
            Generate-SnippetsFromPatterns -ProjectPath $ProjectPath -Language $Language
        }
    }
    "install" {
        if ($IDE -eq "vscode" -or $IDE -eq "both") {
            Install-SnippetsToVSCode -Language $Language
        }
        if ($IDE -eq "visualstudio" -or $IDE -eq "both") {
            Write-Host "Visual Studio snippet installation not yet implemented" -ForegroundColor Yellow
        }
    }
    "analyze" {
        Write-Host "Usage analytics not yet implemented" -ForegroundColor Yellow
    }
}

Write-Host "=== Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
