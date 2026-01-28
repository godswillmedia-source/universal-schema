#
# SYNAPSE Watcher Daemon for CCC (Windows)
# Polls the bridge for tasks, executes with Claude Code, reports results
#
# SAFE DESIGN:
# - No incoming connections (outbound polling only)
# - Credentials in environment variables
# - Never exposes a port
#

# ============================================
# CONFIGURATION
# ============================================
$env:SUPABASE_URL = if ($env:SUPABASE_URL) { $env:SUPABASE_URL } else { "https://vdbejzywxgqaebfedlyh.supabase.co" }
$env:SUPABASE_KEY = if ($env:SUPABASE_KEY) { $env:SUPABASE_KEY } else { "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZkYmVqenl3eGdxYWViZmVkbHloIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzIxNDY5MSwiZXhwIjoyMDc4NzkwNjkxfQ.2eCE03Q1Rnlaa_AAQFXuLcJZWkchd7-0X12jaqQabd4" }
$POLL_INTERVAL = if ($env:POLL_INTERVAL) { [int]$env:POLL_INTERVAL } else { 2 }
$AGENT_ID = if ($env:AGENT_ID) { $env:AGENT_ID } else { "computer_claude" }
$SYNAPSE_DIR = "$env:USERPROFILE\.synapse"
$LOG_FILE = "$SYNAPSE_DIR\watcher.log"

# Create directory if needed
if (!(Test-Path $SYNAPSE_DIR)) {
    New-Item -ItemType Directory -Path $SYNAPSE_DIR -Force | Out-Null
}

# ============================================
# LOGGING
# ============================================
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage
    Add-Content -Path $LOG_FILE -Value $logMessage
}

# ============================================
# API FUNCTIONS
# ============================================
$headers = @{
    "apikey" = $env:SUPABASE_KEY
    "Authorization" = "Bearer $($env:SUPABASE_KEY)"
    "Content-Type" = "application/json"
}

function Get-PendingTasks {
    try {
        $url = "$($env:SUPABASE_URL)/rest/v1/us_instructions?status=eq.pending&target=eq.$AGENT_ID&order=priority.asc,created_at.asc&limit=1"
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        return $response
    }
    catch {
        Write-Log "ERROR fetching tasks: $_"
        return $null
    }
}

function Set-TaskInProgress {
    param([string]$TaskId)
    try {
        $url = "$($env:SUPABASE_URL)/rest/v1/us_instructions?id=eq.$TaskId"
        $body = @{
            status = "in_progress"
            started_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            opened_by = $AGENT_ID
        } | ConvertTo-Json
        Invoke-RestMethod -Uri $url -Headers $headers -Method Patch -Body $body | Out-Null
    }
    catch {
        Write-Log "ERROR marking in_progress: $_"
    }
}

function Set-TaskComplete {
    param([string]$TaskId, [string]$Notes)
    try {
        $url = "$($env:SUPABASE_URL)/rest/v1/us_instructions?id=eq.$TaskId"
        # Truncate notes if too long
        if ($Notes.Length -gt 5000) { $Notes = $Notes.Substring(0, 5000) }
        $body = @{
            status = "completed"
            completed_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            completed_by = $AGENT_ID
            notes = $Notes
        } | ConvertTo-Json
        Invoke-RestMethod -Uri $url -Headers $headers -Method Patch -Body $body | Out-Null
    }
    catch {
        Write-Log "ERROR marking complete: $_"
    }
}

function Set-TaskFailed {
    param([string]$TaskId, [string]$Error)
    try {
        $url = "$($env:SUPABASE_URL)/rest/v1/us_instructions?id=eq.$TaskId"
        if ($Error.Length -gt 1000) { $Error = $Error.Substring(0, 1000) }
        $body = @{
            status = "failed"
            blocked_reason = $Error
        } | ConvertTo-Json
        Invoke-RestMethod -Uri $url -Headers $headers -Method Patch -Body $body | Out-Null
    }
    catch {
        Write-Log "ERROR marking failed: $_"
    }
}

