# SYNAPSE Watcher for CCC

A secure daemon that polls the SYNAPSE bridge for tasks and executes them with Claude Code.

## Why This Is Safe (vs Clawdbot)

| Clawdbot | SYNAPSE Watcher |
|----------|-----------------|
| Opens port, listens for connections | No ports exposed |
| Gateway can be found on Shodan | Nothing to find |
| Anyone who connects can send commands | Only you can write to bridge |
| Credentials in plaintext files | Credentials in env vars |
| Full attack surface | Outbound polling only |

```
CLAWDBOT (dangerous):
Internet → Gateway (exposed) → Claude Code

SYNAPSE (safe):
Claude Code → polls → Supabase (authenticated) ← You write tasks
```

## Installation

### On CCC's machine (your Mac):

```bash
# Clone or copy the synapse-watcher folder
cd synapse-watcher

# Run setup
chmod +x setup.sh
./setup.sh

# Edit credentials (already filled in for you)
nano ~/.synapse/.env

# Secure the credentials file
chmod 600 ~/.synapse/.env

# Start the watcher
~/.synapse/start.sh
```

## Usage

### Start/Stop
```bash
~/.synapse/start.sh    # Start watching
~/.synapse/stop.sh     # Stop watching
```

### Check Status
```bash
~/.synapse/watcher.sh status
```

### View Logs
```bash
~/.synapse/watcher.sh logs
# Or
tail -f ~/.synapse/watcher.log
```

### Auto-Start on Boot

**macOS:**
```bash
launchctl load ~/Library/LaunchAgents/com.synapse.watcher.plist
```

**Linux:**
```bash
systemctl --user enable synapse-watcher
systemctl --user start synapse-watcher
```

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    YOUR WORKFLOW                            │
└─────────────────────────────────────────────────────────────┘

1. You're out, on your phone
   │
   ▼
2. Open Claude.ai, say:
   "Tell CCC to refactor the auth module"
   │
   ▼
3. I (Phone Claude) write task to Supabase bridge:
   INSERT INTO us_instructions (target, title, description)
   VALUES ('computer_claude', 'Refactor auth', '...')
   │
   ▼
4. CCC's watcher polls every 30 seconds:
   "Any tasks for me?"
   │
   ▼
5. Watcher finds task, spawns Claude Code:
   claude --print "Execute this task: ..."
   │
   ▼
6. Claude Code does the work on your Mac
   │
   ▼
7. Watcher marks task complete, logs result
   │
   ▼
8. You check in later, see the work done
```

## Sending Tasks to CCC

From Claude.ai (me), I can send tasks like this:

```bash
curl -X POST "https://vdbejzywxgqaebfedlyh.supabase.co/rest/v1/us_instructions" \
  -H "apikey: YOUR_KEY" \
  -H "Authorization: Bearer YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "source": "phone_claude",
    "target": "computer_claude",
    "status": "pending",
    "priority": 3,
    "title": "Your task title",
    "description": "Detailed instructions..."
  }'
```

Or just tell me in natural language:
> "Send a task to CCC to run the test suite and fix any failures"

I'll create the bridge entry automatically.

## Configuration

Edit `~/.synapse/.env`:

```bash
# Required
export SUPABASE_KEY="your-service-role-key"
export SUPABASE_URL="https://your-project.supabase.co"

# Optional
export AGENT_ID="computer_claude"    # Identifier for this agent
export POLL_INTERVAL="30"            # Seconds between checks
export LOG_FILE="~/.synapse/watcher.log"
```

## Security Best Practices

1. **Protect the .env file:**
   ```bash
   chmod 600 ~/.synapse/.env
   ```

2. **Don't commit credentials:**
   - `.env` is gitignored by default
   - Never put keys in the watcher.sh script

3. **Use a dedicated machine:**
   - Ideally run on a Mac Mini or dedicated dev machine
   - Not your primary laptop with sensitive data

4. **Review the logs:**
   ```bash
   ~/.synapse/watcher.sh logs
   ```

5. **Rotate keys periodically:**
   - If you suspect compromise, rotate the Supabase key
   - Update ~/.synapse/.env with new key

## Troubleshooting

**Watcher won't start:**
```bash
# Check if already running
~/.synapse/watcher.sh status

# Check logs
cat ~/.synapse/watcher.log
```

**Claude Code not found:**
```bash
# Make sure Claude Code CLI is installed
which claude

# If not, install it
# (follow Anthropic's installation guide)
```

**Tasks not being picked up:**
```bash
# Check bridge directly
curl "https://vdbejzywxgqaebfedlyh.supabase.co/rest/v1/us_instructions?status=eq.pending" \
  -H "apikey: YOUR_KEY"

# Make sure target matches AGENT_ID
# Default is "computer_claude"
```

## Files

```
~/.synapse/
├── .env              # Credentials (KEEP SECURE)
├── watcher.sh        # Main daemon script
├── start.sh          # Launcher
├── stop.sh           # Stop script
├── watcher.log       # Activity log
└── watcher.pid       # Process ID file
```

## License

MIT - Do whatever you want with it.
