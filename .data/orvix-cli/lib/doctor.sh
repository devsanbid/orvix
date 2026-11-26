# doctor.sh - Health checks for `orvix doctor` and Settings › System › Health
#
# Each check prints one tab-separated line:
#   <level>\t<id>\t<what>\t<state>\t<fix>
# level is "ok", "warn" (the desktop works, something is missing or off) or
# "fail" (a part of the desktop won't work). The list is fixed and ordered so
# the CLI and the Settings page show the same thing in the same order; the
# `fix` field is a command to run, shown and never run here.
#
# Packages named in `fix` are the ones .install/packages/*.sh installs (or,
# where no category has it, the plain pacman/AUR name). Every external command
# is optional: a missing one is what the check reports.

# Print one result: level, id, what, state, fix
_doctor_row() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"; }

# Is the binary on PATH?
_doctor_has() { command -v "$1" >/dev/null 2>&1; }

# Read a value from a JSON file; "" when jq or the file is missing
_doctor_jq() {
    [[ -f "$1" ]] || return 0
    _doctor_has jq || return 0
    jq -r "$2 // empty" "$1" 2>/dev/null
}

# StateService's file: what Settings saved (the repo copy is only defaults)
_doctor_state() {
    local file="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/state.json"
    _doctor_jq "$file" "$1"
}

# ======================= SESSION =======================
_doctor_hyprland() {
    if ! _doctor_has hyprctl; then
        _doctor_row fail hyprland "Hyprland" "hyprctl isn't installed" "sudo pacman -S hyprland"
        return
    fi
    if ! hyprctl version >/dev/null 2>&1; then
        _doctor_row fail hyprland "Hyprland" "Not running, or not reachable from this terminal" "log in to a Hyprland session and run it there"
        return
    fi
    local version
    version="$(hyprctl version -j 2>/dev/null | jq -r '.tag // empty' 2>/dev/null)"
    [[ -n "$version" ]] || version="running"
    _doctor_row ok hyprland "Hyprland" "$version" ""

    # A broken local/*.lua stops every bind after it
    local errors
    errors="$(hyprctl configerrors 2>/dev/null | head -n 1)"
    if [[ -n "$errors" && "$errors" != "no errors" ]]; then
        _doctor_row warn hyprland-config "Hyprland config" "$errors" "hyprctl configerrors, then fix local/*.lua and hyprctl reload"
    else
        _doctor_row ok hyprland-config "Hyprland config" "No errors" ""
    fi
}

_doctor_shell() {
    if ! _doctor_has quickshell; then
        _doctor_row fail quickshell "Quickshell" "Not installed: no bar, launcher or Settings" "yay -S quickshell-git"
        return
    fi
    if pgrep -x quickshell >/dev/null 2>&1; then
        _doctor_row ok quickshell "Quickshell" "Running" ""
    else
        _doctor_row warn quickshell "Quickshell" "Installed, not running" "orvix reload"
    fi
}

# ======================= DESKTOP SERVICES =======================
_doctor_services() {
    if _doctor_has awww-daemon; then
        if pgrep -f awww-daemon >/dev/null 2>&1; then
            _doctor_row ok wallpaper-daemon "Wallpaper daemon" "Running" ""
        else
            _doctor_row warn wallpaper-daemon "Wallpaper daemon" "Installed, not running" "log in again, or start awww-daemon"
        fi
    else
        _doctor_row fail wallpaper-daemon "Wallpaper daemon" "Not installed: no wallpaper" "sudo pacman -S awww"
    fi

    local agent=""
    local candidate
    for candidate in /usr/lib/polkit-kde-authentication-agent-1 /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 /usr/lib/polkit-gnome-authentication-agent-1; do
        if [[ -x "$candidate" ]]; then
            agent="$candidate"
            break
        fi
    done
    if [[ -z "$agent" ]]; then
        _doctor_row warn polkit "Polkit agent" "None found: apps can't ask for admin rights" "sudo pacman -S polkit-kde-agent"
    elif pgrep -f "$(basename "$agent")" >/dev/null 2>&1; then
        _doctor_row ok polkit "Polkit agent" "Running" ""
    else
        _doctor_row warn polkit "Polkit agent" "Installed, not running" "log in again"
    fi

    if _doctor_has cliphist; then
        if pgrep -f cliphist-watch >/dev/null 2>&1; then
            _doctor_row ok clipboard "Clipboard history" "Running" ""
        else
            _doctor_row warn clipboard "Clipboard history" "Installed, watcher not running" "orvix reload"
        fi
    else
        _doctor_row fail clipboard "Clipboard history" "Not installed: no clipboard history" "sudo pacman -S cliphist"
    fi

    if _doctor_has jq; then
        _doctor_row ok jq "JSON tools" "jq" ""
    else
        _doctor_row fail jq "JSON tools" "jq isn't installed: Settings can't save" "sudo pacman -S jq"
    fi
}

