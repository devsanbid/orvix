#!/usr/bin/env bash
# kitty-apply.sh - Write kitty's theme file, and make open windows follow it
#
#   kitty-apply.sh <theme.conf>
#
# Copies the generated theme over ~/.config/kitty/current-theme.conf and then
# pushes the same colours into every running kitty, through its remote-control
# socket.
#
# Why the socket and not SIGUSR1: kitty's manual says kill -SIGUSR1 reloads the
# config, but the build in use here (0.51.1) does not install a handler for it
# — /proc/<pid>/status shows SIGUSR1 neither caught nor ignored, so the signal
# is quietly discarded, and a theme switch only took effect in a new terminal.
# `kitten @ set-colors` changes the colours of a running window for real, and
# works on an included file, which is what current-theme.conf is.
#
# The socket comes from kitty.conf's `listen_on`, one per instance
# (orvix-kitty-<pid>). A kitty started before that line existed has no socket;
# it keeps its colours until it restarts, and this script says so.

set -u

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
DEST="$CONFIG_HOME/kitty/current-theme.conf"
SOCKET_PREFIX="orvix-kitty-"

die() {
    echo "kitty-apply: $*" >&2
    exit 1
}

[[ $# -ge 1 ]] || die "usage: $(basename "$0") <theme.conf>"
SRC=$1
[[ -f "$SRC" ]] || die "no such file: $SRC"

mkdir -p "$(dirname "$DEST")" || die "cannot create $(dirname "$DEST")"
# A copy, not a move: the caller keeps its own file
cp -f "$SRC" "$DEST" || die "cannot write $DEST"

# Push the colours into each open window. The socket name carries the pid, so
# every running instance is reached. `set-colors -a` applies to all windows in
# that instance.
applied=0
stale=0
for pid in $(pgrep -x kitty 2>/dev/null); do
    sock="$RUNTIME/$SOCKET_PREFIX$pid"
    if [[ -S "$sock" ]]; then
        if kitty @ --to "unix:$sock" set-colors -a -c "$DEST" >/dev/null 2>&1; then
            applied=$((applied + 1))
        else
            stale=$((stale + 1))
        fi
    else
        # Running since before listen_on was in the config
        stale=$((stale + 1))
    fi
done

if ((applied > 0)); then
    echo "kitty: $applied window(s) updated"
elif ((stale > 0)); then
    # Not an error: the file is right and the next window will use it
    echo "kitty: the theme file is written; open windows keep their colours until they restart"
else
    echo "kitty: the theme file is written"
fi

exit 0
