# Dynamic Window Colors for Claude Code

**Feature Added: 2026-01-12**
**User Request:** "claude code determines the color of the window based on the kind of thing you are doing"

## Overview

The terminal window changes color dynamically based on Claude Code's execution state:

- 🔵 **BLUE** - Running a task (active work)
- 🟢 **GREEN** - Task completed successfully
- 🔴 **RED** - Blocked on user input (waiting for response)
- ⚪ **BLACK** - Idle (ready for next task)

## How It Works

### 1. ANSI Escape Sequences

Modern Windows 10+ terminals support ANSI color codes. The system uses escape sequences to change background colors without clearing the screen.

### 2. Color Management Script

`C:\scripts\set-state-color.ps1` - Core PowerShell script that:
- Emits ANSI escape codes for background color changes
- Updates window title with status emoji
- Logs state transitions

### 3. Quick Access Scripts

Batch wrappers for easy calling:
- `C:\scripts\color-running.bat` - Set BLUE (task running)
- `C:\scripts\color-complete.bat` - Set GREEN (task done)
- `C:\scripts\color-blocked.bat` - Set RED (user input needed)
- `C:\scripts\color-idle.bat` - Set BLACK (idle/ready)

## Manual Testing

Test the color changes immediately:

```batch
REM Test BLUE (running)
C:\scripts\color-running.bat
timeout /t 3

REM Test GREEN (complete)
C:\scripts\color-complete.bat
timeout /t 3

REM Test RED (blocked)
C:\scripts\color-blocked.bat
timeout /t 3

REM Back to BLACK (idle)
C:\scripts\color-idle.bat
```

## Integration with Claude Code

### Option 1: Manual Triggers (Immediate)

You can manually trigger color changes during Claude sessions by running these in a separate terminal:

```powershell
# When Claude starts a task
C:\scripts\color-running.bat

# When Claude completes a task
C:\scripts\color-complete.bat

# When Claude asks you a question (AskUserQuestion)
C:\scripts\color-blocked.bat
```

### Option 2: Hook Integration (Automated)

If Claude Code supports execution hooks, configure them in settings:

**Example hook configuration (if supported):**
```json
{
  "hooks": {
    "task-start": "C:\\scripts\\color-running.bat",
    "task-complete": "C:\\scripts\\color-complete.bat",
    "user-question-start": "C:\\scripts\\color-blocked.bat",
    "user-question-end": "C:\\scripts\\color-running.bat"
  }
}
```

### Option 3: State Monitoring (Advanced)

Create a background watcher that monitors Claude Code's state:

```powershell
# C:\scripts\color-watcher.ps1
# Watches logs or process state and changes colors automatically
# (Implementation depends on Claude Code's logging/state exposure)
```

## Color Scheme Details

### BLUE (Running)
- **ANSI Code:** `\e[44m\e[97m`
- **Background:** Dark Blue (#0000AA)
- **Foreground:** Bright White (#FFFFFF)
- **Title:** 🔵 running - BRANCH-NAME

### GREEN (Complete)
- **ANSI Code:** `\e[42m\e[97m`
- **Background:** Dark Green (#00AA00)
- **Foreground:** Bright White (#FFFFFF)
- **Title:** 🟢 complete - BRANCH-NAME

### RED (Blocked)
- **ANSI Code:** `\e[41m\e[97m`
- **Background:** Dark Red (#AA0000)
- **Foreground:** Bright White (#FFFFFF)
- **Title:** 🔴 blocked - BRANCH-NAME

### BLACK (Idle)
- **ANSI Code:** `\e[40m\e[97m`
- **Background:** Black (#000000)
- **Foreground:** Bright White (#FFFFFF)
- **Title:** ⚪ idle - BRANCH-NAME

## Customization

### Changing Colors

Edit `C:\scripts\set-state-color.ps1`:

```powershell
# Example: Make "running" state light blue instead of dark blue
$colors = @{
    "running"  = "`e[104m`e[30m"  # Light blue background, black text
    # ...
}
```

**ANSI Color Codes:**
- Background: `\e[40-47m` (dark), `\e[100-107m` (bright)
- Foreground: `\e[30-37m` (dark), `\e[90-97m` (bright)

### Adding More States

Add new states to the script:

```powershell
# Add "error" state (magenta background)
$colors = @{
    "running"  = "`e[44m`e[97m"
    "complete" = "`e[42m`e[97m"
    "blocked"  = "`e[41m`e[97m"
    "error"    = "`e[45m`e[97m"  # NEW: Magenta for errors
    "idle"     = "`e[40m`e[97m"
}
```

Create corresponding batch file:
```batch
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\scripts\set-state-color.ps1" -State error
```

## Troubleshooting

### Colors Not Changing

**Issue:** ANSI codes not working
**Fix:** Ensure you're using:
- Windows 10 version 1511+ (TH2 update)
- Windows Terminal, PowerShell 7+, or modern cmd.exe
- NOT old-style cmd.exe without ANSI support

### Screen Clears When Color Changes

**Issue:** `Clear-Host` in script clears screen
**Fix:** Comment out the `Clear-Host` line in `set-state-color.ps1`:
```powershell
# Clear-Host  # Comment this out
```

### Colors Persist After Closing

**Issue:** New terminals inherit colors
**Fix:** This is normal ANSI behavior. Colors are per-session only.

## Windows Terminal Integration

If using Windows Terminal, you can create profiles with predefined color schemes:

**settings.json:**
```json
{
  "profiles": {
    "list": [
      {
        "name": "Claude - Running",
        "commandline": "cmd.exe /k C:\\scripts\\color-running.bat",
        "colorScheme": "Claude Blue"
      }
    ]
  },
  "schemes": [
    {
      "name": "Claude Blue",
      "background": "#0000AA",
      "foreground": "#FFFFFF",
      // ... other colors
    }
  ]
}
```

## Future Enhancements

**Planned improvements:**
- [ ] Automatic state detection via log parsing
- [ ] Sound notifications on state changes
- [ ] Taskbar color synchronization (Windows Terminal)
- [ ] Multi-monitor awareness (change specific window only)
- [ ] Integration with system tray icon

## File Locations

- **Color script:** `C:\scripts\set-state-color.ps1`
- **Quick launchers:** `C:\scripts\color-*.bat`
- **Documentation:** `C:\scripts\DYNAMIC_WINDOW_COLORS.md`
- **State log:** `C:\scripts\logs\color-state.log`

## Integration with Existing Features

**Combines with:**
- ✅ Dynamic window titles (shows branch + state emoji)
- ✅ Quick launchers (`CTRL+R → c` for Claude Agent)
- ✅ Multi-agent sessions (each window has different color)
- ✅ Worktree pool management (visual state per agent)

## Example Workflow

```
1. User launches Claude Agent
   → Window: ⚪ BLACK "IDLE - MAIN"

2. User: "Create a new feature"
   → You call: color-running.bat
   → Window: 🔵 BLUE "running - MAIN"

3. Claude works on feature...
   → Window stays BLUE

4. Claude needs user input: "Which approach?"
   → You call: color-blocked.bat
   → Window: 🔴 RED "blocked - MAIN"

5. User responds
   → You call: color-running.bat
   → Window: 🔵 BLUE "running - MAIN"

6. Feature complete, PR created
   → You call: color-complete.bat
   → Window: 🟢 GREEN "complete - MAIN"

7. Ready for next task
   → You call: color-idle.bat
   → Window: ⚪ BLACK "IDLE - MAIN"
```

---

**NOTE:** This feature requires integration with Claude Code's execution lifecycle. Current implementation provides the infrastructure; actual state changes require manual triggers or hook configuration.