# ======================= THEME =======================
_doctor_theme() {
    # A glob, not find: ~/.local/themes is a symlink into the repo on installs
    # that link the themes, and find doesn't follow it
    local themes="$HOME/.local/themes" n=0
    local theme
    for theme in "$themes"/*.json; do
        [[ -f "$theme" ]] && ((n++))
    done
    if ((n == 0)); then
        _doctor_row fail themes "Themes" "No themes in ~/.local/themes" "orvix migrate run"
    else
        _doctor_row ok themes "Themes" "$n preset(s)" ""
    fi

    # Matugen writes GTK, Qt, kitty and Neovim colors from the palette
    if _doctor_has matugen; then
        _doctor_row ok matugen "Matugen" "Installed" ""
    else
        _doctor_row warn matugen "Matugen" "Not installed: GTK, Qt and terminal colors stay as they are" "sudo pacman -S matugen"
    fi

    local missing=()
    local file
    for file in "$HOME/.config/gtk-3.0/colors.css" "$HOME/.config/quickshell/state.json"; do
        [[ -e "$file" ]] || missing+=("${file/#$HOME/~}")
    done
    if ((${#missing[@]} == 0)); then
        _doctor_row ok theme-files "Theme files" "In place" ""
    else
        _doctor_row warn theme-files "Theme files" "Missing: ${missing[*]}" "pick a theme again in Settings › Theme"
    fi

    local mode name
    mode="$(_doctor_state .theme.mode)"
    name="$(_doctor_state .theme.name)"
    case "${mode:-preset}" in
    omarchy)
        if [[ -f "$HOME/.local/state/omarchy/current/theme/colors.toml" ]]; then
            _doctor_row ok theme-source "Theme source" "Following Omarchy" ""
        else
            _doctor_row fail theme-source "Theme source" "Omarchy picked, but it has no current theme" "Settings › System › Omarchy, or pick a preset in Settings › Theme"
        fi
        ;;
    auto)
        _doctor_row ok theme-source "Theme source" "Material You, from the wallpaper" ""
        ;;
    *)
        _doctor_row ok theme-source "Theme source" "Preset: ${name:-tokyonight}" ""
        ;;
    esac
}

# ======================= APPS AND TOOLS =======================
_doctor_apps() {
    local id name key bin
    while IFS='|' read -r id name key; do
        [[ -n "$id" ]] || continue
        bin="$(_doctor_state ".apps.$key.command")"
        bin="${bin%% *}"
        if [[ -z "$bin" ]]; then
            _doctor_row warn "$id" "$name" "Not set" "Settings › System › Apps"
        elif ! _doctor_has "$bin"; then
            _doctor_row fail "$id" "$name" "Not installed: $bin" "install $bin, or pick another in Settings › System › Apps"
        else
            _doctor_row ok "$id" "$name" "$bin" ""
        fi
    done <<'EOF'
terminal|Terminal|terminal
file-manager|File manager|fileManager
browser|Browser|browser
EOF

    local id name tool
    while IFS='|' read -r id name tool; do
        [[ -n "$id" ]] || continue
        if _doctor_has "$tool"; then
            _doctor_row ok "$id" "$name" "$tool" ""
        else
            _doctor_row warn "$id" "$name" "Not installed (no $tool)" "sudo pacman -S $tool"
        fi
    done <<'EOF'
screenshot|Screenshots|grim
region|Region selection|slurp
ocr|Text in screenshots|tesseract
media|Media keys|playerctl
notify|Notifications|notify-send
EOF
}

# ======================= UPDATE SOURCE =======================
_doctor_repo() {
    local dir="${ORVIX_DIR:-$HOME/.orvix}" remote
    if ! _doctor_has git; then
        _doctor_row fail git "Update source" "git isn't installed: orvix update can't run" "sudo pacman -S git"
        return
    fi
    if [[ ! -d "$dir/.git" ]]; then
        _doctor_row warn git "Update source" "$dir isn't a git clone" "clone the dotfiles to ~/.orvix to get updates"
        return
    fi
    remote="$(git -C "$dir" config --get remote.origin.url 2>/dev/null)"
    if [[ -z "$remote" ]]; then
        _doctor_row warn git "Update source" "The clone has no remote" "git -C $dir remote add origin <url>"
    else
        _doctor_row ok git "Update source" "$remote" ""
    fi

    if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null | head -n 1)" ]]; then
        _doctor_row warn git-changes "Local changes" "Files in the repo differ from the release" "orvix git status (orvix update offers to stash them)"
    else
        _doctor_row ok git-changes "Local changes" "None" ""
    fi
}

# ======================= OMARCHY =======================
# ORVIX_OMARCHY_DIR: another install tree (the tests' empty folder)
_doctor_omarchy() {
    local root="${ORVIX_OMARCHY_DIR:-/usr/share/omarchy}"
    [[ -d "$root" ]] || return 0
    local version
    version="$(head -n 1 "$root/version" 2>/dev/null)"
    _doctor_row ok omarchy "Omarchy" "${version:-installed}" ""

    if pgrep -af 'quickshell.*(/usr/share/omarchy|omarchy)/shell' >/dev/null 2>&1; then
        _doctor_row warn omarchy-shell "Omarchy shell" "Running: two bars overlap" "keep one shell (Settings › System › Omarchy)"
    else
        _doctor_row ok omarchy-shell "Omarchy shell" "Not running: Orvix owns the bar" ""
    fi
}

# ======================= ENTRY POINT =======================
# Every check, in the order both the CLI and the settings page show
orvix_doctor_checks() {
    _doctor_hyprland
    _doctor_shell
    _doctor_services
    _doctor_theme
    _doctor_apps
    _doctor_repo
    _doctor_omarchy
}
