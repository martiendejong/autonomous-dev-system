#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Importeert emails van Arjan's contacten uit Gmail en martiendejong.nl mailbox

.DESCRIPTION
    Wrapper script voor email import. Gebruikt Gmail API voor Gmail en IMAP voor martiendejong.nl

.PARAMETER Source
    Email bron: 'gmail', 'martiendejong', of 'all'

.PARAMETER Setup
    Toont setup instructies voor OAuth configuratie

.EXAMPLE
    .\import-arjan-emails.ps1 -Setup
    Toont setup instructies

.EXAMPLE
    .\import-arjan-emails.ps1 -Source gmail
    Importeert alleen van Gmail

.EXAMPLE
    .\import-arjan-emails.ps1 -Source all
    Importeert van beide mailboxen
#>

param(
    [ValidateSet('gmail', 'martiendejong', 'all')

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue
]
    [string]$Source = 'all',

    [switch]$Setup
)

$ErrorActionPreference = 'Stop'

# Paths
$ScriptsRoot = "C:\scripts"
$ToolsDir = "$ScriptsRoot\tools"
$MachineDir = "$ScriptsRoot\_machine"
$OutputDir = "$ScriptsRoot\arjan_emails"

function Show-Setup {
    Write-Host "`n==============================================================" -ForegroundColor Cyan
    Write-Host "  Gmail API Setup Instructies" -ForegroundColor Cyan
    Write-Host "==============================================================" -ForegroundColor Cyan

    Write-Host "`n📋 Stap 1: Google Cloud Console Setup"
    Write-Host "   1. Ga naar: https://console.cloud.google.com/"
    Write-Host "   2. Maak nieuw project of selecteer bestaand project"
    Write-Host "   3. Ga naar 'APIs & Services' > 'Library'"
    Write-Host "   4. Zoek 'Gmail API' en klik 'Enable'"

    Write-Host "`n📋 Stap 2: OAuth Credentials Maken"
    Write-Host "   1. Ga naar 'APIs & Services' > 'Credentials'"
    Write-Host "   2. Klik 'Create Credentials' > 'OAuth client ID'"
    Write-Host "   3. Kies application type: 'Desktop app'"
    Write-Host "   4. Naam: 'Gmail Email Import'"
    Write-Host "   5. Klik 'Create'"

    Write-Host "`n📋 Stap 3: Download Credentials"
    Write-Host "   1. Klik op de download icon (↓) naast de nieuwe credential"
    Write-Host "   2. Sla op als: $MachineDir\gmail-credentials.json"

    Write-Host "`n📋 Stap 4: Python Dependencies Installeren"
    Write-Host "   pip install google-auth-oauthlib google-auth google-api-python-client"

    Write-Host "`n📋 Stap 5: Run Import"
    Write-Host "   .\import-arjan-emails.ps1 -Source gmail"

    Write-Host "`n==============================================================" -ForegroundColor Cyan
    Write-Host "`n📧 info@martiendejong.nl Setup"
    Write-Host "==============================================================`n" -ForegroundColor Cyan

    Write-Host "Voor IMAP import heb je nodig:"
    Write-Host "   - IMAP server adres (bv. mail.martiendejong.nl)"
    Write-Host "   - IMAP poort (meestal 993 voor SSL)"
    Write-Host "   - Email wachtwoord"
    Write-Host "`nDeze gegevens worden gevraagd bij eerste run.`n"
}

function Test-PythonDependencies {
    Write-Host "🔍 Controleren Python dependencies..." -ForegroundColor Yellow

    $required = @(
        'google-auth-oauthlib',
        'google-auth-httplib2',
        'google-api-python-client'
    )

    $missing = @()

    foreach ($package in $required) {
        $installed = pip list 2>$null | Select-String -Pattern "^$package\s"
        if (-not $installed) {
            $missing += $package
        }
    }

    if ($missing.Count -gt 0) {
        Write-Host "❌ Missende Python packages: $($missing -join ', ')" -ForegroundColor Red
        Write-Host "`n📦 Installeren met:" -ForegroundColor Yellow
        Write-Host "   pip install $($missing -join ' ')" -ForegroundColor Cyan
        return $false
    }

    Write-Host "✅ Alle Python dependencies aanwezig" -ForegroundColor Green
    return $true
}

function Import-Gmail {
    Write-Host "`n==============================================================" -ForegroundColor Cyan
    Write-Host "  Gmail Import" -ForegroundColor Cyan
    Write-Host "==============================================================" -ForegroundColor Cyan

    # Check credentials
    $credsPath = "$MachineDir\gmail-credentials.json"
    if (-not (Test-Path $credsPath)) {
        Write-Host "❌ Gmail credentials niet gevonden: $credsPath" -ForegroundColor Red
        Write-Host "`n💡 Run eerst: .\import-arjan-emails.ps1 -Setup" -ForegroundColor Yellow
        return $false
    }

    # Check Python dependencies
    if (-not (Test-PythonDependencies)) {
        return $false
    }

    # Run Python script
    Write-Host "`n🚀 Starten Gmail import..." -ForegroundColor Yellow
    python "$ToolsDir\gmail-import.py"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Gmail import succesvol" -ForegroundColor Green
        return $true
    } else {
        Write-Host "❌ Gmail import mislukt" -ForegroundColor Red
        return $false
    }
}

function Import-Martiendejong {
    Write-Host "`n==============================================================" -ForegroundColor Cyan
    Write-Host "  info@martiendejong.nl IMAP Import" -ForegroundColor Cyan
    Write-Host "==============================================================" -ForegroundColor Cyan

    Write-Host "⚠️  IMAP import nog niet geïmplementeerd" -ForegroundColor Yellow
    Write-Host "`n📋 Handmatige export optie:"
    Write-Host "   1. Log in op webmail.martiendejong.nl (of je provider)"
    Write-Host "   2. Zoek emails van gewenste contacten"
    Write-Host "   3. Exporteer als .eml of .mbox bestanden"
    Write-Host "   4. Plaats in: $OutputDir\[contact_naam]\"

    return $false
}

# Main execution
if ($Setup) {
    Show-Setup
    exit 0
}

Write-Host "`n==============================================================" -ForegroundColor Cyan
Write-Host "  Arjan Emails Import Tool" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host "Output directory: $OutputDir`n" -ForegroundColor Gray

$success = $true

switch ($Source) {
    'gmail' {
        $success = Import-Gmail
    }
    'martiendejong' {
        $success = Import-Martiendejong
    }
    'all' {
        $gmailSuccess = Import-Gmail
        Start-Sleep -Seconds 2
        $martiendejongSuccess = Import-Martiendejong
        $success = $gmailSuccess -and $martiendejongSuccess
    }
}

if ($success) {
    Write-Host "`n✅ Email import voltooid!" -ForegroundColor Green
} else {
    Write-Host "`n⚠️  Email import gedeeltelijk voltooid of mislukt" -ForegroundColor Yellow
}

Write-Host "`n💡 Tip: Upload je ChatGPT conversations naar:" -ForegroundColor Cyan
Write-Host "   $OutputDir\chatgpt_conversations\`n" -ForegroundColor Gray
