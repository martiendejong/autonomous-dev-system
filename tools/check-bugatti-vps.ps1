$ErrorActionPreference = 'Stop'


# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$ErrorActionPreference = 'Stop'

$password = Get-Content 'C:\Projects\client-manager\env\prod\backend.publish.password' -Raw
$password = $password.Trim()

Write-Host "Checking BugattiInsights deployment on VPS..." -ForegroundColor Cyan
Write-Host ""

# Create credential
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ('administrator', $securePassword)

$session = New-PSSession -ComputerName 85.215.217.154 -Credential $cred

# Get file listing
Write-Host "Files in c:\bugattiinsights:" -ForegroundColor Yellow
Invoke-Command -Session $session -ScriptBlock {
    Get-ChildItem c:\bugattiinsights -File | Select-Object -First 20 Name, Length, LastWriteTime
} | Format-Table -AutoSize

Write-Host ""
Write-Host "Checking for database files:" -ForegroundColor Yellow
Invoke-Command -Session $session -ScriptBlock {
    Get-ChildItem c:\bugattiinsights -File | Where-Object { $_.Extension -in @('.db', '.json', '.xml') } | Select-Object Name
} | Format-Table -AutoSize

Write-Host ""
Write-Host "Checking for appsettings.json:" -ForegroundColor Yellow
Invoke-Command -Session $session -ScriptBlock {
    if (Test-Path "c:\bugattiinsights\appsettings.json") {
        Write-Host "✓ appsettings.json exists" -ForegroundColor Green
        Get-Content "c:\bugattiinsights\appsettings.json" -Raw
    } else {
        Write-Host "✗ appsettings.json NOT found" -ForegroundColor Red
    }
}

Remove-PSSession $session
