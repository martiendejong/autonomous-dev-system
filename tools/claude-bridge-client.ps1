#Requires -Version 5.1
<#
.SYNOPSIS
    Claude Bridge Client - Communicate with Browser Claude via bridge server

.DESCRIPTION
    Send messages to and receive messages from Browser Claude through the bridge server.

.EXAMPLE
    .\claude-bridge-client.ps1 -Action send -Message "Can you research the latest AI papers?"

.EXAMPLE
    .\claude-bridge-client.ps1 -Action check
#>

param(
    [Parameter(Mandatory)]
    [ValidateSet("send", "check", "list", "read", "health")]
    [string]$Action,

    [string]$Message,
    [int]$MessageId,
    [string]$BridgeUrl = "http://localhost:9999",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Invoke-BridgeApi {
    param($Method, $Endpoint, $Body = $null)

    $uri = "$BridgeUrl$Endpoint"

    try {
        $params = @{
            Uri = $uri
            Method = $Method
            ContentType = "application/json"
            ErrorAction = "Stop"
        }

        if ($Body) {
            $params.Body = ($Body | ConvertTo-Json -Depth 10)
        }

        $response = Invoke-RestMethod @params
        return $response
    }
    catch {
        if ($_.Exception.Response) {
            $statusCode = $_.Exception.Response.StatusCode.value__
            Write-Host "[ERROR] API Error [$statusCode]: $($_.ErrorDetails.Message)" -ForegroundColor Red
        } else {
            Write-Host "[ERROR] Cannot reach bridge server at $BridgeUrl" -ForegroundColor Red
            Write-Host "        Make sure the bridge server is running:" -ForegroundColor Yellow
            Write-Host "        .\claude-bridge-server.ps1" -ForegroundColor White
        }
        exit 1
    }
}

switch ($Action) {
    "send" {
        if (-not $Message) {
            Write-Host "[ERROR] -Message parameter required for send action" -ForegroundColor Red
            exit 1
        }

        $body = @{
            from = "claude-code"
            to = "claude-browser"
            content = $Message
            type = "text"
        }

        $response = Invoke-BridgeApi -Method POST -Endpoint "/messages" -Body $body

        if ($Json) {
            $response | ConvertTo-Json
        } else {
            Write-Host "[SUCCESS] Message sent to Browser Claude (ID: $($response.message.id))" -ForegroundColor Green
            Write-Host ""
            Write-Host "Message: $Message" -ForegroundColor White
        }
    }

    "check" {
        $response = Invoke-BridgeApi -Method GET -Endpoint "/messages/unread?to=claude-code"

        if ($Json) {
            $response | ConvertTo-Json
        } else {
            if ($response.count -eq 0) {
                Write-Host "[INFO] No unread messages from Browser Claude" -ForegroundColor Gray
            } else {
                Write-Host "[INBOX] You have $($response.count) unread message(s)" -ForegroundColor Cyan
                Write-Host ""

                foreach ($msg in $response.messages) {
                    Write-Host "----------------------------------------" -ForegroundColor DarkGray
                    Write-Host "ID:        $($msg.id)" -ForegroundColor Gray
                    Write-Host "From:      $($msg.from)" -ForegroundColor Gray
                    Write-Host "Timestamp: $($msg.timestamp)" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host $msg.content -ForegroundColor White
                    Write-Host ""
                }
                Write-Host "----------------------------------------" -ForegroundColor DarkGray
                Write-Host ""
                Write-Host "Mark as read: .\claude-bridge-client.ps1 -Action read -MessageId <id>" -ForegroundColor Yellow
            }
        }
    }

    "list" {
        $response = Invoke-BridgeApi -Method GET -Endpoint "/messages"

        if ($Json) {
            $response | ConvertTo-Json
        } else {
            Write-Host "[MESSAGES] All messages ($($response.total) total)" -ForegroundColor Cyan
            Write-Host ""

            if ($response.total -eq 0) {
                Write-Host "No messages yet" -ForegroundColor Gray
            } else {
                foreach ($msg in $response.messages) {
                    $statusIcon = if ($msg.status -eq "read") { "[READ]" } else { "[NEW] " }
                    $statusColor = if ($msg.status -eq "read") { "Green" } else { "Yellow" }

                    Write-Host "$statusIcon " -NoNewline -ForegroundColor $statusColor
                    Write-Host "#$($msg.id) " -NoNewline -ForegroundColor Gray
                    Write-Host "$($msg.from) -> $($msg.to)" -NoNewline -ForegroundColor White
                    Write-Host " [$($msg.timestamp)]" -ForegroundColor DarkGray

                    $preview = $msg.content
                    if ($preview.Length -gt 80) {
                        $preview = $preview.Substring(0, 77) + "..."
                    }
                    Write-Host "  $preview" -ForegroundColor Gray
                    Write-Host ""
                }
            }
        }
    }

    "read" {
        if (-not $MessageId) {
            Write-Host "[ERROR] -MessageId parameter required for read action" -ForegroundColor Red
            exit 1
        }

        $response = Invoke-BridgeApi -Method POST -Endpoint "/messages/$MessageId/read"

        if ($Json) {
            $response | ConvertTo-Json
        } else {
            Write-Host "[SUCCESS] Message #$MessageId marked as read" -ForegroundColor Green
        }
    }

    "health" {
        $response = Invoke-BridgeApi -Method GET -Endpoint "/health"

        if ($Json) {
            $response | ConvertTo-Json
        } else {
            Write-Host "[BRIDGE] Server Status" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Status:   $($response.status)" -ForegroundColor Green
            Write-Host "Uptime:   $([math]::Round($response.uptime, 2)) seconds" -ForegroundColor White
            Write-Host "Messages: $($response.messageCount) total, $($response.unreadCount) unread" -ForegroundColor White
        }
    }
}
