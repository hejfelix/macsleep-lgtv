#!/usr/bin/env bash
set -euo pipefail
LABEL="com.user.macsleep-lgtv"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -f "$HOME/.local/bin/macsleep-lgtv-watcher"
rm -rf "$HOME/.local/share/macsleep-lgtv"
echo "Removed. Config kept at: ~/.config/macsleep-lgtv/"
echo "To fully clean up: pipx uninstall bscpylgtv && rm ~/.aiopylgtv.sqlite"
