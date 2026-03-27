<#
.SYNOPSIS
    Manages feature flags for gradual rollouts and A/B testing.

.DESCRIPTION
    Creates and manages feature flags in configuration files to toggle features
    without deployment. Supports per-user, per-role, and percentage-based rollouts.

    Features:
    - Create/update/delete feature flags
    - Percentage-based gradual rollouts
    - User/role-based targeting
    - Environment-specific flags
    - Flag usage analytics
    - Export/import flag configurations

.PARAMETER Action
    Action: create, update, delete, list, enable, disable, export, import

.PARAMETER FlagName
    Name of the feature flag

.PARAMETER Enabled
    Whether flag is enabled (true/false)

.PARAMETER Percentage
    Rollout percentage (0-100) for gradual rollout

.PARAMETER Users
    Comma-separated list of user IDs for targeting

.PARAMETER Roles
    Comma-separated list of roles for targeting

.PARAMETER Environment
    Environment (development, staging, production)

.PARAMETER ConfigPath
    Path to feature flags configuration file

.PARAMETER InputFile
    Input file for import action

.EXAMPLE
    .\manage-feature-flags.ps1 -Action create -FlagName "NewDashboard" -Enabled true
    .\manage-feature-flags.ps1 -Action update -FlagName "NewDashboard" -Percentage 50
    .\manage-feature-flags.ps1 -Action enable -FlagName "NewDashboard" -Users "user1,user2"
    .\manage-feature-flags.ps1 -Action list
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("create", "update", "delete", "list", "enable", "disable", "export", "import")]
    [string]$Action,

    [string]$FlagName,
    [bool]$Enabled,
    [int]$Percentage = 0,
    [string]$Users,
    [string]$Roles,

    [ValidateSet("development", "staging", "production")]
    [string]$Environment = "development",

    [string]$ConfigPath = "C:/scripts/_machine/feature-flags.json",
    [string]$InputFile
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

function Get-FeatureFlags {
    param([string]$ConfigPath)

    if (Test-Path $ConfigPath) {
        try {
            $flags = Get-Content $ConfigPath | ConvertFrom-Json
            return $flags
        } catch {
            Write-Host "ERROR: Failed to parse feature flags file" -ForegroundColor Red
            return @{}
        }
    }

    return @{
        "version" = "1.0"
        "environment" = $Environment
        "flags" = @{}
    }
}

function Save-FeatureFlags {
    param([object]$Flags, [string]$ConfigPath)

    $Flags | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -Encoding UTF8
}

