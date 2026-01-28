#
# SYNAPSE Watcher Daemon for CCC (Windows) - Multi-Model Edition
# Polls the bridge for tasks, routes to appropriate LLM, reports results
#
# SUPPORTED MODELS:
# - claude (default) - Claude Code CLI
# - gpt4 - OpenAI GPT-4 API
# - local - Ollama local LLM
#
# ROUTING PRIORITY:
# 1. Task specifies model in context.model → Use that
# 2. Task has task_type in context → Rules-based routing
# 3. Default → Claude
#

# ============================================
# CONFIGURATION
# ============================================
$env:SUPABASE_URL = if ($env:SUPABASE_URL) { $env:SUPABASE_URL } else { "https://vdbejzywxgqaebfedlyh.supabase.co" }
$env:SUPABASE_KEY = if ($env:SUPABASE_KEY) { $env:SUPABASE_KEY } else { "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZkYmVqenl3eGdxYWViZmVkbHloIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzIxNDY5MSwiZXhwIjoyMDc4NzkwNjkxfQ.2eCE03Q1Rnlaa_AAQFXuLcJZWkchd7-0X12jaqQabd4" }

# API Keys for different models
$env:OPENAI_API_KEY = if ($env:OPENAI_API_KEY) { $env:OPENAI_API_KEY } else { "" }  # Set this for GPT-4

$POLL_INTERVAL = if ($env:POLL_INTERVAL) { [int]$env:POLL_INTERVAL } else { 2 }
$AGENT_ID = if ($env:AGENT_ID) { $env:AGENT_ID } else { "computer_claude" }
$DEFAULT_MODEL = if ($env:DEFAULT_MODEL) { $env:DEFAULT_MODEL } else { "claude" }
$SYNAPSE_DIR = "$env:USERPROFILE\.synapse"
$LOG_FILE = "$SYNAPSE_DIR\watcher.log"

# Create directory if needed
if (!(Test-Path $SYNAPSE_DIR)) {
    New-Item -ItemType Directory -Path $SYNAPSE_DIR -Force | Out-Null
}

# ============================================
# MODEL ROUTING RULES
# ============================================
$ROUTING_RULES = @{
    # task_type → model
    "code" = "claude"
    "coding" = "claude"
    "debug" = "claude"
    "refactor" = "claude"
    "writing" = "gpt4"
    "creative" = "gpt4"
    "blog" = "gpt4"
    "marketing" = "gpt4"
    "private" = "local"
    "sensitive" = "local"
    "offline" = "local"
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
# API FUNCTIONS (Supabase)
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
    param([string]$TaskId, [string]$Model)
    try {
        $url = "$($env:SUPABASE_URL)/rest/v1/us_instructions?id=eq.$TaskId"
        $body = @{
            status = "in_progress"
            started_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            opened_by = "$AGENT_ID`:$Model"
        } | ConvertTo-Json
        Invoke-RestMethod -Uri $url -Headers $headers -Method Patch -Body $body | Out-Null
    }
    catch {
        Write-Log "ERROR marking in_progress: $_"
    }
}

