---
name: activity-monitoring
description: Real-time user activity tracking and context-aware intelligence using ManicTime integration
invocation: Auto-activated during startup and periodically for context awareness
priority: high
version: 1.0.0
created: 2026-01-19
author: Claude Agent
---

# Activity Monitoring Skill

## Purpose

This skill integrates ManicTime activity tracking into Claude's autonomous operation, enabling:

1. **Context Awareness** - Know what the user is currently doing
2. **Intelligent Assistance** - Adapt responses based on user's focus and activity
3. **Multi-Agent Coordination** - Detect other Claude instances and coordinate appropriately
4. **Idle Detection** - Know when system is unattended vs actively attended
5. **Pattern Learning** - Analyze user work patterns over time

## When This Skill Is Used

**Automatically activated:**
- During agent startup (part of bootstrap sequence)
- Before making autonomous decisions
- When detecting context shifts
- When multiple agents may be running
- Periodically during long-running tasks

**User can also manually request:**
- "What am I currently working on?"
- "Are there other Claude sessions running?"
- "Is the system idle?"
- "Show my activity context"

## Core Tool

**Primary:** `C:\scripts\tools\monitor-activity.ps1`

### Quick Commands

```powershell
# Current active window and application
monitor-activity.ps1 -Mode current

# Count Claude instances (multi-agent detection)
monitor-activity.ps1 -Mode claude

# Check if user is present or away
monitor-activity.ps1 -Mode idle

# Get full context for AI decision-making
monitor-activity.ps1 -Mode context -OutputFormat json

# Analyze work patterns
monitor-activity.ps1 -Mode patterns -Hours 8

# Recent activity summary
monitor-activity.ps1 -Mode recent -Hours 2
```

## Integration Points

### 1. Startup Protocol (MANDATORY)

Every Claude session MUST run activity monitoring during startup:

```
1. Load system state (existing startup)
2. **NEW: Run activity monitoring**
   - Check current user focus
   - Detect other Claude instances
   - Assess if user is present
3. Adjust behavior based on context
4. Continue with task execution
```

### 2. Context-Aware Decision Making

Before major decisions, check context:

```powershell
# Get context
$context = monitor-activity.ps1 -Mode context -OutputFormat object

# Decision logic:
if ($context.System.UserAttending) {
    # User is present - can ask questions, show updates
} else {
    # User away - work autonomously, queue notifications
}

if ($context.ClaudeInstances.Count -gt 1) {
    # Multiple agents - check for conflicts, coordinate
}

if ($context.ActiveWindow.Title -match "Visual Studio|VS Code") {
    # User is coding - be ready to assist with debugging
}
```

### 3. Multi-Agent Conflict Detection

**CRITICAL:** Before allocating worktrees, always check for other Claude instances:

```powershell
# Check for conflicts
$claude = monitor-activity.ps1 -Mode claude -OutputFormat object

if ($claude.Count -gt 1) {
    Write-Warning "⚠️ Multiple Claude agents detected ($($claude.Count))"

    # Read worktree pool to verify no conflicts
    # See multi-agent-conflict skill for full protocol
}
```

### 4. Adaptive Assistance

**Context-aware response strategy:**

| User Activity | Claude Behavior |
|---------------|-----------------|
| **Visual Studio open** | Ready for debugging assistance, code reviews |
| **Browser (research)** | Ready to help with information gathering |
| **Claude window focused** | Actively engaging, user wants interaction |
| **Idle (>15min)** | Work autonomously, minimal interruptions |
| **Multiple Claude sessions** | Coordinate, avoid conflicts |

### 5. Learning from Patterns

**Over time, learn:**
- User's typical work hours
- Preferred tools and workflows
- Context-switching patterns
- When user typically wants Claude's help vs autonomous work

## Workflow Examples

### Example 1: Startup Context Check

```
Agent starts → Run monitor-activity.ps1 -Mode context

Results show:
- User focused on Visual Studio
- 1 Claude instance (just this one)
- User present (idle: 2 minutes)

Action: Be ready for active debugging assistance
```

### Example 2: Multi-Agent Detection

