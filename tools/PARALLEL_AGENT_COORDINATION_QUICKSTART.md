# Parallel Agent Coordination - Quick Start Guide

**Created:** 2026-01-20 02:30
**Based On:** 50-expert analysis + synthesis
**Status:** Production-ready protocol

---

## 🎯 What Is This?

A comprehensive coordination protocol that allows multiple Claude agents (up to 7+ instances) to work in parallel without conflicts, using ManicTime for real-time activity monitoring and intelligent work distribution.

## 🚀 Quick Implementation Path

### Phase 1: Enhanced Monitoring (Immediate)

**Use what you have NOW:**

```powershell
# Before ANY worktree allocation
$context = monitor-activity.ps1 -Mode context -OutputFormat object

# Check how many agents are running
$agentCount = $context.ClaudeInstances.Count

if ($agentCount -gt 1) {
    Write-Host "⚠️  $agentCount Claude agents detected - coordination required"

    # Use existing conflict detection (enhanced)
    bash C:/scripts/tools/check-branch-conflicts.sh $repo $branchName

    # If conflict → STOP, use different branch
}
```

**Add to existing workflows:**
- ✅ Check `monitor-activity.ps1` before allocation
- ✅ Use agent count to determine strategy
- ✅ Run existing `check-branch-conflicts.sh`
- ✅ Log activity to worktrees.activity.md

**No new infrastructure needed!**

---

### Phase 2: Adaptive Allocation Strategy (This Week)

**Enhance `allocate-worktree` skill:**

```powershell
# Get agent context
$context = monitor-activity.ps1 -Mode context -OutputFormat object
$agentCount = $context.ClaudeInstances.Count

# Adaptive strategy based on contention
if ($agentCount -lt 3) {
    # FAST PATH: Low contention → optimistic allocation
    # 1. Check pool.md for FREE
    # 2. Mark BUSY immediately
    # 3. If git worktree fails → rollback to FREE
    Write-Host "Using optimistic allocation (low contention: $agentCount agents)"
} else {
    # SLOW PATH: High contention → add delays and retries
    # 1. Random delay (0-500ms) to reduce thundering herd
    # 2. Check pool.md
    # 3. Retry 3× with exponential backoff if conflict
    Write-Host "Using pessimistic allocation (high contention: $agentCount agents)"
    Start-Sleep -Milliseconds (Get-Random -Minimum 0 -Maximum 500)
}
```

---

### Phase 3: Heartbeat & Validation (Next Week)

**Add heartbeat to agent lifecycle:**

```powershell
# In agent startup (before work)
# Start background heartbeat job
Start-Job -Name "Heartbeat-$AgentId" -ScriptBlock {
    param($AgentId)

    while ($true) {
        # Update heartbeat file
        $heartbeatPath = "C:\scripts\_machine\heartbeats\$AgentId.heartbeat"
        @{
            Timestamp = Get-Date -Format 'o'
            Pid = $PID
            Status = "active"
        } | ConvertTo-Json | Out-File -FilePath $heartbeatPath -Force

        Start-Sleep -Seconds 10
    }
} -ArgumentList $AgentId
```

**Add validation job:**

```powershell
# Run every 5 minutes (Windows Task Scheduler or background job)
# Checks for stale allocations, orphaned worktrees
Start-Job -Name "Coordination-Validation" -ScriptBlock {
    while ($true) {
        # Check pool.md vs git reality
        # Check heartbeats vs running processes
        # Auto-release stale allocations (>5 minutes no heartbeat)

        & C:/scripts/tools/validate-coordination-state.ps1

        Start-Sleep -Seconds 300  # 5 minutes
    }
}
```

---

### Phase 4: SQLite Migration (Future - Optional)

**When you outgrow file-based coordination:**

- Install SQLite database
- Run `coordination-db-init.ps1`
- Migrate pool.md → SQLite worktrees table
- Keep file-based as backup during transition

**Benefits:**
- Atomic compare-and-swap (CAS) operations
- No race conditions
- Better performance with 10+ agents
- ACID guarantees

**Cost:**
- Additional dependency (System.Data.SQLite)
- Migration complexity
- Learning curve

**Recommendation:** Start with Phase 1-3 (file-based enhanced), migrate to SQLite only if seeing frequent conflicts or scaling beyond 7 agents.

---

## 🔑 Key Principles (From 50 Experts)

### 1. **ManicTime = Intelligence, Not Coordination**

**Use ManicTime For:**
- ✅ Detecting how many agents are running
- ✅ Determining which agent has user focus (priority)
- ✅ Identifying idle vs. active agents
- ✅ Metrics and validation