function Create-FeatureFlag {
    param([object]$Flags, [string]$FlagName, [bool]$Enabled)

    if ($Flags.flags.PSObject.Properties.Name -contains $FlagName) {
        Write-Host "ERROR: Feature flag '$FlagName' already exists" -ForegroundColor Red
        Write-Host "Use 'update' action to modify existing flag" -ForegroundColor Yellow
        return $false
    }

    $Flags.flags | Add-Member -MemberType NoteProperty -Name $FlagName -Value @{
        "enabled" = $Enabled
        "percentage" = 0
        "users" = @()
        "roles" = @()
        "createdAt" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        "updatedAt" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    Write-Host "Feature flag '$FlagName' created" -ForegroundColor Green
    Write-Host "  Enabled: $Enabled" -ForegroundColor White
    Write-Host ""

    return $true
}

function Update-FeatureFlag {
    param([object]$Flags, [string]$FlagName, [bool]$Enabled, [int]$Percentage, [string]$Users, [string]$Roles)

    if ($Flags.flags.PSObject.Properties.Name -notcontains $FlagName) {
        Write-Host "ERROR: Feature flag '$FlagName' not found" -ForegroundColor Red
        return $false
    }

    $flag = $Flags.flags.$FlagName

    # Update properties
    if ($PSBoundParameters.ContainsKey('Enabled')) {
        $flag.enabled = $Enabled
    }

    if ($Percentage -gt 0) {
        $flag.percentage = $Percentage
    }

    if ($Users) {
        $flag.users = $Users -split ',' | ForEach-Object { $_.Trim() }
    }

    if ($Roles) {
        $flag.roles = $Roles -split ',' | ForEach-Object { $_.Trim() }
    }

    $flag.updatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

    Write-Host "Feature flag '$FlagName' updated" -ForegroundColor Green
    Write-Host ("  Enabled: {0}" -f $flag.enabled) -ForegroundColor White

    if ($flag.percentage -gt 0) {
        Write-Host ("  Rollout: {0}%" -f $flag.percentage) -ForegroundColor White
    }

    if ($flag.users.Count -gt 0) {
        Write-Host ("  Users: {0}" -f ($flag.users -join ', ')) -ForegroundColor White
    }

    if ($flag.roles.Count -gt 0) {
        Write-Host ("  Roles: {0}" -f ($flag.roles -join ', ')) -ForegroundColor White
    }

    Write-Host ""

    return $true
}

function Delete-FeatureFlag {
    param([object]$Flags, [string]$FlagName)

    if ($Flags.flags.PSObject.Properties.Name -notcontains $FlagName) {
        Write-Host "ERROR: Feature flag '$FlagName' not found" -ForegroundColor Red
        return $false
    }

    $Flags.flags.PSObject.Properties.Remove($FlagName)

    Write-Host "Feature flag '$FlagName' deleted" -ForegroundColor Green
    Write-Host ""

    return $true
}

function List-FeatureFlags {
    param([object]$Flags)

    Write-Host ""
    Write-Host "=== Feature Flags ===" -ForegroundColor Cyan
    Write-Host ""

    if ($Flags.flags.PSObject.Properties.Count -eq 0) {
        Write-Host "No feature flags defined" -ForegroundColor Yellow
        Write-Host ""
        return
    }

    Write-Host ("Environment: {0}" -f $Flags.environment) -ForegroundColor White
    Write-Host ("Total Flags: {0}" -f $Flags.flags.PSObject.Properties.Count) -ForegroundColor White
    Write-Host ""

    foreach ($flagName in $Flags.flags.PSObject.Properties.Name | Sort-Object) {
        $flag = $Flags.flags.$flagName

        $status = if ($flag.enabled) { "ENABLED" } else { "DISABLED" }
        $color = if ($flag.enabled) { "Green" } else { "DarkGray" }

        Write-Host ("  {0,-30} [{1}]" -f $flagName, $status) -ForegroundColor $color

        if ($flag.percentage -gt 0) {
            Write-Host ("    Rollout: {0}%" -f $flag.percentage) -ForegroundColor DarkGray
        }

        if ($flag.users -and $flag.users.Count -gt 0) {
            Write-Host ("    Users: {0}" -f ($flag.users -join ', ')) -ForegroundColor DarkGray
        }

        if ($flag.roles -and $flag.roles.Count -gt 0) {
            Write-Host ("    Roles: {0}" -f ($flag.roles -join ', ')) -ForegroundColor DarkGray
        }

        Write-Host ("    Updated: {0}" -f $flag.updatedAt) -ForegroundColor DarkGray
        Write-Host ""
    }
}

function Enable-FeatureFlag {
    param([object]$Flags, [string]$FlagName, [string]$Users, [string]$Roles)

    return Update-FeatureFlag -Flags $Flags -FlagName $FlagName -Enabled $true -Users $Users -Roles $Roles
}

function Disable-FeatureFlag {
    param([object]$Flags, [string]$FlagName)

    return Update-FeatureFlag -Flags $Flags -FlagName $FlagName -Enabled $false
}

function Export-FeatureFlags {
    param([object]$Flags, [string]$OutputPath)

    if (-not $OutputPath) {
        $OutputPath = "feature-flags-export-$(Get-Date -Format 'yyyy-MM-dd').json"
    }

    $Flags | ConvertTo-Json -Depth 10 | Set-Content $OutputPath -Encoding UTF8

    Write-Host "Feature flags exported to: $OutputPath" -ForegroundColor Green
    Write-Host ""
}

function Import-FeatureFlags {
    param([string]$InputFile, [string]$ConfigPath)

    if (-not (Test-Path $InputFile)) {
        Write-Host "ERROR: Input file not found: $InputFile" -ForegroundColor Red
        return $false
    }

    try {
        $imported = Get-Content $InputFile | ConvertFrom-Json

        Write-Host "Importing feature flags..." -ForegroundColor Cyan
        Write-Host ("  Flags: {0}" -f $imported.flags.PSObject.Properties.Count) -ForegroundColor White
        Write-Host ""

        $confirm = Read-Host "This will overwrite existing flags. Continue? (yes/no)"

        if ($confirm -ne "yes") {
            Write-Host "Import cancelled" -ForegroundColor Yellow
            return $false
        }

        Save-FeatureFlags -Flags $imported -ConfigPath $ConfigPath

        Write-Host "Feature flags imported successfully" -ForegroundColor Green
        Write-Host ""

        return $true

    } catch {
        Write-Host "ERROR: Failed to import flags: $_" -ForegroundColor Red
        return $false
    }
}

function Generate-CodeSnippet {
    param([string]$FlagName, [string]$Language)

    Write-Host ""
    Write-Host "=== Code Integration Example ===" -ForegroundColor Cyan
    Write-Host ""

    if ($Language -eq "csharp") {
        Write-Host "C# (ASP.NET Core):" -ForegroundColor Yellow
        Write-Host @"

// In Startup.cs or Program.cs
services.AddSingleton<IFeatureFlagService, FeatureFlagService>();

// In your controller or service
public class MyController : ControllerBase
{
    private readonly IFeatureFlagService _featureFlags;

    public MyController(IFeatureFlagService featureFlags)
    {
        _featureFlags = featureFlags;
    }

    public IActionResult Index()
    {
        if (_featureFlags.IsEnabled("$FlagName", User.Identity.Name))
        {
            // New feature code
            return View("NewDashboard");
        }
        else
        {
            // Old feature code
            return View("OldDashboard");
        }
    }
}
"@ -ForegroundColor DarkGray

    } elseif ($Language -eq "typescript") {
        Write-Host "TypeScript (React):" -ForegroundColor Yellow
        Write-Host @"

// useFeatureFlag hook
import { useFeatureFlag } from './hooks/useFeatureFlag';

function Dashboard() {
    const isNewDashboard = useFeatureFlag('$FlagName');

    return (
        <div>
            {isNewDashboard ? (
                <NewDashboard />
            ) : (
                <OldDashboard />
            )}
        </div>
    );
}
"@ -ForegroundColor DarkGray
    }

    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "=== Feature Flag Manager ===" -ForegroundColor Cyan
Write-Host ""

# Load existing flags
$flags = Get-FeatureFlags -ConfigPath $ConfigPath

# Execute action
$success = $false

switch ($Action) {
    "create" {
        if (-not $FlagName) {
            Write-Host "ERROR: -FlagName required" -ForegroundColor Red
        } else {
            $success = Create-FeatureFlag -Flags $flags -FlagName $FlagName -Enabled $Enabled
        }
    }
    "update" {
        if (-not $FlagName) {
            Write-Host "ERROR: -FlagName required" -ForegroundColor Red
        } else {
            $success = Update-FeatureFlag -Flags $flags -FlagName $FlagName -Enabled $Enabled -Percentage $Percentage -Users $Users -Roles $Roles
        }
    }
    "delete" {
        if (-not $FlagName) {
            Write-Host "ERROR: -FlagName required" -ForegroundColor Red
        } else {
            $success = Delete-FeatureFlag -Flags $flags -FlagName $FlagName
        }
    }
    "list" {
        List-FeatureFlags -Flags $flags
        $success = $true
    }
    "enable" {
        if (-not $FlagName) {
            Write-Host "ERROR: -FlagName required" -ForegroundColor Red
        } else {
            $success = Enable-FeatureFlag -Flags $flags -FlagName $FlagName -Users $Users -Roles $Roles
        }
    }
    "disable" {
        if (-not $FlagName) {
            Write-Host "ERROR: -FlagName required" -ForegroundColor Red
        } else {
            $success = Disable-FeatureFlag -Flags $flags -FlagName $FlagName
        }
    }
    "export" {
        Export-FeatureFlags -Flags $flags -OutputPath $InputFile
        $success = $true
    }
    "import" {
        if (-not $InputFile) {
            Write-Host "ERROR: -InputFile required for import" -ForegroundColor Red
        } else {
            $success = Import-FeatureFlags -InputFile $InputFile -ConfigPath $ConfigPath
        }
    }
}

# Save flags if action was successful
if ($success -and $Action -ne "list" -and $Action -ne "export") {
    Save-FeatureFlags -Flags $flags -ConfigPath $ConfigPath

    if ($FlagName) {
        Generate-CodeSnippet -FlagName $FlagName -Language "csharp"
    }
}

Write-Host "=== Complete ===" -ForegroundColor Green
Write-Host ""

exit 0
