# orvix omarchy - Control Omarchy's own bar and dock from Orvix
#
# Orvix runs its own bar, and Omarchy's shell can stay up underneath it so its
# plugins, panels and services keep working. That only works while Omarchy's
# bar and dock stay out of the way:
#
#   * the bar is hidden with Omarchy's own flag
#     (~/.local/state/omarchy/toggles/bar-off), which `omarchy toggle bar`
#     flips. It is read when the shell starts, so it survives
#     `omarchy-restart-shell` and every `omarchy update`.
#   * the dock is a shell plugin (`omarchy.dock`), disabled through Omarchy's
#     plugin registry, which writes `disabledPlugins` in shell.json.
#
# `omarchy plugin disable omarchy.bar` does nothing (its manifest is kind
# "bar", not a widget), which is why this uses the toggle flag instead.

local subcmd="${1:-status}"

# Where Omarchy keeps the flags and the shell config. Both are under $HOME
# whatever XDG_* say: omarchy-toggle and the bar probe hardcode
# "$HOME/.local/state/omarchy/toggles", and the shell reads
# "$HOME/.config/omarchy/shell.json". Reading them any other way would check a
# file Omarchy never writes.
_om_bar_flag() { printf '%s' "$HOME/.local/state/omarchy/toggles/bar-off"; }
_om_shell_json() { printf '%s' "$HOME/.config/omarchy/shell.json"; }

_om_have() { command -v "$1" >/dev/null 2>&1; }

# Is Omarchy installed at all? ORVIX_OMARCHY_DIR points the check at another
# tree (the tests' empty folder), as `orvix doctor` does
_om_installed() { [[ -d "${ORVIX_OMARCHY_DIR:-/usr/share/omarchy}" ]]; }

# Is Omarchy's shell running? (its own config folder, not Orvix's)
_om_shell_running() {
    pgrep -f 'quickshell[^ ]* .*(/usr/share/omarchy|omarchy)/shell' >/dev/null 2>&1
}

# What the user sees: the flag means "bar off", so its presence is 'hidden'
_om_bar_state() {
    if [[ -f "$(_om_bar_flag)" ]]; then
        echo hidden
    else
        echo shown
    fi
}

# dock: disabled, or enabled
_om_dock_state() {
    local file
    file="$(_om_shell_json)"
    if [[ ! -f "$file" ]]; then
        echo enabled
        return
    fi
    if _om_have jq && jq -e '(.disabledPlugins // []) | index("omarchy.dock")' "$file" >/dev/null 2>&1; then
        echo hidden
    else
        echo shown
    fi
}

# Hide or show Omarchy's bar, through its own command when it is there, and
# through the flag directly when it isn't (an update to a machine where the
# shell is not up yet).
#
# Note the double negative in Omarchy's own naming: the flag is `bar-off`, so
# `omarchy-toggle-bar on` HIDES the bar and `off` shows it. This command's
# `off` means "the bar is off the screen", so it maps the other way round.
_om_set_bar() {
    local want=$1
    case "$want" in
    off | on) ;;
    *)
        echo "orvix omarchy: bar takes 'on' or 'off', not '$want'" >&2
        return 2
        ;;
    esac
    # want off (hidden) -> flag present -> omarchy-toggle-bar on
    local flag_action=on
    [[ "$want" == "on" ]] && flag_action=off
    if _om_have omarchy-toggle-bar; then
        omarchy-toggle-bar "$flag_action" >/dev/null 2>&1
        return 0
    fi
    local flag
    flag="$(_om_bar_flag)"
    if [[ "$want" == "off" ]]; then
        mkdir -p "$(dirname "$flag")" && touch "$flag"
    else
        rm -f "$flag"
    fi
}

