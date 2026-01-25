$ErrorActionPreference = 'Stop'


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ErrorActionPreference = 'Stop'

# Read password
$password = Get-Content 'C:\Projects\client-manager\env\prod\backend.publish.password' -Raw
$password = $password.Trim()

Write-Host "Connecting to VPS 85.215.217.154..." -ForegroundColor Yellow

$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ('administrator', $securePassword)

try {
    # Try WinRM/PSRemoting first
    Write-Host "Attempting PowerShell Remoting..." -ForegroundColor Gray
    $session = New-PSSession -ComputerName 85.215.217.154 -Credential $cred -ErrorAction Stop

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "VPS Directory Structure" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    # List C:\stores folders
    Write-Host ""
    Write-Host "C:\stores folders:" -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        Get-ChildItem C:\stores -Directory | Select-Object Name, FullName
    } | Format-Table -AutoSize

    # Check IIS sites
    Write-Host ""
    Write-Host "IIS Sites:" -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        Import-Module WebAdministration
        Get-Website | Select-Object Name, PhysicalPath, State
    } | Format-Table -AutoSize

    # Check for bugattiinsights specifically
    Write-Host ""
    Write-Host "BugattiInsights folders:" -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        Get-ChildItem C:\stores -Directory | Where-Object { $_.Name -like '*bugatti*' } | Select-Object Name, FullName
    } | Format-Table -AutoSize

    # Check for registry folders
    Write-Host ""
    Write-Host "Registry folders:" -ForegroundColor Yellow
    Invoke-Command -Session $session -ScriptBlock {
        Get-ChildItem C:\stores -Directory | Where-Object { $_.Name -like '*registry*' } | Select-Object Name, FullName
    } | Format-Table -AutoSize

    Remove-PSSession $session
    Write-Host ""
    Write-Host "✓ Connection successful" -ForegroundColor Green
}
catch {
    Write-Host "PowerShell Remoting failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Note: PowerShell Remoting (WinRM) might not be enabled on the VPS." -ForegroundColor Yellow
    Write-Host "The deployment uses MS Web Deploy (msdeploy) which works differently." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Will need to check the local project folders and documentation instead." -ForegroundColor Cyan
}
