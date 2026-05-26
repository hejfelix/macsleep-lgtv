# HANDOFF — macsleep-lgtv

## What this repo is
A launchd-based daemon that powers an LG webOS TV (C5) off when the Mac
display sleeps or system sleeps, and back on at wake. Uses a compiled Swift
watcher (`src/screen-sleep-watcher.swift`) instead of sleepwatcher because
`NSWorkspace.screensDidSleep` fires reliably on Apple Silicon where
`sleepwatcher -S` does not.

## Current state of the user's machine

| Thing | Location |
|---|---|
| Old sleepwatcher daemon | `com.dkfepaha.sleepwatcher` — still running, should be stopped |
| Old off-script | `~/bin/lgtv-off.sh` (has debounce logic) |
| Old on-script | `~/bin/lgtv-on.sh` |
| Compiled Swift watcher | `~/bin/screen-sleep-watcher` (compiled, not yet wired to launchd) |
| TV IP | 192.168.0.134 |
| TV MAC | F4:14:BF:B7:FE:52 |
| TV input | HDMI_1 |
| bscpylgtv key file | ~/.aiopylgtv.sqlite |
| Log | ~/Library/Logs/lgtv.log (old); should move to ~/Library/Logs/macsleep-lgtv.log |

## What still needs to be done

1. **Stop old sleepwatcher daemon**
   ```
   launchctl bootout gui/$(id -u)/com.dkfepaha.sleepwatcher
   rm ~/Library/LaunchAgents/com.dkfepaha.sleepwatcher.plist
   ```

2. **Write config** to `~/.config/macsleep-lgtv/config.env` from the values above.

3. **Install hooks** from `src/` to `~/.local/share/macsleep-lgtv/`.

4. **Compile the Swift watcher** (already done once to `~/bin/screen-sleep-watcher`,
   but install.sh will put it at `~/.local/bin/macsleep-lgtv-watcher`).

5. **Install + load launchd plist** from `launchd/com.user.macsleep-lgtv.plist.template`.

6. **Test**: let displays sleep, confirm TV turns off, confirm log entry in
   `~/Library/Logs/macsleep-lgtv.log`.

7. **Push to GitHub**: `gh repo create hejfelix/macsleep-lgtv --public --source=. --push`

## To resume in a new session

Open `~/repos/macsleep-lgtv` as the VS Code workspace, then send:

> Resume the macsleep-lgtv setup. See HANDOFF.md for full context.
> The tool errors from the previous session seem to be gone — continue from
> step 1 (stop old sleepwatcher) through to pushing the repo to GitHub.
