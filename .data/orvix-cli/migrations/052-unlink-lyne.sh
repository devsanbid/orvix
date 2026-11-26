# 052-unlink-lyne.sh - Finish the Lyne -> Orvix rename: drop the shims
#
# The rename (migration 051) kept a few old names so a live install didn't
# break mid-session. This migration removes them now that the release is out:
#   * the theme wallpapers lyne-<theme>-contour.jpg -> orvix-<theme>-contour.jpg
#     (the repo and every theme JSON now name the orvix- file)
#   * the ~/.local/bin/lyne command shim (orvix is the only CLI now)
#   * the ~/.lyne-dots symlink, once nothing points into it any more
#   * the old caches and files the shim-era code left behind:
#     ~/.cache/lyne, ~/.local/share/lyne, Lyne.colors when Orvix.colors exists
#   * the conf/legacy.lua Lua globals (the generated local files call the
#     orvix_* names since migration 051; this repoints any that didn't)
#
# Deliberately kept: the third-party lyne-sddm package and its theme (its own
# project, installed and updated under that name), and LYNE_SDDM_REF, which
# lyne-sddm's PKGBUILD reads.

local home="$HOME"
changed=0

# 1. Theme wallpapers already in the user's library, and the theme files that
#    name them. Only the old names, only when the new one isn't there yet.
if [[ -d "$home/.local/wallpapers/themes" ]]; then
    local old new
    while IFS= read -r old; do
        [[ -n "$old" ]] || continue
        new="${old/\/lyne-/\/orvix-}"
        [[ -e "$new" ]] && continue
        mv "$old" "$new" && ((changed++))
    done < <(find "$home/.local/wallpapers/themes" -maxdepth 2 -name 'lyne-*-contour.jpg' 2>/dev/null)
fi

if [[ -d "$home/.local/themes" ]] && command -v jq >/dev/null 2>&1; then
    local json tmp
    for json in "$home/.local/themes"/*.json; do
        [[ -f "$json" ]] || continue
        grep -q 'lyne-[a-z-]*-contour\.jpg' "$json" || continue
        tmp="$(mktemp)"
        if jq 'if .wallpaper then .wallpaper |= sub("(?<p>/)?lyne-(?<t>[a-z-]+)-contour\\.jpg$"; "\(.p // "")orvix-\(.t)-contour.jpg") else . end' "$json" >"$tmp"; then
            mv "$tmp" "$json"
            ((changed++))
        else
            rm -f "$tmp"
        fi
    done
fi

# 2. The command shim: orvix is the CLI now
if [[ -L "$home/.local/bin/lyne" || -f "$home/.local/bin/lyne" ]]; then
    rm -f "$home/.local/bin/lyne" && {
        echo "   Removed the lyne command shim (~/.local/bin/lyne)"
        ((changed++))
    }
fi
# A link to it in other PATH folders (some installs put it in ~/.local/scripts)
local dir
for dir in "$home/.local/scripts" "$home/bin"; do
    [[ -L "$dir/lyne" ]] && rm -f "$dir/lyne" && ((changed++))
done

# 3. The old repo folder, once nothing points into it. A real folder is not
#    touched: it may be someone's clone.
if [[ -L "$home/.lyne-dots" ]]; then
    local target_link
    target_link="$(readlink "$home/.lyne-dots")"
    if [[ "$target_link" == ".orvix" || "$target_link" == "$home/.orvix" ]]; then
        # Any symlink still naming it (a theme, a config) is repointed first
        local link dest
        while IFS= read -r link; do
            dest="$(readlink "$link")" || continue
            ln -sfn "${dest//.lyne-dots/.orvix}" "$link"
        done < <(find "$home/.config" "$home/.local" -maxdepth 4 -type l -lname '*\.lyne-dots*' 2>/dev/null)
        rm -f "$home/.lyne-dots" && {
            echo "   Removed the old repository link (~/.lyne-dots)"
            ((changed++))
        }
    fi
fi

# 4. The shim-era caches and files, only when the Orvix one exists (so nothing
#    is lost if the migration order ever changes)
if [[ -d "$home/.cache/lyne" && -d "$home/.cache/orvix" ]]; then
    rm -rf "$home/.cache/lyne" && ((changed++))
fi
if [[ -d "$home/.local/share/lyne" && -d "$home/.local/share/orvix" ]]; then
    rm -rf "$home/.local/share/lyne" && ((changed++))
fi
if [[ -f "$home/.local/share/color-schemes/Lyne.colors" && -f "$home/.local/share/color-schemes/Orvix.colors" ]]; then
    rm -f "$home/.local/share/color-schemes/Lyne.colors" && ((changed++))
fi

# 5. The desktop entry the shim-era code wrote for the editor
if [[ -f "$home/.local/share/applications/lyne-editor.desktop" ]]; then
    rm -f "$home/.local/share/applications/lyne-editor.desktop"
    # Its Orvix replacement is written by default-apps.sh, which reads the
    # editor from state itself
    local script="$DOTS_DIR/quickshell/.config/quickshell/scripts/default-apps.sh"
    [[ -x "$script" ]] && "$script" apply-all >/dev/null 2>&1
    ((changed++))
fi

# 6. Generated local files still calling the old Lua globals
if [[ -d "$home/.config/hypr/local" ]]; then
    local lua
    while IFS= read -r lua; do
        sed -i -E 's/\blyne_(apps|specials|specials_fallback|workspaces|workspace_step|workspaces_swap|workspaces_forget|lid_rules|autostart|autostart_import|rebind|bind_preset|keyboard_import|set_blur_ignore_alpha)\b/orvix_\1/g' "$lua" && ((changed++))
    done < <(grep -rlE '\blyne_[a-z_]+\b' "$home/.config/hypr/local" --include='*.lua' 2>/dev/null)
fi

# 7. Paths in state.json that name the old repo folder (the wallpaper in use,
#    favorites): the folder is gone now, so they would point at nothing
local state="${XDG_CONFIG_HOME:-$home/.config}/quickshell/state.json"
if [[ -f "$state" ]] && command -v jq >/dev/null 2>&1 && grep -q '\.lyne-dots' "$state"; then
    local tmp
    tmp="$(mktemp)"
    if jq 'walk(if type == "string" then sub("\\.lyne-dots/"; ".orvix/") else . end)' "$state" >"$tmp"; then
        mv "$tmp" "$state"
        ((changed++))
    else
        rm -f "$tmp"
    fi
fi

if ((changed)); then
    echo "   Unlinked the last Lyne names ($changed item(s) updated)"
fi
return 0
