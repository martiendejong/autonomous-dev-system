#Requires -Version 5.1
<#
.SYNOPSIS
    Email Import Wrapper - Arjan Stroeve & Gerelateerde Contacten

.DESCRIPTION
    Wrapper script dat de Python email import script runt met gebruikersvriendelijke prompts.

    Importeert emails van/naar:
    - Arjan Stroeve
    - Allan Drenth
    - Rinus Huisman / Socranext
    - Social Media Hulp
    - Eethuys de Steen
    - Cassandra project

.EXAMPLE
    .\import-arjan-emails-wrapper.ps1
#>

[CmdletBinding()]
param()

# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue


# Kleuren voor output
$colors = @{
    Success = "Green"
    Error = "Red"
    Warning = "Yellow"
    Info = "Cyan"
    Header = "Magenta"
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n$("="*70)" -ForegroundColor $colors.Header
    Write-Host $Message -ForegroundColor $colors.Header
    Write-Host $("="*70)`n -ForegroundColor $colors.Header
}

function Write-Info {
    param([string]$Message)
    Write-Host $Message -ForegroundColor $colors.Info
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $colors.Success
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $colors.Error
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $colors.Warning
}

# Main script
Clear-Host

Write-Header "Email Import - Arjan Stroeve en Gerelateerde Contacten"

Write-Info "Dit script importeert emails van/naar:"
Write-Host "  • Arjan Stroeve"
Write-Host "  • Allan Drenth"
Write-Host "  • Rinus Huisman / Socranext"
Write-Host "  • Social Media Hulp"
Write-Host "  • Eethuys de Steen"
Write-Host "  • Cassandra project"
Write-Host ""

Write-Info "Van accounts:"
Write-Host "  • info@martiendejong.nl"
Write-Host "  • martiendejong2008@gmail.com"
Write-Host ""

Write-Info "Output: C:\scripts\arjan_emails\emails\"
Write-Host ""

# Check Python
Write-Info "Checking Python installation..."
try {
    $pythonVersion = python --version 2>&1
    if ($pythonVersion -match "Python (\d+\.\d+\.\d+)") {
        Write-Success "Python $($matches[1]) gevonden"
    } else {
        Write-Error-Custom "Python niet gevonden of fout formaat"
        Write-Warning-Custom "Installeer Python van https://www.python.org/downloads/"
        exit 1
    }
} catch {
    Write-Error-Custom "Python niet gevonden"
    Write-Warning-Custom "Installeer Python van https://www.python.org/downloads/"
    exit 1
}

# Check script exists
$scriptPath = "C:\scripts\tools\import-arjan-emails.py"
if (-not (Test-Path $scriptPath)) {
    Write-Error-Custom "Import script niet gevonden: $scriptPath"
    exit 1
}
Write-Success "Import script gevonden"

# Check/create output directory
$outputDir = "C:\scripts\arjan_emails\emails"
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    Write-Success "Output directory aangemaakt: $outputDir"
} else {
    Write-Success "Output directory bestaat: $outputDir"
}

Write-Host ""
Write-Header "BELANGRIJKE INFORMATIE"

Write-Warning-Custom "2-Factor Authenticatie (2FA)"
Write-Host "Als je 2FA hebt ingeschakeld op je Gmail account(s), heb je een"
Write-Host "App-Specific Password nodig in plaats van je normale wachtwoord."
Write-Host ""
Write-Host "App Password aanmaken:"
Write-Host "  1. Ga naar: https://myaccount.google.com/apppasswords"
Write-Host "  2. Log in met je Gmail account"
Write-Host "  3. Select app: Mail"
Write-Host "  4. Select device: Windows Computer"
Write-Host "  5. Klik: Generate"
Write-Host "  6. Kopieer het 16-character wachtwoord"
Write-Host "  7. Gebruik dit wachtwoord hieronder"
Write-Host ""

Write-Warning-Custom "IMAP moet ingeschakeld zijn"
Write-Host "Gmail > Settings > Forwarding and POP/IMAP > Enable IMAP"
Write-Host ""

$continue = Read-Host "Druk op ENTER om door te gaan (of CTRL+C om af te breken)"

Write-Host ""
Write-Header "Email Import Starten"

# Run Python script
Write-Info "Starting Python import script..."
Write-Host "Het script zal vragen om wachtwoorden voor beide accounts."
Write-Host ""

try {
    # Change to script directory
    Push-Location "C:\scripts\tools"

    # Run Python script (interactive - will prompt for passwords)
    python import-arjan-emails.py

    $exitCode = $LASTEXITCODE
    Pop-Location

    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Header "Import Voltooid"

        # Check results
        $emailFiles = Get-ChildItem -Path $outputDir -Filter "*.eml" -ErrorAction SilentlyContinue
        $emailCount = ($emailFiles | Measure-Object).Count

        if ($emailCount -gt 0) {
            Write-Success "$emailCount emails geïmporteerd naar $outputDir"

            Write-Host ""
            Write-Info "Volgende stappen:"
            Write-Host "  1. Check email_index.txt voor overzicht"
            Write-Host "  2. Lees emails chronologisch (oudste eerst)"
            Write-Host "  3. Update TIJDLIJN_ARJAN_STROEVE_COMPLEET.md"
            Write-Host "  4. Vul OPENSTAANDE_VRAGEN.md in"
            Write-Host ""

            # Open folder in Explorer
            $openFolder = Read-Host "Wil je de emails folder openen in Explorer? (Y/N)"
            if ($openFolder -eq "Y" -or $openFolder -eq "y") {
                Start-Process explorer.exe $outputDir
            }
        } else {
            Write-Warning-Custom "Geen emails gevonden!"
            Write-Host ""
            Write-Host "Mogelijke oorzaken:"
            Write-Host "  - Geen emails van deze contacten in accounts"
            Write-Host "  - IMAP niet correct geconfigureerd"
            Write-Host "  - Zoektermen niet correct"
            Write-Host ""
            Write-Host "Probeer handmatig te checken in Gmail:"
            Write-Host "  Gmail > Zoekbalk > from:arjan OR to:arjan"
        }
    } else {
        Write-Error-Custom "Import script eindigde met fout (exit code: $exitCode)"
        Write-Host ""
        Write-Info "Troubleshooting:"
        Write-Host "  - Check of wachtwoorden correct waren"
        Write-Host "  - Check of IMAP ingeschakeld is"
        Write-Host "  - Als 2FA: gebruik App Password"
        Write-Host "  - Zie: C:\scripts\arjan_emails\HOE_EMAILS_IMPORTEREN.md"
    }

} catch {
    Write-Error-Custom "Fout tijdens uitvoeren: $_"
    Pop-Location
    exit 1
}

Write-Host ""
