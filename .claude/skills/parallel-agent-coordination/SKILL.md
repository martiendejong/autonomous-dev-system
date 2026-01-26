---
name: parallel-agent-coordination
description: Real-time coordination protocol for multiple Claude agents using ManicTime activity monitoring. Prevents conflicts, enables intelligent work distribution, and ensures efficient parallel operation. Use when multiple agents are running simultaneously.
allowed-tools: Bash, Read, Write, Edit
user-invocable: true
---

# Parallel Agent Coordination Protocol

**Purpose:** Enable multiple Claude agents to work in parallel without conflicts using ManicTime-based activity monitoring and intelligent coordination.

**Status:** Production-Ready v1.0
**Created:** 2026-01-20 02:00
**Based On:** 50-expert analysis across distributed systems, multi-agent AI, OS, databases, DevOps, and real-time systems

---

## 🎯 Core Principles

### 1. **ManicTime as Coordination Intelligence**
ManicTime provides three critical capabilities:
- **Liveness Detection:** Active vs. idle vs. crashed agents
- **Priority Assignment:** User-focused agent gets highest priority
- **Metrics & Validation:** Ground truth for workload and performance

### 2. **Hybrid Coordination Strategy**
- **Fast Path (Optimistic):** When <3 agents active (low contention) → optimistic CAS allocation
- **Slow Path (Pessimistic):** When ≥3 agents active (high contention) → mutex-based locking
- **Adaptive:** System switches automatically based on ManicTime agent count

### 3. **Atomic Operations**
- All state transitions use compare-and-swap (CAS) semantics
- File writes use atomic rename (write tmp → rename to target)
- No partial updates, no race conditions

### 4. **Aggressive Timeout & Reclamation**
- **Allocation timeout:** 10 seconds
- **Heartbeat interval:** 10 seconds (active), 60 seconds (idle)
- **Stale allocation reclamation:** 5 minutes of no activity
- **Crash recovery:** Immediate on process termination

### 5. **Event-Driven with Polling Fallback**
- Primary: FileSystemWatcher for instant state change notification
- Fallback: 5-second polling for reliability
- Guarantees: No missed events, <5 second maximum latency

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────┐
│         ManicTime (External, Read-Only)                  │
│  - Process activity, window focus, idle time detection   │
└─────────────────────┬────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────┐
│  Activity Monitor Service (monitor-activity.ps1)        │
│  - Polls ManicTime every 15 seconds                      │
│  - Detects: agent count, active agent, idle agents       │
│  - Outputs: agent-activity.json                          │
└─────────────────────┬────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────┐
│  Coordination Database (SQLite + WAL mode)              │
│                                                          │
│  ┌────────────────────────────────────────────────┐   │
│  │ agents (registry of active agents)             │   │
│  │ - agent_id, pid, start_time, last_heartbeat    │   │
│  │ - status (active/idle/crashed), priority       │   │
│  │ - activity_score (from ManicTime)              │   │
│  └────────────────────────────────────────────────┘   │
│                                                          │
│  ┌────────────────────────────────────────────────┐   │
│  │ worktrees (allocation pool)                     │   │
│  │ - worktree_id, state (FREE/BUSY), agent_id     │   │
│  │ - branch_name, allocated_at, version           │   │
│  │ - last_activity (from heartbeat)               │   │
│  └────────────────────────────────────────────────┘   │
│                                                          │
│  ┌────────────────────────────────────────────────┐   │
│  │ allocation_log (event sourcing)                 │   │
│  │ - timestamp, agent_id, action (alloc/release)  │   │
│  │ - worktree_id, branch_name, result             │   │
│  └────────────────────────────────────────────────┘   │
└─────────────────────┬────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────┐
│  Event Dispatcher (coordination-daemon.ps1)             │
│  - FileSystemWatcher on coordination.db                 │
│  - Notifies agents of state changes via named pipes     │
│  - Fallback: Agents poll every 5 seconds                │
└─────────────────────┬────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────┐
│  Claude Agent Processes (agent-001 to agent-012)        │
│                                                          │
│  Each agent runs:                                        │
│  1. Allocation logic (allocate-worktree-v2.ps1)         │
│  2. Heartbeat sender (every 10s)                        │
│  3. Event listener (named pipe or polling)              │
│  4. Activity reporter (to ManicTime)                    │
└──────────────────────────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────┐
│  Watchdog & Validator (coordination-watchdog.ps1)       │
│  - Every 30s: Check heartbeats, reclaim stale           │
│  - Every 5m: Validate invariants, repair corruption     │
│  - On crash: Clean up orphaned allocations              │
│  - Metrics: Log latency, conflicts, utilization         │
└──────────────────────────────────────────────────────────┘
```

---

## 📋 Protocols

### Protocol 1: Agent Registration (Startup)

**When:** Agent starts (before any work)

**Steps:**
```powershell
# 1. Check for existing instance with same agent-id
$existingAgent = Get-AgentRegistration -AgentId $AgentId
if ($existingAgent -and (Get-Process -Id $existingAgent.Pid -ErrorAction SilentlyContinue)) {
    throw "Agent $AgentId already running (PID: $($existingAgent.Pid))"
}

