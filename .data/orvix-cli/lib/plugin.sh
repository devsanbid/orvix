# plugin.sh - The Orvix plugin store: manifests, validation, install, state
#
# The one backend for `orvix plugin` and Settings › Plugins. Everything here
# works on a plugin folder and on ~/.config/orvix/plugins, and prints
# tab-separated rows so both callers read the same thing.
#
# The format is docs/PLUGIN_SPEC.md. This file is the only place that decides
# what a valid manifest is, which plugins are official, and where a plugin
# lives — the CLI and the shell both go through it.

ORVIX_PLUGIN_DIR="${ORVIX_PLUGIN_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/orvix/plugins}"
ORVIX_PLUGIN_STATE="${ORVIX_PLUGIN_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/orvix/plugins.json}"
ORVIX_PLUGIN_SOURCES="${ORVIX_PLUGIN_SOURCES:-${XDG_CONFIG_HOME:-$HOME/.config}/orvix/plugin-sources.json}"

# The account whose plugins are Official unless plugin-sources.json says
# otherwise. A GitHub URL is not enough: the owner has to match.
ORVIX_PLUGIN_OFFICIAL_DEFAULT="devsanbid"

_plugin_have() { command -v "$1" >/dev/null 2>&1; }

# jq is the parser everywhere; without it nothing here can work
_plugin_jq() {
    _plugin_have jq || {
        echo "orvix plugin: jq is required" >&2
        return 1
    }
}

# The accounts that count as official: the defaults, then whatever
# ~/.config/orvix/plugin-sources.json adds or replaces ("official": ["..."])
plugin_official_owners() {
    local owners="$ORVIX_PLUGIN_OFFICIAL_DEFAULT"
    if [[ -f "$ORVIX_PLUGIN_SOURCES" ]] && _plugin_have jq; then
        local extra
        extra="$(jq -r '(.official // [])[]?' "$ORVIX_PLUGIN_SOURCES" 2>/dev/null | paste -sd' ' -)"
        [[ -n "$extra" ]] && owners="$owners $extra"
    fi
    # Space-separated on purpose: each account on its own line, deduped
    tr ' ' '\n' <<<"$owners" | sed '/^$/d' | sort -u
}

# plugin_is_official AUTHOR REPOSITORY: official when either the author or the
# repository's owner is an official account. A plugin installed from a URL is
# NOT official for that reason alone.
plugin_is_official() {
    local author="${1,,}" repo="${2:-}" owner="" official
    # https://github.com/OWNER/repo, git@github.com:OWNER/repo.git
    if [[ "$repo" =~ github\.com[:/]+([^/]+)/ ]]; then
        owner="${BASH_REMATCH[1],,}"
    fi
    while IFS= read -r official; do
        [[ -n "$official" ]] || continue
        official="${official,,}"
        [[ "$author" == "$official" || "$owner" == "$official" ]] && return 0
    done < <(plugin_official_owners)
    return 1
}

# plugin_validate DIR: the manifest problems, one per line. Empty means valid.
# Reads only; never writes.
plugin_validate() {
    local dir=$1 manifest="$1/manifest.json" problems=() id author kind kindname
    if [[ ! -d "$dir" ]]; then
        echo "not a folder: $dir"
        return
    fi
    if [[ ! -f "$manifest" ]]; then
        echo "manifest.json is missing"
        return
    fi
    if ! _plugin_have jq; then
        echo "jq is required to read a manifest"
        return
    fi
    if ! jq -e . "$manifest" >/dev/null 2>&1; then
        echo "manifest.json is not valid JSON"
        return
    fi

    # schemaVersion: exactly 1 for now. A newer schema is not guessed at.
    local schema
    schema="$(jq -r '.schemaVersion // empty' "$manifest")"
    if [[ -z "$schema" ]]; then
        problems+=("schemaVersion is missing")
    elif [[ "$schema" != "1" ]]; then
        problems+=("schemaVersion $schema is newer than this Orvix understands (1)")
    fi

    id="$(jq -r '.id // empty' "$manifest")"
    if [[ -z "$id" ]]; then
        problems+=("id is missing")
    elif [[ ! "$id" =~ ^[a-z0-9][a-z0-9-]{1,63}$ ]]; then
        problems+=("id '$id' must be 2-64 characters of a-z, 0-9 and -")
    fi

    for field in name version author; do
        [[ -n "$(jq -r ".$field // empty" "$manifest")" ]] || problems+=("$field is missing")
    done

    local version
    version="$(jq -r '.version // empty' "$manifest")"
    if [[ -n "$version" && ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        problems+=("version '$version' is not MAJOR.MINOR.PATCH")
    fi

    # kinds and the entry point each one needs
    local -A needs=([bar-widget]=barWidget [panel]=panel [service]=service [settings]=settings [script]=script)
    local kinds
    kinds="$(jq -r '(.kinds // [])[]?' "$manifest")"
    if [[ -z "$kinds" ]]; then
        problems+=("kinds is missing or empty")
    fi
    while IFS= read -r kind; do
        [[ -n "$kind" ]] || continue
        kindname="${needs[$kind]:-}"
        if [[ -z "$kindname" ]]; then
            problems+=("kind '$kind' is not one of: ${!needs[*]}")
            continue
        fi
        local entry
        entry="$(jq -r ".entryPoints.$kindname // empty" "$manifest")"
        if [[ -z "$entry" ]]; then
            problems+=("kinds has '$kind' but entryPoints.$kindname is missing")
        elif [[ "$entry" == /* || "$entry" == *..* ]]; then
            # Checked before existence: ../..///etc/passwd exists, and
            # "does not exist" would hide what is really wrong
            problems+=("entryPoints.$kindname '$entry' leaves the plugin folder")
        elif [[ ! -f "$dir/$entry" ]]; then
            problems+=("entryPoints.$kindname '$entry' does not exist in the folder")
        fi
    done <<<"$kinds"

    # bar-widget needs the block the bar reads to place it
    if [[ "$kinds" == *bar-widget* ]] && ! jq -e '.barWidget.category | type == "string"' "$manifest" >/dev/null 2>&1; then
        problems+=("a bar-widget needs barWidget.category (Time, Network, System, …)")
    fi

    # permissions must be known ones: a typo would silently grant nothing
    local perm
    while IFS= read -r perm; do
        [[ -n "$perm" ]] || continue
        case "$perm" in
        files:write | commands:run | network | system:settings) ;;
        *) problems+=("permission '$perm' is not known (files:write, commands:run, network, system:settings)") ;;
        esac
    done < <(jq -r '(.permissions // [])[]?' "$manifest")

    local p
    for p in "${problems[@]}"; do
        printf '%s\n' "$p"
    done
}

# plugin_requires PROBLEMS: given a validated folder, what is missing on this
# machine (commands and files), one per line. Orvix's own version is checked
# by the shell, which knows it.
plugin_missing_requirements() {
    local manifest="$1/manifest.json" cmd file
    [[ -f "$manifest" ]] || return 0
    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] || continue
        _plugin_have "$cmd" || printf 'command not found: %s\n' "$cmd"
    done < <(jq -r '(.requires.commands // [])[]?' "$manifest" 2>/dev/null)
    while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        # ~ expands; anything else is taken as it is
        local path="${file/#\~/$HOME}"
        [[ -e "$path" ]] || printf 'missing: %s\n' "$file"
    done < <(jq -r '(.requires.files // [])[]?' "$manifest" 2>/dev/null)
}
