<#
.SYNOPSIS
    Claude Bridge Server - Communication bridge between Claude Code CLI and Browser Claude

.DESCRIPTION
    HTTP server on localhost:9999 that enables message passing between:
    - Claude Code CLI (this agent)
    - Claude browser plugin

    Both instances can POST messages and GET responses.

.EXAMPLE
    .\claude-bridge-server.ps1 -Port 9999
#>

param(
    [int]$Port = 9999,
    [switch]$Debug
)

$ErrorActionPreference = "Stop"

# Message store (in-memory, persists while server runs)
$script:messages = @()
$script:messageId = 0

# Create HTTP listener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "[BRIDGE] Claude Bridge Server started on http://localhost:$Port" -ForegroundColor Green
Write-Host ""
Write-Host "Endpoints:" -ForegroundColor Cyan
Write-Host "  POST   /messages          - Send a message" -ForegroundColor White
Write-Host "  GET    /messages          - Get all messages" -ForegroundColor White
Write-Host "  GET    /messages/unread   - Get unread messages" -ForegroundColor White
Write-Host "  GET    /messages/:id      - Get specific message" -ForegroundColor White
Write-Host "  POST   /messages/:id/read - Mark message as read" -ForegroundColor White
Write-Host "  DELETE /messages/:id      - Delete message" -ForegroundColor White
Write-Host "  GET    /health            - Health check" -ForegroundColor White
Write-Host ""
Write-Host "Press CTRL+C to stop" -ForegroundColor Yellow
Write-Host ""

function Write-JsonResponse {
    param($Context, $Data, [int]$StatusCode = 200)

    $json = $Data | ConvertTo-Json -Depth 10 -Compress
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)

    $Context.Response.StatusCode = $StatusCode
    $Context.Response.ContentType = "application/json"
    $Context.Response.ContentLength64 = $buffer.Length
    $Context.Response.Headers.Add("Access-Control-Allow-Origin", "*")
    $Context.Response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
    $Context.Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
    $Context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $Context.Response.Close()
}

function Get-RequestBody {
    param($Request)

    $reader = New-Object System.IO.StreamReader($Request.InputStream)
    $body = $reader.ReadToEnd()
    $reader.Close()

    if ($body) {
        return $body | ConvertFrom-Json
    }
    return $null
}

function New-Message {
    param($From, $To, $Content, $Type = "text")

    $script:messageId++

    $message = @{
        id = $script:messageId
        from = $From
        to = $To
        timestamp = (Get-Date).ToUniversalTime().ToString("o")
        content = $Content
        type = $Type
        status = "unread"
    }

    $script:messages += $message

    if ($Debug) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] 📨 New message #$($message.id) from $From → $To" -ForegroundColor Cyan
    }

    return $message
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $method = $request.HttpMethod
        $path = $request.Url.AbsolutePath

        if ($Debug) {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $method $path" -ForegroundColor Gray
        }

        # Handle CORS preflight
        if ($method -eq "OPTIONS") {
            $response.StatusCode = 204
            $response.Headers.Add("Access-Control-Allow-Origin", "*")
            $response.Headers.Add("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
            $response.Headers.Add("Access-Control-Allow-Headers", "Content-Type")
            $response.Close()
            continue
        }

        # Route handling
        switch -Regex ($path) {
            "^/health$" {
                Write-JsonResponse $context @{
                    status = "healthy"
                    uptime = ((Get-Date) - $listener.TimeCreated).TotalSeconds
                    messageCount = $script:messages.Count
                    unreadCount = ($script:messages | Where-Object { $_.status -eq "unread" }).Count
                }
            }

            "^/messages$" {
                if ($method -eq "GET") {
                    # Get all messages
                    $filter = $request.QueryString["from"]
                    $to = $request.QueryString["to"]

                    $filtered = $script:messages
                    if ($filter) { $filtered = $filtered | Where-Object { $_.from -eq $filter } }
                    if ($to) { $filtered = $filtered | Where-Object { $_.to -eq $to } }

                    Write-JsonResponse $context @{
                        messages = $filtered
                        total = $filtered.Count
                    }
                }
                elseif ($method -eq "POST") {
                    # Create new message
                    $body = Get-RequestBody $request

                    if (-not $body.from -or -not $body.to -or -not $body.content) {
                        Write-JsonResponse $context @{
                            error = "Missing required fields: from, to, content"
                        } 400
                        continue
                    }

                    $messageType = if ($body.type) { $body.type } else { "text" }
                    $message = New-Message -From $body.from -To $body.to -Content $body.content -Type $messageType

                    Write-JsonResponse $context @{
                        success = $true
                        message = $message
                    } 201
                }
            }

            "^/messages/unread$" {
                if ($method -eq "GET") {
                    $to = $request.QueryString["to"]
                    $unread = $script:messages | Where-Object { $_.status -eq "unread" }

                    if ($to) {
                        $unread = $unread | Where-Object { $_.to -eq $to }
                    }

                    Write-JsonResponse $context @{
                        messages = $unread
                        count = $unread.Count
                    }
                }
            }

            "^/messages/(\d+)$" {
                $messageId = [int]$Matches[1]
                $message = $script:messages | Where-Object { $_.id -eq $messageId } | Select-Object -First 1

                if (-not $message) {
                    Write-JsonResponse $context @{
                        error = "Message not found"
                    } 404
                    continue
                }

                if ($method -eq "GET") {
                    Write-JsonResponse $context $message
                }
                elseif ($method -eq "DELETE") {
                    $script:messages = $script:messages | Where-Object { $_.id -ne $messageId }
                    Write-JsonResponse $context @{
                        success = $true
                        message = "Message deleted"
                    }
                }
            }

            "^/messages/(\d+)/read$" {
                $messageId = [int]$Matches[1]
                $message = $script:messages | Where-Object { $_.id -eq $messageId } | Select-Object -First 1

                if (-not $message) {
                    Write-JsonResponse $context @{
                        error = "Message not found"
                    } 404
                    continue
                }

                if ($method -eq "POST") {
                    $message.status = "read"
                    $message.readAt = (Get-Date).ToUniversalTime().ToString("o")

                    Write-JsonResponse $context @{
                        success = $true
                        message = $message
                    }
                }
            }

            default {
                Write-JsonResponse $context @{
                    error = "Not found"
                    path = $path
                } 404
            }
        }
    }
}
catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
}
finally {
    $listener.Stop()
    Write-Host "🛑 Server stopped" -ForegroundColor Yellow
}
