#!/usr/bin/env bash
#
# plist.sh — generates, loads (and removes) the Monitor LaunchAgent.
#
# It is called by install.sh, but can also be used directly:
#
#   MONITOR_BIN=/path/to/Monitor ./Scripts/plist.sh      # install/reload
#   ./Scripts/plist.sh --uninstall                       # remove the agent
#
# Environment variables (all with defaults):
#   MONITOR_LABEL  reverse-DNS label of the agent   (default: com.monitor.menubar)
#   MONITOR_BIN    path to the installed executable  (required when installing)

set -euo pipefail

LABEL="${MONITOR_LABEL:-com.monitor.menubar}"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST="$PLIST_DIR/$LABEL.plist"
DOMAIN="gui/$(id -u)"

# --- uninstall mode ---------------------------------------------------------
if [[ "${1:-}" == "--uninstall" ]]; then
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    echo "LaunchAgent removed: $LABEL"
    exit 0
fi

# --- binary validation ------------------------------------------------------
BIN="${MONITOR_BIN:-}"
if [[ -z "$BIN" ]]; then
    echo "error: set MONITOR_BIN to the executable path (or use install.sh)." >&2
    exit 1
fi
if [[ ! -x "$BIN" ]]; then
    echo "error: '$BIN' does not exist or is not executable." >&2
    exit 1
fi

# --- plist generation -------------------------------------------------------
mkdir -p "$PLIST_DIR"

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>

    <key>ProgramArguments</key>
    <array>
        <string>$BIN</string>
    </array>

    <!-- start at login -->
    <key>RunAtLoad</key>
    <true/>

    <!-- only restart on crash; the menu "Quit" exits cleanly and stays closed -->
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>

    <!-- UI app; avoids throttling applied to background processes -->
    <key>ProcessType</key>
    <string>Interactive</string>

    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/Monitor.out.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/Monitor.err.log</string>
</dict>
</plist>
EOF

echo "plist generated at: $PLIST"

# --- (re)load the agent -----------------------------------------------------
# bootout removes a previous version (if any) before bringing up the new one.
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl bootstrap "$DOMAIN" "$PLIST"
launchctl kickstart -k "$DOMAIN/$LABEL" 2>/dev/null || true

echo "LaunchAgent loaded: $LABEL"
