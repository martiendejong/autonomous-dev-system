# Brand2Boost Backup System

Automated nightly backup system for your-app data with 5-day retention.

## 📁 What Gets Backed Up

**Source:** `C:\stores\your-app`
**Backup Location:** `C:\backups\your-app`

### Included:
- ✅ `identity.db` - User authentication database
- ✅ `llm-logs.db` - LLM interaction logs
- ✅ All `.prompt.txt` files - Prompt templates
- ✅ All `p-*` directories - Project data
- ✅ `prompts/` directory
- ✅ `.chats/` directory
- ✅ Configuration files (JSON, TXT)
- ✅ All user data and settings

### Excluded (temporary/build files):
- ❌ `.git` - Git repository data
- ❌ `bin/` - Build output
- ❌ `obj/` - Build cache
- ❌ `logs/` - Log files
- ❌ `model-usage-stats/` - Statistics
- ❌ `.hazina/` - Framework cache

## 🚀 Setup (One-time)

### Step 1: Set Up Nightly Scheduled Task

**Right-click** `Setup Nightly Backup.bat` and select **"Run as Administrator"**

This will:
- Create a Windows scheduled task
- Run automatically every night at 3:00 AM
- Keep the last 5 backups (oldest deleted automatically)
- Run in the background (no windows)

### Step 2: Verify Setup

Open PowerShell and run:
```powershell
Get-ScheduledTask -TaskName "Brand2Boost Nightly Backup" | Get-ScheduledTaskInfo
```

## 📝 Manual Backup Commands

### Run Backup Now
```powershell
cd C:\scripts\tools
.\backup-your-app.ps1
```

### Test Backup (Dry Run - No Changes)
```powershell
.\backup-your-app.ps1 -DryRun
```

### Run Scheduled Task Manually
```powershell
Start-ScheduledTask -TaskName "Brand2Boost Nightly Backup"
```

## 📂 Backup Structure

Backups are stored in:
```
C:\backups\your-app\
├── backup_2026-01-19_03-00-00\   (Most recent)
├── backup_2026-01-18_03-00-00\
├── backup_2026-01-17_03-00-00\
├── backup_2026-01-16_03-00-00\
├── backup_2026-01-15_03-00-00\   (Oldest - will be deleted when new backup is created)
└── backup.log                      (Backup operation log)
```

## 🔧 Configuration

Edit `backup-your-app.ps1` to customize:

```powershell
param(
    [string]$SourcePath = "C:\stores\your-app",      # What to backup
    [string]$BackupRoot = "C:\backups\your-app",     # Where to store backups
    [int]$MaxBackups = 5,                                # Number of backups to keep
    [string[]]$ExcludeDirs = @(".git", "bin", "obj", "logs", "model-usage-stats", ".hazina")
)
```

## 📊 View Backup Log

```powershell
Get-Content C:\backups\your-app\backup.log -Tail 50
```

## ♻️ Restoring from Backup

### Full Restore
1. Stop the your-app application
2. Copy backup folder contents to `C:\stores\your-app`
```powershell
# Example: Restore from January 19th backup
Copy-Item -Path "C:\backups\your-app\backup_2026-01-19_03-00-00\*" `
          -Destination "C:\stores\your-app" `
          -Recurse -Force
```
3. Restart the application

### Restore Specific Files
```powershell
# Example: Restore only the database
Copy-Item -Path "C:\backups\your-app\backup_2026-01-19_03-00-00\identity.db*" `
          -Destination "C:\stores\your-app"
```

## 🗑️ Uninstall

### Remove Scheduled Task
**Right-click PowerShell as Administrator** and run:
```powershell
Unregister-ScheduledTask -TaskName "Brand2Boost Nightly Backup" -Confirm:$false
```

### Delete Backups
```powershell
Remove-Item -Path "C:\backups\your-app" -Recurse -Force
```

## ⚠️ Important Notes

1. **Backup Size:** Each backup is approximately 400-500 MB
2. **Disk Space:** 5 backups ≈ 2-2.5 GB total
3. **Backup Time:** Backups run at 3:00 AM (configurable)
4. **Automatic Rotation:** Oldest backup is deleted when 6th backup is created
5. **Database Integrity:** SQLite database files are backed up with their -wal and -shm files

## 🆘 Troubleshooting

### Check if Task is Running
```powershell
Get-ScheduledTask -TaskName "Brand2Boost Nightly Backup"
```

### View Last Run Result
```powershell
Get-ScheduledTask -TaskName "Brand2Boost Nightly Backup" | Get-ScheduledTaskInfo
```

### Manual Test Run
```powershell
cd C:\scripts\tools
.\backup-your-app.ps1
```

### Check Backup Log
```powershell
Get-Content C:\backups\your-app\backup.log
```

## 📅 Backup Schedule

Default: **Every day at 3:00 AM**

To change the time, edit `register-backup-task.ps1` line:
```powershell
$trigger = New-ScheduledTaskTrigger -Daily -At "03:00"  # Change time here
```

Then re-run `Setup Nightly Backup.bat` as Administrator.

---

**Created:** 2026-01-19
**Version:** 1.0
**Location:** `C:\scripts\tools\`
