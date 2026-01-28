# SYNAPSE Watcher - Multi-Model Edition

Routes tasks to different LLMs based on task type.

## Supported Models

| Model | Command | Best For |
|-------|---------|----------|
| `claude` | Claude Code CLI | Coding, debugging, agentic work |
| `gpt4` | OpenAI API | Creative writing, marketing, nuance |
| `local` | Ollama | Private/sensitive data, offline |

## Routing Priority

1. **Explicit model** - Task specifies `context.model`
2. **Task type** - Task has `context.task_type`
3. **Keyword detection** - Scans title/description
4. **Default** - Falls back to Claude

## How to Specify Model

When creating a task, add `model` to the context:

```json
{
  "title": "Write a blog post about AI",
  "description": "...",
  "context": {
    "model": "gpt4"
  }
}
```

Or use task_type for automatic routing:

```json
{
  "title": "Refactor the auth module",
  "context": {
    "task_type": "code"
  }
}
```

## Task Types → Models

| task_type | Routes to |
|-----------|-----------|
| `code`, `coding`, `debug`, `refactor` | claude |
| `writing`, `creative`, `blog`, `marketing` | gpt4 |
| `private`, `sensitive`, `offline` | local |

## Keyword Detection

If no model/task_type specified, scans for keywords:

| Keywords | Routes to |
|----------|-----------|
| code, script, function, debug, python, javascript, api | claude |
| write, blog, article, creative, story, marketing, email | gpt4 |
| private, sensitive, secret, personal, offline | local |

## Setup

### Requirements

**Claude Code:**
```bash
# Must be installed and authenticated
claude --version
```

**GPT-4 (optional):**
```bash
export OPENAI_API_KEY="sk-..."
```

**Ollama (optional):**
```bash
# Install from ollama.ai, then:
ollama serve
ollama pull llama3
```

### Configuration

```bash
# Required
export SUPABASE_KEY="your-key"

# Optional
export OPENAI_API_KEY="sk-..."      # For GPT-4
export DEFAULT_MODEL="claude"        # Fallback model
export POLL_INTERVAL="2"             # Seconds between checks
```

## Example Tasks

**Coding task (→ Claude):**
```json
{
  "title": "Fix the authentication bug",
  "description": "Users are getting logged out randomly",
  "target": "computer_claude"
}
```

**Writing task (→ GPT-4):**
```json
{
  "title": "Write a blog post about our new feature",
  "description": "Announce the new dashboard to customers",
  "target": "computer_claude",
  "context": { "task_type": "writing" }
}
```

**Private task (→ Local):**
```json
{
  "title": "Analyze my personal finances",
  "description": "Review spending patterns",
  "target": "computer_claude",
  "context": { "model": "local" }
}
```

## Logs

The watcher logs which model handled each task:

```
[2026-01-28 14:30:00] 📋 TASK: Fix the auth bug
[2026-01-28 14:30:00] 🆔 ID: abc123
[2026-01-28 14:30:00] 🤖 MODEL: claude
[2026-01-28 14:30:00] 📍 Detected coding keywords → claude
[2026-01-28 14:30:05] ✅ Task completed successfully
```

## Adding More Models

Edit the `invoke_model` function to add new providers:

```bash
# In watcher.sh
invoke_gemini() {
  # Your Gemini API call here
}

# Add to switch statement
case "$model" in
  gemini) invoke_gemini "$prompt" ;;
  # ...
esac
```
