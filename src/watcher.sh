#!/usr/bin/env bash
# Display and system sleep/wake watcher.
# - System sleep/wake: detected via process pause/resume (bash sleeps during system sleep).
# - Display sleep/wake: polled via ioreg every 5 s (CGDisplayIsAsleep equivalent).
#   CurrentPowerState == 4 means displays are awake; < 4 means sleeping.
set -uo pipefail

SHARE_DIR="$HOME/.local/share/macsleep-lgtv"

log() { /usr/bin/logger -t macsleep-lgtv "$*"; echo "$(date '+%F %T') $*"; }

display_power_state() {
    /usr/sbin/ioreg -r -n IODisplayWrangler -k CurrentPowerState 2>/dev/null \
        | /usr/bin/awk '/"CurrentPowerState"/{print $NF; exit}'
}

log "watcher started"

displays_asleep=0
last_wake=$(date +%s)

while true; do
    before=$(date +%s)
    sleep 5
    after=$(date +%s)

    # If we slept much longer than 5 s, the system was suspended — treat as wake
    gap=$(( after - before ))
    if (( gap > 15 )); then
        log "didWake (system)"
        "$SHARE_DIR/lgtv-on.sh" wake
        displays_asleep=0
        last_wake=$after
        continue
    fi

    state=$(display_power_state)
    [[ -z "$state" ]] && continue

    if (( state < 4 )) && (( displays_asleep == 0 )); then
        displays_asleep=1
        log "screensDidSleep"
        "$SHARE_DIR/lgtv-off.sh" screensleep
    elif (( state == 4 )) && (( displays_asleep == 1 )); then
        displays_asleep=0
        log "screensDidWake"
        "$SHARE_DIR/lgtv-on.sh" screenwake
    fi
done