function Set-TaskComplete {
    param([string]$TaskId, [string]$Notes, [string]$Model)
    try {
        $url = "$($env:SUPABASE_URL)/rest/v1/us_instructions?id=eq.$TaskId"
        if ($Notes.Length -gt 5000) { $Notes = $Notes.Substring(0, 5000) }
        $body = @{
            status = "completed"
            completed_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            completed_by = "$AGENT_ID`:$Model"
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
# MODEL ROUTING
# ============================================
function Get-ModelForTask {
    param($Task)
    
    # Priority 1: Explicit model in context
    if ($Task.context -and $Task.context.model) {
        Write-Log "📍 Using explicit model from task: $($Task.context.model)"
        return $Task.context.model
    }
    
    # Priority 2: Task type routing
    if ($Task.context -and $Task.context.task_type) {
        $taskType = $Task.context.task_type.ToLower()
        if ($ROUTING_RULES.ContainsKey($taskType)) {
            $model = $ROUTING_RULES[$taskType]
            Write-Log "📍 Routing by task_type '$taskType' → $model"
            return $model
        }
    }
    
    # Priority 3: Keyword detection in title/description
    $text = "$($Task.title) $($Task.description)".ToLower()
    
    if ($text -match "code|script|function|debug|refactor|python|javascript|api") {
        Write-Log "📍 Detected coding keywords → claude"
        return "claude"
    }
    if ($text -match "write|blog|article|creative|story|marketing|email") {
        Write-Log "📍 Detected writing keywords → gpt4"
        return "gpt4"
    }
    if ($text -match "private|sensitive|secret|personal|offline") {
        Write-Log "📍 Detected privacy keywords → local"
        return "local"
    }
    
    # Priority 4: Default
    Write-Log "📍 Using default model: $DEFAULT_MODEL"
    return $DEFAULT_MODEL
}

# ============================================
# MODEL EXECUTORS
# ============================================
function Invoke-Claude {
    param([string]$Prompt)
    
    $outputFile = "$env:TEMP\claude_output_$(Get-Random).txt"
    $errorFile = "$env:TEMP\claude_error_$(Get-Random).txt"
    
    try {
        $process = Start-Process -FilePath "claude" -ArgumentList "--print", "`"$Prompt`"" -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outputFile -RedirectStandardError $errorFile
        
        if ($process.ExitCode -eq 0) {
            $output = Get-Content $outputFile -Raw -ErrorAction SilentlyContinue
            return @{ success = $true; output = $output }
        }
        else {
            $error = Get-Content $errorFile -Raw -ErrorAction SilentlyContinue
            return @{ success = $false; error = $error }
        }
    }
    finally {
        Remove-Item $outputFile -ErrorAction SilentlyContinue
        Remove-Item $errorFile -ErrorAction SilentlyContinue
    }
}

function Invoke-GPT4 {
    param([string]$Prompt)
    
    if (-not $env:OPENAI_API_KEY) {
        return @{ success = $false; error = "OPENAI_API_KEY not set" }
    }
    
    try {
        $body = @{
            model = "gpt-4-turbo-preview"
            messages = @(
                @{ role = "system"; content = "You are a helpful assistant executing tasks." }
                @{ role = "user"; content = $Prompt }
            )
            max_tokens = 4096
        } | ConvertTo-Json -Depth 10
        
        $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/chat/completions" `
            -Method Post `
            -Headers @{ "Authorization" = "Bearer $($env:OPENAI_API_KEY)"; "Content-Type" = "application/json" } `
            -Body $body
        
        $output = $response.choices[0].message.content
        return @{ success = $true; output = $output }
    }
    catch {
        return @{ success = $false; error = $_.ToString() }
    }
}

function Invoke-LocalLLM {
    param([string]$Prompt)
    
    # Using Ollama - make sure it's running: ollama serve
    try {
        $body = @{
            model = "llama3"  # or whatever model you have
            prompt = $Prompt
            stream = $false
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/generate" `
            -Method Post `
            -Headers @{ "Content-Type" = "application/json" } `
            -Body $body
        
        return @{ success = $true; output = $response.response }
    }
    catch {
        return @{ success = $false; error = "Local LLM error: $_. Is Ollama running?" }
    }
}

function Invoke-Model {
    param([string]$Model, [string]$Prompt)
    
    switch ($Model.ToLower()) {
        "claude" { return Invoke-Claude -Prompt $Prompt }
        "gpt4" { return Invoke-GPT4 -Prompt $Prompt }
        "gpt-4" { return Invoke-GPT4 -Prompt $Prompt }
        "openai" { return Invoke-GPT4 -Prompt $Prompt }
        "local" { return Invoke-LocalLLM -Prompt $Prompt }
        "ollama" { return Invoke-LocalLLM -Prompt $Prompt }
        "llama" { return Invoke-LocalLLM -Prompt $Prompt }
        default { 
            Write-Log "⚠️ Unknown model '$Model', falling back to Claude"
            return Invoke-Claude -Prompt $Prompt 
        }
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
    
    # Determine which model to use
    $model = Get-ModelForTask -Task $Task
    
    Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    Write-Log "📋 TASK: $title"
    Write-Log "🆔 ID: $taskId"
    Write-Log "🤖 MODEL: $model"
    Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Mark as in progress
    Set-TaskInProgress -TaskId $taskId -Model $model
    Add-ChangelogEntry -TaskId $taskId -Action "started" -Details "Task picked up by watcher, routing to $model"
    
    # Build prompt
    $prompt = @"
You are executing a task from the SYNAPSE bridge.

TASK: $title

DESCRIPTION:
$description

INSTRUCTIONS:
1. Execute this task to the best of your ability
2. When done, summarize what you accomplished
3. If you cannot complete the task, explain why

Begin.
"@

    Write-Log "🚀 Executing with $model..."
    
    $result = Invoke-Model -Model $model -Prompt $prompt
    
    if ($result.success) {
        Write-Log "✅ Task completed successfully"
        Set-TaskComplete -TaskId $taskId -Notes $result.output -Model $model
        Add-ChangelogEntry -TaskId $taskId -Action "completed" -Details "Completed by $model"
    }
    else {
        Write-Log "❌ Task failed: $($result.error)"
        Set-TaskFailed -TaskId $taskId -Error $result.error
        Add-ChangelogEntry -TaskId $taskId -Action "failed" -Details "Error from $model`: $($result.error)"
    }
}

# ============================================
# MAIN LOOP
# ============================================
function Start-Watcher {
    Write-Log "════════════════════════════════════════════════════"
    Write-Log "🌉 SYNAPSE Watcher Started (Multi-Model Edition)"
    Write-Log "   Agent: $AGENT_ID"
    Write-Log "   Bridge: $($env:SUPABASE_URL)"
    Write-Log "   Poll interval: ${POLL_INTERVAL}s"
    Write-Log "   Default model: $DEFAULT_MODEL"
    Write-Log "════════════════════════════════════════════════════"
    
    # Check available models
    Write-Log "🔍 Checking available models..."
    
    try { 
        $null = Get-Command claude -ErrorAction Stop
        Write-Log "   ✅ Claude Code: Available"
    } catch { 
        Write-Log "   ❌ Claude Code: Not found" 
    }
    
    if ($env:OPENAI_API_KEY) {
        Write-Log "   ✅ GPT-4: API key configured"
    } else {
        Write-Log "   ⚠️ GPT-4: No API key (set OPENAI_API_KEY)"
    }
    
    try {
        $null = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -TimeoutSec 2
        Write-Log "   ✅ Ollama: Running"
    } catch {
        Write-Log "   ⚠️ Ollama: Not running (start with 'ollama serve')"
    }
    
    Write-Log "════════════════════════════════════════════════════"
    
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
