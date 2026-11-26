#!/usr/bin/env bats
# `orvix omarchy`, on a fake HOME: the bar flag (Omarchy's own, where `on`
# hides the bar and `off` shows it), the dock through the plugin registry, the
# rule in state.json, and the hooks.

load helpers

setup() {
    orvix_setup
    export ORVIX_DIR="$REPO"
    # Omarchy hardcodes $HOME/.local/state and $HOME/.config for these, so the
    # tests use the same paths, not XDG_*
    STATE_DIR="$HOME/.local/state/omarchy"
    CONFIG="$HOME/.config/omarchy"
    FLAG="$STATE_DIR/toggles/bar-off"
    SHELL_JSON="$CONFIG/shell.json"
    Orvix="$REPO/local/.local/bin/orvix"
    mkdir -p "$STATE_DIR/toggles" "$CONFIG" "$HOME/.config/quickshell"
    echo '{"omarchy": {}}' >"$HOME/.config/quickshell/state.json"
    # A tree that looks installed, so the commands run; `nstalled` empties it
    # for the tests that check the "not installed" answer
    OMARCHY_TREE="$BATS_TEST_TMPDIR/omarchy-tree"
    mkdir -p "$OMARCHY_TREE"
    export ORVIX_OMARCHY_DIR="$OMARCHY_TREE"
}

teardown() { repo_unchanged; }

omarchy_cmd() { "$Orvix" omarchy "$@"; }

# not_installed: point the detection at a folder that isn't there
not_installed() {
    export ORVIX_OMARCHY_DIR="$BATS_TEST_TMPDIR/no-omarchy"
}

# The toggle command Omarchy ships, as a stub that only flips the flag
stub_toggle() {
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    cat >"$BATS_TEST_TMPDIR/bin/omarchy-toggle-bar" <<EOF
#!/bin/bash
flag="$FLAG"
case "\${1:-toggle}" in
  on) mkdir -p "\$(dirname "\$flag")"; touch "\$flag" ;;
  off) rm -f "\$flag" ;;
  toggle) if [[ -f "\$flag" ]]; then rm -f "\$flag"; else mkdir -p "\$(dirname "\$flag")"; touch "\$flag"; fi ;;
esac
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/omarchy-toggle-bar"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
}

@test "omarchy bar off: Omarchy's flag is set, and 'on' clears it" {
    stub_toggle
    run omarchy_cmd bar off
    assert_success
    assert_output "Omarchy's bar is hidden"
    assert [ -f "$FLAG" ]

    run omarchy_cmd bar on
    assert_success
    assert_output "Omarchy's bar is shown"
    refute [ -f "$FLAG" ]
}

@test "omarchy bar: without the toggle command, the flag is written directly" {
    run omarchy_cmd bar off
    assert_success
    assert_output "Omarchy's bar is hidden"
    assert [ -f "$FLAG" ]

    run omarchy_cmd bar on
    assert_success
    refute [ -f "$FLAG" ]
}

@test "omarchy bar: a bad argument is refused, and changes nothing" {
    stub_toggle
    run omarchy_cmd bar sideways
    assert_failure 2
    assert_output --partial "bar takes 'on' or 'off'"
    refute [ -f "$FLAG" ]
}

@test "omarchy status: what shows, and whether the rule is on" {
    echo '{"omarchy": {"hideOmarchyBar": true}}' >"$HOME/.config/quickshell/state.json"
    touch "$FLAG"
    run omarchy_cmd status
    assert_success
    assert_line --partial "Omarchy bar    hidden"
    assert_line --partial "Keep hidden    on"
    assert_line --partial "Hooks          not installed"
}

@test "omarchy on: turns the rule on, hides the bar, and 'off' shows it again" {
    stub_toggle
    run omarchy_cmd on
    assert_success
    assert_line --partial "Keeping Omarchy's bar hidden"
    assert [ -f "$FLAG" ]
    assert_equal "$(jq -r '.omarchy.hideOmarchyBar' "$HOME/.config/quickshell/state.json")" "true"

    run omarchy_cmd off
    assert_success
    assert_line --partial "shown again"
    refute [ -f "$FLAG" ]
    assert_equal "$(jq -r '.omarchy.hideOmarchyBar' "$HOME/.config/quickshell/state.json")" "false"
}

@test "omarchy restore: does nothing while the rule is off" {
    echo '{"omarchy": {"hideOmarchyBar": false}}' >"$HOME/.config/quickshell/state.json"
    run omarchy_cmd restore
    assert_success
    assert_output --partial "nothing to restore"
    refute [ -f "$FLAG" ]
}

@test "omarchy restore: hides it when the rule is on (what the hooks run)" {
    echo '{"omarchy": {"hideOmarchyBar": true}}' >"$HOME/.config/quickshell/state.json"
    run omarchy_cmd restore
    assert_success
    assert [ -f "$FLAG" ]
}

@test "omarchy restore --quiet: says nothing" {
    echo '{"omarchy": {"hideOmarchyBar": true}}' >"$HOME/.config/quickshell/state.json"
    run omarchy_cmd restore --quiet
    assert_success
    assert_output ""
    assert [ -f "$FLAG" ]
}

@test "omarchy hooks install: a post-update and a post-boot hook, running restore" {
    run omarchy_cmd hooks install
    assert_success
    local hook
    for hook in post-update post-boot; do
        local file="$CONFIG/hooks/$hook.d/50-orvix-omarchy-bar"
        assert [ -x "$file" ]
        run cat "$file"
        assert_line --partial "orvix\" omarchy restore --quiet"
    done
}

@test "omarchy hooks remove: takes them away, and says so when there are none" {
    omarchy_cmd hooks install >/dev/null
    run omarchy_cmd hooks remove
    assert_success
    assert_line --partial "Removed"
    refute [ -f "$CONFIG/hooks/post-update.d/50-orvix-omarchy-bar" ]
    run omarchy_cmd hooks remove
    assert_success
    assert_output --partial "No Orvix hooks"
}

@test "omarchy dock: without a running Omarchy shell there is nothing to change" {
    run omarchy_cmd dock off
    assert_failure
    assert_output --partial "shell isn't running"
}

@test "omarchy dock: with a shell running, the plugin registry is asked" {
    stub_toggle
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    # omarchy plugin disable/enable, and a shell process for the check
    cat >"$BATS_TEST_TMPDIR/bin/omarchy" <<'EOF'
#!/bin/bash
echo "omarchy $*" >>"$STUB_LOG"
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/omarchy"
    cat >"$BATS_TEST_TMPDIR/bin/pgrep" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/bin/pgrep"
    # The shell.json the state is read from afterwards
    mkdir -p "$CONFIG"
    echo '{"disabledPlugins": ["omarchy.dock"]}' >"$SHELL_JSON"
    PATH="$BATS_TEST_TMPDIR/bin:$PATH" run omarchy_cmd dock off
    assert_success
    assert_output --partial "hidden"
    grep -q "omarchy plugin disable omarchy.dock" "$STUB_LOG"
}

@test "omarchy: an unknown subcommand is a usage error" {
    run omarchy_cmd sideways
    assert_failure 2
    assert_output --partial "unknown subcommand"
}

@test "omarchy: nothing at all when Omarchy isn't installed" {
    not_installed
    run omarchy_cmd status
    assert_failure
    assert_output "Omarchy isn't installed"

    run omarchy_cmd bar off
    assert_failure
    assert_output --partial "isn't installed"
    refute [ -f "$FLAG" ]
}
