# macsleep-lgtv

Turn your **LG webOS TV** off when your Mac sleeps or its displays sleep —
and back on when you wake. Works with the LG C-series (tested on C5) and any
TV supported by [`bscpylgtv`](https://github.com/chros73/bscpylgtv).

macOS's built-in display-sleep notification is not reliably delivered to
[`sleepwatcher`](https://www.bernhard-baehr.de/) on modern hardware, so this
project ships a tiny Swift daemon that listens for
`NSWorkspace.screensDidSleep` / `.screensDidWake` — the same events the OS
uses internally — alongside the system sleep/wake notifications.

## Features

- Powers TV off on both **system sleep** and **display sleep** (idle timeout or hotcorner)
- Wakes TV via **Wake-on-LAN** and restores a configurable HDMI input
- **Debounces** duplicate events (display sleep fires just before system sleep)
- One launchd agent — no menubar app, no background CPU when idle

## Requirements

| Requirement | Notes |
|---|---|
| macOS (Apple Silicon or Intel) | Tested on macOS 14+ |
| Xcode Command Line Tools | `xcode-select --install` |
| [Homebrew](https://brew.sh) | |
| LG webOS TV with **Mobile TV On** enabled | *Settings → General → Devices → External Devices* |

## Install

```bash
git clone https://github.com/hejfelix/macsleep-lgtv.git
cd macsleep-lgtv
./install.sh
```

The installer will:
1. Install `wakeonlan` + `pipx` via Homebrew
2. Install `bscpylgtv` via pipx
3. Prompt for your TV's **IP**, **MAC**, and HDMI input
4. **Pair with your TV** — accept the prompt on the TV screen
5. Compile the Swift watcher
6. Register a launchd agent that starts at login

## Configuration

`~/.config/macsleep-lgtv/config.env`:

```sh
TV_IP="192.168.0.134"
TV_MAC="F4:14:BF:B7:FE:52"
TV_INPUT="HDMI_1"
KEY_FILE="$HOME/.aiopylgtv.sqlite"
DEBOUNCE_SECONDS=10
```

After editing, reload:

```bash
launchctl kickstart -k "gui/$(id -u)/com.user.macsleep-lgtv"
```

## Logs

```bash
tail -f ~/Library/Logs/macsleep-lgtv.log
```

## Uninstall

```bash
./uninstall.sh
```

## How it works

`screen-sleep-watcher` is a ~30-line Swift program that registers
`NSWorkspace.notificationCenter` observers for four events:

| NSWorkspace notification | Trigger | Action |
|---|---|---|
| `screensDidSleep` | Display idle timeout, hot corner, lid close | TV off |
| `willSleep` | System sleep | TV off (debounced) |
| `screensDidWake` | Display wakes | TV on + input switch |
| `didWake` | System wake | TV on + input switch (debounced) |

On macOS the `screensDidSleep` notification fires reliably for both
user-idle display sleep and manual sleep (hot corner, menu bar), whereas
the `IORegisterForSystemPower` callback used by `sleepwatcher -S` often
does not on Apple Silicon.

## Troubleshooting

**TV doesn't power off** — check the log. If you see `power_off failed`,
re-pair:
```bash
bscpylgtvcommand -p ~/.aiopylgtv.sqlite 192.168.0.134 sw_info
```
Accept the prompt on the TV, then try again.

**TV doesn't wake** — verify *Mobile TV On* is enabled on the TV, and test
WoL directly: `wakeonlan F4:14:BF:B7:FE:52`.

**Duplicate events** — raise `DEBOUNCE_SECONDS` in config.

## License

MIT
