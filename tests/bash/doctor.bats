#!/usr/bin/env bats
# `orvix doctor` and .data/orvix-cli/lib/doctor.sh, on a fake HOME: every
# check, the three output formats and the exit status. The commands it looks
# for are stubs at the front of PATH, and the test's HOME has no Omarchy, so
# the checks are the same on any machine.

load helpers

setup() {
    orvix_setup
    export ORVIX_DIR="$REPO"
    # Where the test puts the commands the doctor looks for
    STUBS="$BATS_TEST_TMPDIR/doctor-stubs"
    mkdir -p "$STUBS"
    export PATH="$STUBS:$PATH"
    # No Omarchy, and nothing of Orvix running: the test decides what is
    export ORVIX_OMARCHY_DIR="$BATS_TEST_TMPDIR/no-omarchy"
    printf '#!/bin/bash\nexit 1\n' >"$STUBS/pgrep"
    chmod +x "$STUBS/pgrep"
    # The files a normal install has
    mkdir -p "$HOME/.config/quickshell" "$HOME/.config/gtk-3.0" "$HOME/.local/themes"
    echo '{"theme": {"mode": "preset", "name": "tokyonight"}, "apps": {"terminal": {"command": "kitty"}, "fileManager": {"command": "dolphin"}, "browser": {"command": "zen-browser"}}}' >"$HOME/.config/quickshell/state.json"
    : >"$HOME/.config/gtk-3.0/colors.css"
    echo '{"name": "Tokyo Night"}' >"$HOME/.local/themes/tokyonight.json"
}

teardown() { repo_unchanged; }

# stub NAME [EXIT]: a command at the front of PATH
stub() {
    printf '#!/bin/bash\nexit %s\n' "${2:-0}" >"$STUBS/$1"
    chmod +x "$STUBS/$1"
}

doctor() { "$REPO/local/.local/bin/orvix" doctor "$@"; }

# The whole desktop installed, nothing to report but the update source
all_installed() {
    local tool
    for tool in hyprctl quickshell awww-daemon matugen kitty dolphin zen-browser grim slurp tesseract playerctl cliphist; do
        stub "$tool"
    done
}

# running NAME...: the pgrep stub answers 0 when the pattern names one of
# these, 1 otherwise (pgrep -af 'pattern')
running() {
    local names
    names="$(printf '%s\n' "$@")"
    printf '#!/bin/bash\nnames=%s\nfor n in $names; do\n  for a in "$@"; do\n    case "$a" in *"$n"*) exit 0;; esac\n  done\ndone\nexit 1\n' "'$names'" >"$STUBS/pgrep"
    chmod +x "$STUBS/pgrep"
}

@test "doctor: every check, and a summary with the count" {
    all_installed
    run doctor
    assert_success
    assert_line --partial "Hyprland"
    assert_line --partial "Terminal             kitty"
    assert_line --partial "Theme source         Preset: tokyonight"
    # jq renders the JSON; it comes from /usr/bin
    assert_line --partial "JSON tools"
    assert_line --regexp '^[0-9]+ ok, [0-9]+ warning\(s\), [0-9]+ failure\(s\)$'
}

@test "doctor: a missing tool is a failure, with the command that installs it" {
    # A PATH of symlinks to the tools a check needs, without hyprctl (the
    # real /usr/bin has it on a machine that runs Orvix)
    local safe="$BATS_TEST_TMPDIR/safe-bin" tool
    mkdir -p "$safe"
    for tool in bash sh head find sed grep jq wc basename cat sort; do
        ln -sf "$(command -v "$tool")" "$safe/$tool"
    done
    printf '#!/bin/bash\nexit 1\n' >"$safe/pgrep"
    chmod +x "$safe/pgrep"
    run env PATH="$safe" ORVIX_DIR="$REPO" ORVIX_OMARCHY_DIR="$ORVIX_OMARCHY_DIR" HOME="$HOME" "$REPO/local/.local/bin/orvix" doctor
    assert_failure
    assert_line --partial "FAIL  Hyprland"
    assert_line --partial "sudo pacman -S hyprland"
}

@test "doctor: an installed but stopped shell is a warning, not a failure" {
    all_installed
    run doctor
    assert_line --partial "warn  Quickshell           Installed, not running"
    assert_line --partial "orvix reload"
}

@test "doctor: problems are listed before what works" {
    all_installed
    # A missing app is a failure; everything else is fine
    echo '{"apps": {"terminal": {"command": "kitty-missing"}}}' >"$HOME/.config/quickshell/state.json"
    run doctor
    assert_failure
    local first_ok last_fail
    first_ok="$(printf '%s\n' "${lines[@]}" | grep -n '  ok  ' | head -n1 | cut -d: -f1)"
    last_fail="$(printf '%s\n' "${lines[@]}" | grep -n 'FAIL' | tail -n1 | cut -d: -f1)"
    ((first_ok > last_fail))
}

@test "doctor: --quiet prints only failures, and nothing when all is fine" {
    all_installed
    running cliphist-watch polkit
    run doctor --quiet
    # No ok lines, no warnings: the update source warns here (no remote)
    assert_equal "$output" ""
}

@test "doctor: --json is machine-readable and counts the levels" {
    stub quickshell
    run doctor --json
    assert_failure
    echo "$output" | jq -e '.checks | length > 5'
    echo "$output" | jq -e '.fail >= 1'
    # quickshell is a stub that exits 0, so the check is ok
    echo "$output" | jq -e 'any(.checks[]; .id == "quickshell")'
}

@test "doctor: a bad option is a usage error" {
    run doctor --nope
    assert_failure 2
    assert_output --partial "unknown option"
}

@test "doctor: Omarchy's checks appear only when it's installed" {
    run doctor --json
    echo "$output" | jq -e '[.checks[].id] | index("omarchy") == null'
}

@test "doctor: the theme source comes from state.json, not the defaults" {
    all_installed
    jq '.theme.mode = "omarchy"' "$HOME/.config/quickshell/state.json" >"$HOME/state.tmp" &&
        mv "$HOME/state.tmp" "$HOME/.config/quickshell/state.json"
    run doctor
    assert_failure
    assert_line --partial "Omarchy picked, but it has no current theme"
}
