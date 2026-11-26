# shell-launch.sh - Start Orvix's Quickshell, unless Omarchy's shell has it
#
# Orvix's shell (quickshell/.config/quickshell) and Omarchy's (omarchy-shell,
# `quickshell -p /usr/share/omarchy/shell`) both start at login and would give
# two bars. This is what conf/autostart.lua starts instead of Quickshell
# directly:
#
#   guard off (default)   Orvix starts, as it always did
#   guard on              Orvix waits for Omarchy's shell; when it is running,
#                         Orvix's shell is not started, and Settings says why
#
# The guard is set in Settings › System › Omarchy ("Skip Orvix's bar when
# Omarchy's is running"), state key `omarchy.skipShellWithOmarchy`.
# `orvix reload` and Settings › About restart Orvix's shell by hand, so they
# ignore the guard (`--force`).

set -u

STATE="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/state.json"

# read_setting PATH DEFAULT: the value from state.json, as jq prints it
read_setting() {
    local path=$1 fallback=$2 value=""
    if [[ -f "$STATE" ]] && command -v jq >/dev/null 2>&1; then
        value="$(jq -r "$path // empty" "$STATE" 2>/dev/null)"
    fi
    printf '%s' "${value:-$fallback}"
}

# omarchy_shell_running: Omarchy's shell process (its own config folder)
omarchy_shell_running() {
    pgrep -f 'quickshell[^ ]* .*(/usr/share/omarchy|omarchy)/shell' >/dev/null 2>&1
}

guard=$(read_setting '.omarchy.skipShellWithOmarchy' false)

if [[ "${1:-}" != "--force" && "$guard" == "true" ]] && omarchy_shell_running; then
    # Leave a note for Settings › System › Omarchy (and for the user)
    runtime="${XDG_RUNTIME_DIR:-/tmp}"
    printf '%s\n' "skipped" >"$runtime/orvix-shell-skipped" 2>/dev/null || true
    command -v notify-send >/dev/null 2>&1 &&
        notify-send -a Orvix "Orvix's bar was not started" \
            "Omarchy's shell is running. Turn the guard off in Settings › System › Omarchy." 2>/dev/null
    exit 0
fi

rm -f "${XDG_RUNTIME_DIR:-/tmp}/orvix-shell-skipped" 2>/dev/null || true

# Same 2 jemalloc arenas as before (less RSS)
MALLOC_CONF=narenas:2 exec quickshell
