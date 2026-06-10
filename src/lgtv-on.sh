#!/bin/zsh
set -u
CONFIG="${MACSLEEP_LGTV_CONFIG:-$HOME/.config/macsleep-lgtv/config.env}"
[[ -f "$CONFIG" ]] || { echo "missing config: $CONFIG" >&2; exit 1; }
source "$CONFIG"

LOG="$HOME/Library/Logs/macsleep-lgtv.log"
TRIGGER="${1:-wake}"

exec >>"$LOG" 2>&1
echo "--- $(date '+%F %T') on ($TRIGGER) ---"

# Bail out if the expected TV display is not connected
SP_DISPLAYS=$(/usr/sbin/system_profiler SPDisplaysDataType 2>/dev/null)
if [[ -n "${TV_DISPLAY_NAME:-}" ]]; then
  if ! echo "$SP_DISPLAYS" | grep -Fq "$TV_DISPLAY_NAME"; then
    echo "'$TV_DISPLAY_NAME' not found in connected displays — skipping"
    exit 0
  fi
else
  # Fallback: require any HDMI connection or Television marker
  if ! echo "$SP_DISPLAYS" | grep -qE "Connection Type.*HDMI|Television: Yes"; then
    echo "no HDMI/TV display connected — skipping"
    exit 0
  fi
fi

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
