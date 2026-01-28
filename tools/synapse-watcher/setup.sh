#!/bin/bash
#
# SYNAPSE Watcher Setup Script
# Run this on CCC's machine to install the watcher daemon
#

set -e

echo "═══════════════════════════════════════════════════════"
echo "  SYNAPSE Watcher Setup"
echo "  Secure bridge polling for CCC"
echo "═══════════════════════════════════════════════════════"
echo ""

# Create directories
INSTALL_DIR="$HOME/.synapse"
mkdir -p "$INSTALL_DIR"

# Copy watcher script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/watcher.sh" "$INSTALL_DIR/watcher.sh"
chmod +x "$INSTALL_DIR/watcher.sh"

echo "✅ Watcher installed to $INSTALL_DIR/watcher.sh"

# Create environment file (user fills in)
if [ ! -f "$INSTALL_DIR/.env" ]; then
  cat > "$INSTALL_DIR/.env" << 'EOF'
# SYNAPSE Watcher Configuration
# Fill in your credentials below

# Supabase service role key (REQUIRED)
export SUPABASE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZkYmVqenl3eGdxYWViZmVkbHloIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzIxNDY5MSwiZXhwIjoyMDc4NzkwNjkxfQ.2eCE03Q1Rnlaa_AAQFXuLcJZWkchd7-0X12jaqQabd4"

# Supabase URL
export SUPABASE_URL="https://vdbejzywxgqaebfedlyh.supabase.co"

# Agent identifier
export AGENT_ID="computer_claude"

# How often to check for tasks (seconds)
export POLL_INTERVAL="2"

# Log file location
export LOG_FILE="$HOME/.synapse/watcher.log"
EOF
  echo "✅ Environment file created: $INSTALL_DIR/.env"
  echo "   ⚠️  Edit this file to add your credentials!"
else
  echo "✅ Environment file exists: $INSTALL_DIR/.env"
fi

# Create launcher script
cat > "$INSTALL_DIR/start.sh" << 'EOF'
#!/bin/bash
# Load environment and start watcher
source "$HOME/.synapse/.env"
"$HOME/.synapse/watcher.sh" start
EOF
chmod +x "$INSTALL_DIR/start.sh"

cat > "$INSTALL_DIR/stop.sh" << 'EOF'
#!/bin/bash
"$HOME/.synapse/watcher.sh" stop
EOF
chmod +x "$INSTALL_DIR/stop.sh"

echo "✅ Launcher scripts created"

# Create launchd plist for macOS (auto-start on boot)
if [[ "$OSTYPE" == "darwin"* ]]; then
  PLIST_PATH="$HOME/Library/LaunchAgents/com.synapse.watcher.plist"
  cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.synapse.watcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>${HOME}/.synapse/start.sh</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>KeepAlive</key>
    <false/>
    <key>StandardOutPath</key>
    <string>${HOME}/.synapse/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.synapse/launchd.error.log</string>
</dict>
</plist>
EOF
  echo "✅ macOS LaunchAgent created: $PLIST_PATH"
  echo ""
  echo "   To enable auto-start on boot:"
  echo "   launchctl load $PLIST_PATH"
  echo ""
  echo "   To disable auto-start:"
  echo "   launchctl unload $PLIST_PATH"
fi

# Create systemd service for Linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  SERVICE_PATH="$HOME/.config/systemd/user/synapse-watcher.service"
  mkdir -p "$(dirname "$SERVICE_PATH")"
  cat > "$SERVICE_PATH" << EOF
[Unit]
Description=SYNAPSE Bridge Watcher
After=network.target

[Service]
Type=simple
ExecStart=${HOME}/.synapse/start.sh
ExecStop=${HOME}/.synapse/stop.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF
  echo "✅ Linux systemd service created: $SERVICE_PATH"
  echo ""
  echo "   To enable auto-start on boot:"
  echo "   systemctl --user enable synapse-watcher"
  echo "   systemctl --user start synapse-watcher"
  echo ""
  echo "   To check status:"
  echo "   systemctl --user status synapse-watcher"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Setup Complete!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  USAGE:"
echo ""
echo "  1. Start watcher:"
echo "     ~/.synapse/start.sh"
echo ""
echo "  2. Stop watcher:"
echo "     ~/.synapse/stop.sh"
echo ""
echo "  3. Check status:"
echo "     ~/.synapse/watcher.sh status"
echo ""
echo "  4. View logs:"
echo "     ~/.synapse/watcher.sh logs"
echo ""
echo "  SECURITY NOTES:"
echo "  • Credentials stored in ~/.synapse/.env (chmod 600 recommended)"
echo "  • No ports exposed - outbound polling only"
echo "  • Logs stored locally in ~/.synapse/"
echo ""
echo "═══════════════════════════════════════════════════════"
