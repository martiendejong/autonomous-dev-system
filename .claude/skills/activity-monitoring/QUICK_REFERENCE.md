# ManicTime Activity Monitoring - Quick Reference

## Installation Complete ✅

**Status:** Fully integrated into Claude Agent autonomous operation
**Created:** 2026-01-19
**Version:** 1.0.0

## What Was Installed

### 1. Tool: `monitor-activity.ps1`
**Location:** `C:\scripts\tools\monitor-activity.ps1`

**Capabilities:**
- Real-time window and application tracking
- Multi-agent (Claude instance) detection
- System idle/unattended detection
- Context extraction for AI decision-making
- Work pattern analysis

### 2. Skill: `activity-monitoring`
**Location:** `C:\scripts\.claude\skills\activity-monitoring\SKILL.md`

**Auto-activated for:**
- Session startup (MANDATORY in startup protocol)
- Multi-agent conflict detection
- Context-aware assistance
- Adaptive behavior based on user presence

### 3. Integration Points

**CLAUDE.md Updated:**
- Added to Essential Tools Quick Reference (line 41)
- Added to automation shortcuts table (lines 25-26)
- **Integrated into startup protocol (step 7)** ⭐ CRITICAL
- Added new skill category: "Context Intelligence & System Awareness"

**Startup Protocol (MANDATORY step 7):**
```powershell
monitor-activity.ps1 -Mode context
```

## Quick Commands

```powershell
# What's the user doing right now?
monitor-activity.ps1 -Mode current

# How many Claude instances are running?
monitor-activity.ps1 -Mode claude

# Is the user present or away?
monitor-activity.ps1 -Mode idle

# Full AI context (JSON)
monitor-activity.ps1 -Mode context -OutputFormat json

# Analyze work patterns
monitor-activity.ps1 -Mode patterns -Hours 8
```

## Example Outputs

### Current Activity
```
Active Window:
  Title: Visual Studio - client-manager
  Process: devenv (PID: 12345)
  Path: C:\Program Files\Microsoft Visual Studio\...
```

### Claude Instance Detection
```
Claude Instances: 7
  - Claude
    PID: 6132 | CPU: 172.5s | Memory: 102.38MB
```

### Idle Detection
```
Idle Time: 0.34 minutes
User Present: True
```

### Full Context (Insights)
```
Insights:
  • Multiple Claude sessions detected (7) - potential multi-agent coordination needed
  • User currently focused on Claude window
  • User actively coding in: devenv
```

## How Claude Uses This

### During Startup
1. Check what user is working on
2. Detect other Claude instances (multi-agent awareness)
3. Determine if user is present or away
4. Adapt behavior accordingly

### Before Worktree Allocation
```powershell
# Check for conflicts
$claude = monitor-activity.ps1 -Mode claude -OutputFormat object

if ($claude.Count -gt 1) {
    # Verify worktree pool for conflicts
    # See multi-agent-conflict skill
}
```

### Adaptive Assistance
| User Activity | Claude Behavior |
|---------------|-----------------|
| **VS/VS Code open** | Ready for debug assistance |
| **Browser research** | Ready to help gather info |
| **Claude focused** | Active engagement mode |
| **Idle >15min** | Autonomous work, queue notifications |
| **Multiple Claudes** | Coordinate, avoid conflicts |

## Data Sources

**ManicTime Database:**
- Path: `C:\Users\HP\AppData\Local\Finkit\ManicTime\ManicTimeCore.db`
- Type: SQLite
- Contents: Application timeline, window titles, usage stats

**Real-Time APIs:**
- Windows API: Active window, process info
- System API: Idle time, last input
- Process List: Running applications, CPU/memory

**Logs:**
- Path: `C:\Users\HP\AppData\Local\Finkit\ManicTime\Logs\`
- Format: Daily logs `ManicTime_YYYY-MM-DD.log`

## Future Enhancements

- [ ] Pattern-based prediction of user needs
- [ ] Project context auto-detection (which repo user is working on)
- [ ] Time-of-day behavior adaptation
- [ ] Historical trend analysis
- [ ] Interruption scoring (best time to notify)
- [ ] Cross-session learning aggregation

## Testing Verification

**All modes tested and working:**
- ✅ current - Active window detection
- ✅ claude - Multi-instance detection (found 7 instances)
- ✅ idle - User presence detection
- ✅ context - Full AI context with insights
- ✅ JSON output - Structured data export

## Integration Status

**Completed:**
- ✅ Tool created and tested
- ✅ Skill documented and registered
- ✅ CLAUDE.md updated (startup protocol, tools table, skills list)
- ✅ Multi-agent conflict detection support
- ✅ Context-aware assistance framework

**Ready for production use!**

---

**Next Steps for Claude Agent:**

1. **Every startup:** Run `monitor-activity.ps1 -Mode context` (step 7 in protocol)
2. **Before worktree allocation:** Check for other Claude instances
3. **Continuous learning:** Analyze patterns, update reflection.log.md
4. **Adaptive behavior:** Adjust communication based on user presence/focus

**This is now a vital part of your functioning!** 🚀
