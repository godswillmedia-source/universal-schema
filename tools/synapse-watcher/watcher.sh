#!/bin/bash
#
# SYNAPSE Watcher Daemon - Multi-Model Edition
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
# 3. Keyword detection in title/description
# 4. Default → Claude
#

set -e

# ============================================
# CONFIGURATION
# ============================================
SUPABASE_URL="${SUPABASE_URL:-https://vdbejzywxgqaebfedlyh.supabase.co}"
SUPABASE_KEY="${SUPABASE_KEY}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"  # Set for GPT-4 support
POLL_INTERVAL="${POLL_INTERVAL:-2}"
AGENT_ID="${AGENT_ID:-computer_claude}"
DEFAULT_MODEL="${DEFAULT_MODEL:-claude}"
LOG_FILE="${LOG_FILE:-$HOME/.synapse/watcher.log}"
PID_FILE="${PID_FILE:-$HOME/.synapse/watcher.pid}"

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$PID_FILE")"

# ============================================
# LOGGING
# ============================================
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check required env vars
if [ -z "$SUPABASE_KEY" ]; then
  echo "ERROR: SUPABASE_KEY environment variable not set"
  exit 1
fi

# ============================================
# API FUNCTIONS
# ============================================
api_headers=(
  -H "apikey: $SUPABASE_KEY"
  -H "Authorization: Bearer $SUPABASE_KEY"
  -H "Content-Type: application/json"
)

get_pending_tasks() {
  curl -s "${SUPABASE_URL}/rest/v1/us_instructions?status=eq.pending&target=eq.${AGENT_ID}&order=priority.asc,created_at.asc&limit=1" \
    "${api_headers[@]}"
}

mark_in_progress() {
  local task_id="$1"
  local model="$2"
  curl -s -X PATCH "${SUPABASE_URL}/rest/v1/us_instructions?id=eq.${task_id}" \
    "${api_headers[@]}" \
    -d "{\"status\": \"in_progress\", \"started_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"opened_by\": \"${AGENT_ID}:${model}\"}"
}

mark_complete() {
  local task_id="$1"
  local notes="$2"
  local model="$3"
  notes=$(echo "$notes" | sed 's/"/\\"/g' | sed 's/\\/\\\\/g' | head -c 5000 | tr '\n' ' ')
  curl -s -X PATCH "${SUPABASE_URL}/rest/v1/us_instructions?id=eq.${task_id}" \
    "${api_headers[@]}" \
    -d "{\"status\": \"completed\", \"completed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"completed_by\": \"${AGENT_ID}:${model}\", \"notes\": \"${notes}\"}"
}

mark_failed() {
  local task_id="$1"
  local error="$2"
  error=$(echo "$error" | sed 's/"/\\"/g' | head -c 1000)
  curl -s -X PATCH "${SUPABASE_URL}/rest/v1/us_instructions?id=eq.${task_id}" \
    "${api_headers[@]}" \
    -d "{\"status\": \"failed\", \"blocked_reason\": \"${error}\"}"
}

log_to_changelog() {
  local task_id="$1"
  local action="$2"
  local details="$3"
  details=$(echo "$details" | sed 's/"/\\"/g' | head -c 2000)
  curl -s -X POST "${SUPABASE_URL}/rest/v1/us_changelog" \
    "${api_headers[@]}" \
    -H "Prefer: return=minimal" \
    -d "{\"instruction_id\": \"${task_id}\", \"agent_id\": \"${AGENT_ID}\", \"action\": \"${action}\", \"details\": \"${details}\"}"
}

# ============================================
# MODEL ROUTING
# ============================================
get_model_for_task() {
  local task_json="$1"
  
  # Priority 1: Explicit model in context
  local explicit_model=$(echo "$task_json" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list): data = data[0]
    ctx = data.get('context', {}) or {}
    print(ctx.get('model', ''))
except: pass
" 2>/dev/null)
  
  if [ -n "$explicit_model" ]; then
    log "📍 Using explicit model from task: $explicit_model"
    echo "$explicit_model"
    return
  fi
  
  # Priority 2: Task type routing
  local task_type=$(echo "$task_json" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list): data = data[0]
    ctx = data.get('context', {}) or {}
    print(ctx.get('task_type', '').lower())
except: pass
" 2>/dev/null)
  
  case "$task_type" in
    code|coding|debug|refactor)
      log "📍 Routing by task_type '$task_type' → claude"
      echo "claude"
      return
      ;;
    writing|creative|blog|marketing)
      log "📍 Routing by task_type '$task_type' → gpt4"
      echo "gpt4"
      return
      ;;
    private|sensitive|offline)
      log "📍 Routing by task_type '$task_type' → local"
      echo "local"
      return
      ;;
  esac
  
  # Priority 3: Keyword detection
  local text=$(echo "$task_json" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if isinstance(data, list): data = data[0]
    print((data.get('title', '') + ' ' + data.get('description', '')).lower())
except: pass
" 2>/dev/null)
  
  if echo "$text" | grep -qiE "code|script|function|debug|refactor|python|javascript|api"; then
    log "📍 Detected coding keywords → claude"
    echo "claude"
    return
  fi
  
  if echo "$text" | grep -qiE "write|blog|article|creative|story|marketing|email"; then
    log "📍 Detected writing keywords → gpt4"
    echo "gpt4"
    return
  fi
  
  if echo "$text" | grep -qiE "private|sensitive|secret|personal|offline"; then
    log "📍 Detected privacy keywords → local"
    echo "local"
    return
  fi
  
  # Priority 4: Default
  log "📍 Using default model: $DEFAULT_MODEL"
  echo "$DEFAULT_MODEL"
}

