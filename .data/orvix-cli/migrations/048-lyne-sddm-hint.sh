# 048-lyne-sddm-hint.sh - Point SDDM users to the lyne-sddm login screen
#
# New installs ask whether to build lyne-sddm (a login screen in the lock
# screen's style that follows the theme). Existing installs only get a hint,
# once: changing someone's login screen during orvix update without asking
# would be a surprise, and the build needs sudo. Nothing is installed here.
# Where SDDM isn't the display manager, or lyne-sddm is already installed,
# it says nothing. One installed by its own install.sh gets told that
# orvix sddm install moves it to the package orvix update keeps up to date,
# keeping its settings.

source "$DOTS_DIR/.data/orvix-cli/lib/sddm.sh"

if pacman -Q lyne-sddm-git &>/dev/null || pacman -Q lyne-sddm &>/dev/null; then
    :
elif _sddm_script_install; then
    echo "   lyne-sddm can now be a package that orvix update keeps up to date:"
    echo "   orvix sddm install replaces the script install and keeps its settings"
elif [[ "$(sddm_dm)" == sddm ]]; then
    echo "   New: lyne-sddm, a login screen in the lock screen's style that follows"
    echo "   the theme. Install it with: orvix sddm install"
fi
true
