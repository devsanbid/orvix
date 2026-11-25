#!/bin/bash
# =============================================================================
#
#   █   █▄█ █▄ █ █▀▀ ▄▄ █▀▄ █▀█ ▀█▀ █▀
#   █▄▄  █  █ ▀█ ██▄    █▄▀ █▄█  █  ▄█
#
#   Bootstrap: installs the latest release
#   curl -fsSL https://caioax.github.io/orvix/install | bash
#
# =============================================================================
# Clones the repo into ~/.orvix, moves main back to the newest release tag
# (vMAJOR.MINOR.PATCH, what the stable channel follows) and runs that
# release's install.sh. main keeps tracking origin's main, so orvix update
# works from there on either channel. Arguments go to install.sh
# (`| bash -s -- --dry-run`). ORVIX_BOOTSTRAP_REPO clones another repo
# =============================================================================

REPO_URL="${ORVIX_BOOTSTRAP_REPO:-https://github.com/caioax/orvix.git}"
DOTS_DIR="$HOME/.orvix"
TAG_RE='^v[0-9]+\.[0-9]+\.[0-9]+$'

step() { echo -e "\e[1;34m:: $1\e[0m"; }
fail() {
    echo -e "\e[1;31merror:\e[0m $1" >&2
    exit 1
}

# In a function called on the last line: a download cut short runs nothing
main() {
    if [[ -e "$DOTS_DIR" || -L "$DOTS_DIR" ]]; then
        fail "$DOTS_DIR already exists. If orvix is installed, \`orvix update\` updates it; otherwise move that folder away and run this again"
    fi

    if ! command -v git &>/dev/null; then
        command -v pacman &>/dev/null || fail "orvix is for Arch Linux: pacman not found"
        step "Installing git..."
        sudo pacman -S --needed --noconfirm git || fail "couldn't install git"
    fi

    step "Cloning orvix..."
    git clone --branch main "$REPO_URL" "$DOTS_DIR" || fail "couldn't clone $REPO_URL"

    local tag
    tag="$(git -C "$DOTS_DIR" tag --merged origin/main --list 'v*' --sort=-v:refname | grep -E -m1 "$TAG_RE")"
    if [[ -n "$tag" ]]; then
        step "Installing orvix $tag (the latest release)..."
        git -C "$DOTS_DIR" reset --quiet --hard "$tag" || fail "couldn't check out $tag"
    else
        step "No release yet: installing the tip of main..."
    fi

    # Piped into bash, stdin is this script: the installer's questions read
    # the terminal
    if [[ ! -t 0 ]] && { : </dev/tty; } 2>/dev/null; then
        exec </dev/tty
    fi
    cd "$DOTS_DIR" || fail "couldn't enter $DOTS_DIR"
    exec ./install.sh "$@"
}

main "$@"
