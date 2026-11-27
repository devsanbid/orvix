#!/usr/bin/env bash
# speedup-browser-startup.sh - Keep a Chromium-based browser warm
#
# The Linux counterpart of Edge's Startup Boost: the browser runs with no
# windows, so a new window or link opens in the process that is already warm
# instead of starting one from scratch.
#
#   usage: speedup-browser-startup.sh start|stop|status|restart-if-changed
#
# How it works, and why each part is needed:
#
#   * `--no-startup-window` alone does not keep Chromium alive: it quits once
#     extensions have loaded unless something holds it. `--keep-alive-for-test`
#     is that holder, and needs no app (Chromium's own tests use it for this).
#   * The browser is started as a systemd user unit, so it outlives this
#     script and can be stopped and inspected like any other service.
#   * A new window from the same profile is handed to the running process by
#     Chromium itself (its process singleton socket). That is why the warm
#     browser has to use the same profile: the default browser's own.
#   * `restart-if-changed` is what a timer runs: the browser is restarted only
#     when it was upgraded on disk or the default browser changed, and only
#     while it owns no windows. A restart with a window open would close it.
#
# Licensed MIT, like the plugin that inspired it (AgentRBY's
# omarchy-speedup-browser-startup); see README.md.

set -u

UNIT="speedup-browser-startup"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}/speedup-browser-startup"
LIST="$RUNTIME/browsers"

die() {
    echo "speedup-browser-startup: $*" >&2
    exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

# Browsers this works with, and the class Hyprland reports for their windows.
# Firefox, Zen and Flatpak browsers have no keep-alive switch, so they are
# deliberately absent: for them the plugin does nothing.
browser_binary() {
    case "$1" in
    chromium) echo chromium ;;
    chrome | google-chrome) echo google-chrome-stable ;;
    brave | brave-browser) echo brave-browser ;;
    brave-origin | brave-browser-origin) echo brave-browser-origin ;;
    edge | microsoft-edge) echo microsoft-edge-stable ;;
    vivaldi | vivaldi-stable) echo vivaldi-stable ;;
    esac
}

browser_class() {
    case "$1" in
    chromium) echo Chromium ;;
    chrome | google-chrome) echo Google-chrome ;;
    brave | brave-browser) echo Brave-browser ;;
    brave-origin | brave-browser-origin) echo Brave-browser ;;
    edge | microsoft-edge) echo Microsoft-edge ;;
    vivaldi | vivaldi-stable) echo Vivaldi-stable ;;
    esac
}

# The browser the desktop opens links with, as this plugin's short name.
# Orvix keeps it in state.json (Settings › System › Apps), then the freedesktop
# default is tried, then a plain PATH search.
default_browser() {
    local cmd=""
    local state="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/state.json"
    if [[ -f "$state" ]] && have jq; then
        cmd="$(jq -r '.apps.browser.command // empty' "$state" 2>/dev/null | awk '{print $1}')"
    fi
    if [[ -z "$cmd" ]] && have xdg-settings; then
        cmd="$(xdg-settings get default-web-browser 2>/dev/null | sed 's/\.desktop$//')"
    fi
    local name
    for name in chromium chrome google-chrome brave brave-browser brave-origin edge microsoft-edge vivaldi vivaldi-stable; do
        case "$cmd" in
        *"$name"*)
            echo "$name"
            return 0
            ;;
        esac
    done
    # Nothing recognised: the plugin does nothing rather than guessing
    return 1
}

# How many windows of this browser are open, from Hyprland
window_count() {
    local class=$1
    have hyprctl || {
        echo 0
        return
    }
    hyprctl clients -j 2>/dev/null | jq --arg c "$class" '[.[] | select((.class // "") | ascii_downcase == ($c | ascii_downcase))] | length' 2>/dev/null || echo 0
}

# The browser's version, so an upgrade can be noticed: the binary's own
# version string is what changes when a package replaces it
binary_stamp() {
    local bin=$1
    [[ -x "$bin" ]] || {
        echo "missing"
        return
    }
    # Path, size and mtime: an upgrade rewrites the binary
    stat -Lc '%n %s %Y' "$bin" 2>/dev/null || echo "$bin"
}

