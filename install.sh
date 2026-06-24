#!/usr/bin/env bash
#
# install.sh — builds Monitor in release, installs the binary to a stable
# location and registers the LaunchAgent to start at login (via Scripts/plist.sh).
#
# Usage:
#   ./install.sh              install (or update) Monitor
#   ./install.sh --uninstall  remove the LaunchAgent and the installed binary

set -euo pipefail

# project root = folder where this script lives
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

LABEL="com.monitor.menubar"
INSTALL_DIR="$HOME/.local/bin"
BIN="$INSTALL_DIR/Monitor"

# --- uninstall mode ---------------------------------------------------------
if [[ "${1:-}" == "--uninstall" ]]; then
    MONITOR_LABEL="$LABEL" "$ROOT/Scripts/plist.sh" --uninstall
    rm -f "$BIN"
    echo "✅ Monitor uninstalled."
    exit 0
fi

# --- build ------------------------------------------------------------------
echo "==> Building (release)..."
swift build -c release

# --- install the binary -----------------------------------------------------
echo "==> Installing binary to $BIN"
mkdir -p "$INSTALL_DIR"
cp -f "$ROOT/.build/release/Monitor" "$BIN"
chmod +x "$BIN"

# --- register the LaunchAgent -----------------------------------------------
echo "==> Registering LaunchAgent..."
MONITOR_LABEL="$LABEL" MONITOR_BIN="$BIN" "$ROOT/Scripts/plist.sh"

echo ""
echo "✅ Installed! Monitor is now running in the menu bar and will start at login."
echo "   Uninstall: ./install.sh --uninstall"
