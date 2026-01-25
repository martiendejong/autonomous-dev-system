<#
.SYNOPSIS
    Email management wrapper for IMAP operations

.DESCRIPTION
    Quick access to email-manager.js functions

.EXAMPLE
    email list
    email list -Count 5 -Offset 10
    email spam 1234,1235
    email archive 1234
    email search "anthropic"
    email folders
#>

param(
    [Parameter(Position=0)]
    [ValidateSet('list', 'spam', 'archive', 'trash', 'folders', 'search', 'help')]
    [string]$Command = 'list',

    [Parameter(Position=1)]
    [string]$Argument,

    [int]$Count = 10,
    [int]$Offset = 0
)
# AUTO-USAGE TRACKING
$toolName = $MyInvocation.MyCommand.Name -replace '\.ps1$', ''
. "$PSScriptRoot\_usage-logger.ps1" -ToolName $toolName -Action "execute" -Metadata @{ Parameters = ($PSBoundParameters.Keys -join ',') } -ErrorAction SilentlyContinue

$scriptPath = Join-Path $PSScriptRoot "email-manager.js"

switch ($Command) {
    'list' {
        node $scriptPath list --count=$Count --offset=$Offset
    }
    'spam' {
        if (-not $Argument) {
            Write-Host "Usage: email spam <uid1,uid2,...>" -ForegroundColor Yellow
        } else {
            node $scriptPath spam $Argument
        }
    }
    'archive' {
        if (-not $Argument) {
            Write-Host "Usage: email archive <uid1,uid2,...>" -ForegroundColor Yellow
        } else {
            node $scriptPath archive $Argument
        }
    }
    'trash' {
        if (-not $Argument) {
            Write-Host "Usage: email trash <uid1,uid2,...>" -ForegroundColor Yellow
        } else {
            node $scriptPath trash $Argument
        }
    }
    'folders' {
        node $scriptPath folders
    }
    'search' {
        if (-not $Argument) {
            Write-Host "Usage: email search <query>" -ForegroundColor Yellow
        } else {
            node $scriptPath search $Argument
        }
    }
    'help' {
        Write-Host @"
Email Manager - Quick Commands

  email list                    Show 10 most recent messages
  email list -Count 5           Show 5 messages
  email list -Offset 10         Skip first 10, show next batch
  email spam 1234,1235          Move UIDs to Spam
  email archive 1234            Move UID to Archive
  email trash 1234              Move UID to Trash
  email search "query"          Search by from/subject
  email folders                 List all folders

"@ -ForegroundColor Cyan
    }
}
