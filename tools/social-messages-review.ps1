<#
.SYNOPSIS
    Daily review of social media messages needing attention

.DESCRIPTION
    Claude agent runs daily to review unread messages from social media accounts
    and collaborate with user on crafting appropriate responses.

    Features:
    - Fetch unread conversations from Facebook Pages inbox
    - Display message summaries with sender info and context
    - Generate AI-powered reply drafts using OpenAI API
    - Get user approval (y/n/e for edit/r for regenerate)
    - Save approved replies to database for sending
    - Mark conversations as addressed

    Workflow:
    1. Load unread conversations from API
    2. For each conversation:
       - Display participant names and message history
       - Generate contextual reply using AI
       - Present to user for approval
       - Save approved replies to pending_reply field
    3. Summary report of actions taken

.PARAMETER ProjectId
    Project ID to review messages for (required)

.PARAMETER AccountId
    Specific connected account ID, or review all if omitted

.PARAMETER AutoDraft
    Automatically generate AI reply drafts (default: true)

.PARAMETER MaxConversations
    Maximum number of conversations to review (default: 10)

.PARAMETER ApiBaseUrl
    API base URL (default: https://localhost:7001)

.PARAMETER OpenAIModel
    OpenAI model for reply generation (default: gpt-4o)

.PARAMETER OpenAIApiKey
    OpenAI API key (auto-loaded from appsettings.Secrets.json if not provided)

.EXAMPLE
    # Review all unread messages for a project
    .\social-messages-review.ps1 -ProjectId "proj-123"

.EXAMPLE
    # Review specific account only
    .\social-messages-review.ps1 -ProjectId "proj-123" -AccountId "acc-456"

.EXAMPLE
    # Review without auto-drafting replies (manual mode)
    .\social-messages-review.ps1 -ProjectId "proj-123" -AutoDraft:$false

.EXAMPLE
    # Review top 5 conversations only
    .\social-messages-review.ps1 -ProjectId "proj-123" -MaxConversations 5

.NOTES
    Created: 2026-01-25
    Part of social media messaging integration (Phase 4)
    Requires: Client-manager API running
    API keys auto-loaded from appsettings.Secrets.json
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectId,

    [Parameter(Mandatory=$false)]
    [string]$AccountId = "",

    [Parameter(Mandatory=$false)]
    [switch]$AutoDraft = $true,

    [Parameter(Mandatory=$false)]
    [int]$MaxConversations = 10,

    [Parameter(Mandatory=$false)]
    [string]$ApiBaseUrl = "https://localhost:7001",

    [Parameter(Mandatory=$false)]
    [string]$OpenAIModel = "gpt-4o",

    [Parameter(Mandatory=$false)]
    [string]$OpenAIApiKey = ""
)

# Import required modules
$ErrorActionPreference = "Stop"

# Load API key from appsettings.Secrets.json if not provided
if ([string]::IsNullOrEmpty($OpenAIApiKey)) {
    $secretsPath = "C:\Projects\client-manager\ClientManagerAPI\appsettings.Secrets.json"
    if (Test-Path $secretsPath) {
        try {
            $secrets = Get-Content $secretsPath -Raw | ConvertFrom-Json
            $OpenAIApiKey = $secrets.OpenAI.ApiKey
            if ([string]::IsNullOrEmpty($OpenAIApiKey)) {
                Write-Warning "OpenAI API key not found in appsettings.Secrets.json"
            }
        } catch {
            Write-Warning "Failed to load API key from $secretsPath : $_"
        }
    }
}

