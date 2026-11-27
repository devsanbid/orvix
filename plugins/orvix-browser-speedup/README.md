# Browser startup speedup

Keeps your Chromium-based browser running with no windows, so a new window or
link opens in the process that is already warm instead of starting the browser
again. The Linux counterpart of Edge's Startup Boost, which Linux builds don't
ship.

This is an **Official** Orvix plugin (published under `devsanbid`).

## What it does

| | Time to a window |
| --- | --- |
| Fresh browser start | about half a second, more on a cold cache |
| With this plugin | the warm process maps a window; Chromium's own hand-off does the work |

Measured on this machine with Chromium: a new window from the warm process
appeared in Hyprland in **635 ms** with the browser already resident. The
original Omarchy plugin measured ~0.08 s for Edge on a Ryzen 7 5800X; the
number depends on the browser and the machine, and this plugin does not
promise one.

The trade-off is memory: the browser stays resident, about 0.5–0.8 GB, with
its extensions running in the background.

## How it works

- `bin/speedup-browser-startup.sh start` runs the browser with
  `--no-startup-window --keep-alive-for-test` as a systemd **user unit**
  (`speedup-browser-startup`), in `app-graphical.slice` so it has the session's
  display and environment.
- `--no-startup-window` alone is not enough: Chromium quits once extensions
  load unless something holds it. `--keep-alive-for-test` is that holder, and
  needs no app. Chromium's own tests use it for this.
- A new window goes to the running process through Chromium's own process
  singleton socket, because the warm browser uses the same profile the
  launcher would.
- Every 60 seconds while it runs, `restart-if-changed` restarts the warm
  browser only if it was upgraded on disk or the default browser changed —
  **and only while it owns no windows**. A restart with a window open would
  close that window, so it waits. It never restarts during a pacman
  transaction.
- Session restore ("Continue where you left off") keeps working.

## Supported browsers

Chromium, Google Chrome, Brave, Brave Origin, Microsoft Edge, Vivaldi.

**Not** Firefox, Zen or Flatpak browsers: they have no keep-alive switch, so
this plugin does nothing for them, and says so rather than showing a control
that would not work.

## Install

```bash
orvix plugin install github:devsanbid/orvix --force   # the plugin lives in plugins/
```

or, from a checkout of this repository:

```bash
orvix plugin install ~/.orvix/plugins/orvix-browser-speedup
orvix plugin enable browser-speedup
```

Settings › Plugins shows it, with its own settings page.

## Settings

- **Show an icon while it runs** — a small bolt in the bar. Off, the browser
  keeps running with nothing on screen. (The plugin's bar widget takes no room
  at all while it is stopped.)

## Extra flags

The background browser reads `~/.config/speedup-browser-startup-flags.conf`,
one flag per line, `#` for comments. Put flags there rather than in the
browser's own flags file: a flag the launcher's fast hand-off doesn't know
makes every new window start a second browser process, which defeats the
purpose.

```
--disable-features=ElasticOverscroll
```

## Controls by hand

```bash
bash ~/.config/orvix/plugins/browser-speedup/bin/speedup-browser-startup.sh status
bash ~/.config/orvix/plugins/browser-speedup/bin/speedup-browser-startup.sh stop
bash ~/.config/orvix/plugins/browser-speedup/bin/speedup-browser-startup.sh start
```

## Things to know

- **Exit ends it.** Exit from the browser's menu stops the warm process until
  the plugin loads again, at your next login (`orvix reload` restarts it).
- **Your browser was already open when the plugin loaded?** It is left alone;
  the speedup starts at the next login.
- **`--keep-alive-for-test` is undocumented.** It has existed since 2010, but a
  future Chromium could change it.
- **Restarting never stops it.** The warm browser is a systemd unit, not a
  child of the shell.

## Attribution

Inspired by and equivalent in mechanism to
[AgentRBY/omarchy-speedup-browser-startup](https://github.com/AgentRBY/omarchy-speedup-browser-startup)
(MIT), the Omarchy plugin that does the same thing. This is an independent
implementation for Orvix's plugin format: the shell script is written for
Orvix's state, its browser detection reads Orvix's Settings › System › Apps,
and it reports through Orvix's store. No code was copied; the technique
(the systemd unit, the two Chromium flags, the restart-on-upgrade check) is the
same, and that is credited here.

## License

MIT, the same as the original.
