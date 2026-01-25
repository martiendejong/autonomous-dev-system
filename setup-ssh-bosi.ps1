# SSH Setup Script - Run as Administrator
# Creates user 'bosi' and enables SSH server

Write-Host "=== SSH Setup for user 'bosi' ===" -ForegroundColor Cyan

# 1. Install OpenSSH Server if not present
Write-Host "`n[1/5] Checking OpenSSH Server..." -ForegroundColor Yellow
$sshCapability = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
if ($sshCapability.State -ne 'Installed') {
    Write-Host "Installing OpenSSH Server..." -ForegroundColor Yellow
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Write-Host "OpenSSH Server installed." -ForegroundColor Green
} else {
    Write-Host "OpenSSH Server already installed." -ForegroundColor Green
}

# 2. Create user 'bosi' if not exists
Write-Host "`n[2/5] Creating user 'bosi'..." -ForegroundColor Yellow
$userExists = Get-LocalUser -Name 'bosi' -ErrorAction SilentlyContinue
if (-not $userExists) {
    $password = ConvertTo-SecureString 'Th1s1sSp4rt4!' -AsPlainText -Force
    New-LocalUser -Name 'bosi' -Password $password -FullName 'Bosi SSH User' -Description 'SSH access user' -PasswordNeverExpires
    Write-Host "User 'bosi' created." -ForegroundColor Green
} else {
    Write-Host "User 'bosi' already exists. Updating password..." -ForegroundColor Yellow
    $password = ConvertTo-SecureString 'Th1s1sSp4rt4!' -AsPlainText -Force
    Set-LocalUser -Name 'bosi' -Password $password
    Write-Host "Password updated." -ForegroundColor Green
}

# 3. Add user to Administrators group (for full access)
Write-Host "`n[3/5] Adding 'bosi' to Administrators group..." -ForegroundColor Yellow
try {
    Add-LocalGroupMember -Group "Administrators" -Member "bosi" -ErrorAction SilentlyContinue
    Write-Host "User 'bosi' added to Administrators." -ForegroundColor Green
} catch {
    Write-Host "User might already be in Administrators group." -ForegroundColor Yellow
}

# 4. Start and configure SSH service
Write-Host "`n[4/5] Configuring SSH service..." -ForegroundColor Yellow
Start-Service sshd -ErrorAction SilentlyContinue
Set-Service -Name sshd -StartupType 'Automatic'
Write-Host "SSH service started and set to auto-start." -ForegroundColor Green

# 5. Configure firewall
Write-Host "`n[5/5] Configuring firewall..." -ForegroundColor Yellow
$firewallRule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
if (-not $firewallRule) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    Write-Host "Firewall rule created." -ForegroundColor Green
} else {
    Write-Host "Firewall rule already exists." -ForegroundColor Green
}

# Summary
Write-Host "`n=== SSH SETUP COMPLETE ===" -ForegroundColor Cyan
Write-Host @"

Connection details:
  Host: 192.168.1.161
  Port: 22
  User: bosi
  Pass: Th1s1sSp4rt4!

Test locally:
  ssh bosi@localhost

Test from another device on your network:
  ssh bosi@192.168.1.161

Android apps: Termux, JuiceSSH, ConnectBot
"@ -ForegroundColor White

# Test SSH service status
Write-Host "`nSSH Service Status:" -ForegroundColor Yellow
Get-Service sshd | Format-Table Name, Status, StartType -AutoSize
