# orvix plugin - Install, enable, disable, update and remove Orvix plugins
#
# The store is ~/.config/orvix/plugins/<id>/; what is enabled and each
# plugin's settings live in ~/.local/state/orvix/plugins.json. The format is
# docs/PLUGIN_SPEC.md, and Settings › Plugins reads the same state, so a
# change made here shows up there without a restart.

local subcmd="${1:-list}"
shift 2>/dev/null || true

source "$DOTS_DIR/.data/orvix-cli/lib/plugin.sh"

_tab() { printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$@"; }

# "enabled" / "disabled" / "error" for a plugin id, from the state file
_state_of() {
    local id=$1
    [[ -f "$ORVIX_PLUGIN_STATE" ]] || {
        echo disabled
        return
    }
    jq -r --arg id "$id" '.plugins[$id].enabled // false | if . then "enabled" else "disabled" end' "$ORVIX_PLUGIN_STATE" 2>/dev/null || echo disabled
}

# The manifest value, or empty
_manifest() {
    jq -r "$2 // empty" "$1/manifest.json" 2>/dev/null
}

# Write enabled/settings for a plugin, creating the state file
_state_set() {
    local id=$1 key=$2 value=$3
    _plugin_jq || return 1
    mkdir -p "$(dirname "$ORVIX_PLUGIN_STATE")"
    [[ -f "$ORVIX_PLUGIN_STATE" ]] || echo '{"plugins":{}}' >"$ORVIX_PLUGIN_STATE"
    local tmp
    tmp="$(mktemp)"
    if jq --arg id "$id" --arg k "$key" --argjson v "$value" '.plugins[$id] = ((.plugins[$id] // {}) | .[$k] = $v)' "$ORVIX_PLUGIN_STATE" >"$tmp" 2>/dev/null; then
        mv "$tmp" "$ORVIX_PLUGIN_STATE"
    else
        rm -f "$tmp"
        echo "orvix plugin: couldn't write $ORVIX_PLUGIN_STATE" >&2
        return 1
    fi
}

# Where a plugin came from, and whether that makes it official
_source_line() {
    local manifest=$1 author repo
    author="$(_manifest "$(dirname "$manifest")" '.author')"
    repo="$(_manifest "$(dirname "$manifest")" '.repository // .homepage')"
    if plugin_is_official "$author" "$repo"; then
        printf 'official'
    else
        printf 'third-party'
    fi
}

# Every installed plugin, one row each:
#   id  name  version  source  state  kinds
_list_rows() {
    local dir manifest id name version state kinds
    [[ -d "$ORVIX_PLUGIN_DIR" ]] || return 0
    for dir in "$ORVIX_PLUGIN_DIR"/*/; do
        manifest="$dir/manifest.json"
        [[ -f "$manifest" ]] || continue
        id="$(_manifest "$dir" '.id')"
        [[ -n "$id" ]] || id="$(basename "$dir")"
        name="$(_manifest "$dir" '.name')"
        version="$(_manifest "$dir" '.version')"
        kinds="$(_manifest "$dir" '.kinds | join(",")')"
        state="$(_state_of "$id")"
        _tab "$id" "$name" "$version" "$(_source_line "$manifest")" "$state" "$kinds"
    done
}

# Install from a local folder or a git URL into the store. The manifest is
# validated before anything is copied; a plugin that fails is not installed.
_install() {
    local source=$1 id="" temp="" problems
    _plugin_jq || return 1

    case "$source" in
    /* | ./* | ../*)
        # A folder on disk: taken as it is (an update from a local checkout)
        ;;
    github:* | http* | git@*)
        _plugin_have git || {
            echo "orvix plugin: git is required to install from a URL" >&2
            return 1
        }
        temp="$(mktemp -d)"
        local url="$source"
        [[ "$source" == github:* ]] && url="https://github.com/${source#github:}.git"
        echo "   Cloning $url"
        if ! git clone --depth 1 -q "$url" "$temp" 2>/dev/null; then
            rm -rf "$temp"
            echo "orvix plugin: couldn't clone $url" >&2
            return 1
        fi
        source="$temp"
        ;;
    esac

    [[ -f "$source/manifest.json" ]] || {
        echo "orvix plugin: no manifest.json in $source" >&2
        [[ -n "$temp" ]] && rm -rf "$temp"
        return 1
    }

    problems="$(plugin_validate "$source")"
    if [[ -n "$problems" ]]; then
        echo "orvix plugin: $source is not a valid plugin:" >&2
        printf '  %s\n' "$problems" >&2
        [[ -n "$temp" ]] && rm -rf "$temp"
        return 1
    fi

    id="$(_manifest "$source" '.id')"
    local dest="$ORVIX_PLUGIN_DIR/$id"
    if [[ -e "$dest" ]]; then
        # Same id already there: an install of a newer version is an update
        local old new
        old="$(_manifest "$dest" '.version')"
        new="$(_manifest "$source" '.version')"
        if [[ "$old" == "$new" ]]; then
            echo "orvix plugin: $id $old is already installed"
            [[ -n "$temp" ]] && rm -rf "$temp"
            return 0
        fi
        echo "   $id $old -> $new"
        _swap "$source" "$dest" || return 1
    else
        mkdir -p "$ORVIX_PLUGIN_DIR"
        cp -a "$source" "$dest" || {
            echo "orvix plugin: couldn't copy into $dest" >&2
            return 1
        }
    fi
    [[ -n "$temp" ]] && rm -rf "$temp"

    # What it asks for that this machine doesn't have
    local missing
    missing="$(plugin_missing_requirements "$dest")"
    if [[ -n "$missing" ]]; then
        echo "   Installed, but it needs:"
        while IFS= read -r line; do printf '     %s\n' "$line"; done <<<"$missing"
        echo "   Enable it anyway with: orvix plugin enable $id"
        return 0
    fi
    echo "   Installed $id $(_manifest "$dest" '.version') ($(_source_line "$dest/manifest.json"))"
    echo "   Enable it with: orvix plugin enable $id"
}

# Replace dest with source, keeping the old one until the new one is in place
_swap() {
    local source=$1 dest=$2 backup
    backup="$dest.old.$$"
    mv "$dest" "$backup" || return 1
    if cp -a "$source" "$dest"; then
        rm -rf "$backup"
        return 0
    fi
    # The new one didn't land: put the old one back
    rm -rf "$dest"
    mv "$backup" "$dest"
    echo "orvix plugin: the install failed, the previous version is back" >&2
    return 1
}

case "$subcmd" in
    -h | --help)
        echo "Usage: orvix plugin <command> [args]"
        echo ""
        echo "Orvix plugins: bar widgets, panels, services and their settings. A"
        echo "plugin is a folder with a manifest.json; the format and the rules are"
        echo "in docs/PLUGIN_SPEC.md. Settings › Plugins shows the same plugins."
        echo ""
        echo "Commands:"
        echo "  list                    Installed plugins, with their state"
        echo "  info <id>               Everything the manifest declares"
        echo "  install <path|url>      A folder, or github:owner/repo (or any git URL)"
        echo "  enable <id>             Load it (checks what it needs first)"
        echo "  disable <id>            Unload it; nothing is deleted"
        echo "  update [<id> | --all]   Re-fetch from the plugin's repository"
        echo "  remove <id> [--keep-settings]"
        echo "  validate <path>         Check a folder against the spec"
        echo "  sources                  The accounts whose plugins are Official"
        ;;
    list)
        if [[ ! -d "$ORVIX_PLUGIN_DIR" ]] || [[ -z "$(ls -A "$ORVIX_PLUGIN_DIR" 2>/dev/null)" ]]; then
            echo "No plugins installed."
            echo ""
            echo "Install one with: orvix plugin install github:devsanbid/orvix-browser-speedup"
            return 0
        fi
        printf '%-22s %-28s %-9s %-12s %-9s %s\n' "ID" "NAME" "VERSION" "SOURCE" "STATE" "KINDS"
        _list_rows | while IFS=$'\t' read -r id name version source state kinds; do
            printf '%-22s %-28s %-9s %-12s %-9s %s\n' "$id" "${name:0:28}" "$version" "$source" "$state" "$kinds"
        done
        ;;
    info)
        local id="${1:-}"
        [[ -n "$id" ]] || {
            echo "Usage: orvix plugin info <id>" >&2
            return 2
        }
        local dir="$ORVIX_PLUGIN_DIR/$id"
        [[ -f "$dir/manifest.json" ]] || {
            echo "orvix plugin: '$id' isn't installed (orvix plugin list)" >&2
            return 1
        }
        _plugin_jq || return 1
        jq -r '
            "id:          \(.id)",
            "name:        \(.name)",
            "version:     \(.version)",
            "author:      \(.author)",
            "license:     \(.license // "none declared")",
            "description: \(.description // "")",
            "repository:  \(.repository // .homepage // "none declared")",
            "kinds:       \((.kinds // []) | join(", "))",
            "permissions: \((.permissions // []) | if length == 0 then "none (it can only draw)" else join(", ") end)",
            "requires:    \(.requires // {} | to_entries | map("\(.key)=\(.value)") | if length == 0 then "nothing" else join(", ") end)"
        ' "$dir/manifest.json"
        echo "source:      $(_source_line "$dir/manifest.json")"
        echo "state:       $(_state_of "$id")"
        local missing
        missing="$(plugin_missing_requirements "$dir")"
        if [[ -n "$missing" ]]; then
            echo "missing:"
            while IFS= read -r line; do printf '  %s\n' "$line"; done <<<"$missing"
        fi
        ;;
    install)
        local source="${1:-}"
        [[ -n "$source" ]] || {
            echo "Usage: orvix plugin install <path|github:owner/repo>" >&2
            return 2
        }
        _install "$source"
        ;;
    validate)
        local path="${1:-}"
        [[ -n "$path" ]] || {
            echo "Usage: orvix plugin validate <path>" >&2
            return 2
        }
        local problems
        problems="$(plugin_validate "$path")"
        if [[ -z "$problems" ]]; then
            echo "valid: $(_manifest "$path" '.id') $(_manifest "$path" '.version')"
            return 0
        fi
        echo "invalid:" >&2
        printf '  %s\n' "$problems" >&2
        return 1
        ;;
    enable)
        local id="${1:-}"
        local dir="$ORVIX_PLUGIN_DIR/$id"
        [[ -n "$id" ]] || {
            echo "Usage: orvix plugin enable <id>" >&2
            return 2
        }
        [[ -f "$dir/manifest.json" ]] || {
            echo "orvix plugin: '$id' isn't installed" >&2
            return 1
        }
        local missing
        missing="$(plugin_missing_requirements "$dir")"
        if [[ -n "$missing" ]]; then
            echo "orvix plugin: '$id' needs something this machine doesn't have:" >&2
            while IFS= read -r line; do printf '  %s\n' "$line" >&2; done <<<"$missing"
            return 1
        fi
        _state_set "$id" enabled true || return 1
        echo "Enabled $id. It loads with the shell; 'orvix reload' now if it should show at once."
        ;;
    disable)
        local id="${1:-}"
        [[ -n "$id" ]] || {
            echo "Usage: orvix plugin disable <id>" >&2
            return 2
        }
        _state_set "$id" enabled false || return 1
        echo "Disabled $id. Nothing was deleted."
        ;;
    update)
        local target="${1:-}"
        [[ -n "$target" ]] || {
            echo "Usage: orvix plugin update <id|--all>" >&2
            return 2
        }
        local ids=()
        if [[ "$target" == "--all" ]]; then
            local d
            for d in "$ORVIX_PLUGIN_DIR"/*/; do
                [[ -f "$d/manifest.json" ]] && ids+=("$(_manifest "$d" '.id')")
            done
        else
            ids=("$target")
        fi
        local id repo
        for id in "${ids[@]}"; do
            [[ -n "$id" ]] || continue
            local dir="$ORVIX_PLUGIN_DIR/$id"
            if [[ ! -f "$dir/manifest.json" ]]; then
                echo "orvix plugin: '$id' isn't installed" >&2
                continue
            fi
            repo="$(_manifest "$dir" '.repository // .homepage')"
            if [[ -z "$repo" ]]; then
                echo "   $id declares no repository, nothing to update from"
                continue
            fi
            _install "$repo"
        done
        ;;
    remove)
        local id="${1:-}" keep=""
        [[ "${2:-}" == "--keep-settings" ]] && keep=1
        [[ -n "$id" ]] || {
            echo "Usage: orvix plugin remove <id> [--keep-settings]" >&2
            return 2
        }
        local dir="$ORVIX_PLUGIN_DIR/$id"
        if [[ ! -d "$dir" ]]; then
            echo "orvix plugin: '$id' isn't installed" >&2
            return 1
        fi
        rm -rf "$dir" || return 1
        if [[ -z "$keep" ]] && [[ -f "$ORVIX_PLUGIN_STATE" ]] && _plugin_have jq; then
            local tmp
            tmp="$(mktemp)"
            if jq --arg id "$id" 'del(.plugins[$id])' "$ORVIX_PLUGIN_STATE" >"$tmp" 2>/dev/null; then
                mv "$tmp" "$ORVIX_PLUGIN_STATE"
            else
                rm -f "$tmp"
            fi
        fi
        echo "Removed $id."
        ;;
    sources)
        echo "Official plugins come from:"
        plugin_official_owners | sed 's/^/  /'
        echo ""
        echo "Add more in $ORVIX_PLUGIN_SOURCES:"
        echo '  {"official": ["another-account"]}'
        ;;
    *)
        echo "orvix plugin: unknown command '$subcmd' (orvix plugin --help lists them)" >&2
        return 2
        ;;
esac