# Hide or show Omarchy's dock, through its plugin registry
_om_set_dock() {
    local want=$1
    case "$want" in
    off | on) ;;
    *)
        echo "orvix omarchy: dock takes 'on' or 'off', not '$want'" >&2
        return 2
        ;;
    esac
    if ! _om_have omarchy; then
        echo "orvix omarchy: the omarchy command isn't installed" >&2
        return 1
    fi
    # The plugin registry lives in the running shell: without one there is
    # nothing to change, and writing shell.json by hand would fight it
    if ! _om_shell_running; then
        echo "orvix omarchy: Omarchy's shell isn't running, so its dock can't change" >&2
        echo "               (start it with: omarchy-launch-shell)" >&2
        return 1
    fi
    if [[ "$want" == "off" ]]; then
        omarchy plugin disable omarchy.dock >/dev/null 2>&1
    else
        omarchy plugin enable omarchy.dock >/dev/null 2>&1
    fi
}

# Write the post-update and post-boot hooks that keep the bar hidden. They
# call this command, so the rule lives in one place.
_om_install_hooks() {
    # Omarchy reads hooks from $HOME/.config too
    local dir="$HOME/.config/omarchy/hooks"
    local self
    self="${BASH_SOURCE[0]}"
    # The real orvix entry point, whatever path this file was reached by
    self="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../.." && pwd)/local/.local/bin/orvix"
    mkdir -p "$dir/post-update.d" "$dir/post-boot.d" || return 1
    local name hook
    for name in post-update post-boot; do
        hook="$dir/$name.d/50-orvix-omarchy-bar"
        {
            printf '%s\n' '#!/bin/bash'
            printf '%s\n' '# Written by `orvix omarchy hooks install`. Edits are overwritten.'
            printf '%s\n' '#'
            printf '%s\n' "# Keeps Omarchy's bar (and dock) out of the way of Orvix's, after an"
            printf '%s\n' '# update or at login. It only acts when Settings › System › Omarchy has the'
            printf '%s\n' '# guard on (state.json: omarchy.hideOmarchyBar); the flag Omarchy reads is'
            printf '%s\n' '# what actually hides the bar.'
            printf '%s\n' "exec \"$self\" omarchy restore --quiet"
        } >"$hook"
        chmod +x "$hook" || return 1
        echo "   Installed $hook"
    done
}

# Remove the hooks again
_om_remove_hooks() {
    # Omarchy reads hooks from $HOME/.config too
    local dir="$HOME/.config/omarchy/hooks" removed=0
    local name hook
    for name in post-update post-boot; do
        hook="$dir/$name.d/50-orvix-omarchy-bar"
        if [[ -f "$hook" ]]; then
            rm -f "$hook" && removed=1 && echo "   Removed $hook"
        fi
    done
    ((removed)) || echo "   No Orvix hooks were installed"
}

# Is the "keep it hidden" rule on? Off until Settings or `orvix omarchy on`.
_om_rule_on() {
    local file="$HOME/.config/quickshell/state.json"
    [[ -f "$file" ]] || return 1
    _om_have jq || return 1
    [[ "$(jq -r '.omarchy.hideOmarchyBar // false' "$file" 2>/dev/null)" == "true" ]]
}

# Apply the rule: hide the bar (and dock) only when it is on
_om_restore() {
    local quiet=${1:-}
    if ! _om_installed; then
        [[ "$quiet" == "--quiet" ]] || echo "Omarchy isn't installed"
        return 0
    fi
    if ! _om_rule_on; then
        [[ "$quiet" == "--quiet" ]] || echo "The rule is off (omarchy.hideOmarchyBar), nothing to restore"
        return 0
    fi
    _om_set_bar off
    [[ -n "$quiet" ]] || echo "   Omarchy's bar: hidden"
    if _om_shell_running && [[ "$(_om_dock_state)" == "shown" ]]; then
        _om_set_dock off
        [[ -n "$quiet" ]] || echo "   Omarchy's dock: hidden"
    fi
    return 0
}