# Extra flags from the plugin's own file (--disable-features=… and similar),
# one per line, # for comments. Omarchy's fast hand-off only accepts the
# flags it ships; anything else belongs here so a new window still reuses the
# warm process.
extra_flags() {
    local file="${XDG_CONFIG_HOME:-$HOME/.config}/speedup-browser-startup-flags.conf"
    [[ -f "$file" ]] || return 0
    sed 's/[[:space:]]*#.*$//' "$file" | sed '/^[[:space:]]*$/d'
}

_running() { systemctl --user is-active --quiet "$UNIT" 2>/dev/null; }

_owns_windows() {
    local name=$1 class
    class="$(browser_class "$name")"
    [[ "$(window_count "$class")" -gt 0 ]]
}

cmd_start() {
    local name bin class flags=()
    name="$(default_browser)" || {
        echo "No supported Chromium-based browser is the default; nothing to do."
        return 0
    }
    bin="$(browser_binary "$name")"
    have "$bin" || die "$bin is not installed"

    # Already running: leave it alone. A browser the user started by hand is
    # not ours to take over (the plugin says the same: the speedup starts at
    # the next login).
    if _running; then
        echo "Already running."
        return 0
    fi
    if _owns_windows "$name"; then
        echo "$name already has windows open; leaving it to the next login."
        return 0
    fi

    while IFS= read -r flag; do
        [[ -n "$flag" ]] && flags+=("$flag")
    done < <(extra_flags)

    mkdir -p "$RUNTIME"
    # Remembered for stop and for the update check
    printf '%s\n' "$name" >"$LIST"
    binary_stamp "$(command -v "$bin")" >"$RUNTIME/stamp"

    systemctl --user stop "$UNIT" 2>/dev/null
    # app-graphical.slice puts it where session apps run, so it has the
    # display and the same environment a launcher-started browser would
    systemctl --user reset-failed "$UNIT" 2>/dev/null
    systemd-run --user --unit="$UNIT" --collect \
        --slice=app-graphical.slice \
        --description="Warm $name for instant new windows (Orvix plugin)" \
        "$(command -v "$bin")" --no-startup-window --keep-alive-for-test "${flags[@]}" >/dev/null 2>&1 ||
        die "couldn't start the background $name"

    echo "Started $name in the background."
}

cmd_stop() {
    local name
    name="$(cat "$LIST" 2>/dev/null || true)"
    if _running; then
        systemctl --user stop "$UNIT" 2>/dev/null
        echo "Stopped the background browser."
    else
        echo "Not running."
    fi
    rm -f "$LIST"
    return 0
}

cmd_status() {
    local name
    name="$(cat "$LIST" 2>/dev/null || default_browser 2>/dev/null || true)"
    if _running; then
        echo "running${name:+ ($name)}"
        if [[ -n "$name" ]]; then
            echo "windows: $(window_count "$(browser_class "$name")")"
        fi
    else
        echo "stopped"
    fi
}

# The timer's job: restart only when it must, and only with no windows open
cmd_restart_if_changed() {
    _running || return 0
    local name old new bin
    name="$(cat "$LIST" 2>/dev/null || true)"
    [[ -n "$name" ]] || return 0
    bin="$(browser_binary "$name")"
    have "$bin" || {
        cmd_stop
        return 0
    }

    # A pacman transaction is rewriting packages: never restart into that
    if have fuser && [[ -e /var/lib/pacman/db.lck ]]; then
        if fuser /var/lib/pacman/db.lck >/dev/null 2>&1; then
            return 0
        fi
    fi

    old="$(cat "$RUNTIME/stamp" 2>/dev/null || true)"
    new="$(binary_stamp "$(command -v "$bin")")"
    local reason=""
    if [[ "$old" != "$new" ]]; then
        reason="the browser was updated"
    else
        local current
        current="$(default_browser 2>/dev/null || true)"
        [[ "$current" != "$name" ]] && reason="the default browser changed"
    fi
    [[ -n "$reason" ]] || return 0

    # A restart closes windows, so it waits until there are none
    _owns_windows "$name" && return 0

    echo "Restarting: $reason"
    cmd_stop >/dev/null
    cmd_start >/dev/null
}

case "${1:-status}" in
start) cmd_start ;;
stop) cmd_stop ;;
status) cmd_status ;;
restart-if-changed) cmd_restart_if_changed ;;
*)
    echo "usage: $(basename "$0") start|stop|status|restart-if-changed" >&2
    exit 2
    ;;
esac
