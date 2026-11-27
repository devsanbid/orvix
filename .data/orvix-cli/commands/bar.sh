# orvix bar - Show or hide Orvix's own bar
#
# The bar is the shell's window on each screen. Hiding it is a setting
# (`bar.show` in state.json), so it stays hidden across restarts, and the
# Settings page that changes it keeps working with the bar gone (a window,
# not a bar panel). This command is the way back from a terminal when the
# bar is off, e.g. from a TTY or a keybind that survived.

local subcmd="${1:-status}"
local STATE="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/state.json"

_state() {
    if [[ -f "$STATE" ]] && command -v jq >/dev/null 2>&1; then
        # Not "// empty": `false` is a value, and `//` drops it as falsy, which
        # made a hidden bar read back as "nothing set"
        jq -r "$1 | if . == null then empty else tostring end" "$STATE" 2>/dev/null
    fi
}

# "shown" unless bar.show is exactly false
_bar_state() {
    if [[ "$(_state '.bar.show')" == "false" ]]; then
        echo hidden
    else
        echo shown
    fi
}

_set_bar() {
    local want=$1
    case "$want" in
    on | off) ;;
    *)
        echo "orvix bar: takes 'on' or 'off', not '$want'" >&2
        return 2
        ;;
    esac
    if ! command -v jq >/dev/null 2>&1; then
        echo "orvix bar: jq is required" >&2
        return 1
    fi
    mkdir -p "$(dirname "$STATE")"
    [[ -f "$STATE" ]] || echo '{}' >"$STATE"
    local value=true
    [[ "$want" == "off" ]] && value=false
    if jq --argjson v "$value" '.bar.show = $v' "$STATE" >"$STATE.tmp" 2>/dev/null; then
        mv "$STATE.tmp" "$STATE"
    else
        rm -f "$STATE.tmp"
        echo "orvix bar: couldn't write $STATE" >&2
        return 1
    fi
    # Report what was written, not a re-read: the shell may not have picked
    # the change up yet, and the answer is the setting, not the pixels
    if [[ "$value" == "true" ]]; then
        echo "Orvix's bar is shown"
    else
        echo "Orvix's bar is hidden"
    fi
}

case "$subcmd" in
    -h | --help)
        echo "Usage: orvix bar [status|on|off|toggle]"
        echo ""
        echo "Shows or hides Orvix's own bar. The setting is saved (bar.show in"
        echo "state.json), so it survives a restart, and Settings › Bar changes the"
        echo "same one. Settings itself is a window, so it keeps working with the bar"
        echo "off; this command is the way back from a terminal."
        echo ""
        echo "  status   shown or hidden (default)"
        echo "  on       Draw the bar"
        echo "  off      Hide it: the screens get the space back"
        echo "  toggle   The other one"
        echo ""
        echo "Omarchy's own bar is separate: orvix omarchy bar on|off"
        ;;
    status)
        echo "Orvix's bar is $(_bar_state)"
        # Worth saying: two bars is the usual reason to reach for this
        if command -v pgrep >/dev/null 2>&1 && pgrep -f 'quickshell[^ ]* .*(/usr/share/omarchy|omarchy)/shell' >/dev/null 2>&1; then
            local flag="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/toggles/bar-off"
            if [[ -f "$flag" ]]; then
                echo "Omarchy's shell is running, its bar hidden"
            else
                echo "Omarchy's shell is running and its bar is shown: two bars. orvix omarchy bar off"
            fi
        fi
        ;;
    on | off)
        _set_bar "$subcmd"
        ;;
    toggle)
        if [[ "$(_bar_state)" == "hidden" ]]; then
            _set_bar on
        else
            _set_bar off
        fi
        ;;
    *)
        echo "orvix bar: unknown subcommand '$subcmd' (orvix bar --help lists them)" >&2
        return 2
        ;;
esac
