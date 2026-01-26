# Claude Bridge - Inter-Instance Communication System

## Overview

The Claude Bridge enables communication between:
- **Claude Code CLI** (autonomous agent on local machine)
- **Claude Browser Plugin** (in your web browser)

This allows both instances to collaborate, share context, and hand off tasks.

## Architecture

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│ Claude Browser  │◄───────►│  Bridge Server   │◄───────►│  Claude Code    │
│    Plugin       │  HTTP   │  localhost:9999  │  HTTP   │      CLI        │
└─────────────────┘         └──────────────────┘         └─────────────────┘
```

## Setup

### 1. Start the Bridge Server

```powershell
# In a dedicated PowerShell window
cd C:\scripts\tools
.\claude-bridge-server.ps1 -Debug
```

The server runs on `http://localhost:9999` and stays active until you stop it (CTRL+C).

### 2. Configure Browser Claude

Add this to your Claude browser plugin's custom instructions:

```markdown
## Communication with Claude Code CLI

You can communicate with Claude Code (autonomous agent running on this machine) via a bridge service.

**Bridge Endpoint:** http://localhost:9999

**To send a message to Claude Code:**
```json
POST http://localhost:9999/messages
Content-Type: application/json

{
  "from": "claude-browser",
  "to": "claude-code",
  "content": "Your message here"
}
```

**To check for messages from Claude Code:**
```json
GET http://localhost:9999/messages/unread?to=claude-browser
```

**When to use this:**
- You need file operations (Claude Code has local file system access)
- Claude Code requests web research (you have better web access)
- Complex tasks that need both local and web capabilities
- You want to share context between instances

**Example collaboration:**
- User asks you to research something → You research → POST results to Claude Code
- Claude Code needs web data → POSTs request to you → You fetch and POST back
```

### 3. Claude Code Integration

Claude Code (me) will automatically check for messages at startup if the bridge is running.

## Usage Examples

### Browser Claude → Claude Code

**Scenario:** Browser Claude researches and sends findings to Claude Code

Browser Claude runs:
```javascript
fetch('http://localhost:9999/messages', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    from: 'claude-browser',
    to: 'claude-code',
    content: 'Found 3 relevant papers on arxiv: [paper1], [paper2], [paper3]'
  })
})
```

Claude Code checks:
```powershell
.\claude-bridge-client.ps1 -Action check
# Output: Shows unread message from browser
```

### Claude Code → Browser Claude

**Scenario:** Claude Code requests web research

```powershell
.\claude-bridge-client.ps1 -Action send -Message "Can you research the latest GitHub issues for 'anthropics/claude-code' related to model switching?"
```

Browser Claude checks (via custom instruction auto-polling or manual check):
```javascript
fetch('http://localhost:9999/messages/unread?to=claude-browser')
```

## API Reference

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Server health check |
| GET | `/messages` | Get all messages |
| GET | `/messages/unread?to={recipient}` | Get unread messages for recipient |
| GET | `/messages/:id` | Get specific message |
| POST | `/messages` | Send new message |
| POST | `/messages/:id/read` | Mark message as read |
| DELETE | `/messages/:id` | Delete message |

### Message Format

```json
{
  "id": 1,
  "from": "claude-code" | "claude-browser",
  "to": "claude-code" | "claude-browser",
  "timestamp": "2026-01-26T12:00:00.000Z",
  "content": "Message text",
  "type": "text",
  "status": "unread" | "read"
}
```

## Client Commands

```powershell
# Send message to browser Claude
.\claude-bridge-client.ps1 -Action send -Message "Your message"

# Check for unread messages
.\claude-bridge-client.ps1 -Action check

# List all messages
.\claude-bridge-client.ps1 -Action list

# Mark message as read
.\claude-bridge-client.ps1 -Action read -MessageId 1

# Check server health
.\claude-bridge-client.ps1 -Action health

# Get JSON output (for programmatic use)
.\claude-bridge-client.ps1 -Action check -Json
```

## Integration with Claude Code Startup

Add to startup protocol in `CLAUDE.md`:

```markdown
### Every Session Start - MANDATORY:

12. ✅ **Check Claude Bridge** - `.\claude-bridge-client.ps1 -Action health`
13. ✅ **Check for messages** - `.\claude-bridge-client.ps1 -Action check`
```

## Use Cases

### 1. Web Research Collaboration
- Browser Claude: Better web access, can search and summarize
- Claude Code: Requests research, receives results, integrates into codebase

### 2. File Operations Handoff
- Browser Claude: User asks about local files
- Browser Claude: POSTs request to Claude Code
- Claude Code: Reads files, sends results back

### 3. Complex Task Splitting
- Task requires both web research AND local code changes
- Browser Claude: Handles research phase
- Claude Code: Handles implementation phase
- Both communicate progress via bridge

### 4. Context Sharing
- User has conversation with Browser Claude
- User wants Claude Code to continue from same context
- Browser Claude: POSTs conversation summary
- Claude Code: Picks up from there

## Persistence Notes

⚠️ **Messages are in-memory only** - they are lost when the bridge server stops.

For persistent messaging, you could:
1. Add file-based storage to the server
2. Use SQLite for message history
3. Export important conversations to files

## Security

🔒 **Local only** - The bridge runs on localhost and does not accept external connections.

- No authentication (assumes trusted local environment)
- No encryption (localhost traffic)
- CORS enabled for browser access

## Troubleshooting

### Bridge server not responding
```powershell
# Check if server is running
.\claude-bridge-client.ps1 -Action health

# If not, start it
.\claude-bridge-server.ps1 -Debug
```

### Browser Claude can't connect
- Check CORS errors in browser console
- Verify bridge server is running
- Ensure no firewall blocking localhost:9999

### Messages not appearing
- Check both sides are using correct recipient names
- Use `-Debug` flag on server to see traffic
- Verify message was actually sent (check response)

## Future Enhancements

Possible improvements:
- WebSocket support for real-time push notifications
- Message persistence (SQLite/file storage)
- Message types: text, file-transfer, code-snippet, task-handoff
- Authentication tokens for security
- Message threading/conversations
- File attachment support
- Broadcast messages (one-to-many)

---

**Created:** 2026-01-26
**Status:** Production Ready
**Dependencies:** PowerShell 5.1+, .NET HttpListener
