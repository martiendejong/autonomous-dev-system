# Quick Access to Notifications Dashboard

**See also:** `QUICK_LAUNCHERS.md` for all available quick launch commands (Claude Agent, frontends, etc.)

## File Location
`C:\Users\HP\notifications.html`

## Access Methods (Ranked by Speed)

### Method 1: Quick Launch with CTRL+R (Recommended)
**After adding C:\scripts to PATH:**
1. Press `CTRL+R`
2. Type `n`
3. Press Enter

**Alternative (works now without PATH):**
1. Press `CTRL+R`
2. Type `C:\scripts\n.bat`
3. Press Enter

### Method 2: Direct File Launch
1. Press `CTRL+R`
2. Type `C:\Users\HP\notifications.html`
3. Press Enter

### Method 3: Browser Bookmark
Create a bookmark in your browser:
- URL: `file:///C:/Users/HP/notifications.html`
- Name: "Notifications"
- Pin to bookmarks bar for one-click access

### Method 4: Taskbar Pin (One-time setup)
1. Navigate to `C:\Users\HP\notifications.html`
2. Right-click → Open with → Choose your browser
3. Pin the opened page to taskbar
4. Click the taskbar icon anytime to view

---

## Adding C:\scripts to PATH (Recommended for "n" command)

Run this in PowerShell as Administrator:
```powershell
[Environment]::SetEnvironmentVariable(
    "Path",
    [Environment]::GetEnvironmentVariable("Path", "User") + ";C:\scripts",
    "User"
)
```

Then restart any open terminals/Command Prompts.

**Verify it worked:**
```
echo %PATH% | findstr scripts
```

---

## What Works Right Now (No Setup)

✅ **CTRL+R → `C:\scripts\n.bat`** (opens notifications)
✅ **CTRL+R → `C:\Users\HP\notifications.html`** (opens notifications)
✅ **Browser bookmark** (if created)

---

## Auto-Refresh
The dashboard auto-refreshes every 30 seconds to show latest updates.
