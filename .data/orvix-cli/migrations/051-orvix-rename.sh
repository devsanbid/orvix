# 051-orvix-rename.sh - finish the Lyne -> Orvix rename on an existing install
#
# The code, CLI and config paths are Orvix now. This migration adopts what
# already exists on the machine so nothing looks different after updating:
#   * the Neovim palette cache (~/.cache/lyne -> ~/.cache/orvix)
#   * the KDE color scheme (Lyne.colors -> Orvix.colors)
#   * the repo folder (~/.lyne-dots -> ~/.orvix), when it's the default place
#   * the symlinks that point into the repo
# Nothing is deleted: the old folder stays as a symlink to the new one.

local home="$HOME"

# 1. Files the shell/Neovim read from the cache
if [[ -f "$home/.cache/lyne/nvim.json" && ! -f "$home/.cache/orvix/nvim.json" ]]; then
    mkdir -p "$home/.cache/orvix"
    cp "$home/.cache/lyne/nvim.json" "$home/.cache/orvix/nvim.json"
fi

# 2. KDE color scheme (KDE apps read it by path)
if [[ -f "$home/.local/share/color-schemes/Lyne.colors" && ! -f "$home/.local/share/color-schemes/Orvix.colors" ]]; then
    cp "$home/.local/share/color-schemes/Lyne.colors" "$home/.local/share/color-schemes/Orvix.colors"
fi

# 3. The repo folder itself, only from the default location and only when
# the new one is free. DOTS_DIR is the folder the CLI runs from.
local real_dots target
real_dots="$(realpath -m "$DOTS_DIR")"
target="$home/.orvix"
if [[ "$real_dots" == "$home/.lyne-dots" && ! -e "$target" ]]; then
    if mv "$real_dots" "$target"; then
        ln -s .orvix "$home/.lyne-dots"
        echo "   Moved the dotfiles folder to ~/.orvix (old path kept as a symlink)"
    fi
fi

# 4. Repoint the symlinks the installer made (configs, CLI, wallpapers).
# Only links whose target names the old folder, never user files.
if [[ -d "$target" ]]; then
    local root link dest
    for root in "$home/.config" "$home/.local/bin" "$home/.local/share" \
        "$home/.local/scripts" "$home/.local/themes" "$home/.local/wallpapers"; do
        [[ -d "$root" ]] || continue
        while IFS= read -r link; do
            dest="$(readlink "$link")" || continue
            [[ "$dest" == *".lyne-dots"* ]] || continue
            ln -sfn "${dest//.lyne-dots/.orvix}" "$link" &&
                echo "   Relinked ${link#"$home"/}"
        done < <(find "$root" -maxdepth 3 -type l -lname '*\.lyne-dots*' 2>/dev/null)
    done

    # The new CLI name on PATH, next to the old one
    if [[ -x "$target/local/.local/bin/orvix" && ! -e "$home/.local/bin/orvix" ]]; then
        mkdir -p "$home/.local/bin"
        ln -sfn "../../.orvix/local/.local/bin/orvix" "$home/.local/bin/orvix" &&
            echo "   Added ~/.local/bin/orvix"
    fi
fi

return 0