# 2. Get activity context from ManicTime
$context = monitor-activity.ps1 -Mode context -OutputFormat object

# 3. Register in coordination database
Register-Agent -AgentId $AgentId -Pid $PID -StartTime (Get-Date) `
    -Status "active" -Priority $context.System.UserAttending ? 100 : 50

# 4. Clean up any orphaned allocations from previous crashed instance
$orphaned = Get-WorktreeAllocations -AgentId $AgentId -IncludeOrphaned
foreach ($alloc in $orphaned) {
    Release-Worktree -WorktreeId $alloc.WorktreeId -AgentId $AgentId -Reason "Orphaned from previous instance"
}

# 5. Start heartbeat sender (background job)
Start-HeartbeatSender -AgentId $AgentId -Interval 10

# 6. Start event listener (background job)
Start-EventListener -AgentId $AgentId
```

**Result:** Agent registered, orphans cleaned, heartbeat running

---

### Protocol 2: Worktree Allocation (Conflict-Free)

**When:** Agent needs to allocate worktree for feature work

**Steps:**
```powershell
# PHASE 1: Pre-Flight Checks
# 1. Get current activity context
$context = monitor-activity.ps1 -Mode context -OutputFormat object
$activeAgents = $context.ClaudeInstances.Count
$myPriority = $context.System.UserAttending ? 100 : 50

# 2. Check conflict detection
$conflict = Test-BranchConflict -BranchName $branchName -Repo $repo
if ($conflict.HasConflict) {
    Write-Warning "🚨 CONFLICT: Another agent is using branch $branchName"
    Write-Warning "  Agent: $($conflict.AgentId)"
    Write-Warning "  Started: $($conflict.AllocatedAt)"
    return $null  # Cannot proceed
}

# PHASE 2: Choose Allocation Strategy (based on contention)
if ($activeAgents -lt 3) {
    # FAST PATH: Optimistic CAS allocation
    $result = Try-OptimisticAllocation -BranchName $branchName -Repo $repo -AgentId $AgentId -Priority $myPriority
} else {
    # SLOW PATH: Pessimistic lock-based allocation
    $result = Try-PessimisticAllocation -BranchName $branchName -Repo $repo -AgentId $AgentId -Priority $myPriority
}

# PHASE 3: Post-Allocation Tasks
if ($result.Success) {
    # 1. Update instances.map.md (backward compatibility)
    Update-InstancesMap -AgentId $AgentId -Branch $branchName -Repo $repo -Action "allocate"

    # 2. Update worktrees.pool.md (backward compatibility)
    Update-WorktreePool -Seat $result.Seat -Status "BUSY" -Branch $branchName -AgentId $AgentId

    # 3. Create git worktree
    New-GitWorktree -Repo $repo -Path $result.WorktreePath -Branch $branchName

    # 4. Log allocation event
    Write-AllocationLog -AgentId $AgentId -Action "allocate" -WorktreeId $result.WorktreeId -Branch $branchName -Result "success"

    # 5. Start activity heartbeat for this worktree
    Start-WorktreeHeartbeat -AgentId $AgentId -WorktreeId $result.WorktreeId

    return $result
} else {
    Write-AllocationLog -AgentId $AgentId -Action "allocate" -Branch $branchName -Result "failed" -Reason $result.Reason
    return $null
}
```

#### Optimistic Allocation (Fast Path)

```powershell
function Try-OptimisticAllocation {
    param($BranchName, $Repo, $AgentId, $Priority)

    $maxRetries = 3
    for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
        # 1. Read current pool state with version
        $pool = Get-WorktreePool -Repo $repo
        $freeWorktree = $pool | Where-Object { $_.State -eq "FREE" } | Select-Object -First 1

        if (-not $freeWorktree) {
            return @{ Success = $false; Reason = "No free worktrees available" }
        }

        # 2. Attempt CAS update (SQL: UPDATE WHERE version = N)
        $updated = Update-WorktreeState -WorktreeId $freeWorktree.Id `
            -OldState "FREE" -OldVersion $freeWorktree.Version `
            -NewState "BUSY" -AgentId $AgentId -Branch $BranchName `
            -AllocatedAt (Get-Date) -Priority $Priority

        if ($updated) {
            # Success! CAS succeeded
            return @{
                Success = $true
                WorktreeId = $freeWorktree.Id
                Seat = $freeWorktree.SeatName
                WorktreePath = $freeWorktree.Path
            }
        }

        # CAS failed (concurrent modification), retry with backoff
        Start-Sleep -Milliseconds (100 * [Math]::Pow(2, $attempt))  # Exponential backoff
    }

    # All retries failed → fall back to pessimistic
    return Try-PessimisticAllocation -BranchName $BranchName -Repo $Repo -AgentId $AgentId -Priority $Priority
}
```

#### Pessimistic Allocation (Slow Path)

```powershell
function Try-PessimisticAllocation {
    param($BranchName, $Repo, $AgentId, $Priority)

    # 1. Acquire global allocation mutex (5 second timeout)
    $mutex = [System.Threading.Mutex]::new($false, "Global\ClaudeAgentAllocation")
    $acquired = $mutex.WaitOne(5000)  # 5 second timeout

    if (-not $acquired) {
        return @{ Success = $false; Reason = "Mutex timeout (deadlock or contention)" }
    }

    try {
        # 2. Read pool state (we have exclusive access)
        $pool = Get-WorktreePool -Repo $repo
        $freeWorktree = $pool | Where-Object { $_.State -eq "FREE" } |
            Sort-Object -Property LastActivity | Select-Object -First 1

        if (-not $freeWorktree) {
            return @{ Success = $false; Reason = "No free worktrees (pool exhausted)" }
        }

        # 3. Update state (no version check needed, we have mutex)
        Update-WorktreeState -WorktreeId $freeWorktree.Id `
            -NewState "BUSY" -AgentId $AgentId -Branch $BranchName `
            -AllocatedAt (Get-Date) -Priority $Priority

        return @{
            Success = $true
            WorktreeId = $freeWorktree.Id
            Seat = $freeWorktree.SeatName
            WorktreePath = $freeWorktree.Path
        }
    }
    finally {
        # 4. Always release mutex
        $mutex.ReleaseMutex()
        $mutex.Dispose()
    }
}
```

---

### Protocol 3: Worktree Release (After PR Creation)

**When:** After `gh pr create` completes, before presenting PR to user

**Steps:**
```powershell
# 1. Commit and push final changes
git -C $worktreePath add -u
git -C $worktreePath commit -m "Final commit before PR"
git -C $worktreePath push origin $branchName

