#!/usr/bin/env bats
# `orvix bar`: the setting behind Settings › Bar › "Show the bar". The bar is a
# window, so hiding it leaves Settings reachable; this command is the way back
# from a terminal when the bar is off.

load helpers

setup() {
    orvix_setup
    export ORVIX_DIR="$REPO"
    # The command honours XDG_CONFIG_HOME; helpers.bash unsets it, and the
    # running session may export the real one, so pin it to the fake HOME
    export XDG_CONFIG_HOME="$HOME/.config"
    STATE="$HOME/.config/quickshell/state.json"
    mkdir -p "$HOME/.config/quickshell"
    echo '{"bar": {}}' >"$STATE"
}

teardown() { repo_unchanged; }

@test "bar: status says shown when nothing is set" {
    echo '{}' >"$STATE"
    run "$REPO/local/.local/bin/orvix" bar status
    assert_success
    assert_line --index 0 "Orvix's bar is shown"
}

@test "bar off: writes bar.show false, and says hidden" {
    run "$REPO/local/.local/bin/orvix" bar off
    assert_success
    assert_output "Orvix's bar is hidden"
    assert_equal "$(jq -r '.bar.show' "$STATE")" "false"
}

@test "bar on: writes bar.show true" {
    "$REPO/local/.local/bin/orvix" bar off >/dev/null
    run "$REPO/local/.local/bin/orvix" bar on
    assert_success
    assert_output "Orvix's bar is shown"
    assert_equal "$(jq -r '.bar.show' "$STATE")" "true"
}

@test "bar toggle: flips whichever way it is now" {
    echo '{"bar": {"show": true}}' >"$STATE"
    run "$REPO/local/.local/bin/orvix" bar toggle
    assert_output "Orvix's bar is hidden"
    assert_equal "$(jq -r '.bar.show' "$STATE")" "false"

    run "$REPO/local/.local/bin/orvix" bar toggle
    assert_output "Orvix's bar is shown"
    assert_equal "$(jq -r '.bar.show' "$STATE")" "true"
}

@test "bar off keeps the rest of state.json" {
    echo '{"bar": {"autoHide": true, "height": 40}, "theme": {"name": "nord"}}' >"$STATE"
    "$REPO/local/.local/bin/orvix" bar off >/dev/null
    assert_equal "$(jq -r '.bar.autoHide' "$STATE")" "true"
    assert_equal "$(jq -r '.bar.height' "$STATE")" "40"
    assert_equal "$(jq -r '.theme.name' "$STATE")" "nord"
}

@test "bar: an unknown subcommand is a usage error, and changes nothing" {
    echo '{"bar": {"show": true}}' >"$STATE"
    run "$REPO/local/.local/bin/orvix" bar sideways
    assert_failure 2
    assert_output --partial "unknown subcommand"
    assert_equal "$(jq -r '.bar.show' "$STATE")" "true"
}

@test "bar status: a missing state.json is not an error" {
    rm -f "$STATE"
    run "$REPO/local/.local/bin/orvix" bar status
    assert_success
    assert_line --index 0 "Orvix's bar is shown"
}