```
About to allocate worktree → Check Claude instances

monitor-activity.ps1 -Mode claude shows 2 instances

Action: Check worktree pool, verify no BUSY conflicts
If conflict: Wait or use different seat
```

### Example 3: Idle System

```
monitor-activity.ps1 -Mode idle shows 25 minutes idle

User likely away → Queue notifications, work autonomously
Don't interrupt with questions
```

### Example 4: Context Switch Detection

```
Previous check: User in Visual Studio
Current check: User in Brave browser researching

Insight: User may need research assistance soon
```

## Data Sources

### ManicTime Database
- **Location:** `C:\Users\HP\AppData\Local\Finkit\ManicTime\ManicTimeCore.db`
- **Type:** SQLite database
- **Contents:** Application usage, window titles, activity timeline

### Real-Time System Data
- Active window title and process (via Windows API)
- Running processes (especially Claude instances)
- System idle time (via GetLastInputInfo API)
- CPU and memory usage patterns

### Log Files
- **Location:** `C:\Users\HP\AppData\Local\Finkit\ManicTime\Logs\`
- **Format:** Daily logs `ManicTime_YYYY-MM-DD.log`
- **Contents:** Activity events, application switches

## Context Object Structure

```json
{
  "Timestamp": "2026-01-19T20:00:00+01:00",
  "ActiveWindow": {
    "Title": "Example Window Title",
    "ProcessName": "process.exe",
    "ProcessId": 12345,
    "Path": "C:\\Path\\To\\Process.exe"
  },
  "ClaudeInstances": {
    "Count": 2,
    "Instances": [
      {
        "WindowTitle": "Claude",
        "ProcessId": 6132,
        "CPU": 172.5,
        "Memory": 102.38,
        "StartTime": "..."
      }
    ]
  },
  "IdleTime": {
    "Total": "00:15:30",
    "Minutes": 15.5,
    "IsIdle": true
  },
  "System": {
    "UserAttending": false,
    "MultipleClaudeSessions": true,
    "HighActivityProcesses": [...]
  },
  "Insights": [
    "System appears idle for 15.5 minutes - user may be away",
    "Multiple Claude sessions detected (2) - potential multi-agent coordination needed"
  ]
}
```

## Best Practices

### DO:
✅ Check context during startup (MANDATORY)
✅ Use context to adapt communication style
✅ Detect multi-agent scenarios before worktree allocation
✅ Learn from user patterns over time
✅ Respect user presence/absence (idle detection)
✅ Use insights to provide proactive help

### DON'T:
❌ Skip context check during startup
❌ Ignore multi-agent warnings
❌ Interrupt user when system is idle
❌ Assume single-agent environment
❌ Use intrusive notifications when user is focused elsewhere

## Future Enhancements

1. **Pattern Analysis** - ML-based prediction of user needs
2. **Proactive Suggestions** - Based on historical patterns
3. **Cross-Session Learning** - Aggregate knowledge across sessions
4. **Time-of-Day Awareness** - Different behavior for different hours
5. **Project Context Detection** - Identify which project user is working on
6. **Interruption Scoring** - When is best time to notify user

## Integration with Other Skills

- **multi-agent-conflict** - Uses activity monitoring for conflict detection
- **allocate-worktree** - Checks for other Claude instances first
- **session-reflection** - Log activity patterns in reflection.log.md
- **clickhub-coding-agent** - Autonomous operation uses idle detection

## Maintenance

**Update activity monitoring when:**
- ManicTime database schema changes
- New data sources become available
- Pattern detection needs refinement
- User requests new activity insights

## Testing

```powershell
# Test all modes
monitor-activity.ps1 -Mode current
monitor-activity.ps1 -Mode claude
monitor-activity.ps1 -Mode idle
monitor-activity.ps1 -Mode patterns -Hours 4
monitor-activity.ps1 -Mode context -OutputFormat json
```

---

**Status:** Active and integrated into startup protocol
**Priority:** High - Core infrastructure for context-aware operation
**Dependencies:** ManicTime installed and running
**Last Updated:** 2026-01-19