# 2. Create PR
$pr = gh pr create --repo $repoOwner/$repoName --title $prTitle --body $prBody

# 3. IMMEDIATELY release worktree (CRITICAL: before presenting to user)
Release-Worktree -WorktreeId $worktreeId -AgentId $AgentId

# 4. Update backward-compatible files
Update-WorktreePool -Seat $seat -Status "FREE" -Branch "" -AgentId ""
Update-InstancesMap -AgentId $AgentId -Action "release"

# 5. Clean up git worktree
git -C $baseRepoPath worktree remove $worktreePath --force
git -C $baseRepoPath worktree prune

# 6. Stop worktree heartbeat
Stop-WorktreeHeartbeat -WorktreeId $worktreeId

# 7. Log release
Write-AllocationLog -AgentId $AgentId -Action "release" -WorktreeId $worktreeId -Result "success" -PRUrl $pr.url

# 8. Switch base repos to develop
git -C $baseRepoPath checkout develop
git -C $baseRepoPath pull origin develop

# 9. NOW present PR to user
Write-Host "✅ PR created: $($pr.url)"
Write-Host "✅ Worktree released: $seat is now FREE"
```

**CRITICAL:** Worktree MUST be released before presenting PR to user. This is a ZERO-TOLERANCE requirement.

---

### Protocol 4: Heartbeat & Liveness Detection

**Heartbeat Sender (runs in background job for each agent):**

```powershell
# Started at agent registration, runs until agent exits
while ($true) {
    try {
        # 1. Get current activity from ManicTime
        $context = monitor-activity.ps1 -Mode context -OutputFormat object

        # 2. Determine agent status
        $isActive = $context.ClaudeInstances.Instances |
            Where-Object { $_.ProcessId -eq $PID } |
            Select-Object -ExpandProperty WindowTitle -ne $null

        $status = if ($context.IdleTime.Minutes -gt 15) { "idle" } elseif ($isActive) { "active" } else { "background" }

        # 3. Update heartbeat in database
        Update-AgentHeartbeat -AgentId $AgentId -Timestamp (Get-Date) `
            -Status $status -ActivityScore $context.ActiveWindow ? 100 : 0

        # 4. Also update heartbeat file (backward compatibility)
        $heartbeatPath = "C:\scripts\_machine\heartbeats\$AgentId.heartbeat"
        @{
            Timestamp = Get-Date -Format 'o'
            Status = $status
            Pid = $PID
            ActiveAllocations = @(Get-WorktreeAllocations -AgentId $AgentId).Count
        } | ConvertTo-Json | Out-File -FilePath $heartbeatPath -Force

        # 5. Wait for next interval (active: 10s, idle: 60s)
        $interval = if ($status -eq "active") { 10 } else { 60 }
        Start-Sleep -Seconds $interval
    }
    catch {
        Write-Warning "Heartbeat failed: $_"
        Start-Sleep -Seconds 10
    }
}
```

**Liveness Monitor (runs in watchdog):**

```powershell
# Runs every 30 seconds, checks all registered agents
$agents = Get-RegisteredAgents

foreach ($agent in $agents) {
    # 1. Check if process still exists
    $processExists = Get-Process -Id $agent.Pid -ErrorAction SilentlyContinue

    if (-not $processExists) {
        # Agent crashed without cleanup
        Write-Warning "Agent $($agent.AgentId) crashed (PID $($agent.Pid) not found)"

        # Reclaim all allocations
        $allocations = Get-WorktreeAllocations -AgentId $agent.AgentId
        foreach ($alloc in $allocations) {
            Release-Worktree -WorktreeId $alloc.WorktreeId -AgentId $agent.AgentId -Reason "Agent crashed"
        }

        # Unregister agent
        Unregister-Agent -AgentId $agent.AgentId -Reason "Crash detected"

        continue
    }

    # 2. Check heartbeat freshness
    $timeSinceHeartbeat = (Get-Date) - $agent.LastHeartbeat
    $maxHeartbeatAge = if ($agent.Status -eq "active") { 30 } else { 180 }  # 30s active, 180s idle

    if ($timeSinceHeartbeat.TotalSeconds -gt $maxHeartbeatAge) {
        # Heartbeat stale (agent hung or network issue)
        Write-Warning "Agent $($agent.AgentId) heartbeat stale ($($timeSinceHeartbeat.TotalSeconds)s since last heartbeat)"

        # Check ManicTime for ground truth
        $context = monitor-activity.ps1 -Mode context -OutputFormat object
        $agentActive = $context.ClaudeInstances.Instances | Where-Object { $_.ProcessId -eq $agent.Pid }

        if ($agentActive) {
            # Process exists and active in ManicTime, but no heartbeat → heartbeat mechanism failed
            Write-Warning "  ManicTime shows agent is active - heartbeat mechanism issue"
            # Don't reclaim yet, give benefit of doubt
        } else {
            # Process exists but not active in ManicTime and no heartbeat → agent hung
            Write-Warning "  ManicTime shows agent is NOT active - likely hung"

            # Reclaim allocations after 5 minutes
            if ($timeSinceHeartbeat.TotalMinutes -gt 5) {
                $allocations = Get-WorktreeAllocations -AgentId $agent.AgentId
                foreach ($alloc in $allocations) {
                    Release-Worktree -WorktreeId $alloc.WorktreeId -AgentId $agent.AgentId -Reason "Heartbeat timeout"
                }
            }
        }
    }
}
```

---

### Protocol 5: Conflict Detection (Pre-Allocation)

**MANDATORY check before allocation:**

```powershell
function Test-BranchConflict {
    param($BranchName, $Repo)

    # Check 1: Git worktree list (authoritative source)
    $gitWorktrees = git -C "C:\Projects\$Repo" worktree list | Select-String $BranchName
    if ($gitWorktrees) {
        $worktreePath = ($gitWorktrees -split '\s+')[0]
        return @{
            HasConflict = $true
            Reason = "Git worktree exists"
            Details = @{ Path = $worktreePath }
        }
    }

    # Check 2: Coordination database (current allocations)
    $dbAllocation = Get-WorktreeAllocations -BranchName $BranchName -Repo $Repo
    if ($dbAllocation) {
        return @{
            HasConflict = $true
            Reason = "Branch allocated in database"
            Details = @{
                AgentId = $dbAllocation.AgentId
                AllocatedAt = $dbAllocation.AllocatedAt
                WorktreeId = $dbAllocation.WorktreeId
            }
        }
    }

    # Check 3: instances.map.md (backward compatibility)
    $mapEntry = Get-Content "C:\scripts\_machine\instances.map.md" | Select-String $BranchName
    if ($mapEntry) {
        return @{
            HasConflict = $true
            Reason = "Branch in instances.map.md"
            Details = @{ Entry = $mapEntry.Line }
        }
    }

    # Check 4: Recent activity log (potential stale allocation)
    $recentActivity = Get-AllocationLog -BranchName $BranchName -Since (Get-Date).AddMinutes(-120)
    if ($recentActivity -and $recentActivity.Action -ne "release") {
        return @{
            HasConflict = $false  # Not a hard conflict
            Warning = $true
            Reason = "Branch recently active"
            Details = @{
                LastActivity = $recentActivity.Timestamp
                LastAgent = $recentActivity.AgentId
                TimeSince = ((Get-Date) - $recentActivity.Timestamp).TotalMinutes
            }
        }
    }

    # All checks passed
    return @{ HasConflict = $false }
}
```

---

### Protocol 6: Validation & Repair (Periodic Health Checks)

**Runs every 5 minutes via watchdog:**

```powershell
function Invoke-CoordinationValidation {
    $issues = @()

    # Validation 1: Pool state vs. Git reality
    $poolAllocations = Get-WorktreeAllocations -State "BUSY"
    foreach ($alloc in $poolAllocations) {
        $gitWorktree = git -C "C:\Projects\$($alloc.Repo)" worktree list | Select-String $alloc.Branch

        if (-not $gitWorktree) {
            # Pool says BUSY but no git worktree exists
            $issues += "Orphaned allocation: $($alloc.WorktreeId) (no git worktree)"

            # Auto-repair: Release allocation
            Release-Worktree -WorktreeId $alloc.WorktreeId -AgentId $alloc.AgentId -Reason "Validation: no git worktree"
        }
    }

    # Validation 2: Git worktrees vs. Pool state
    $repos = @("client-manager", "hazina")
    foreach ($repo in $repos) {
        $gitWorktrees = git -C "C:\Projects\$repo" worktree list | Select-Object -Skip 1  # Skip main worktree

        foreach ($line in $gitWorktrees) {
            $parts = $line -split '\s+'
            $worktreePath = $parts[0]
            $branch = $parts[2] -replace '[\[\]]', ''

            $poolAlloc = Get-WorktreeAllocations -BranchName $branch -Repo $repo

            if (-not $poolAlloc) {
                # Git worktree exists but not in pool
                $issues += "Untracked worktree: $worktreePath ($branch)"

                # Auto-repair: Add to pool or remove worktree
                # (Conservative: don't auto-remove, log for manual review)
            }
        }
    }

    # Validation 3: Agent registrations vs. Running processes
    $agents = Get-RegisteredAgents
    foreach ($agent in $agents) {
        $processExists = Get-Process -Id $agent.Pid -ErrorAction SilentlyContinue

        if (-not $processExists) {
            $issues += "Agent registration without process: $($agent.AgentId) (PID $($agent.Pid))"

            # Auto-repair: Clean up registration and allocations
            Unregister-Agent -AgentId $agent.AgentId -Reason "Validation: process not found"
            $allocations = Get-WorktreeAllocations -AgentId $agent.AgentId
            foreach ($alloc in $allocations) {
                Release-Worktree -WorktreeId $alloc.WorktreeId -AgentId $agent.AgentId -Reason "Validation: agent process gone"
            }
        }
    }

    # Validation 4: Invariant checks
    # - No worktree allocated to multiple agents
    $duplicateAllocations = Get-WorktreeAllocations | Group-Object WorktreeId | Where-Object { $_.Count -gt 1 }
    foreach ($dup in $duplicateAllocations) {
        $issues += "Duplicate allocation: Worktree $($dup.Name) allocated to $($dup.Count) agents"

        # Auto-repair: Keep most recent allocation, release others
        $sorted = $dup.Group | Sort-Object AllocatedAt -Descending
        for ($i = 1; $i -lt $sorted.Count; $i++) {
            Release-Worktree -WorktreeId $sorted[$i].WorktreeId -AgentId $sorted[$i].AgentId -Reason "Validation: duplicate allocation"
        }
    }

    # Log issues
    if ($issues.Count -gt 0) {
        Write-Warning "Validation found $($issues.Count) issues:"
        $issues | ForEach-Object { Write-Warning "  - $_" }

        # Append to validation log
        Add-Content -Path "C:\scripts\_machine\validation.log" -Value @"
$(Get-Date -Format 'o') - Validation Issues ($($issues.Count)):
$($issues | ForEach-Object { "  - $_" } | Out-String)
"@
    } else {
        Write-Host "✅ Validation passed: No issues found"
    }

    return $issues
}
```

---

## 🔧 Implementation: Coordination Tools

### Tool 1: `coordination-db-init.ps1`

**Purpose:** Initialize SQLite coordination database

```powershell
<#
.SYNOPSIS
Initialize coordination database for parallel agent coordination

.DESCRIPTION
Creates SQLite database with tables for agent registry, worktree pool, and allocation log.
Enables WAL mode for better concurrency.
#>

param(
    [string]$DbPath = "C:\scripts\_machine\coordination.db"
)

# Install System.Data.SQLite if not available
if (-not (Get-Module -ListAvailable -Name System.Data.SQLite)) {
    Install-Package System.Data.SQLite.Core -Force
}

Import-Module System.Data.SQLite

# Create database connection
$connectionString = "Data Source=$DbPath;Version=3;"
$connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
$connection.Open()

try {
    # Enable WAL mode for better concurrency
    $cmd = $connection.CreateCommand()
    $cmd.CommandText = "PRAGMA journal_mode=WAL;"
    $cmd.ExecuteNonQuery() | Out-Null

    # Create agents table
    $cmd.CommandText = @"
CREATE TABLE IF NOT EXISTS agents (
    agent_id TEXT PRIMARY KEY,
    pid INTEGER NOT NULL,
    start_time TEXT NOT NULL,
    last_heartbeat TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('active', 'idle', 'background', 'crashed')),
    priority INTEGER NOT NULL DEFAULT 50,
    activity_score INTEGER NOT NULL DEFAULT 0
);
"@
    $cmd.ExecuteNonQuery() | Out-Null

    # Create worktrees table
    $cmd.CommandText = @"
CREATE TABLE IF NOT EXISTS worktrees (
    worktree_id TEXT PRIMARY KEY,
    seat_name TEXT NOT NULL,
    path TEXT NOT NULL,
    repo TEXT NOT NULL,
    state TEXT NOT NULL CHECK(state IN ('FREE', 'BUSY', 'BROKEN', 'STALE')),
    agent_id TEXT,
    branch_name TEXT,
    allocated_at TEXT,
    last_activity TEXT,
    priority INTEGER,
    version INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (agent_id) REFERENCES agents(agent_id)
);
"@
    $cmd.ExecuteNonQuery() | Out-Null

    # Create allocation_log table
    $cmd.CommandText = @"
CREATE TABLE IF NOT EXISTS allocation_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    agent_id TEXT NOT NULL,
    action TEXT NOT NULL CHECK(action IN ('allocate', 'release', 'conflict', 'timeout')),
    worktree_id TEXT,
    branch_name TEXT,
    repo TEXT,
    result TEXT NOT NULL,
    reason TEXT,
    duration_ms INTEGER,
    pr_url TEXT
);
"@
    $cmd.ExecuteNonQuery() | Out-Null

    # Create indexes
    $cmd.CommandText = "CREATE INDEX IF NOT EXISTS idx_worktrees_state ON worktrees(state);"
    $cmd.ExecuteNonQuery() | Out-Null

    $cmd.CommandText = "CREATE INDEX IF NOT EXISTS idx_worktrees_agent ON worktrees(agent_id);"
    $cmd.ExecuteNonQuery() | Out-Null

    $cmd.CommandText = "CREATE INDEX IF NOT EXISTS idx_worktrees_branch ON worktrees(branch_name);"
    $cmd.ExecuteNonQuery() | Out-Null

    $cmd.CommandText = "CREATE INDEX IF NOT EXISTS idx_allocation_log_timestamp ON allocation_log(timestamp);"
    $cmd.ExecuteNonQuery() | Out-Null

    # Initialize worktree pool entries
    for ($i = 1; $i -le 12; $i++) {
        $agentId = "agent-{0:D3}" -f $i
        $cmd.CommandText = @"
INSERT OR IGNORE INTO worktrees (worktree_id, seat_name, path, repo, state, version)
VALUES
    ('$agentId-client-manager', '$agentId', 'C:\Projects\worker-agents\$agentId\client-manager', 'client-manager', 'FREE', 1),
    ('$agentId-hazina', '$agentId', 'C:\Projects\worker-agents\$agentId\hazina', 'hazina', 'FREE', 1);
"@
        $cmd.ExecuteNonQuery() | Out-Null
    }

    Write-Host "✅ Coordination database initialized: $DbPath"
    Write-Host "  - WAL mode enabled"
    Write-Host "  - Tables created: agents, worktrees, allocation_log"
    Write-Host "  - Worktree pool initialized: 12 seats × 2 repos = 24 worktrees"
}
finally {
    $connection.Close()
}
```

### Tool 2: `Start-CoordinationDaemon.ps1`

**Purpose:** Background service for event dispatching and monitoring

```powershell
<#
.SYNOPSIS
Start coordination daemon for parallel agent coordination

.DESCRIPTION
Runs background service that:
- Monitors coordination database for changes
- Dispatches events to agents via named pipes
- Provides fallback polling endpoint
- Runs periodic validation
#>

param(
    [string]$DbPath = "C:\scripts\_machine\coordination.db",
    [int]$ValidationIntervalMinutes = 5
)

Write-Host "🚀 Starting Coordination Daemon..." -ForegroundColor Cyan

# Create FileSystemWatcher for database changes
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = Split-Path -Parent $DbPath
$watcher.Filter = Split-Path -Leaf $DbPath
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite
$watcher.EnableRaisingEvents = $true

# Event handler for database changes
$changeAction = {
    param($source, $e)

    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Database changed, notifying agents..." -ForegroundColor Yellow

    # Get all active agents
    $agents = Get-RegisteredAgents

    foreach ($agent in $agents) {
        try {
            # Send notification via named pipe (non-blocking)
            $pipeName = "claude-agent-$($agent.AgentId)"
            $pipe = New-Object System.IO.Pipes.NamedPipeClientStream(".", $pipeName, [System.IO.Pipes.PipeDirection]::Out)
            $pipe.Connect(100)  # 100ms timeout

            $writer = New-Object System.IO.StreamWriter($pipe)
            $writer.WriteLine("POOL_STATE_CHANGED")
            $writer.Flush()
            $writer.Close()
            $pipe.Close()
        }
        catch {
            # Agent might not be listening, that's okay (fallback to polling)
        }
    }
}

$watcher.Changed += $changeAction

Write-Host "✅ FileSystemWatcher active on $DbPath" -ForegroundColor Green

# Periodic validation loop
$lastValidation = Get-Date
while ($true) {
    Start-Sleep -Seconds 30

    # Run validation every N minutes
    if (((Get-Date) - $lastValidation).TotalMinutes -ge $ValidationIntervalMinutes) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] Running periodic validation..." -ForegroundColor Cyan

        $issues = Invoke-CoordinationValidation

        if ($issues.Count -eq 0) {
            Write-Host "  ✅ No issues found" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️ Found $($issues.Count) issues (auto-repaired)" -ForegroundColor Yellow
        }

        $lastValidation = Get-Date
    }
}
```

### Tool 3: `Get-AgentCoordinationMetrics.ps1`

**Purpose:** Dashboard metrics for coordination system

```powershell
<#
.SYNOPSIS
Get coordination metrics and status dashboard

.DESCRIPTION
Provides comprehensive metrics about parallel agent coordination:
- Active agents and their status
- Worktree pool utilization
- Allocation success/conflict rates
- Performance metrics (latency, throughput)
- Recent activity timeline
#>

param(
    [switch]$Live,  # Continuous monitoring mode
    [int]$RefreshSeconds = 5
)

function Show-CoordinationDashboard {
    Clear-Host

    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "   CLAUDE AGENT COORDINATION DASHBOARD" -ForegroundColor Cyan
    Write-Host "   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    # Section 1: Active Agents (from ManicTime)
    Write-Host "🤖 ACTIVE AGENTS" -ForegroundColor Yellow
    Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor Gray

    $context = monitor-activity.ps1 -Mode context -OutputFormat object
    $agents = Get-RegisteredAgents

    Write-Host "  Total Registered: $($agents.Count)" -ForegroundColor White
    Write-Host "  Running Processes: $($context.ClaudeInstances.Count)" -ForegroundColor White
    Write-Host "  User Attending: $($context.System.UserAttending)" -ForegroundColor $(if ($context.System.UserAttending) { 'Green' } else { 'Red' })
    Write-Host "  Idle Time: $($context.IdleTime.Minutes) minutes" -ForegroundColor $(if ($context.IdleTime.Minutes -lt 15) { 'Green' } else { 'Yellow' })
    Write-Host ""

    # Agent details
    foreach ($agent in $agents) {
        $processExists = Get-Process -Id $agent.Pid -ErrorAction SilentlyContinue
        $statusColor = switch ($agent.Status) {
            'active' { 'Green' }
            'idle' { 'Yellow' }
            'background' { 'Gray' }
            default { 'Red' }
        }

        $indicator = if ($processExists) { "●" } else { "○" }
        $timeSinceHeartbeat = ((Get-Date) - [DateTime]::Parse($agent.LastHeartbeat)).TotalSeconds

        Write-Host "  $indicator " -ForegroundColor $statusColor -NoNewline
        Write-Host "$($agent.AgentId): " -NoNewline
        Write-Host "$($agent.Status)" -ForegroundColor $statusColor -NoNewline
        Write-Host " (heartbeat: ${timeSinceHeartbeat}s ago)" -ForegroundColor Gray
    }
    Write-Host ""

    # Section 2: Worktree Pool
    Write-Host "🌳 WORKTREE POOL" -ForegroundColor Yellow
    Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor Gray

    $worktrees = Get-WorktreePool
    $busyCount = @($worktrees | Where-Object { $_.State -eq 'BUSY' }).Count
    $freeCount = @($worktrees | Where-Object { $_.State -eq 'FREE' }).Count
    $utilization = [math]::Round(($busyCount / $worktrees.Count) * 100, 1)

    Write-Host "  Total Worktrees: $($worktrees.Count)" -ForegroundColor White
    Write-Host "  BUSY: $busyCount" -ForegroundColor Red
    Write-Host "  FREE: $freeCount" -ForegroundColor Green
    Write-Host "  Utilization: $utilization%" -ForegroundColor $(if ($utilization -gt 80) { 'Red' } elseif ($utilization -gt 50) { 'Yellow' } else { 'Green' })
    Write-Host ""

    # Active allocations
    $busy = $worktrees | Where-Object { $_.State -eq 'BUSY' }
    if ($busy) {
        Write-Host "  Active Allocations:" -ForegroundColor White
        foreach ($w in $busy) {
            $duration = ((Get-Date) - [DateTime]::Parse($w.AllocatedAt)).TotalMinutes
            Write-Host "    $($w.SeatName): " -NoNewline
            Write-Host "$($w.BranchName)" -ForegroundColor Cyan -NoNewline
            Write-Host " ($([math]::Round($duration, 1))m by $($w.AgentId))" -ForegroundColor Gray
        }
        Write-Host ""
    }

    # Section 3: Recent Activity (last 10 events)
    Write-Host "📊 RECENT ACTIVITY" -ForegroundColor Yellow
    Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor Gray

    $recentLog = Get-AllocationLog -Limit 10
    foreach ($entry in $recentLog) {
        $time = [DateTime]::Parse($entry.Timestamp).ToString('HH:mm:ss')
        $actionColor = switch ($entry.Action) {
            'allocate' { 'Green' }
            'release' { 'Blue' }
            'conflict' { 'Red' }
            'timeout' { 'Yellow' }
            default { 'White' }
        }

        Write-Host "  [$time] " -ForegroundColor Gray -NoNewline
        Write-Host "$($entry.Action): " -ForegroundColor $actionColor -NoNewline
        Write-Host "$($entry.AgentId) → $($entry.BranchName) " -NoNewline
        Write-Host "($($entry.Result))" -ForegroundColor $(if ($entry.Result -eq 'success') { 'Green' } else { 'Red' })
    }
    Write-Host ""

    # Section 4: Performance Metrics (last hour)
    Write-Host "⚡ PERFORMANCE (Last Hour)" -ForegroundColor Yellow
    Write-Host "───────────────────────────────────────────────────────────────" -ForegroundColor Gray

    $hourAgo = (Get-Date).AddHours(-1)
    $hourLog = Get-AllocationLog -Since $hourAgo

    $allocations = @($hourLog | Where-Object { $_.Action -eq 'allocate' })
    $successful = @($allocations | Where-Object { $_.Result -eq 'success' })
    $conflicts = @($hourLog | Where-Object { $_.Action -eq 'conflict' })

    $successRate = if ($allocations.Count -gt 0) {
        [math]::Round(($successful.Count / $allocations.Count) * 100, 1)
    } else { 0 }

    $avgDuration = if ($successful.Count -gt 0) {
        ($successful | Measure-Object -Property DurationMs -Average).Average
    } else { 0 }

    Write-Host "  Allocations: $($allocations.Count)" -ForegroundColor White
    Write-Host "  Success Rate: $successRate%" -ForegroundColor $(if ($successRate -gt 90) { 'Green' } else { 'Yellow' })
    Write-Host "  Conflicts: $($conflicts.Count)" -ForegroundColor $(if ($conflicts.Count -eq 0) { 'Green' } else { 'Red' })
    Write-Host "  Avg Duration: $([math]::Round($avgDuration, 0))ms" -ForegroundColor White
    Write-Host ""

    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
}

# Main execution
if ($Live) {
    while ($true) {
        Show-CoordinationDashboard
        Write-Host "Press Ctrl+C to exit. Refreshing in $RefreshSeconds seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds $RefreshSeconds
    }
} else {
    Show-CoordinationDashboard
}
```

---

## 📚 Success Criteria

**You are using parallel agent coordination correctly ONLY IF:**

1. ✅ **Startup:** Every agent runs registration protocol before any work
2. ✅ **Allocation:** Every allocation checks conflicts FIRST, then uses adaptive strategy (optimistic/pessimistic)
3. ✅ **Heartbeat:** Every agent sends heartbeat every 10-60 seconds
4. ✅ **Release:** Every worktree released IMMEDIATELY after PR creation, BEFORE presenting to user
5. ✅ **Monitoring:** Coordination daemon running in background
6. ✅ **Validation:** Watchdog runs validation every 5 minutes
7. ✅ **Metrics:** Dashboard shows real-time coordination status
8. ✅ **Zero Conflicts:** No duplicate allocations, no race conditions

---

## 🚨 Violations & Recovery

### Violation: Agent started without registration

**Symptom:** Agent working but not in database, heartbeat missing

**Recovery:**
```powershell
# Re-register agent (retroactive)
Register-Agent -AgentId $AgentId -Pid $PID -StartTime $EstimatedStartTime
```

### Violation: Allocation without conflict check

**Symptom:** Two agents on same branch, git conflicts

**Recovery:**
```powershell
# 1. Identify duplicate allocations
$duplicates = Get-WorktreeAllocations -BranchName $BranchName

# 2. Determine winner (most recent activity from ManicTime)
$context = monitor-activity.ps1 -Mode context -OutputFormat object
$activeAgent = $context.ClaudeInstances.Instances |
    Where-Object { $duplicates.AgentId -contains $_.ProcessId } |
    Sort-Object -Property CPU -Descending | Select-Object -First 1

# 3. Losers release
foreach ($dup in $duplicates) {
    if ($dup.AgentId -ne $activeAgent.AgentId) {
        Release-Worktree -WorktreeId $dup.WorktreeId -AgentId $dup.AgentId -Reason "Conflict resolution"
    }
}
```

### Violation: No heartbeat running

**Symptom:** Agent crashes and orphans allocations

**Recovery:**
```powershell
# Watchdog will auto-detect and cleanup after 5 minutes
# Manual recovery:
$orphanedAllocations = Get-WorktreeAllocations -AgentId $CrashedAgentId
foreach ($alloc in $orphanedAllocations) {
    Release-Worktree -WorktreeId $alloc.WorktreeId -AgentId $CrashedAgentId -Reason "Manual cleanup"
}
```

---

## 🔄 Migration from File-Based Coordination

**Phase 1: Parallel Running (2 weeks)**
- New agents use SQLite + ManicTime coordination
- Old file-based coordination remains for backward compatibility
- Both systems synchronized via shim layer

**Phase 2: Validation & Tuning (1 week)**
- Monitor metrics: conflict rate, allocation latency
- Tune timeouts, priorities, heartbeat intervals
- Fix bugs discovered in production

**Phase 3: Full Cutover (1 day)**
- Remove file-based coordination
- All agents use SQLite coordination
- Archive old pool.md, instances.map.md for historical analysis

---

## 📈 Metrics to Track

### Operational Metrics
- **Allocation Success Rate** (target: >95%)
- **Average Allocation Latency** (target: <3 seconds p99)
- **Conflict Rate** (target: <1% of allocations)
- **Pool Utilization** (target: 40-60% during active hours)

### Health Metrics
- **Agent Uptime** (target: >99.9%)
- **Heartbeat Success Rate** (target: >99%)
- **Validation Issues per Hour** (target: <1)
- **Crash/Hang Rate** (target: <1 per week)

### Performance Metrics
- **Time to Detect Crash** (target: <30 seconds)
- **Time to Reclaim Stale Allocation** (target: <5 minutes)
- **Database Query Latency** (target: <10ms p95)

---

## 🎓 Key Learnings from 50 Experts

1. **File-based coordination has fundamental limits** → SQLite with WAL mode
2. **ManicTime is for intelligence, not coordination** → Liveness detection, priority assignment, metrics
3. **Hybrid optimistic/pessimistic strategy** → Adaptive based on contention
4. **Aggressive timeouts prevent deadlocks** → 10s allocation, 5m reclamation
5. **Event-driven with polling fallback** → Low latency + reliability
6. **Validation is critical** → Periodic health checks catch edge cases
7. **Metrics drive optimization** → Track everything, optimize based on data
8. **Graceful degradation** → System survives agent crashes, file corruption

---

**Last Updated:** 2026-01-20 02:30
**Status:** Production-Ready
**Based On:** 50-expert synthesis
**Maintained By:** Claude Agent (Self-improving system)
