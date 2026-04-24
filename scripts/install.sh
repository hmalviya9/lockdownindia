#!/usr/bin/env bash
# Install the lockdown-indicator launchd job.
# Runs the updater every 6 hours: 00:15, 06:15, 12:15, 18:15 local time.
#
# Usage:
#   ./scripts/install.sh           # install + load
#   ./scripts/install.sh uninstall # unload + remove

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="com.lockdown-indicator.update"
PLIST_SRC="$ROOT/scripts/com.lockdown-indicator.plist"
LAUNCHAGENTS="$HOME/Library/LaunchAgents"
PLIST_DST="$LAUNCHAGENTS/$LABEL.plist"

case "${1:-install}" in
  install)
    mkdir -p "$LAUNCHAGENTS"
    cp "$PLIST_SRC" "$PLIST_DST"
    # Replace path placeholder if present (defensive)
    sed -i '' "s|/Users/hiteshmalviya/Downloads/india-energy-thesis|$ROOT|g" "$PLIST_DST"
    chmod 644 "$PLIST_DST"

    # Make worker script executable
    chmod +x "$ROOT/scripts/update-indicator.sh"

    # Bootstrap (modern launchctl)
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"

    echo "Installed $LABEL"
    echo "Status: $(launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null | grep -E '^\s*(state|last exit code)' | head -3 || echo 'unknown')"
    echo "Next runs at: 00:15, 06:15, 12:15, 18:15 local time"
    echo "Logs: $ROOT/scripts/launchd.out.log + $ROOT/scripts/update.log"
    ;;
  uninstall)
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    rm -f "$PLIST_DST"
    echo "Uninstalled $LABEL"
    ;;
  *)
    echo "Usage: $0 [install|uninstall]"
    exit 1
    ;;
esac
