# Simple fish setup for programming.
# Escape hatch: FISH_NO_TMUX=1 fish

set -g fish_greeting

# Environment that bash normally sets via Omarchy
set -q OMARCHY_PATH; or set -gx OMARCHY_PATH /usr/share/omarchy
set -q EDITOR; or set -gx EDITOR nvim
set -q VISUAL; or set -gx VISUAL $EDITOR
set -q BAT_THEME; or set -gx BAT_THEME ansi
fish_add_path -a $HOME/.local/bin
fish_add_path -a $HOME/.local/share/mise/shims
fish_add_path -a $HOME/.lscode/bin

# A program started from a session that itself runs inside tmux (for example
# Hyprland started from a tmux pane) passes TMUX and TERM_PROGRAM=tmux down to
# every child, including terminals. Checking only `set -q TMUX` would then keep
# tmux from starting in those terminals. A shell is genuinely inside tmux only
# when its own tty is one of the tmux server's pane ttys.
function __fish_in_tmux_pane --description 'True when this shell really runs in a tmux pane'
    set -q TMUX; or return 1
    set -l my_tty (command tty)
    for pane_tty in (command tmux list-panes -a -F '#{pane_tty}' 2>/dev/null)
        test "$pane_tty" = "$my_tty"; and return 0
    end
    return 1
end

if status is-interactive
    # Reattach the same tmux session after closing the terminal. Skip virtual
    # consoles so the compositor can be started there without every GUI app
    # inheriting TMUX.
    if not __fish_in_tmux_pane
            and not set -q FISH_NO_TMUX
            and not set -q NVIM
            and not set -q INSIDE_EMACS
            and not set -q VSCODE_INJECTION
            and not set -q VSCODE_PID
            and test "$TERM" != dumb
            and not string match -q '/dev/tty*' (command tty)
            and command -q tmux
        # Drop stale tmux variables inherited from an enclosing tmux client
        # before attaching, so the new client is not mistaken for a nested one.
        set -e TMUX
        set -e TMUX_PANE
        exec tmux new-session -A -s main
    end

    # Vim mode
    set -g fish_key_bindings fish_vi_key_bindings
    set -g fish_cursor_default block
    set -g fish_cursor_insert block
    set -g fish_cursor_replace_one block
    set -g fish_cursor_replace block
    set -g fish_cursor_visual block
    set -g fish_vi_force_cursor 1

    # Starship already draws the mode in the prompt
    function fish_mode_prompt
    end

    # No ghost autosuggestions
    set -g fish_autosuggestion_enabled 0

    # Syntax highlighting
    set -g fish_color_normal normal
    set -g fish_color_command blue
    set -g fish_color_keyword magenta
    set -g fish_color_quote green
    set -g fish_color_redirection cyan
    set -g fish_color_end yellow
    set -g fish_color_error red --bold
    set -g fish_color_param cyan
    set -g fish_color_option brblue
    set -g fish_color_comment brblack
    set -g fish_color_operator yellow
    set -g fish_color_escape yellow
    set -g fish_color_autosuggestion brblack
    set -g fish_color_valid_path --underline
    set -g fish_color_cancel red
    set -g fish_color_search_match --background=brblack
    set -g fish_color_selection --background=brblack
    set -g fish_pager_color_prefix blue --bold
    set -g fish_pager_color_completion normal
    set -g fish_pager_color_description yellow
    set -g fish_pager_color_progress brwhite --background=brblack
    set -g fish_pager_color_selected_background --background=brblack

    # Fast, clean programming prompt
    command -q starship; and starship init fish | source

    # zoxide: cd jumps by name, cdi is the interactive picker
    command -q zoxide; and zoxide init fish --cmd z | source

    # mise is already activated by /usr/share/fish/vendor_conf.d/mise-activate.fish.
    # Activating it a second time here only repeated the PATH setup and slowed
    # down every shell startup, so only do it if the vendor file is missing.
    if command -q mise; and not functions -q __mise_env_eval
        mise activate fish | source
    end

    # Two mise hooks are also needlessly slow:
    #  - __mise_env_eval_on_prompt runs `mise hook-env` after *every* prompt
    #    (~40 ms each). The PWD hook (__mise_cd_hook) already refreshes the
    #    environment when you cd, so this is redundant.
    #  - fish_command_not_found runs `mise hook-not-found`, which can hit the
    #    network (install/update a tool) before a typo is even reported.
    #    Fish's built-in handler reports it instantly instead.
    functions -e __mise_env_eval_on_prompt
    function fish_command_not_found
        __fish_default_command_not_found_handler $argv
    end

    alias vim nvim
    alias cls clear

    if command -q eza
        alias ls 'eza --group-directories-first --icons=auto'
        alias lsa 'ls -a'
        alias lt 'eza --tree --level=2 --long --icons --git'
    end

    function __auto_ls --on-variable PWD --description 'ls after changing directory'
        status is-command-substitution; and return
        if command -q eza
            eza --group-directories-first --icons=auto
        else
            command ls
        end
    end
end

# kimi-code, when it is installed for this user
test -d "$HOME/.kimi-code/bin"; and fish_add_path -g "$HOME/.kimi-code/bin"
