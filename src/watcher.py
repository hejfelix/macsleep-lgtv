#!/usr/bin/env python3
"""
Display and system sleep/wake watcher.
Uses CGDisplayIsAsleep (CoreGraphics via ctypes) for reliable display sleep
detection on Apple Silicon — the same API as the previous Swift implementation.
"""
import ctypes, ctypes.util, os, subprocess, sys, time, syslog

SHARE_DIR = os.path.expanduser("~/.local/share/macsleep-lgtv")
POLL_INTERVAL = 5  # seconds

_cg = ctypes.CDLL(ctypes.util.find_library("CoreGraphics"))
_cg.CGMainDisplayID.restype = ctypes.c_uint32
_cg.CGDisplayIsAsleep.restype = ctypes.c_bool
_cg.CGDisplayIsAsleep.argtypes = [ctypes.c_uint32]

def display_is_asleep():
    return _cg.CGDisplayIsAsleep(_cg.CGMainDisplayID())

def log(msg):
    syslog.syslog(syslog.LOG_NOTICE, f"macsleep-lgtv: {msg}")
    ts = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"{ts} {msg}", flush=True)

def run_hook(script, event):
    subprocess.Popen([os.path.join(SHARE_DIR, script), event])

log("watcher started")

displays_asleep = False

while True:
    before = time.monotonic()
    time.sleep(POLL_INTERVAL)
    after = time.monotonic()

    # Gap >> POLL_INTERVAL means system was suspended
    if (after - before) > POLL_INTERVAL * 3:
        log("didWake (system)")
        run_hook("lgtv-on.sh", "wake")
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
