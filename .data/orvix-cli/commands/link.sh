# orvix link - Link the dotfiles packages an install left out

source "$DOTS_DIR/.install/setup/stow.sh"

# What a package still needs after its link (its program, its plugin manager)
_link_hints() {
    local dir
    for dir in "$@"; do
        case "$dir" in
        kitty | ghostty | zsh | fish | tmux | fastfetch)
            command -v "$dir" &>/dev/null || echo "  $dir isn't installed: sudo pacman -S $dir"
            ;;
        nvim)
            command -v nvim &>/dev/null || echo "  Neovim isn't installed: sudo pacman -S neovim"
            ;;
        esac
        case "$dir" in
        zsh)
            [[ -d "$HOME/.oh-my-zsh" ]] ||
                echo "  ~/.zshrc needs Oh My Zsh and its plugins: ./install.sh with the terminal category sets them up"
            ;;
        tmux)
            [[ -d "$HOME/.tmux/plugins/tpm" ]] ||
                echo "  The tmux plugins need TPM: git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm, then prefix + I"
            ;;
        esac
    done
}

case "${1:-status}" in
    -h|--help)
        echo "Usage: orvix link [status|all|<package>...]"
        echo ""
        echo "Links dotfiles packages into your HOME with GNU Stow, like the installer"
        echo "does for the categories chosen. Files already at their place go to the"
        echo "backup folder first (~/.orvix-backup/<date>/); orvix unlink brings"
        echo "them back."
        echo ""
        echo "  status        Each package, linked (●) or not (○), and its category (default)"
        echo "  all           Link every package in the repo"
        echo "  <package>...  Link these: kitty, ghostty, zsh, fish, tmux, fastfetch"
        echo "                (terminal), nvim (editor), theming, kde (theming). Any"
        echo "                top-level folder with dotfiles is a package too, so a new"
        echo "                one needs no setup."
        ;;
    status)
        local dir group targets
        local -a recorded packages
        mapfile -t recorded < <(stow_recorded_packages)
        mapfile -t packages < <(stow_all_packages)
        for dir in "${packages[@]}"; do
            group="$(stow_package_group "$dir")"
            targets="$(get_stow_targets "$dir")"
            targets="${targets//$HOME/\~}"
            printf '  %s %-11s %-9s %s\n' \
                "$([[ " ${recorded[*]} " == *" $dir "* ]] && echo "●" || echo "○")" \
                "$dir" "$group" "${targets// /, }"
        done
        ;;
    all|--all)
        local -a packages
        mapfile -t packages < <(stow_all_packages)
        stow_link "${packages[@]}" || return 1
        _link_hints "${packages[@]}"
        ;;
    *)
        local dir
        local -a packages
        mapfile -t packages < <(stow_all_packages)
        for dir in "$@"; do
            if [[ " ${packages[*]} " != *" $dir "* ]]; then
                echo "orvix link: unknown package '$dir' (orvix link status lists them)"
                return 1
            fi
        done
        stow_link "$@" || return 1
        _link_hints "$@"
        ;;
esac
