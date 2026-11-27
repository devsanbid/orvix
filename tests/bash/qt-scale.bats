#!/usr/bin/env bats
# quickshell/.config/quickshell/scripts/qt-scale.sh: QT_SCALE_FACTOR for the
# session. It is an environment variable, so it lives in the two files the
# session reads — hypr/local/extra_environment.lua and uwsm/env — and this
# script has to keep them in step without duplicating the line.

load helpers

setup() {
    orvix_setup
    export HOME="$BATS_TEST_TMPDIR/home" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/home/.config"
    mkdir -p "$HOME/.config/hypr/local" "$HOME/.config/uwsm"
    LUA="$HOME/.config/hypr/local/extra_environment.lua"
    UWSM="$HOME/.config/uwsm/env"
    SCALE="$REPO/quickshell/.config/quickshell/scripts/qt-scale.sh"
}

teardown() { repo_unchanged; }

scale() { bash "$SCALE" "$@"; }

@test "get: 1.0 when neither file has a value" {
    run scale get
    assert_success
    assert_output "1.0"
}

@test "set: writes the lua line and the uwsm line" {
    run scale set 1.25
    assert_success
    assert_output "1.25"
    grep -qx 'hl.env("QT_SCALE_FACTOR", "1.25") -- set by Settings > GTK and Qt' "$LUA"
    grep -qx 'export QT_SCALE_FACTOR=1.25' "$UWSM"
}

@test "set twice: one line, the second value" {
    scale set 1.25 >/dev/null
    scale set 1.5 >/dev/null
    scale set 1.1 >/dev/null
    assert_equal "$(grep -c QT_SCALE_FACTOR "$LUA")" "1"
    assert_equal "$(grep -c QT_SCALE_FACTOR "$UWSM")" "1"
    assert_equal "$(scale get)" "1.1"
}

@test "set: keeps the rest of the environment file" {
    printf '%s\n' 'hl.env("MY_VAR", "1")' 'hl.env("OTHER", "2")' >"$LUA"
    scale set 1.4 >/dev/null
    grep -qx 'hl.env("MY_VAR", "1")' "$LUA"
    grep -qx 'hl.env("OTHER", "2")' "$LUA"
    assert_equal "$(grep -c QT_SCALE_FACTOR "$LUA")" "1"
}

@test "set: a line already there is replaced, not appended" {
    printf '%s\n' 'hl.env("QT_SCALE_FACTOR", "2.0")' >"$LUA"
    scale set 1.2 >/dev/null
    assert_equal "$(grep -c QT_SCALE_FACTOR "$LUA")" "1"
    grep -qx 'hl.env("QT_SCALE_FACTOR", "1.2") -- set by Settings > GTK and Qt' "$LUA"
}

@test "set: out of range is refused, and nothing is written" {
    run scale set 9
    assert_failure 2
    assert_output --partial "1.0 to 2.5"
    refute [ -f "$LUA" ]
    run scale set 0.5
    assert_failure 2
    refute [ -f "$LUA" ]
}

@test "set: a non-number is a usage error" {
    run scale set abc
    assert_failure 2
    assert_output --partial "usage"
}

@test "get: falls back to the uwsm file when the lua one has no value" {
    printf '%s\n' 'export QT_SCALE_FACTOR=1.3' >"$UWSM"
    run scale get
    assert_success
    assert_output "1.3"
}
