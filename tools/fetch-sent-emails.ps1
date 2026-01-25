# Email Fetcher - Retrieve Sent Emails via IMAP
# Uses MailKit library for robust IMAP access

param(
    [Parameter(Mandatory=$false)]
    [string]$Filter = "meppel.nl",

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\scripts\correspondence\gemeente-meppel",

    [Parameter(Mandatory=$false)]
    [int]$MaxEmails = 100,

    [Parameter(Mandatory=$false)]
    [switch]$AllEmails
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

# Check if MailKit is available
$mailKitPath = "C:\Program Files\PackageManagement\NuGet\Packages\MailKit.*\lib\netstandard2.0\MailKit.dll"
$mailKitFound = Test-Path $mailKitPath

if (-not $mailKitFound) {
    Write-Host "MailKit not found. Installing via NuGet..." -ForegroundColor Yellow

    # Install NuGet provider
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null

    # Install MailKit
    Install-Package MailKit -Force -Scope CurrentUser -SkipDependencies | Out-Null

    $mailKitPath = (Get-ChildItem "C:\Program Files\PackageManagement\NuGet\Packages\MailKit.*\lib\netstandard2.0\MailKit.dll" | Select-Object -First 1).FullName
    $mimeKitPath = (Get-ChildItem "C:\Program Files\PackageManagement\NuGet\Packages\MimeKit.*\lib\netstandard2.0\MimeKit.dll" | Select-Object -First 1).FullName
} else {
    $mailKitPath = (Get-ChildItem $mailKitPath | Select-Object -First 1).FullName
    $mimeKitPath = $mailKitPath -replace "MailKit", "MimeKit"
}

# Load credentials
$credFile = "C:\scripts\_machine\credentials.md"
if (-not (Test-Path $credFile)) {
    Write-Error "Credentials file not found: $credFile"
    exit 1
}

$credContent = Get-Content $credFile -Raw
if ($credContent -match 'IMAP Host:\*\* ([\w\.]+)') {
    $imapHost = $matches[1]
}
if ($credContent -match 'IMAP Port:\*\* (\d+)') {
    $imapPort = [int]$matches[1]
}
if ($credContent -match 'Email:\*\* ([\w@\.]+)') {
    $emailAddress = $matches[1]
}
if ($credContent -match 'IMAP Password:\*\* ([\w\d]+)') {
    $imapPassword = $matches[1]
}

Write-Host "=== Email Fetcher ===" -ForegroundColor Cyan
Write-Host "Host: $imapHost"
Write-Host "Email: $emailAddress"
Write-Host "Filter: $Filter"
Write-Host "Output: $OutputPath"
Write-Host ""

# Simple IMAP implementation using System.Net.Sockets
try {
    Add-Type -AssemblyName System.Net.Security

    $client = New-Object System.Net.Sockets.TcpClient($imapHost, $imapPort)
    $stream = New-Object System.Net.Security.SslStream($client.GetStream(), $false)
    $stream.AuthenticateAsClient($imapHost)

    $reader = New-Object System.IO.StreamReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true

    # Read greeting
    $response = $reader.ReadLine()
    Write-Host "Server: $response" -ForegroundColor Gray

    # Login
    $writer.WriteLine("A001 LOGIN `"$emailAddress`" `"$imapPassword`"")
    $response = $reader.ReadLine()
    Write-Host "Login: $response" -ForegroundColor Gray

    if ($response -notmatch "A001 OK") {
        throw "Login failed: $response"
    }

    # Select Sent folder
    $writer.WriteLine("A002 SELECT INBOX.Sent")
    do {
        $response = $reader.ReadLine()
        Write-Host "Select: $response" -ForegroundColor Gray
    } while ($response -notmatch "^A002")

    # Search for emails
    if ($AllEmails) {
        $writer.WriteLine("A003 SEARCH ALL")
    } else {
        $writer.WriteLine("A003 SEARCH TO `"$Filter`"")
    }

    $searchResults = @()
    do {
        $response = $reader.ReadLine()
        if ($response -match "^\* SEARCH (.+)") {
            $searchResults += $matches[1] -split " "
        }
    } while ($response -notmatch "^A003")

    Write-Host "Found $($searchResults.Count) matching emails" -ForegroundColor Green

    # Fetch each email
    $emailCount = 0
    foreach ($msgId in $searchResults | Select-Object -First $MaxEmails) {
        $writer.WriteLine("A$($msgId.PadLeft(3, '0')) FETCH $msgId (BODY.PEEK[HEADER] BODY.PEEK[TEXT])")

        $headers = ""
        $body = ""
        $inHeader = $false
        $inBody = $false

        do {
            $response = $reader.ReadLine()

            if ($response -match "BODY\[HEADER\]") {
                $inHeader = $true
            } elseif ($response -match "BODY\[TEXT\]") {
                $inHeader = $false
                $inBody = $true
            } elseif ($inHeader) {
                $headers += "$response`n"
            } elseif ($inBody -and $response -ne ")") {
                $body += "$response`n"
            }
        } while ($response -notmatch "^A$($msgId.PadLeft(3, '0'))")

        # Parse subject and date from headers
        if ($headers -match "Subject: (.+)") {
            $subject = $matches[1].Trim()
        }
        if ($headers -match "Date: (.+)") {
            $date = $matches[1].Trim()
        }

        # Save email
        $emailCount++
        $fileName = "$($emailCount.ToString('D3'))_$(($subject -replace '[^\w\s-]', '') -replace '\s+', '_').txt"
        $filePath = Join-Path $OutputPath $fileName

        @"
=== EMAIL $emailCount ===
Date: $date
Subject: $subject

--- HEADERS ---
$headers

--- BODY ---
$body
"@ | Out-File -FilePath $filePath -Encoding UTF8

        Write-Host "Saved: $fileName" -ForegroundColor Green
    }

    # Logout
    $writer.WriteLine("A999 LOGOUT")
    $response = $reader.ReadLine()

    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Fetched: $emailCount emails"
    Write-Host "Saved to: $OutputPath"

} catch {
    Write-Error "IMAP Error: $_"
    Write-Host $_.Exception.Message -ForegroundColor Red
} finally {
    if ($reader) { $reader.Close() }
    if ($writer) { $writer.Close() }
    if ($stream) { $stream.Close() }
    if ($client) { $client.Close() }
}
