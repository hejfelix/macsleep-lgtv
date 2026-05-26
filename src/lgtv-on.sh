#!/bin/zsh
set -u
CONFIG="${MACSLEEP_LGTV_CONFIG:-$HOME/.config/macsleep-lgtv/config.env}"
[[ -f "$CONFIG" ]] || { echo "missing config: $CONFIG" >&2; exit 1; }
source "$CONFIG"

LOG="$HOME/Library/Logs/macsleep-lgtv.log"
TRIGGER="${1:-wake}"

exec >>"$LOG" 2>&1
echo "--- $(date '+%F %T') on ($TRIGGER) ---"

WOL="$(command -v wakeonlan 2>/dev/null || true)"
: "${WOL:=/opt/homebrew/bin/wakeonlan}"
BSCPY="$(command -v bscpylgtvcommand 2>/dev/null || true)"
: "${BSCPY:=$HOME/.local/bin/bscpylgtvcommand}"

"$WOL" "$TV_MAC" || true

for i in {1..15}; do
  sleep 2
  if /usr/bin/nc -z -w 1 "$TV_IP" 3000 2>/dev/null; then
    echo "TV reachable on attempt $i"
    "$BSCPY" -p "$KEY_FILE" "$TV_IP" set_input "$TV_INPUT" \
      && { echo "input set to $TV_INPUT"; exit 0; }
  fi
done
echo "TV did not become reachable"
exit 1