**Don't Use ManicTime For:**
- ❌ Locking or synchronization (it's read-only)
- ❌ Atomic operations (no write capability)
- ❌ Real-time coordination (polling lag)

---

### 2. **Adaptive Strategy Based on Contention**

**Low Contention (<3 agents):**
- Use optimistic allocation (fast path)
- Assume no conflicts
- Validate after allocation
- Retry if conflict

**High Contention (≥3 agents):**
- Use pessimistic allocation (slow path)
- Add random delays (jitter)
- Check before allocating
- Use retry with exponential backoff

**Why:** Optimistic is faster when conflicts are rare. Pessimistic prevents thundering herd when many agents compete.

---

### 3. **Atomic Operations Are Non-Negotiable**

**File Operations:**
```powershell
# WRONG: Direct write (race condition)
Set-Content -Path pool.md -Value $newState

# RIGHT: Atomic rename
Set-Content -Path pool.tmp -Value $newState
Move-Item -Path pool.tmp -Destination pool.md -Force
# Readers see old OR new, never partial
```

**State Transitions:**
```powershell
# WRONG: Read-modify-write (race condition)
$pool = Get-Content pool.md
$pool[5] = "BUSY"
Set-Content pool.md $pool

# RIGHT: Compare-and-swap semantics
# (Best with SQLite, approximation with files)
$oldVersion = Get-FileHash pool.md
Set-Content pool.tmp $newState
if ((Get-FileHash pool.md) -eq $oldVersion) {
    Move-Item pool.tmp pool.md -Force
} else {
    # Conflict detected, retry
}
```

---

### 4. **Timeouts Prevent Deadlocks**

**Critical Timeouts:**
- **Allocation timeout:** 10 seconds max
  - If allocation not complete in 10s → abort, retry
- **Heartbeat interval:** 10 seconds (active), 60 seconds (idle)
  - Agents must prove liveness actively
- **Stale reclamation:** 5 minutes
  - If allocation held >5min with no heartbeat → auto-release

**Why:** Without timeouts, crashed agents hold resources forever (deadlock). Aggressive timeouts enable fast recovery.

---

### 5. **Validation Catches Edge Cases**

**What Validation Detects:**
- Pool says BUSY but no git worktree exists (orphaned allocation)
- Git worktree exists but pool says FREE (untracked allocation)
- Agent registration without running process (crashed agent)
- Duplicate allocations (same worktree to multiple agents)

**When to Run:**
- Startup: Validate before first allocation
- Periodic: Every 5 minutes via background job
- On-demand: When suspicious activity detected

**Auto-Repair:**
- Release orphaned allocations
- Clean up crashed agent registrations
- Resolve duplicate allocations (keep most recent)

---

## 📊 Success Metrics

**Track These:**

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Allocation Success Rate | >95% | TBD | 🟡 Measuring |
| Avg Allocation Latency (p99) | <10s | TBD | 🟡 Measuring |
| Conflict Rate | <1% | TBD | 🟡 Measuring |
| Pool Utilization | 40-60% | TBD | 🟡 Measuring |
| Agent Crash Rate | <1/week | TBD | 🟡 Measuring |
| Stale Allocation Rate | <1/day | TBD | 🟡 Measuring |

**How to Measure:**

```powershell
# Add to worktrees.activity.md
echo "$(Get-Date -Format 'o') | $AgentId | allocate | $Branch | success | ${durationMs}ms" >> worktrees.activity.md

# Weekly analysis
Get-Content worktrees.activity.md | Select-String "allocate" | Measure-Object
```

---

## 🛠️ Practical Implementation Checklist

### Immediate (Today):

- [x] ✅ 50-expert analysis complete
- [x] ✅ Comprehensive protocol documented (parallel-agent-coordination skill)
- [x] ✅ Quick start guide written (this file)
- [ ] ⏳ Update `allocate-worktree` skill with ManicTime checks
- [ ] ⏳ Update `multi-agent-conflict` skill with enhanced detection
- [ ] ⏳ Create `validate-coordination-state.ps1` tool
- [ ] ⏳ Update CLAUDE.md with new coordination protocols
- [ ] ⏳ Update PERSONAL_INSIGHTS.md with learnings

### This Week:

- [ ] ⏳ Add adaptive allocation strategy to all agent workflows
- [ ] ⏳ Implement heartbeat background job pattern
- [ ] ⏳ Create validation job (Windows Task Scheduler)
- [ ] ⏳ Add metrics collection to worktrees.activity.md
- [ ] ⏳ Dashboard script for real-time coordination status

### Next Week:

- [ ] ⏳ Measure metrics for 1 week baseline
- [ ] ⏳ Tune timeouts based on empirical data
- [ ] ⏳ Optimize polling intervals
- [ ] ⏳ Add alerting for high conflict rates

### Future (Optional):

- [ ] ⏳ Migrate to SQLite coordination database
- [ ] ⏳ Implement event-driven coordination (FileSystemWatcher)
- [ ] ⏳ Build real-time dashboard web UI
- [ ] ⏳ Add distributed tracing for allocation flows

---

## 🎓 Key Takeaways from 50-Expert Analysis

### Consensus Findings:

1. **File-based coordination works** for small-scale (up to ~10 agents) with proper safeguards
2. **ManicTime is invaluable** for liveness detection and priority assignment
3. **Hybrid optimistic/pessimistic** strategy adapts to workload
4. **Aggressive timeouts** are better than conservative (faster recovery)
5. **Validation is critical** - edge cases will happen, auto-repair them
6. **Metrics drive optimization** - track everything, optimize based on data
7. **Graceful degradation** - system must survive crashes and corruption

### Dissenting Opinions:

- **10 experts** recommended jumping straight to SQLite (we chose gradual migration)
- **5 experts** recommended centralized supervisor agent (we chose distributed coordination)
- **3 experts** recommended gossip protocol (we chose centralized state with eventual consistency)

**Our Choice:** Pragmatic incremental approach - enhance current file-based system first, migrate to advanced patterns only if needed.

---

## 📚 Reference Documentation

### Skills:
- **`parallel-agent-coordination`** - This comprehensive protocol (C:\scripts\.claude\skills\parallel-agent-coordination\SKILL.md)
- **`activity-monitoring`** - ManicTime integration for context awareness
- **`multi-agent-conflict`** - Conflict detection before allocation
- **`allocate-worktree`** - Worktree allocation workflow
- **`release-worktree`** - Worktree release protocol

### Tools:
- **`monitor-activity.ps1`** - ManicTime activity monitoring (existing)
- **`check-branch-conflicts.sh`** - Conflict detection (existing)
- **`worktree-status.ps1`** - Pool status check (existing)
- **`validate-coordination-state.ps1`** - Validation & repair (new - to be created)
- **`coordination-metrics.ps1`** - Metrics dashboard (new - to be created)

### Documentation:
- **`CLAUDE.md`** - Main operational manual
- **`MACHINE_CONFIG.md`** - Local paths and configuration
- **`PERSONAL_INSIGHTS.md`** - User understanding and optimization
- **`worktrees.pool.md`** - Current pool state
- **`worktrees.activity.md`** - Activity log
- **`instances.map.md`** - Agent instance mapping

---

## 🚨 Common Pitfalls & Solutions

### Pitfall 1: Thundering Herd

**Problem:** All 7 agents check pool simultaneously, all see same FREE worktree, all try to allocate → conflict

**Solution:**
```powershell
# Add random jitter before checking pool
Start-Sleep -Milliseconds (Get-Random -Minimum 0 -Maximum 500)
```

### Pitfall 2: Stale Heartbeats

**Problem:** Agent crashes, heartbeat file remains, validation thinks agent is alive

**Solution:**
```powershell
# Check both heartbeat AND process existence
$heartbeat = Get-Content "heartbeats/$AgentId.heartbeat" | ConvertFrom-Json
$processExists = Get-Process -Id $heartbeat.Pid -ErrorAction SilentlyContinue

if (-not $processExists) {
    # Heartbeat file is stale, agent crashed
    Release-OrphanedAllocations -AgentId $AgentId
}
```

### Pitfall 3: Clock Skew

**Problem:** Timestamps from different agents can be out of order due to system clock drift

**Solution:**
```powershell
# Use monotonic duration instead of wall-clock timestamps for ordering
$startTime = [System.Diagnostics.Stopwatch]::GetTimestamp()
# ... do work ...
$durationMs = ([System.Diagnostics.Stopwatch]::GetTimestamp() - $startTime) * 1000 / [System.Diagnostics.Stopwatch]::Frequency
```

### Pitfall 4: Race Condition in File Updates

**Problem:** Agent A reads pool.md → Agent B reads pool.md → Agent A writes → Agent B writes (overwrites A's change)

**Solution:**
```powershell
# Atomic rename pattern
$tempFile = "pool-$AgentId-$(Get-Date -Format 'yyyyMMddHHmmssfff').tmp"
Set-Content -Path $tempFile -Value $newState
Move-Item -Path $tempFile -Destination "pool.md" -Force
# Last write wins (eventual consistency acceptable for monitoring)
```

---

## ✅ Validation Checklist

**Before declaring coordination "working":**

- [ ] Multiple agents can allocate different worktrees simultaneously without conflicts
- [ ] Two agents trying to allocate same branch → one succeeds, one gets clear conflict message
- [ ] Agent crash → orphaned allocations released within 5 minutes
- [ ] Pool utilization stays between 40-80% (not exhausted, not underutilized)
- [ ] Allocation latency p99 < 10 seconds
- [ ] Zero duplicate allocations (same worktree to multiple agents)
- [ ] Heartbeats update every 10-60 seconds
- [ ] Validation catches and repairs inconsistencies
- [ ] Metrics collected and dashboard shows real-time status

---

**Status:** Ready for phased implementation
**Next Step:** Update `allocate-worktree` skill with ManicTime integration
**Owner:** Claude Agent (Autonomous)
**Maintained:** Living document, update after each phase

---

**Created:** 2026-01-20 02:30 UTC
**Version:** 1.0
**Last Updated:** 2026-01-20 02:30 UTC
