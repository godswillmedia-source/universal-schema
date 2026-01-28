#!/bin/bash
#
# SYNAPSE Watcher Daemon for CCC
# Polls the bridge for tasks, executes with Claude Code, reports results
#
# SAFE DESIGN:
# - No incoming connections (outbound polling only)
# - Credentials in environment variables
# - Never exposes a port
#

set -e

# ============================================
# CONFIGURATION (set these as env vars)
# ============================================
SUPABASE_URL="${SUPABASE_URL:-https://vdbejzywxgqaebfedlyh.supabase.co}"
SUPABASE_KEY="${SUPABASE_KEY}"  # Service role key - MUST be set
POLL_INTERVAL="${POLL_INTERVAL:-2}"  # seconds between checks
AGENT_ID="${AGENT_ID:-computer_claude}"
LOG_FILE="${LOG_FILE:-$HOME/.synapse/watcher.log}"
PID_FILE="${PID_FILE:-$HOME/.synapse/watcher.pid}"

# ============================================
# SETUP
# ============================================
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$PID_FILE")"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check required env vars
if [ -z "$SUPABASE_KEY" ]; then
  echo "ERROR: SUPABASE_KEY environment variable not set"
  echo "Export it before running: export SUPABASE_KEY='your-service-role-key'"
  exit 1
fi

# Check if Claude Code is available
if ! command -v claude &> /dev/null; then
  echo "ERROR: Claude Code CLI not found. Install it first."
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
  curl -s -X PATCH "${SUPABASE_URL}/rest/v1/us_instructions?id=eq.${task_id}" \
    "${api_headers[@]}" \
    -d "{\"status\": \"in_progress\", \"started_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"opened_by\": \"${AGENT_ID}\"}"
}

mark_complete() {
  local task_id="$1"
  local notes="$2"
  # Escape quotes in notes for JSON
  notes=$(echo "$notes" | sed 's/"/\\"/g' | head -c 5000)
  curl -s -X PATCH "${SUPABASE_URL}/rest/v1/us_instructions?id=eq.${task_id}" \
    "${api_headers[@]}" \
    -d "{\"status\": \"completed\", \"completed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\", \"completed_by\": \"${AGENT_ID}\", \"notes\": \"${notes}\"}"
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
# TASK EXECUTION
# ============================================
execute_task() {
  local task_json="$1"
  
  # Parse task
  local task_id=$(echo "$task_json" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])" 2>/dev/null)
  local title=$(echo "$task_json" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['title'])" 2>/dev/null)
  local description=$(echo "$task_json" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['description'])" 2>/dev/null)
  local requires_local=$(echo "$task_json" | python3 -c "import sys,json; print(json.load(sys.stdin)[0].get('requires_local', False))" 2>/dev/null)
  
  if [ -z "$task_id" ]; then
    log "ERROR: Could not parse task ID"
    return 1
  fi
  
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "📋 TASK: $title"
  log "🆔 ID: $task_id"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # Mark as in progress
  mark_in_progress "$task_id"
  log_to_changelog "$task_id" "started" "Task picked up by watcher daemon"
  
  # Build prompt for Claude Code
  local prompt="You are CCC (Computer Claude Code), executing a task from the SYNAPSE bridge.

TASK: $title

DESCRIPTION:
$description

INSTRUCTIONS:
1. Execute this task to the best of your ability
2. If you need to write code, do it
3. If you need to run commands, do it
4. When done, summarize what you accomplished
5. If you cannot complete the task, explain why

Begin."

  # Execute with Claude Code
  log "🚀 Executing with Claude Code..."
  local output_file="/tmp/claude_output_${task_id}.txt"
  local error_file="/tmp/claude_error_${task_id}.txt"
  
  # Run Claude Code with timeout (30 minutes max)
  if timeout 1800 claude --print "$prompt" > "$output_file" 2> "$error_file"; then
    local output=$(cat "$output_file")
    log "✅ Task completed successfully"
    mark_complete "$task_id" "$output"
    log_to_changelog "$task_id" "completed" "Task executed successfully"
  else
    local error=$(cat "$error_file")
    log "❌ Task failed: $error"
    mark_failed "$task_id" "$error"
    log_to_changelog "$task_id" "failed" "Error: $error"
  fi
  
  # Cleanup
  rm -f "$output_file" "$error_file"
}

# ============================================
# MAIN LOOP
# ============================================
main() {
  # Save PID
  echo $$ > "$PID_FILE"
  
  log "════════════════════════════════════════════════════"
  log "🌉 SYNAPSE Watcher Started"
  log "   Agent: $AGENT_ID"
  log "   Bridge: $SUPABASE_URL"
  log "   Poll interval: ${POLL_INTERVAL}s"
  log "   PID: $$"
  log "════════════════════════════════════════════════════"
  
  # Trap for clean shutdown
  trap 'log "🛑 Watcher stopped"; rm -f "$PID_FILE"; exit 0' SIGTERM SIGINT
  
  while true; do
    # Check for pending tasks
    local tasks=$(get_pending_tasks)
    
    # Check if we got a valid response with tasks
    if echo "$tasks" | python3 -c "import sys,json; data=json.load(sys.stdin); exit(0 if len(data) > 0 else 1)" 2>/dev/null; then
      execute_task "$tasks"
    fi
    
    # Wait before next poll
    sleep "$POLL_INTERVAL"
  done
}

# ============================================
# COMMAND HANDLING
# ============================================
case "${1:-start}" in
  start)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "Watcher already running (PID: $(cat "$PID_FILE"))"
      exit 1
    fi
    main
    ;;
  stop)
    if [ -f "$PID_FILE" ]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
      rm -f "$PID_FILE"
      echo "Watcher stopped"
    else
      echo "Watcher not running"
    fi
    ;;
  status)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "Watcher running (PID: $(cat "$PID_FILE"))"
    else
      echo "Watcher not running"
    fi
    ;;
  logs)
    tail -f "$LOG_FILE"
    ;;
  *)
    echo "Usage: $0 {start|stop|status|logs}"
    exit 1
    ;;
esac