case "$subcmd" in
    -h | --help)
        echo "Usage: orvix omarchy <bar|dock|restore|hooks|status> ..."
        echo ""
        echo "Omarchy's bar and dock, kept out of Orvix's way. Orvix runs its own"
        echo "bar; Omarchy's shell can stay up behind it so its plugins and panels"
        echo "keep working. These commands make sure only one bar shows, and the"
        echo "hiding survives \`omarchy update\` and every login."
        echo ""
        echo "Subcommands:"
        echo "  status              What is showing now, and whether the rule is on"
        echo "  bar on|off          Show or hide Omarchy's bar (default: off)"
        echo "  dock on|off         Show or hide Omarchy's dock"
        echo "  restore [--quiet]   Re-apply the rule: hide the bar (and dock) if it is on."
        echo "                      This is what the hooks run after an update and at login"
        echo "  hooks install       Add post-update and post-boot hooks that run 'restore'"
        echo "  hooks remove        Take them away again"
        echo "  on | off            Turn the rule on (and apply it) or off (and show the bar)"
        echo ""
        echo "The bar is hidden with Omarchy's own flag"
        echo "(~/.local/state/omarchy/toggles/bar-off), so nothing is killed and no"
        echo "Omarchy file is edited. The dock is a plugin, so it is disabled through"
        echo "Omarchy's plugin registry."
        ;;
    status)
        if ! _om_installed; then
            echo "Omarchy isn't installed"
            return 1
        fi
        printf 'Omarchy bar    %s\n' "$(_om_bar_state)"
        printf 'Omarchy dock   %s\n' "$(_om_dock_state)"
        printf 'Omarchy shell  %s\n' "$(_om_shell_running && echo running || echo "not running")"
        printf 'Keep hidden    %s\n' "$(_om_rule_on && echo on || echo off)"
        local hooks="$HOME/.config/omarchy/hooks"
        if [[ -f "$hooks/post-update.d/50-orvix-omarchy-bar" && -f "$hooks/post-boot.d/50-orvix-omarchy-bar" ]]; then
            printf 'Hooks          installed\n'
        else
            printf 'Hooks          not installed\n'
        fi
        ;;
    bar)
        local want="${2:-off}"
        _om_installed || {
            echo "orvix omarchy: Omarchy isn't installed" >&2
            return 1
        }
        _om_set_bar "$want" || return
        # The flag is what matters; report what it says now, not what we asked
        echo "Omarchy's bar is $(_om_bar_state)"
        ;;
    dock)
        local want="${2:-off}"
        _om_installed || {
            echo "orvix omarchy: Omarchy isn't installed" >&2
            return 1
        }
        _om_set_dock "$want" || return
        sleep 1
        echo "Omarchy's dock is $(_om_dock_state)"
        ;;
    restore)
        _om_restore "${2:-}"
        ;;
    hooks)
        local action="${2:-}"
        case "$action" in
        install) _om_install_hooks ;;
        remove) _om_remove_hooks ;;
        *)
            echo "Usage: orvix omarchy hooks install|remove" >&2
            return 2
            ;;
        esac
        ;;
    on | off)
        # The rule lives in state.json, which the shell writes; here it is set
        # through jq so it also works from a terminal with no shell running
        local file="$HOME/.config/quickshell/state.json"
        _om_have jq || {
            echo "orvix omarchy: jq is required" >&2
            return 1
        }
        mkdir -p "$(dirname "$file")"
        [[ -f "$file" ]] || echo '{}' >"$file"
        local value=false
        [[ "$subcmd" == "on" ]] && value=true
        if jq --argjson v "$value" '.omarchy.hideOmarchyBar = $v' "$file" >"$file.tmp" 2>/dev/null; then
            mv "$file.tmp" "$file"
        else
            rm -f "$file.tmp"
            echo "orvix omarchy: couldn't write $file" >&2
            return 1
        fi
        if [[ "$subcmd" == "on" ]]; then
            _om_set_bar off
            _om_shell_running && _om_set_dock off
            echo "Keeping Omarchy's bar hidden (and its dock, when the shell runs)"
            echo "Run 'orvix omarchy hooks install' so it survives omarchy update and login"
        else
            _om_set_bar on
            _om_shell_running && _om_set_dock on
            echo "Omarchy's bar and dock are shown again"
        fi
        ;;
    *)
        echo "orvix omarchy: unknown subcommand '$subcmd' (orvix omarchy --help lists them)" >&2
        return 2
        ;;
esac
