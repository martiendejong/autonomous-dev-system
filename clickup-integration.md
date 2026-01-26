# ClickUp Integration

**Created:** 2026-01-14
**Status:** Active

---

## Overview

Claude Agent can synchronize with ClickUp to:
- Pull tasks from ClickUp lists
- Update task status when work is completed
- Create tasks when issues are discovered
- Track work in progress

---

## Configuration

**Config file:** `C:\scripts\_machine\clickup-config.json`

### Repository → ClickUp Mapping

| Repository | Workspace | Folder | List | List ID |
|------------|-----------|--------|------|---------|
| myproject | GigsHub | Internal | Brand Designer | 901214097647 |
| myframework | GigsHub | Internal | Brand Designer | (shared list) |

---

## Workspaces Summary

### 1. Martien de Jong's Workspace (Personal)
- **ID:** 9015747737
- **Role:** Owner
- **Usage:** Personal/household tasks, tax admin

### 2. Furniture Website (Company)
- **ID:** 9015748488
- **Role:** Admin
- **Usage:** Legacy Vera AI list (not actively used)

### 3. GigsHub Workspace (PRIMARY)
- **ID:** 9012956001
- **Role:** Member
- **Usage:** **myproject/myframework development tasks**
- **Key List:** Brand Designer (901214097647) - 100 tasks

---

## Brand Designer Task Statuses

| Status | Meaning |
|--------|---------|
| todo | To do - ready to start |
| busy | In progress |
| review | Ready for review |
| needs input | Waiting for clarification |
| needs refinement | Needs more detail |
| next sprint | Planned for next sprint |
| blocked | Blocked by dependency |
| done | Completed |
| cancelled | Cancelled |

---

## API Usage

### Authentication
```powershell
$headers = @{Authorization = "pk_74525428_TXT8V1QUA13N7SCRM0UUM6WNQO2I2NML"}
```

### Common Endpoints

**Get tasks from Brand Designer list:**
```powershell
Invoke-RestMethod -Uri "https://api.clickup.com/api/v2/list/901214097647/task?archived=false" -Headers $headers
```

**Update task status:**
```powershell
Invoke-RestMethod -Method PUT -Uri "https://api.clickup.com/api/v2/task/{task_id}" -Headers $headers -Body (@{status="review"} | ConvertTo-Json) -ContentType "application/json"
```

**Create task:**
```powershell
$body = @{name="Task name"; description="Details"; status="todo"} | ConvertTo-Json
Invoke-RestMethod -Method POST -Uri "https://api.clickup.com/api/v2/list/901214097647/task" -Headers $headers -Body $body -ContentType "application/json"
```

---

## Workflow Integration

### Starting Work on a Task

1. **Pull tasks from ClickUp:**
   ```
   clickup-sync.ps1 -Action list
   ```

2. **Agent picks task and updates status:**
   ```
   clickup-sync.ps1 -Action update -TaskId "869bhfw7r" -Status "busy"
   ```

3. **When PR created, update to "review":**
   ```
   clickup-sync.ps1 -Action update -TaskId "869bhfw7r" -Status "review"
   clickup-sync.ps1 -Action comment -TaskId "869bhfw7r" -Comment "PR #149 created"
   ```

### Agent Autonomy

Claude Agent can autonomously:
- Check for high-priority tasks at session start
- Update task status when PRs are created
- Add comments with PR links
- Create new tasks when bugs are discovered

---

## Current Open Tasks (as of 2026-01-14)

**Total:** 100 open tasks

| Status | Count |
|--------|-------|
| done | 49 |
| review | 15 |
| todo | 8 |
| busy | 8 |
| needs refinement | 7 |
| needs input | 5 |
| next sprint | 4 |
| cancelled | 3 |
| blocked | 1 |

**Recent high-activity tasks:**
- restaurant menu (869bhfw7r)
- project chat url (869brntyj)
- left: one list of all generated items (869brkx6e)
- token usage for in chat generated items (869brmb1z)

---

## Tools

- **clickup-sync.ps1** - Main sync tool (see `C:\scripts\tools\`)
- **clickup-config.json** - Configuration (see `C:\scripts\_machine\`)

---

## Security

- API key stored in `_machine/clickup-config.json` (not committed to git)
- `.gitignore` should exclude `_machine/*.json` with secrets

---

**Maintained by:** Claude Agent
