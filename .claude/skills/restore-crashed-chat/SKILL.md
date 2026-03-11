---
name: restore-crashed-chat
description: Restore a crashed Claude Code chat session by its easy ID (crash-001, crash-002, etc.)
triggers:
  - restore chat
  - restore crashed chat
  - restore the chat with id
  - crash-001
  - crash-002
  - continue crashed session
  - recover chat
---

# Restore Crashed Chat Skill

When the user asks to restore a crashed chat, follow this workflow:

## 1. Check for Crashed Chats

First, run the crashed chats detector to see what's available:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:/scripts/tools/get-crashed-chats.ps1" -ShowContext
```

This will show:
- List of crashed chats with easy IDs (crash-001, crash-002, etc.)
- Last activity time for each
- The last user message for context

## 2. Restore Specific Chat

If the user specifies a chat ID (e.g., "restore crash-001"):

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:/scripts/tools/restore-chat.ps1" -ChatId crash-001
```

This generates restore context including:
- Original session metadata
- Recent conversation history
- Instructions for continuation

## 3. Apply Restore Context

After generating the restore context:

1. **Read the context** - The script outputs markdown with the previous conversation
2. **Understand the state** - Review what was being worked on
3. **Check current state** - Verify any files/tasks mentioned still exist
4. **Continue the work** - Pick up where the crashed session left off

## Quick Reference

| Command | Purpose |
|---------|---------|
| `get-crashed-chats.ps1` | List all crashed chats with easy IDs |
| `get-crashed-chats.ps1 -ShowContext` | Include last user message |
| `restore-chat.ps1 -ChatId crash-001` | Generate restore context |
| `restore-chat.ps1 -ChatId crash-001 -Clipboard` | Copy to clipboard |

## How It Works

The system tracks "clean exits" - sessions where the user properly closed Claude Code:

1. When `claude_agent.bat` starts → records session start time
2. When Claude exits normally → marks session as "clean exit"
3. Sessions after last clean exit WITHOUT a clean exit marker = crashed

## Example Usage

**User:** "restore the chat with id crash-001"

**Claude should:**
1. Run `restore-chat.ps1 -ChatId crash-001`
2. Read the generated context
3. Acknowledge what was being worked on
4. Ask how to proceed or continue automatically

## Files

| File | Purpose |
|------|---------|
| `C:\scripts\_machine\session-tracker.json` | Tracks clean exits |
| `C:\scripts\_machine\crashed-chats.json` | Cached list of crashed chats |
| `C:\scripts\tools\session-tracker.ps1` | Records start/end of sessions |
| `C:\scripts\tools\get-crashed-chats.ps1` | Lists crashed chats |
| `C:\scripts\tools\restore-chat.ps1` | Generates restore context |