function Add-ChangelogEntry {
    param([string]$TaskId, [string]$Action, [string]$Details)
    try {
        $url = "$($env:SUPABASE_URL)/rest/v1/us_changelog"
        if ($Details.Length -gt 2000) { $Details = $Details.Substring(0, 2000) }
        $body = @{
            instruction_id = $TaskId
            agent_id = $AGENT_ID
            action = $Action
            details = $Details
        } | ConvertTo-Json
        $changelogHeaders = $headers.Clone()
        $changelogHeaders["Prefer"] = "return=minimal"
        Invoke-RestMethod -Uri $url -Headers $changelogHeaders -Method Post -Body $body | Out-Null
    }
    catch {
        Write-Log "ERROR adding changelog: $_"
    }
}

# ============================================
# TASK EXECUTION
# ============================================
function Invoke-Task {
    param($Task)
    
    $taskId = $Task.id
    $title = $Task.title
    $description = $Task.description
    
    Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Log "📋 TASK: $title"
    Write-Log "🆔 ID: $taskId"
    Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Mark as in progress
    Set-TaskInProgress -TaskId $taskId
    Add-ChangelogEntry -TaskId $taskId -Action "started" -Details "Task picked up by Windows watcher daemon"
    
    # Build prompt for Claude Code
    $prompt = @"
You are CCC (Computer Claude Code), executing a task from the SYNAPSE bridge.

TASK: $title

DESCRIPTION:
$description

INSTRUCTIONS:
1. Execute this task to the best of your ability
2. If you need to write code, do it
3. If you need to run commands, do it
4. When done, summarize what you accomplished
5. If you cannot complete the task, explain why

Begin.
"@

    Write-Log "🚀 Executing with Claude Code..."
    
    $outputFile = "$env:TEMP\claude_output_$taskId.txt"
    $errorFile = "$env:TEMP\claude_error_$taskId.txt"
    
    try {
        # Run Claude Code
        $process = Start-Process -FilePath "claude" -ArgumentList "--print", "`"$prompt`"" -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outputFile -RedirectStandardError $errorFile
        
        if ($process.ExitCode -eq 0) {
            $output = Get-Content $outputFile -Raw -ErrorAction SilentlyContinue
            Write-Log "✅ Task completed successfully"
            Set-TaskComplete -TaskId $taskId -Notes $output
            Add-ChangelogEntry -TaskId $taskId -Action "completed" -Details "Task executed successfully"
        }
        else {
            $errorOutput = Get-Content $errorFile -Raw -ErrorAction SilentlyContinue
            Write-Log "❌ Task failed: $errorOutput"
            Set-TaskFailed -TaskId $taskId -Error $errorOutput
            Add-ChangelogEntry -TaskId $taskId -Action "failed" -Details "Error: $errorOutput"
        }
    }
    catch {
        Write-Log "❌ Exception: $_"
        Set-TaskFailed -TaskId $taskId -Error $_.ToString()
        Add-ChangelogEntry -TaskId $taskId -Action "failed" -Details "Exception: $_"
    }
    finally {
        # Cleanup
        Remove-Item $outputFile -ErrorAction SilentlyContinue
        Remove-Item $errorFile -ErrorAction SilentlyContinue
    }
}

# ============================================
# MAIN LOOP
# ============================================
function Start-Watcher {
    Write-Log "════════════════════════════════════════════════════"
    Write-Log "🌉 SYNAPSE Watcher Started (Windows)"
    Write-Log "   Agent: $AGENT_ID"
    Write-Log "   Bridge: $($env:SUPABASE_URL)"
    Write-Log "   Poll interval: ${POLL_INTERVAL}s"
    Write-Log "════════════════════════════════════════════════════"
    
    # Check if Claude Code is available
    try {
        $null = Get-Command claude -ErrorAction Stop
    }
    catch {
        Write-Log "ERROR: Claude Code CLI not found. Install it first."
        Write-Log "Visit: https://docs.anthropic.com/claude-code"
        exit 1
    }
    
    while ($true) {
        try {
            $tasks = Get-PendingTasks
            
            if ($tasks -and $tasks.Count -gt 0) {
                foreach ($task in $tasks) {
                    Invoke-Task -Task $task
                }
            }
        }
        catch {
            Write-Log "ERROR in main loop: $_"
        }
        
        Start-Sleep -Seconds $POLL_INTERVAL
    }
}

# ============================================
# RUN
# ============================================
Start-Watcher
