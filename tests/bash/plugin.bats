#!/usr/bin/env bats
# `orvix plugin` and lib/plugin.sh: manifests, validation, the store, and the
# Official/third-party rule. The plugin format is docs/PLUGIN_SPEC.md.

load helpers

setup() {
    orvix_setup
    export ORVIX_DIR="$REPO"
    # The store and the state live under XDG_*; pin them to the fake HOME
    export XDG_CONFIG_HOME="$HOME/.config" XDG_STATE_HOME="$HOME/.local/state"
    STORE="$HOME/.config/orvix/plugins"
    STATE="$HOME/.local/state/orvix/plugins.json"
    ORVIX_CLI="$REPO/local/.local/bin/orvix"
    mkdir -p "$HOME/.config/quickshell"
    echo '{}' >"$HOME/.config/quickshell/state.json"
}

teardown() { repo_unchanged; }

# make_plugin DIR ID [extra json]: a valid plugin folder with a bar widget
make_plugin() {
    local dir=$1 id=$2 extra=${3:-}
    mkdir -p "$dir"
    cat >"$dir/manifest.json" <<EOF
{
  "schemaVersion": 1,
  "id": "$id",
  "name": "${id^} plugin",
  "version": "1.0.0",
  "author": "devsanbid",
  "kinds": ["bar-widget"],
  "entryPoints": { "barWidget": "main.qml" },
  "barWidget": { "category": "System" }
  $extra
}
EOF
    echo 'import QtQuick
Item {}' >"$dir/main.qml"
}

plugin() { "$ORVIX_CLI" plugin "$@"; }

@test "validate: a good folder is valid" {
    make_plugin "$BATS_TEST_TMPDIR/good" good
    run plugin validate "$BATS_TEST_TMPDIR/good"
    assert_success
    assert_output "valid: good 1.0.0"
}

@test "validate: every problem is reported, not just the first" {
    mkdir -p "$BATS_TEST_TMPDIR/bad"
    cat >"$BATS_TEST_TMPDIR/bad/manifest.json" <<'EOF'
{"schemaVersion": 2, "id": "Bad_ID", "name": "", "version": "1.0", "author": "",
 "kinds": ["nope"], "entryPoints": {"barWidget": "missing.qml"},
 "permissions": ["root"]}
EOF
    run plugin validate "$BATS_TEST_TMPDIR/bad"
    assert_failure
    assert_line --partial "schemaVersion 2 is newer"
    assert_line --partial "id 'Bad_ID' must be"
    assert_line --partial "name is missing"
    assert_line --partial "author is missing"
    assert_line --partial "version '1.0' is not MAJOR.MINOR.PATCH"
    assert_line --partial "kind 'nope' is not one of"
    assert_line --partial "permission 'root' is not known"
}

@test "validate: an entry point that leaves the folder is refused" {
    mkdir -p "$BATS_TEST_TMPDIR/esc"
    cat >"$BATS_TEST_TMPDIR/esc/manifest.json" <<'EOF'
{"schemaVersion": 1, "id": "esc", "name": "Esc", "version": "1.0.0",
 "author": "x", "kinds": ["settings"], "entryPoints": {"settings": "../../../etc/passwd"}}
EOF
    run plugin validate "$BATS_TEST_TMPDIR/esc"
    assert_failure
    assert_line --partial "leaves the plugin folder"
}

@test "validate: a missing manifest, or broken JSON" {
    mkdir -p "$BATS_TEST_TMPDIR/empty"
    run plugin validate "$BATS_TEST_TMPDIR/empty"
    assert_failure
    assert_output --partial "manifest.json is missing"

    mkdir -p "$BATS_TEST_TMPDIR/broken"
    echo 'not json' >"$BATS_TEST_TMPDIR/broken/manifest.json"
    run plugin validate "$BATS_TEST_TMPDIR/broken"
    assert_failure
    assert_output --partial "not valid JSON"
}

@test "validate: a bar-widget needs the category the bar places it by" {
    mkdir -p "$BATS_TEST_TMPDIR/nocat"
    cat >"$BATS_TEST_TMPDIR/nocat/manifest.json" <<'EOF'
{"schemaVersion": 1, "id": "nocat", "name": "No cat", "version": "1.0.0",
 "author": "x", "kinds": ["bar-widget"], "entryPoints": {"barWidget": "m.qml"}}
EOF
    echo 'import QtQuick
Item {}' >"$BATS_TEST_TMPDIR/nocat/m.qml"
    run plugin validate "$BATS_TEST_TMPDIR/nocat"
    assert_failure
    assert_line --partial "needs barWidget.category"
}

@test "install: a folder goes into the store, and lists as official" {
    make_plugin "$BATS_TEST_TMPDIR/src" speedup
    run plugin install "$BATS_TEST_TMPDIR/src"
    assert_success
    assert [ -f "$STORE/speedup/manifest.json" ]
    assert_line --partial "(official)"

    run plugin list
    assert_success
    assert_line --partial "speedup"
    assert_line --partial "official"
    assert_line --partial "disabled"
}