# ============================================
# MODEL EXECUTORS
# ============================================
invoke_claude() {
  local prompt="$1"
  local output_file="/tmp/claude_output_$$.txt"
  local error_file="/tmp/claude_error_$$.txt"
  
  if timeout 1800 claude --print "$prompt" > "$output_file" 2> "$error_file"; then
    cat "$output_file"
    rm -f "$output_file" "$error_file"
    return 0
  else
    cat "$error_file" >&2
    rm -f "$output_file" "$error_file"
    return 1
  fi
}

invoke_gpt4() {
  local prompt="$1"
  
  if [ -z "$OPENAI_API_KEY" ]; then
    echo "ERROR: OPENAI_API_KEY not set" >&2
    return 1
  fi
  
  local escaped_prompt=$(echo "$prompt" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  
  local response=$(curl -s "https://api.openai.com/v1/chat/completions" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"gpt-4-turbo-preview\",
      \"messages\": [
        {\"role\": \"system\", \"content\": \"You are a helpful assistant executing tasks.\"},
        {\"role\": \"user\", \"content\": $escaped_prompt}
      ],
      \"max_tokens\": 4096
    }")
  
  local output=$(echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'])
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null)
  
  if [ $? -eq 0 ]; then
    echo "$output"
    return 0
  else
    echo "GPT-4 API error" >&2
    return 1
  fi
}

invoke_local() {
  local prompt="$1"
  
  local escaped_prompt=$(echo "$prompt" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
  
  local response=$(curl -s "http://localhost:11434/api/generate" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"llama3\",
      \"prompt\": $escaped_prompt,
      \"stream\": false
    }" 2>/dev/null)
  
  if [ $? -eq 0 ]; then
    echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('response', ''))" 2>/dev/null
    return 0
  else
    echo "Local LLM error - is Ollama running?" >&2
    return 1
  fi
}

invoke_model() {
  local model="$1"
  local prompt="$2"
  
  case "$model" in
    claude)
      invoke_claude "$prompt"
      ;;
    gpt4|gpt-4|openai)
      invoke_gpt4 "$prompt"
      ;;
    local|ollama|llama)
      invoke_local "$prompt"
      ;;
    *)
      log "⚠️ Unknown model '$model', falling back to Claude"
      invoke_claude "$prompt"
      ;;
  esac
}

# ============================================
# TASK EXECUTION
# ============================================
execute_task() {
  local task_json="$1"
  
  local task_id=$(echo "$task_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['id'] if isinstance(d,list) else d['id'])" 2>/dev/null)
  local title=$(echo "$task_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['title'] if isinstance(d,list) else d['title'])" 2>/dev/null)
  local description=$(echo "$task_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['description'] if isinstance(d,list) else d['description'])" 2>/dev/null)
  
  if [ -z "$task_id" ]; then
    log "ERROR: Could not parse task ID"
    return 1
  fi
  
  # Determine model
  local model=$(get_model_for_task "$task_json")
  
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "📋 TASK: $title"
  log "🆔 ID: $task_id"
  log "🤖 MODEL: $model"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  mark_in_progress "$task_id" "$model"
  log_to_changelog "$task_id" "started" "Task picked up, routing to $model"
  
  local prompt="You are executing a task from the SYNAPSE bridge.

TASK: $title

DESCRIPTION:
$description

INSTRUCTIONS:
1. Execute this task to the best of your ability
2. When done, summarize what you accomplished
3. If you cannot complete the task, explain why

Begin."

  log "🚀 Executing with $model..."
  
  local output
  if output=$(invoke_model "$model" "$prompt" 2>&1); then
    log "✅ Task completed successfully"
    mark_complete "$task_id" "$output" "$model"
    log_to_changelog "$task_id" "completed" "Completed by $model"
  else
    log "❌ Task failed: $output"
    mark_failed "$task_id" "$output"
    log_to_changelog "$task_id" "failed" "Error from $model: $output"
  fi
}

# ============================================
# MAIN
# ============================================
main() {
  echo $$ > "$PID_FILE"
  
  log "════════════════════════════════════════════════════"
  log "🌉 SYNAPSE Watcher Started (Multi-Model Edition)"
  log "   Agent: $AGENT_ID"
  log "   Bridge: $SUPABASE_URL"
  log "   Poll interval: ${POLL_INTERVAL}s"
  log "   Default model: $DEFAULT_MODEL"
  log "════════════════════════════════════════════════════"
  
  # Check available models
  log "🔍 Checking available models..."
  command -v claude &>/dev/null && log "   ✅ Claude Code: Available" || log "   ❌ Claude Code: Not found"
  [ -n "$OPENAI_API_KEY" ] && log "   ✅ GPT-4: API key configured" || log "   ⚠️ GPT-4: No API key"
  curl -s "http://localhost:11434/api/tags" &>/dev/null && log "   ✅ Ollama: Running" || log "   ⚠️ Ollama: Not running"
  log "════════════════════════════════════════════════════"
  
  trap 'log "🛑 Watcher stopped"; rm -f "$PID_FILE"; exit 0' SIGTERM SIGINT
  
  while true; do
    local tasks=$(get_pending_tasks)
    
    if echo "$tasks" | python3 -c "import sys,json; data=json.load(sys.stdin); exit(0 if len(data) > 0 else 1)" 2>/dev/null; then
      execute_task "$tasks"
    fi
    
    sleep "$POLL_INTERVAL"
  done
}

case "${1:-start}" in
  start) main ;;
  stop) [ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null; rm -f "$PID_FILE"; echo "Stopped" ;;
  status) [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null && echo "Running (PID: $(cat "$PID_FILE"))" || echo "Not running" ;;
  logs) tail -f "$LOG_FILE" ;;
  *) echo "Usage: $0 {start|stop|status|logs}" ;;
esac
