#!/usr/bin/env bash
# qt-scale.sh - Read and set QT_SCALE_FACTOR for the session
#
#   qt-scale.sh get                 the value the next login will use
#   qt-scale.sh set <1.0-2.5>       write it, keeping everything else
#
# Qt reads QT_SCALE_FACTOR at start, so it is an environment variable, not a
# setting in a config file. This desktop sets its environment in two places
# that have to agree (see the comment at the top of hypr/conf/environment.lua):
#
#   ~/.config/hypr/local/extra_environment.lua   the per-machine file
#   ~/.config/uwsm/env                            for sessions started by uwsm
#
# Both are written, so the value holds whichever way the session starts. Only
# the line this script owns is touched, and it is marked as such.

set -u

LUA="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/local/extra_environment.lua"
UWSM="${XDG_CONFIG_HOME:-$HOME/.config}/uwsm/env"

usage() { echo "usage: $(basename "$0") get|set <1.0-2.5>" >&2; }

# The value in the lua file: hl.env("QT_SCALE_FACTOR", "1.1")
read_lua() {
    [[ -f "$LUA" ]] || return 0
    sed -nE 's/^[[:space:]]*hl\.env\("QT_SCALE_FACTOR"[[:space:]]*,[[:space:]]*"([0-9.]+)".*/\1/p' "$LUA" | tail -n 1
}

# The value in the uwsm env file: export QT_SCALE_FACTOR=1.1
read_uwsm() {
    [[ -f "$UWSM" ]] || return 0
    sed -nE 's/^[[:space:]]*export QT_SCALE_FACTOR="?([0-9.]+)"?.*/\1/p' "$UWSM" | tail -n 1
}

# Rewrite `key` lines in a file, or append the line the caller gives.
#   set_in FILE REGEX FIND REPLACE APPEND
set_in() {
    local file=$1 regex=$2 append=$3
    mkdir -p "$(dirname "$file")"
    touch "$file" || return 1
    if grep -qE "$regex" "$file"; then
        # Replace every matching line, keeping the rest of the file as it is
        local tmp
        tmp="$(mktemp)"
        sed -E "s|^[[:space:]]*$regex.*|$append|" "$file" >"$tmp" && mv "$tmp" "$file"
    else
        printf '%s\n' "$append" >>"$file"
    fi
}

cmd_get() {
    # The lua file is the one this script treats as the source of truth
    local v
    v="$(read_lua)"
    [[ -n "$v" ]] || v="$(read_uwsm)"
    echo "${v:-1.0}"
}

cmd_set() {
    local want=${1:-}
    if ! [[ "$want" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        usage
        return 2
    fi
    # The environment variable takes a small range; beyond it Qt windows are
    # unusable, and 1.0 is the smallest that makes sense
    if ! awk -v v="$want" 'BEGIN { exit !(v >= 1.0 && v <= 2.5) }'; then
        echo "qt-scale: 1.0 to 2.5, not $want" >&2
        return 2
    fi

    # The regex has to match the whole line as sed sees it, quotes included
    set_in "$LUA" "hl\\.env\\(\"QT_SCALE_FACTOR\"[^)]*\\)" \
        "hl.env(\"QT_SCALE_FACTOR\", \"$want\") -- set by Settings > GTK and Qt" || return 1
    set_in "$UWSM" 'export QT_SCALE_FACTOR=' \
        "export QT_SCALE_FACTOR=$want" || return 1

    echo "$want"
}

case "${1:-get}" in
get) cmd_get ;;
set) cmd_set "${2:-}" ;;
*) usage ;;
esac