@test "install: a third-party author is labelled third-party, not official" {
    mkdir -p "$BATS_TEST_TMPDIR/third"
    cat >"$BATS_TEST_TMPDIR/third/manifest.json" <<'EOF'
{"schemaVersion": 1, "id": "third", "name": "Third", "version": "0.1.0",
 "author": "someone-else", "repository": "https://github.com/someone-else/third",
 "kinds": ["settings"], "entryPoints": {"settings": "s.qml"}}
EOF
    echo 'import QtQuick
Item {}' >"$BATS_TEST_TMPDIR/third/s.qml"
    run plugin install "$BATS_TEST_TMPDIR/third"
    assert_success
    assert_line --partial "(third-party)"
}

@test "install: an invalid plugin is refused and nothing is copied" {
    mkdir -p "$BATS_TEST_TMPDIR/bad"
    echo '{"schemaVersion": 1}' >"$BATS_TEST_TMPDIR/bad/manifest.json"
    run plugin install "$BATS_TEST_TMPDIR/bad"
    assert_failure
    assert_line --partial "is not a valid plugin"
    refute [ -d "$STORE" ]
}

@test "install: a plugin whose needs aren't met installs but says so" {
    mkdir -p "$BATS_TEST_TMPDIR/needs"
    cat >"$BATS_TEST_TMPDIR/needs/manifest.json" <<'EOF'
{"schemaVersion": 1, "id": "needs", "name": "Needs", "version": "1.0.0",
 "author": "devsanbid", "kinds": ["settings"], "entryPoints": {"settings": "s.qml"},
 "requires": {"commands": ["definitely-not-a-real-binary"]}}
EOF
    echo 'import QtQuick
Item {}' >"$BATS_TEST_TMPDIR/needs/s.qml"
    run plugin install "$BATS_TEST_TMPDIR/needs"
    assert_success
    assert_line --partial "command not found: definitely-not-a-real-binary"
    # Installed, but enabling is refused until the requirement is there
    run plugin enable needs
    assert_failure
    assert_output --partial "needs something this machine doesn't have"
}

@test "enable and disable: the state file, and nothing deleted" {
    make_plugin "$BATS_TEST_TMPDIR/src" demo
    plugin install "$BATS_TEST_TMPDIR/src" >/dev/null

    run plugin enable demo
    assert_success
    assert_equal "$(jq -r '.plugins.demo.enabled' "$STATE")" "true"
    assert [ -f "$STORE/demo/manifest.json" ]

    run plugin disable demo
    assert_success
    assert_equal "$(jq -r '.plugins.demo.enabled' "$STATE")" "false"
    assert [ -f "$STORE/demo/manifest.json" ]
}

@test "update: the newer version replaces the old one" {
    # The installed copy has to name where updates come from, so the source
    # manifest carries the repository from the start
    make_plugin "$BATS_TEST_TMPDIR/src" up ",
  \"repository\": \"$BATS_TEST_TMPDIR/new\""
    plugin install "$BATS_TEST_TMPDIR/src" >/dev/null
    assert_equal "$(jq -r .version "$STORE/up/manifest.json")" "1.0.0"

    # The repository now holds a newer version of the same id
    make_plugin "$BATS_TEST_TMPDIR/new" up ",
  \"repository\": \"$BATS_TEST_TMPDIR/new\""
    jq '.version = "2.0.0"' "$BATS_TEST_TMPDIR/new/manifest.json" >"$BATS_TEST_TMPDIR/new/m.tmp" &&
        mv "$BATS_TEST_TMPDIR/new/m.tmp" "$BATS_TEST_TMPDIR/new/manifest.json"

    run plugin update up
    assert_success
    assert_equal "$(jq -r .version "$STORE/up/manifest.json")" "2.0.0"
}

@test "remove: the folder goes, and its state with it" {
    make_plugin "$BATS_TEST_TMPDIR/src" gone
    plugin install "$BATS_TEST_TMPDIR/src" >/dev/null
    plugin enable gone >/dev/null

    run plugin remove gone
    assert_success
    refute [ -d "$STORE/gone" ]
    assert_equal "$(jq -r '.plugins.gone // "absent"' "$STATE")" "absent"
}

@test "remove --keep-settings: the folder goes, the settings stay" {
    make_plugin "$BATS_TEST_TMPDIR/src" keep
    plugin install "$BATS_TEST_TMPDIR/src" >/dev/null
    plugin enable keep >/dev/null

    run plugin remove keep --keep-settings
    assert_success
    refute [ -d "$STORE/keep" ]
    assert_equal "$(jq -r '.plugins.keep.enabled' "$STATE")" "true"
}

@test "info: everything the manifest declares" {
    make_plugin "$BATS_TEST_TMPDIR/src" info
    plugin install "$BATS_TEST_TMPDIR/src" >/dev/null
    run plugin info info
    assert_success
    assert_line --partial "id:          info"
    assert_line --partial "version:     1.0.0"
    assert_line --partial "source:      official"
    assert_line --partial "permissions: none (it can only draw)"
}

@test "sources: lists the official accounts" {
    run plugin sources
    assert_success
    assert_line --partial "devsanbid"
}

@test "plugin: an unknown command is a usage error" {
    run plugin sideways
    assert_failure 2
    assert_output --partial "unknown command"
}