# Color helpers
function Write-ColorText {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Write-Success { param([string]$Text) Write-ColorText $Text "Green" }
function Write-Info { param([string]$Text) Write-ColorText $Text "Cyan" }
function Write-Warning { param([string]$Text) Write-ColorText $Text "Yellow" }
function Write-Error { param([string]$Text) Write-ColorText $Text "Red" }

# API client helpers
function Invoke-ApiGet {
    param([string]$Endpoint)
    try {
        $uri = "$ApiBaseUrl$Endpoint"
        $response = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json"
        return $response
    } catch {
        Write-Error "API GET failed for $Endpoint : $_"
        throw
    }
}

function Invoke-ApiPost {
    param([string]$Endpoint, [object]$Body)
    try {
        $uri = "$ApiBaseUrl$Endpoint"
        $json = $Body | ConvertTo-Json -Depth 10
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $json -ContentType "application/json"
        return $response
    } catch {
        Write-Error "API POST failed for $Endpoint : $_"
        throw
    }
}

# OpenAI API client
function Get-AIReplyDraft {
    param(
        [string]$ConversationContext,
        [string]$ParticipantName,
        [string]$BusinessContext = "Brand2Boost - a brand development and promotion SaaS platform"
    )

    if ([string]::IsNullOrEmpty($OpenAIApiKey)) {
        Write-Warning "OpenAI API key not configured. Skipping AI draft generation."
        return $null
    }

    $systemPrompt = @"
You are a professional social media manager for $BusinessContext.

Your task is to draft a helpful, professional, and friendly reply to a message from $ParticipantName.

Guidelines:
- Be professional but warm and approachable
- Keep replies concise (2-3 sentences)
- Address the specific question or concern raised
- Offer next steps or additional help if appropriate
- Use a conversational tone
- Do not use emojis unless the incoming message uses them

Message context:
$ConversationContext

Draft a reply:
"@

    try {
        $headers = @{
            "Authorization" = "Bearer $OpenAIApiKey"
            "Content-Type" = "application/json"
        }

        $body = @{
            model = $OpenAIModel
            messages = @(
                @{
                    role = "system"
                    content = $systemPrompt
                }
            )
            temperature = 0.7
            max_tokens = 200
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" `
            -Method Post -Headers $headers -Body $body

        return $response.choices[0].message.content.Trim()
    } catch {
        Write-Warning "Failed to generate AI reply: $_"
        return $null
    }
}

# Format message history for display
function Format-MessageHistory {
    param([array]$Messages)

    $formatted = ""
    foreach ($msg in $Messages | Sort-Object { $_.sentAt }) {
        $sender = if ($msg.isFromMe) { "You" } else { $msg.senderName }
        $time = (Get-Date $msg.sentAt).ToString("MMM dd, HH:mm")
        $content = $msg.content

        $formatted += "[$time] $sender`: $content`n"
    }
    return $formatted
}

# Main workflow
Write-Info "=== Social Media Message Review ==="
Write-Info "Project: $ProjectId"
if ($AccountId) { Write-Info "Account: $AccountId" }
Write-Info "Max Conversations: $MaxConversations"
Write-Info "Auto-Draft: $AutoDraft"
Write-Info ""

# Step 1: Fetch connected accounts
Write-Info "Loading connected accounts..."
try {
    $accounts = Invoke-ApiGet "/social/$ProjectId/accounts"

    # Filter to messaging-capable accounts (Facebook)
    $messagingAccounts = $accounts | Where-Object { $_.provider -eq "facebook" }

    if ($messagingAccounts.Count -eq 0) {
        Write-Warning "No messaging-capable accounts found (Facebook Pages required)"
        exit 0
    }

    # Filter to specific account if requested
    if ($AccountId) {
        $messagingAccounts = $messagingAccounts | Where-Object { $_.id -eq $AccountId }
        if ($messagingAccounts.Count -eq 0) {
            Write-Error "Account $AccountId not found or not messaging-capable"
            exit 1
        }
    }

    Write-Success "Found $($messagingAccounts.Count) messaging account(s)"
} catch {
    Write-Error "Failed to load accounts: $_"
    exit 1
}

# Step 2: Process each account
$totalReviewed = 0
$totalRepliesDrafted = 0
$totalRepliesApproved = 0

foreach ($account in $messagingAccounts) {
    Write-Info "`n--- Account: $($account.displayName) ($($account.provider)) ---"

    # Fetch unread conversations
    try {
        Write-Info "Fetching unread conversations..."
        $response = Invoke-ApiGet "/social/$ProjectId/accounts/$($account.id)/conversations?unreadOnly=true&limit=$MaxConversations"
        $conversations = $response.conversations

        if ($conversations.Count -eq 0) {
            Write-Success "No unread messages! ✓"
            continue
        }

        Write-Info "Found $($conversations.Count) unread conversation(s)"

        # Process each conversation
        foreach ($conv in $conversations) {
            $totalReviewed++

            Write-Info "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            Write-ColorText "Conversation #$totalReviewed" "Magenta"

            # Get participant names
            $participants = if ($conv.participants) {
                ($conv.participants | ForEach-Object { $_.name }) -join ", "
            } else {
                "Unknown"
            }
            Write-Info "From: $participants"
            Write-Info "Unread: $($conv.unreadCount) message(s)"
            if ($conv.lastMessageAt) {
                $lastMsgTime = (Get-Date $conv.lastMessageAt).ToString("yyyy-MM-dd HH:mm")
                Write-Info "Last message: $lastMsgTime"
            }
            Write-Info ""

            # Fetch messages for this conversation
            try {
                $messagesResponse = Invoke-ApiGet "/social/$ProjectId/conversations/$($conv.id)/messages?limit=20"
                $messages = $messagesResponse.messages

                # Display message history
                Write-ColorText "Message History:" "Yellow"
                Write-ColorText "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "DarkGray"

                $history = Format-MessageHistory -Messages $messages
                Write-Host $history

                Write-ColorText "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "DarkGray"

                # Generate AI reply draft if enabled
                $replyDraft = $null
                if ($AutoDraft) {
                    Write-Info "`nGenerating AI reply draft..."
                    $totalRepliesDrafted++

                    $replyDraft = Get-AIReplyDraft -ConversationContext $history -ParticipantName $participants

                    if ($replyDraft) {
                        Write-ColorText "`n📝 AI-Drafted Reply:" "Green"
                        Write-ColorText "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "DarkGray"
                        Write-Host $replyDraft
                        Write-ColorText "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "DarkGray"
                    }
                }

                # Get user decision
                Write-Info "`nWhat would you like to do?"
                if ($replyDraft) {
                    Write-Info "[y] Approve and save reply"
                    Write-Info "[e] Edit reply"
                    Write-Info "[r] Regenerate reply"
                }
                Write-Info "[s] Skip this conversation"
                Write-Info "[m] Write manual reply"
                Write-Info "[q] Quit review"

                $decision = Read-Host "`nYour choice"

                switch ($decision.ToLower()) {
                    "y" {
                        if ($replyDraft) {
                            # Save to pending reply
                            Write-Info "Saving reply to pending..."
                            try {
                                # Find the last message from them (not from me)
                                $lastIncomingMessage = $messages | Where-Object { -not $_.isFromMe } | Select-Object -First 1

                                if ($lastIncomingMessage) {
                                    Invoke-ApiPost "/social/$ProjectId/messages/$($lastIncomingMessage.id)/pending-reply" `
                                        @{ replyContent = $replyDraft }
                                    Write-Success "✓ Reply saved and ready for sending"
                                    $totalRepliesApproved++
                                } else {
                                    Write-Warning "No incoming message found to attach reply to"
                                }
                            } catch {
                                Write-Error "Failed to save reply: $_"
                            }
                        } else {
                            Write-Warning "No draft available to approve"
                        }
                    }
                    "e" {
                        if ($replyDraft) {
                            Write-Info "`nEnter your edited reply (Ctrl+C twice to cancel, blank line to finish):"
                            $editedLines = @()
                            while ($true) {
                                $line = Read-Host
                                if ([string]::IsNullOrEmpty($line)) { break }
                                $editedLines += $line
                            }

                            if ($editedLines.Count -gt 0) {
                                $editedReply = $editedLines -join "`n"
                                Write-Info "Saving edited reply..."
                                try {
                                    $lastIncomingMessage = $messages | Where-Object { -not $_.isFromMe } | Select-Object -First 1
                                    if ($lastIncomingMessage) {
                                        Invoke-ApiPost "/social/$ProjectId/messages/$($lastIncomingMessage.id)/pending-reply" `
                                            @{ replyContent = $editedReply }
                                        Write-Success "✓ Edited reply saved"
                                        $totalRepliesApproved++
                                    }
                                } catch {
                                    Write-Error "Failed to save edited reply: $_"
                                }
                            }
                        } else {
                            Write-Warning "No draft to edit. Use 'm' for manual reply."
                        }
                    }
                    "r" {
                        Write-Info "Regenerating reply..."
                        $replyDraft = Get-AIReplyDraft -ConversationContext $history -ParticipantName $participants
                        if ($replyDraft) {
                            Write-ColorText "`n📝 New AI-Drafted Reply:" "Green"
                            Write-Host $replyDraft
                            Write-Info "`nApprove this version? (y/n)"
                            $approve = Read-Host
                            if ($approve.ToLower() -eq "y") {
                                try {
                                    $lastIncomingMessage = $messages | Where-Object { -not $_.isFromMe } | Select-Object -First 1
                                    if ($lastIncomingMessage) {
                                        Invoke-ApiPost "/social/$ProjectId/messages/$($lastIncomingMessage.id)/pending-reply" `
                                            @{ replyContent = $replyDraft }
                                        Write-Success "✓ Reply saved"
                                        $totalRepliesApproved++
                                    }
                                } catch {
                                    Write-Error "Failed to save reply: $_"
                                }
                            }
                        }
                    }
                    "m" {
                        Write-Info "`nEnter your manual reply (blank line to finish):"
                        $manualLines = @()
                        while ($true) {
                            $line = Read-Host
                            if ([string]::IsNullOrEmpty($line)) { break }
                            $manualLines += $line
                        }

                        if ($manualLines.Count -gt 0) {
                            $manualReply = $manualLines -join "`n"
                            Write-Info "Saving manual reply..."
                            try {
                                $lastIncomingMessage = $messages | Where-Object { -not $_.isFromMe } | Select-Object -First 1
                                if ($lastIncomingMessage) {
                                    Invoke-ApiPost "/social/$ProjectId/messages/$($lastIncomingMessage.id)/pending-reply" `
                                        @{ replyContent = $manualReply }
                                    Write-Success "✓ Manual reply saved"
                                    $totalRepliesApproved++
                                }
                            } catch {
                                Write-Error "Failed to save manual reply: $_"
                            }
                        }
                    }
                    "s" {
                        Write-Info "Skipping conversation..."
                    }
                    "q" {
                        Write-Warning "Quitting review..."
                        break
                    }
                    default {
                        Write-Warning "Invalid choice. Skipping..."
                    }
                }

            } catch {
                Write-Error "Failed to load messages for conversation: $_"
            }
        }

    } catch {
        Write-Error "Failed to load conversations for account: $_"
    }
}

# Summary
Write-Info "`n"
Write-ColorText "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Cyan"
Write-ColorText "Review Summary" "Cyan"
Write-ColorText "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Cyan"
Write-Info "Conversations reviewed: $totalReviewed"
Write-Info "AI replies drafted: $totalRepliesDrafted"
Write-Success "Replies approved & saved: $totalRepliesApproved"
Write-Info ""
Write-Success "✓ Review complete!"

if ($totalRepliesApproved -gt 0) {
    Write-Info "`nNext steps:"
    Write-Info "- Approved replies are saved as pending_reply in the database"
    Write-Info "- Use the Social Inbox UI to review and send these replies"
    Write-Info "- Or trigger sending via API: POST /social/{projectId}/conversations/{conversationId}/send"
}
