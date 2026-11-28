#!/usr/bin/env bash
# ghostty-apply.sh - Write ghostty's theme file, and make open windows follow it
#
#   ghostty-apply.sh <theme.conf>   write the colours and reload every window
#   ghostty-apply.sh --clear        remove the file (Omarchy's theme shows)
#
# Ghostty reloads its whole config, included files too, on SIGUSR2. A window
# started later reads the same file when it opens.

set -u

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DEST="$CONFIG_HOME/ghostty/current-theme.conf"

die() {
    echo "ghostty-apply: $*" >&2
    exit 1
}

reload() {
    if pgrep -x ghostty >/dev/null 2>&1; then
        pkill -USR2 -x ghostty 2>/dev/null || true
        echo "ghostty: reloaded $(pgrep -x ghostty | wc -l) window(s)"
    else
        echo "ghostty: the theme file is written"
    fi
}

if [[ "${1:-}" == "--clear" ]]; then
    rm -f "$DEST" || die "cannot remove $DEST"
    reload
    exit 0
fi

[[ $# -ge 1 ]] || die "usage: $(basename "$0") <theme.conf> | --clear"
SRC=$1
[[ -f "$SRC" ]] || die "no such file: $SRC"

mkdir -p "$(dirname "$DEST")" || die "cannot create $(dirname "$DEST")"
cp -f "$SRC" "$DEST" || die "cannot write $DEST"

reload
exit 0
