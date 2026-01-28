# SYNAPSE Watcher - Windows Setup

## Quick Start

1. **Install Claude Code** (if not already)
   - Download from: https://docs.anthropic.com/claude-code
   - Make sure `claude` command works in PowerShell

2. **Copy files to your Windows PC**
   - Put `watcher-windows.ps1` and `START-WATCHER.bat` somewhere (e.g., `C:\synapse\`)

3. **Double-click `START-WATCHER.bat`**
   - That's it! Watcher starts polling every 2 seconds

## Keep Windows Awake

The PC needs to stay on. Options:

### Option A: Disable Sleep (Easiest)
1. Settings → System → Power & Sleep
2. Set "Sleep" to **Never** (when plugged in)

### Option B: Use Caffeine App
- Download: https://www.zhornsoftware.co.uk/caffeine/
- Prevents sleep while running

### Option C: Power Settings via Command
```cmd
powercfg -change -standby-timeout-ac 0
powercfg -change -monitor-timeout-ac 0
```

## Auto-Start on Boot

### Option A: Startup Folder (Easiest)
1. Press `Win + R`
2. Type `shell:startup` → Enter
3. Copy `START-WATCHER.bat` into that folder
4. Done! Watcher starts when you log in

### Option B: Task Scheduler (Runs without login)
1. Open Task Scheduler
2. Create Basic Task → Name: "SYNAPSE Watcher"
3. Trigger: "When the computer starts"
4. Action: Start a program
5. Program: `powershell`
6. Arguments: `-ExecutionPolicy Bypass -File "C:\synapse\watcher-windows.ps1"`
7. Check "Run whether user is logged on or not"

## Logs

Logs are stored in:
```
%USERPROFILE%\.synapse\watcher.log
```

View logs:
```powershell
Get-Content $env:USERPROFILE\.synapse\watcher.log -Tail 50 -Wait
```

## Troubleshooting

**"claude is not recognized"**
- Claude Code not installed or not in PATH
- Restart PowerShell after installing Claude Code

**"Execution Policy" error**
- Run PowerShell as Admin
- Run: `Set-ExecutionPolicy RemoteSigned`

**Tasks not being picked up**
- Check that SUPABASE_KEY is correct in the script
- Check logs: `%USERPROFILE%\.synapse\watcher.log`

## Security Notes

- ✅ No ports exposed (outbound only)
- ✅ Credentials in script, not exposed to network
- ⚠️ Anyone with access to the Windows PC can see the script
- 💡 Keep the PC locked when away
