#!/usr/bin/env bats
# Where the orvix CLI and the session find the repo: the CLI from its own path
# (~/.local/bin/orvix links into the repo), uwsm/env's ORVIX_DIR from its own
# link; neither needs the repo at ~/.orvix nor the project's zsh

load helpers

setup() {
    orvix_setup
    # A clone somewhere else, with a migration of its own to tell it apart
    CLONE="$BATS_TEST_TMPDIR/elsewhere/dots"
    mkdir -p "$CLONE/local/.local/bin" "$CLONE/.data/orvix-cli/migrations"
    # ORVIX_TEST_CLI: a copy of the CLI (to sabotage it)
    cp "${ORVIX_TEST_CLI:-$REPO/local/.local/bin/orvix}" "$CLONE/local/.local/bin/orvix"
    ln -s "$REPO/.data/orvix-cli/commands" "$REPO/.data/orvix-cli/lib" "$CLONE/.data/orvix-cli/"
    ln -s "$REPO/.install" "$CLONE/"
    : >"$CLONE/.data/orvix-cli/migrations/001-only-in-the-clone.sh"
    mkdir -p "$HOME/.local/bin"
    ln -s "$CLONE/local/.local/bin/orvix" "$HOME/.local/bin/orvix"
}

# A plain bash login-less environment: no zsh, no ORVIX_DIR, only ~/.local/bin
plain() {
    env -i HOME="$HOME" PATH="$HOME/.local/bin:/usr/bin:/bin" bash -c "$1"
}

@test "the CLI finds the clone it's in, through the link, from plain bash" {
    run plain 'orvix migrate list'
    assert_success
    assert_line --partial "001-only-in-the-clone.sh"
    refute_line --partial "038-record-stowed-packages.sh"
    run plain 'orvix help'
    assert_success
    assert_line --partial "Usage: orvix <command>"
}

@test "ORVIX_DIR wins over the CLI's own path" {
    run env -i HOME="$HOME" PATH="$HOME/.local/bin:/usr/bin:/bin" ORVIX_DIR="$REPO" bash -c 'orvix migrate list'
    assert_success
    assert_line --partial "038-record-stowed-packages.sh"
}

# uwsm sources the file with sh
uwsm_env() {
    env -i HOME="$HOME" PATH=/usr/bin:/bin sh -c '. "$HOME/.config/uwsm/env" && printf "%s\n" "$ORVIX_DIR"'
}

@test "uwsm/env: ORVIX_DIR is the repo its link reaches, else ~/.orvix" {
    mkdir -p "$HOME/.config/uwsm"
    ln -s "$REPO/hyprland/.config/uwsm/env" "$HOME/.config/uwsm/env"
    run uwsm_env
    assert_success
    assert_output "$(realpath "$REPO")"

    # A clone elsewhere, linked the same way
    mkdir -p "$CLONE/hyprland/.config/uwsm"
    cp "$REPO/hyprland/.config/uwsm/env" "$CLONE/hyprland/.config/uwsm/"
    ln -sfn "$CLONE/hyprland/.config/uwsm/env" "$HOME/.config/uwsm/env"
    run uwsm_env
    assert_output "$(realpath "$CLONE")"

    # Copied, not linked
    rm "$HOME/.config/uwsm/env"
    cp "$REPO/hyprland/.config/uwsm/env" "$HOME/.config/uwsm/env"
    run uwsm_env
    assert_output "$HOME/.orvix"
}

@test "orvix reload and the autostart start Quickshell with 2 jemalloc arenas" {
    # Stand-ins for this test only: the real pkill would hit the user's shell
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/bin/bash\necho "quickshell $* MALLOC_CONF=${MALLOC_CONF:-}" >>"$STUB_LOG"\n' >"$BATS_TEST_TMPDIR/bin/quickshell"
    printf '#!/bin/bash\necho "pkill $*" >>"$STUB_LOG"\nexit 1\n' >"$BATS_TEST_TMPDIR/bin/pkill"
    chmod +x "$BATS_TEST_TMPDIR/bin/"*
    run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" ORVIX_DIR="$REPO" "$REPO/local/.local/bin/orvix" reload
    assert_success
    # setsid starts it in the background
    for _ in {1..50}; do grep -q '^quickshell  MALLOC' "$STUB_LOG" && break; sleep 0.1; done
    run cat "$STUB_LOG"
    assert_line "quickshell kill MALLOC_CONF="
    assert_line "pkill -KILL -x quickshell"
    assert_line "quickshell  MALLOC_CONF=narenas:2"

    run grep -F 'name = "Quickshell",        command = "env MALLOC_CONF=narenas:2 quickshell"' "$REPO/hyprland/.config/hypr/conf/autostart.lua"
    assert_success
}
