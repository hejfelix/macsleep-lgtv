#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARE_DIR="$HOME/.local/share/macsleep-lgtv"
BIN_DIR="$HOME/.local/bin"
CONFIG_DIR="$HOME/.config/macsleep-lgtv"
CONFIG_FILE="$CONFIG_DIR/config.env"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_DIR/com.user.macsleep-lgtv.plist"
LOG="$HOME/Library/Logs/macsleep-lgtv.log"
LABEL="com.user.macsleep-lgtv"
WATCHER="$BIN_DIR/macsleep-lgtv-watcher"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; }

command -v brew >/dev/null \
  || { err "Homebrew required — see https://brew.sh"; exit 1; }

say "Installing Homebrew dependencies"
for pkg in wakeonlan pipx; do
  brew list "$pkg" >/dev/null 2>&1 || brew install "$pkg"
done
pipx ensurepath >/dev/null 2>&1 || true
export PATH="$HOME/.local/bin:$PATH"

say "Installing bscpylgtv"
pipx list 2>/dev/null | grep -q bscpylgtv || pipx install bscpylgtv

mkdir -p "$SHARE_DIR" "$BIN_DIR" "$CONFIG_DIR" "$LAUNCH_DIR" "$(dirname "$LOG")"

if [[ ! -f "$CONFIG_FILE" ]]; then
  say "Creating config at $CONFIG_FILE"
  read -rp "  TV IP address: " TV_IP
  read -rp "  TV MAC address (e.g. F4:14:BF:B7:FE:52): " TV_MAC
  read -rp "  HDMI input to restore on wake [HDMI_1]: " TV_INPUT
  TV_INPUT="${TV_INPUT:-HDMI_1}"
  cat > "$CONFIG_FILE" <<CONF
TV_IP="$TV_IP"
TV_MAC="$TV_MAC"
TV_INPUT="$TV_INPUT"
KEY_FILE="\$HOME/.aiopylgtv.sqlite"
DEBOUNCE_SECONDS=10
CONF
  chmod 600 "$CONFIG_FILE"
else
  say "Using existing config: $CONFIG_FILE"
fi

say "Installing shell hooks"
install -m 755 "$REPO_DIR/src/lgtv-off.sh" "$SHARE_DIR/lgtv-off.sh"
install -m 755 "$REPO_DIR/src/lgtv-on.sh"  "$SHARE_DIR/lgtv-on.sh"
install -m 755 "$REPO_DIR/src/watcher.py"   "$WATCHER"

source "$CONFIG_FILE"
KEY_FILE="${KEY_FILE/#\$HOME/$HOME}"
if [[ ! -s "$KEY_FILE" ]]; then
  say "Pairing with TV at $TV_IP — accept the prompt on the TV screen"
  "$BIN_DIR/bscpylgtvcommand" -p "$KEY_FILE" "$TV_IP" sw_info \
    || err "Pairing failed. Retry: $SHARE_DIR/lgtv-off.sh manual"
else
  say "Pairing key already present"
fi

say "Installing launchd agent"
PYTHON_BIN="$(command -v python3)"
sed -e "s|__PYTHON_BIN__|$PYTHON_BIN|g" \
    -e "s|__WATCHER_BIN__|$WATCHER|g" \
    -e "s|__LOG__|$LOG|g" \
    "$REPO_DIR/launchd/com.user.macsleep-lgtv.plist.template" > "$PLIST"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"

# Verify the watcher can reach the TV at all.
say "Testing TV connection"
if "$PYTHON_BIN" "$WATCHER" --test; then
  say "TV reachable ✓"
else
  printf '\033[1;33m  Warning: could not reach TV at %s.\n' "$TV_IP"
  printf '  Check that the TV is on and the IP is correct in %s\033[0m\n' "$CONFIG_FILE"
fi

printf '\033[1;33m\n  Note: on first sleep, macOS may show a "local network access" dialog.\n'
printf '  Approve it — the TV will power off correctly on the next sleep.\033[0m\n'

say "Done!"
printf '\n  Logs:    tail -f %s\n  Config:  %s\n  Reload:  launchctl kickstart -k gui/%s/%s\n\n' \
  "$LOG" "$CONFIG_FILE" "$(id -u)" "$LABEL"
