#!/bin/zsh
set -u
CONFIG="${MACSLEEP_LGTV_CONFIG:-$HOME/.config/macsleep-lgtv/config.env}"
[[ -f "$CONFIG" ]] || { echo "missing config: $CONFIG" >&2; exit 1; }
source "$CONFIG"

LOG="$HOME/Library/Logs/macsleep-lgtv.log"
LOCK="/tmp/macsleep-lgtv-off.lock"
TRIGGER="${1:-sleep}"

exec >>"$LOG" 2>&1
echo "--- $(date '+%F %T') off ($TRIGGER) ---"

if [[ -f "$LOCK" ]]; then
  AGE=$(( $(date +%s) - $(stat -f %m "$LOCK") ))
  if (( AGE < ${DEBOUNCE_SECONDS:-10} )); then
    echo "debounced ($TRIGGER, ${AGE}s ago)"
    exit 0
  fi
fi
touch "$LOCK"

BSCPY="$(command -v bscpylgtvcommand 2>/dev/null || true)"
: "${BSCPY:=$HOME/.local/bin/bscpylgtvcommand}"

for i in {1..3}; do
  if "$BSCPY" -p "$KEY_FILE" "$TV_IP" power_off 2>&1; then
    echo "powered off"
    exit 0
  fi
  (( i < 3 )) && sleep 1
done
echo "power_off failed after 3 attempts"
