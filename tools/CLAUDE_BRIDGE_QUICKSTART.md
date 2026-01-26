# Claude Bridge - Quick Start Guide

Get Claude Code CLI and Browser Claude communicating in 5 minutes!

## Prerequisites

- ✅ Claude Code CLI installed and running (you're using it now!)
- ✅ Claude browser plugin installed in your browser
- ✅ PowerShell 5.1 or higher

## Step 1: Start the Bridge Server (30 seconds)

Open a **new PowerShell window** (keep it open):

```powershell
cd C:\scripts\tools
.\claude-bridge-server.ps1 -Debug
```

You should see:
```
🌉 Claude Bridge Server started on http://localhost:9999

Endpoints:
  POST   /messages          - Send a message
  GET    /messages          - Get all messages
  GET    /messages/unread   - Get unread messages
  ...

Press CTRL+C to stop
```

✅ **Leave this window open** - the server needs to keep running!

---

## Step 2: Configure Browser Claude (2 minutes)

1. Open your browser Claude plugin
2. Go to **Settings** or **Custom Instructions**
3. Copy the contents of: `C:\scripts\tools\BROWSER_CLAUDE_INSTRUCTIONS.txt`
4. Paste into custom instructions
5. Save

✅ Browser Claude now knows about the bridge!

---

## Step 3: Test the Connection (1 minute)

### Test from Claude Code → Browser Claude

In your current Claude Code session (this one!):

```powershell
.\claude-bridge-client.ps1 -Action send -Message "Hello from Claude Code! Can you receive this?"
```

### Test from Browser Claude → Claude Code

In your browser Claude, send:

```javascript
fetch('http://localhost:9999/messages', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    from: 'claude-browser',
    to: 'claude-code',
    content: 'Hello from Browser Claude!'
  })
})
```

### Check if it worked

Back in Claude Code:

```powershell
.\claude-bridge-client.ps1 -Action check
```

You should see the message from Browser Claude! 🎉

---

## Step 4: Try a Real Collaboration (2 minutes)

### Example 1: Web Research

**Claude Code sends request:**
```powershell
.\claude-bridge-client.ps1 -Action send -Message "Can you research the latest features in React 19 from the official React blog?"
```

**Browser Claude:**
1. Sees the request (either manually check or auto-poll)
2. Researches React 19
3. Sends results back:
```javascript
fetch('http://localhost:9999/messages', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    from: 'claude-browser',
    to: 'claude-code',
    type: 'research-results',
    content: 'React 19 key features: Server Components, Actions, use() hook...',
    data: {
      summary: 'Detailed summary here',
      links: ['https://react.dev/blog/...']
    }
  })
})
```

**Claude Code checks results:**
```powershell
.\claude-bridge-client.ps1 -Action check
```

### Example 2: UI Testing

**Claude Code requests test:**
```powershell
.\claude-bridge-client.ps1 -Action send -Message "Please test the login form at http://localhost:3000/login. Try credentials: test@test.com / Test123!"
```

**Browser Claude:**
1. Navigates to http://localhost:3000/login
2. Fills email: test@test.com
3. Fills password: Test123!
4. Clicks login button
5. Observes result (success/error)
6. Checks console for errors
7. Takes screenshot
8. Sends report back

```javascript
fetch('http://localhost:9999/messages', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    from: 'claude-browser',
    to: 'claude-code',
    type: 'test-results',
    content: 'Login test completed',
    status: 'success',
    results: {
      logged_in: true,
      redirect_to: '/dashboard',
      console_errors: [],
      screenshot: 'base64...'
    }
  })
})
```

---

## Step 5: Automate (Optional)

### Auto-start bridge on system startup

Create `C:\scripts\startup\start-bridge.bat`:
```batch
@echo off
start "Claude Bridge" powershell -NoExit -File "C:\scripts\tools\claude-bridge-server.ps1" -Debug
```

Add to Windows startup folder:
```
Win + R → shell:startup → paste shortcut to start-bridge.bat
```

### Add bridge check to Claude Code startup

Already done! I'll add this to my startup protocol.

---

## Common Commands Reference

```powershell
# Check server health
.\claude-bridge-client.ps1 -Action health

# Send message to Browser Claude
.\claude-bridge-client.ps1 -Action send -Message "Your message"

# Check for new messages
.\claude-bridge-client.ps1 -Action check

# List all messages
.\claude-bridge-client.ps1 -Action list

# Mark message as read
.\claude-bridge-client.ps1 -Action read -MessageId 1

# Get JSON output (for scripts)
.\claude-bridge-client.ps1 -Action check -Json
```

---

## Troubleshooting

### "Cannot reach bridge server"

**Problem:** Bridge server not running

**Solution:**
```powershell
# Start the server
.\claude-bridge-server.ps1 -Debug
```

### "No messages"

**Problem:** Browser Claude hasn't sent anything yet

**Solution:**
1. Verify browser Claude has custom instructions configured
2. Test manually with `fetch()` in browser console
3. Check server window for incoming requests (if using `-Debug`)

### Browser Claude: "fetch failed"

**Problem:** CORS or network issue

**Solution:**
1. Ensure bridge server is running
2. Check URL is exactly `http://localhost:9999` (not `https`)
3. Look at browser console for specific error
4. Check server `-Debug` output for CORS issues

### Messages not appearing in browser Claude

**Problem:** Browser Claude isn't polling for messages

**Solution:**
Browser Claude needs to manually check or implement auto-polling:
```javascript
// Manual check
fetch('http://localhost:9999/messages/unread?to=claude-browser')
  .then(r => r.json())
  .then(data => console.log(data.messages))

// Auto-poll every 10 seconds
setInterval(() => {
  fetch('http://localhost:9999/messages/unread?to=claude-browser')
    .then(r => r.json())
    .then(data => {
      if (data.count > 0) {
        console.log('New messages:', data.messages)
      }
    })
}, 10000)
```

---

## Advanced Usage

See detailed documentation:
- **Full API Reference:** `CLAUDE_BRIDGE_INSTRUCTIONS.md`
- **Advanced Use Cases:** `CLAUDE_BRIDGE_USE_CASES.md`
- **Browser Instructions:** `BROWSER_CLAUDE_INSTRUCTIONS.txt`

---

## What's Next?

Now that you have the bridge running, try:

1. **Collaborative Development**
   - Claude Code: Makes code changes
   - Browser Claude: Tests UI immediately
   - Instant feedback loop!

2. **Intelligent Task Distribution**
   - Complex tasks automatically split
   - Browser Claude: Handles web/UI
   - Claude Code: Handles file system/code

3. **Research & Implementation**
   - Browser Claude: Researches best practices
   - Claude Code: Implements based on research
   - Seamless knowledge transfer

4. **Continuous Testing**
   - Claude Code: Deploys changes
   - Browser Claude: Runs test suite
   - Automated quality assurance

---

## Tips for Success

✅ **DO:**
- Keep bridge server running during development sessions
- Use descriptive message content
- Include screenshots/data in test results
- Mark messages as read after processing
- Use structured message types for automation

❌ **DON'T:**
- Stop bridge server while expecting messages
- Send vague messages ("it doesn't work")
- Forget to check for responses
- Use external URLs for bridge (localhost only)

---

## Example Session Flow

```
Session Start:
1. [You] Start bridge server → Keep window open
2. [Claude Code] Checks bridge health → "Server healthy"
3. [Browser Claude] Ready to receive requests

During Development:
4. [Claude Code] Makes backend changes
5. [Claude Code] → Browser: "Test /api/users endpoint"
6. [Browser Claude] Tests endpoint, sends results
7. [Claude Code] Fixes issues based on feedback
8. Repeat until working

Session End:
9. [Claude Code] Logs session in reflection.log.md
10. Bridge server can be stopped (CTRL+C)
```

---

**You're all set!** 🎉

Start collaborating between Claude Code and Browser Claude!

**Questions?** Check the full documentation in:
- `C:\scripts\tools\CLAUDE_BRIDGE_INSTRUCTIONS.md`
- `C:\scripts\tools\CLAUDE_BRIDGE_USE_CASES.md`

---

**Created:** 2026-01-26
**Time to Setup:** ~5 minutes
**Difficulty:** Easy
**Status:** Production Ready
