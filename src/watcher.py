#!/usr/bin/env python3
"""
Display and system sleep/wake watcher.
Uses CGDisplayIsAsleep (CoreGraphics via ctypes) for reliable display sleep
detection on Apple Silicon — the same API as the previous Swift implementation.
"""

import ctypes, ctypes.util, os, subprocess, sys, time, syslog

SHARE_DIR = os.path.expanduser("~/.local/share/macsleep-lgtv")
POLL_INTERVAL = 5  # seconds

# --test: triggered by install.sh to force the macOS local network permission
# dialog for this binary before the daemon ever needs it at sleep time.
if "--test" in sys.argv:
    cfg = os.path.expanduser("~/.config/macsleep-lgtv/config.env")
    tv_ip = ""
    bscpylgtvcommand = os.path.expanduser("~/.local/bin/bscpylgtvcommand")
    for line in open(cfg):
        if line.startswith("TV_IP="):
            tv_ip = line.split("=", 1)[1].strip().strip('"')
    # Run bscpylgtvcommand as a subprocess of this process — macOS checks the
    # calling process chain, so this triggers the permission dialog for
    # macsleep-lgtv-watcher, which is the binary that runs at sleep time.
    result = subprocess.run(
        [bscpylgtvcommand, tv_ip, "get_software_info"], capture_output=True, text=True
    )
    conn_errors = (
        "No route to host",
        "Connection refused",
        "timed out",
        "Network is unreachable",
    )
    if any(e in result.stderr for e in conn_errors):
        print(f"Could not reach TV at {tv_ip}", file=sys.stderr)
        print(result.stderr.strip(), file=sys.stderr)
        sys.exit(1)
    else:
        print("TV reachable ✓")
        sys.exit(0)

SHARE_DIR = os.path.expanduser("~/.local/share/macsleep-lgtv")
POLL_INTERVAL = 5  # seconds

_cg = ctypes.CDLL(ctypes.util.find_library("CoreGraphics"))
_cg.CGMainDisplayID.restype = ctypes.c_uint32
_cg.CGDisplayIsAsleep.restype = ctypes.c_bool
_cg.CGDisplayIsAsleep.argtypes = [ctypes.c_uint32]
_cg.CGGetOnlineDisplayList.restype = ctypes.c_int32  # CGError
_cg.CGGetOnlineDisplayList.argtypes = [
    ctypes.c_uint32,
    ctypes.POINTER(ctypes.c_uint32),
    ctypes.POINTER(ctypes.c_uint32),
]


def display_is_asleep():
    return _cg.CGDisplayIsAsleep(_cg.CGMainDisplayID())


def online_display_ids():
    """Set of display IDs currently connected (online), powered on or not."""
    max_displays = 16
    arr = (ctypes.c_uint32 * max_displays)()
    count = ctypes.c_uint32(0)
    if _cg.CGGetOnlineDisplayList(max_displays, arr, ctypes.byref(count)) != 0:
        return set()
    return {arr[i] for i in range(count.value)}


def log(msg):
    syslog.syslog(syslog.LOG_NOTICE, f"macsleep-lgtv: {msg}")
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"{ts} {msg}", flush=True)


def run_hook(script, event):
    subprocess.Popen([os.path.join(SHARE_DIR, script), event])


log("watcher started")


# Touch the TV once on startup so macOS triggers the "local network access"
# permission dialog while the screen is on, rather than at first sleep when
# the user can't see it.
def warmup_tv_connection():
    cfg = os.path.expanduser("~/.config/macsleep-lgtv/config.env")
    tv_ip = ""
    key_file = ""
    try:
        for line in open(cfg):
            if line.startswith("TV_IP="):
                tv_ip = line.split("=", 1)[1].strip().strip('"')
            elif line.startswith("KEY_FILE="):
                key_file = line.split("=", 1)[1].strip().strip('"')
    except OSError:
        return
    if not tv_ip:
        return
    key_file = os.path.expandvars(key_file or "$HOME/.aiopylgtv.sqlite")
    bscpylgtvcommand = os.path.expanduser("~/.local/bin/bscpylgtvcommand")
    if not os.path.exists(bscpylgtvcommand):
        return
    log(f"warmup: connecting to TV at {tv_ip}")
    try:
        r = subprocess.run(
            [bscpylgtvcommand, "-p", key_file, tv_ip, "get_software_info"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if r.returncode == 0:
            log("warmup: ok")
        else:
            err = (r.stderr or "").strip().splitlines()[-1] if r.stderr else "no stderr"
            log(f"warmup: rc={r.returncode} {err}")
    except Exception as e:
        log(f"warmup failed (non-fatal): {e}")


warmup_tv_connection()

displays_asleep = False
known_displays = online_display_ids()

while True:
    before = time.monotonic()
    time.sleep(POLL_INTERVAL)
    after = time.monotonic()

    current_displays = online_display_ids()
    new_displays = current_displays - known_displays
    known_displays = current_displays

    # Gap >> POLL_INTERVAL means system was suspended
    if (after - before) > POLL_INTERVAL * 3:
        log("didWake (system)")
        run_hook("lgtv-on.sh", "wake")
        displays_asleep = False
        continue

    # A new display was connected (e.g. HDMI cable plugged in after wake).
    # lgtv-on.sh guards on TV_DISPLAY_NAME, so it no-ops for non-TV displays.
    if new_displays:
        log(f"displayDidConnect ({len(new_displays)} new)")
        run_hook("lgtv-on.sh", "displayconnect")
        displays_asleep = False
        continue

    asleep = display_is_asleep()
    if asleep and not displays_asleep:
        displays_asleep = True
        log("screensDidSleep")
        run_hook("lgtv-off.sh", "screensleep")
    elif not asleep and displays_asleep:
        displays_asleep = False
        log("screensDidWake")
        run_hook("lgtv-on.sh", "screenwake")
